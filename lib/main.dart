import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/add_saving_screen.dart';
import 'screens/quests_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..load(),
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.mint)),
      );
    }

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
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddSavingScreen())),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.mint.withOpacity(0.15),
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
            NavigationDestination(
                icon: Icon(Icons.history),
                label: 'ประวัติ'),
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
