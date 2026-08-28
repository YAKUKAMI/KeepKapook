import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/backup_file_service.dart';
import '../services/notifications/notification_controller.dart';
import '../state/app_state.dart';
import '../state/backup.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/notification_schedule.dart';
import '../widgets/notification_settings_card.dart';
import '../widgets/simulation_notice.dart';
import 'achievements_screen.dart';
import 'unallocated_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _backupFiles = BackupFileService();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final notifications = context.watch<NotificationController?>();
    final notificationGoalName = selectReminderGoalName(
      app.activeGoals.map((goal) => goal.name),
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('ตั้งค่า',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _section('เกี่ยวกับแอป', const [
              SimulationNotice(),
            ]),
            _section('โปรไฟล์', [
              TextFormField(
                initialValue: app.user.name,
                onFieldSubmitted: app.setName,
                decoration: const InputDecoration(
                  labelText: 'ชื่อเล่น',
                  helperText: 'กด Enter เพื่อบันทึก',
                ),
              ),
            ]),
            _section('โหมดผู้ออม (เพดานแนะนำ/วัน)', [
              Row(
                children: SaverMode.values.map((m) {
                  final active = app.user.mode == m;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: active
                              ? AppColors.mint.withValues(alpha: 0.15)
                              : null,
                          side: BorderSide(
                              color: active ? AppColors.mint : Colors.black12),
                        ),
                        onPressed: () => app.setMode(m),
                        child: Text(
                            m == SaverMode.child ? '🧒 เด็ก' : '🧑 ผู้ใหญ่'),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                  'เพดานปัจจุบัน (Lv.${app.level}): ${formatMoney(app.dailyCapSatang)}/วัน — เป็นเป้าหมายแนะนำ (ต่อรายการไม่เกิน ${formatMoney(maxMoneyInputSatang)})',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedText)),
            ]),
            if (notifications?.isSupported ?? false)
              NotificationSettingsCard(
                controller: notifications!,
                goalName: notificationGoalName,
              ),
            _section('ทางลัด', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('ความสำเร็จ'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AchievementsScreen())),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wallet_outlined),
                title: const Text('เงินที่ยังไม่จัดสรร'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UnallocatedScreen())),
              ),
            ]),
            _section('จัดการข้อมูล', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('สำรองข้อมูล'),
                subtitle: const Text('บันทึกหรือแชร์ไฟล์ JSON ไว้นอกแอป'),
                onTap: () => _exportBackup(context, app),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('กู้คืนข้อมูล'),
                subtitle: const Text('เลือกไฟล์สำรองและตรวจสอบก่อนเขียนทับ'),
                onTap: () => _importBackup(context, app),
              ),
              const Divider(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.white,
                      title: const Text('ล้างข้อมูลทั้งหมด?'),
                      content: const Text(
                          'กระปุก รายการ รายรับจ่าย และ EXP ทั้งหมดจะถูกลบ แล้วเริ่มตั้งค่าใหม่'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('ยกเลิก')),
                        FilledButton(
                          onPressed: () {
                            app.resetDemo();
                            Navigator.pop(ctx);
                          },
                          child: const Text('ล้างทั้งหมด'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('ล้างข้อมูลทั้งหมด'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kCardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

  Future<void> _exportBackup(BuildContext context, AppState app) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final exportedAt = DateTime.now();
      final appVersion = await _backupFiles.appVersion();
      final json = createBackupJson(
        state: app.toJson(),
        exportedAt: exportedAt,
        appVersion: appVersion,
      );
      if (!context.mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await _backupFiles.shareBackup(
        json: json,
        fileName: backupFileName(exportedAt),
        sharePositionOrigin: origin,
      );
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('สร้างไฟล์สำรองเรียบร้อยแล้ว')),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('สร้างไฟล์สำรองไม่สำเร็จ กรุณาลองอีกครั้ง'),
        ),
      );
    }
  }

  Future<void> _importBackup(BuildContext context, AppState app) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final raw = await _backupFiles.pickBackupJson();
      if (raw == null || !context.mounted) return;
      final preview = validateBackupJson(raw);
      final confirmed = await _confirmRestore(context, preview);
      if (confirmed != true || !context.mounted) return;

      await app.restoreBackup(preview);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('กู้คืนข้อมูลเรียบร้อยแล้ว')),
      );
    } on BackupValidationException catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.userMessage)));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'กู้คืนข้อมูลไม่สำเร็จ ข้อมูลปัจจุบันยังไม่ถูกเขียนทับ',
          ),
        ),
      );
    }
  }

  Future<bool?> _confirmRestore(
    BuildContext context,
    BackupPreview preview,
  ) {
    final localExportedAt = preview.exportedAt.toLocal();
    final exportTime = TimeOfDay.fromDateTime(localExportedAt).format(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('ยืนยันกู้คืนข้อมูล'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ข้อมูลที่จะได้กลับมา'),
              const SizedBox(height: 10),
              _previewRow('วันที่สำรอง',
                  '${formatThaiDate(localExportedAt)} เวลา $exportTime'),
              _previewRow('เวอร์ชันแอป', preview.appVersion),
              _previewRow('กระปุก', '${preview.goalCount} กระปุก'),
              _previewRow(
                  'รายการออม', '${preview.savingTransactionCount} รายการ'),
              _previewRow(
                  'รายรับ-รายจ่าย', '${preview.ledgerEntryCount} รายการ'),
              _previewRow('ยอดออมรวม', formatMoney(preview.totalSavedSatang)),
              _previewRow(
                  'ยังไม่จัดสรร', formatMoney(preview.unallocatedSatang)),
              const SizedBox(height: 12),
              const Text(
                'ข้อมูลปัจจุบันทั้งหมดจะถูกเขียนทับ โดยระบบจะสำรองข้อมูลปัจจุบันไว้ก่อนเสมอ',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('เขียนทับและกู้คืน'),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
