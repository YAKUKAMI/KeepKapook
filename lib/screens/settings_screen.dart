import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'achievements_screen.dart';
import 'unallocated_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('ตั้งค่า',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

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
                          backgroundColor:
                              active ? AppColors.mint.withOpacity(0.15) : null,
                          side: BorderSide(
                              color: active
                                  ? AppColors.mint
                                  : Colors.black12),
                        ),
                        onPressed: () => app.setMode(m),
                        child: Text(m == SaverMode.child ? '🧒 เด็ก' : '🧑 ผู้ใหญ่'),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                  'เพดานปัจจุบัน (Lv.${app.level}): ${formatMoney(app.dailyCap)}/วัน — เป็นเป้าหมายแนะนำ บันทึกเงินจริงได้ไม่จำกัด',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedText)),
            ]),

            _section('ทางลัด', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('ความสำเร็จ'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AchievementsScreen())),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wallet_outlined),
                title: const Text('เงินที่ยังไม่จัดสรร'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UnallocatedScreen())),
              ),
            ]),

            _section('จัดการข้อมูล', [
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
}
