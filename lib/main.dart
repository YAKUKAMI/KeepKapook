import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/notifications/notification_controller.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/quests_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'utils/notification_schedule.dart';
import 'widgets/conversational_entry_sheet.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..load()),
        ChangeNotifierProvider(
          create: (_) => NotificationController()..load(),
        ),
      ],
      child: const KeepKapookApp(),
    ),
  );
}

class KeepKapookApp extends StatelessWidget {
  const KeepKapookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeepKapook',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _handledRecordSavedSerial = 0;
  bool _notificationWorkScheduled = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final notifications = context.watch<NotificationController?>();
    if (!app.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.mint)),
      );
    }

    _scheduleNotificationWork(app, notifications);

    late final Widget content;
    if (!app.user.onboarded) {
      content = const OnboardingScreen();
    } else {
      final pages = [
        const _TitledScaffold(title: 'KeepKapook', child: DashboardScreen()),
        const GoalsScreen(),
        const QuestsScreen(),
        const HistoryScreen(),
        const SettingsScreen(),
      ];

      content = Scaffold(
        body: SafeArea(child: pages[_index]),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.coral,
          tooltip: 'พิมพ์บันทึกรายการ',
          onPressed: () => showConversationalEntrySheet(context),
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.mint.withValues(alpha: 0.15),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'ภาพรวม'),
            NavigationDestination(
                icon: Icon(Icons.savings_outlined),
                selectedIcon: Icon(Icons.savings),
                label: 'กระปุก'),
            NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'ภารกิจ'),
            NavigationDestination(icon: Icon(Icons.history), label: 'ประวัติ'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'ตั้งค่า'),
          ],
        ),
      );
    }

    final loadErrorMessage = app.loadErrorMessage;
    if (loadErrorMessage == null) return content;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: MaterialBanner(
            content: Text(loadErrorMessage),
            backgroundColor: AppColors.warmYellow,
            actions: [
              TextButton(
                onPressed: app.clearLoadErrorMessage,
                child: const Text('รับทราบ'),
              ),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  void _scheduleNotificationWork(
    AppState app,
    NotificationController? notifications,
  ) {
    if (!app.user.onboarded ||
        notifications == null ||
        !notifications.isSupported ||
        !notifications.loaded ||
        app.recordSavedSerial <= _handledRecordSavedSerial ||
        _notificationWorkScheduled) {
      return;
    }
    _handledRecordSavedSerial = app.recordSavedSerial;
    _notificationWorkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationWorkScheduled = false;
      if (!mounted) return;
      unawaited(_handleRecordSaved(app, notifications));
    });
  }

  Future<void> _handleRecordSaved(
    AppState app,
    NotificationController notifications,
  ) async {
    final goalName = selectReminderGoalName(
      app.activeGoals.map((goal) => goal.name),
    );
    if (notifications.preferences.permissionPromptHandled) {
      await notifications.refreshSchedules(goalName: goalName);
      return;
    }
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('ให้เราช่วยเตือนแบบเบา ๆ ไหม?'),
        content: const Text(
          'KeepKapook เตือนได้ 2 แบบตามที่คุณเลือก\n\n'
          '• กลับมาบันทึกประจำวัน เวลาเริ่มต้น 20:00\n'
          '• ดูสรุปสัปดาห์ เช้าวันจันทร์ เวลาเริ่มต้น 09:00\n\n'
          'เปลี่ยนเวลาหรือปิดแยกได้ในตั้งค่า และข้อมูลไม่ออกจากเครื่อง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ไม่ใช้การเตือน'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('เปิดการเตือน'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (enable != true) {
      await notifications.declinePermissionOffer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ได้เลย แอปจะไม่ถามสิทธิ์ซ้ำและยังใช้ได้ตามปกติ'),
        ),
      );
      return;
    }
    final granted = await notifications.acceptPermissionOffer(
      goalName: goalName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'เปิดการเตือนแล้ว ปรับเวลาได้ที่หน้าตั้งค่า'
              : 'ไม่เป็นไร แอปจะไม่ถามสิทธิ์ซ้ำและยังใช้ได้ตามปกติ',
        ),
      ),
    );
  }
}

class _TitledScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _TitledScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🐷', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.deepGreen)),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
