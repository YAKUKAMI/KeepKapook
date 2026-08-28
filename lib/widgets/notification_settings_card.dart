import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notifications/notification_controller.dart';
import '../theme/app_theme.dart';
import '../utils/notification_schedule.dart';

class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({
    super.key,
    required this.controller,
    this.goalName,
  });

  final NotificationController controller;
  final String? goalName;

  @override
  Widget build(BuildContext context) {
    final preferences = controller.preferences;
    final canEdit = preferences.permissionGranted && !controller.busy;
    return Container(
      key: const Key('notification-settings-section'),
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
            const Text(
              'การแจ้งเตือน',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _permissionMessage(preferences),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const Key('daily-notification-switch'),
              contentPadding: EdgeInsets.zero,
              value: preferences.dailyEnabled,
              onChanged: canEdit
                  ? (enabled) => unawaited(
                        controller.setDailyEnabled(
                          enabled,
                          goalName: goalName,
                        ),
                      )
                  : null,
              title: const Text('บันทึกประจำวัน'),
              subtitle: const Text('ชวนกลับมาเติมความคืบหน้าวันละครั้ง'),
            ),
            ListTile(
              key: const Key('daily-notification-time'),
              contentPadding: EdgeInsets.zero,
              enabled: canEdit,
              leading: const Icon(Icons.schedule),
              title: const Text('เวลาบันทึกประจำวัน'),
              trailing: Text(
                formatReminderTime(preferences.dailyTime),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: canEdit
                  ? () => unawaited(_pickTime(context, daily: true))
                  : null,
            ),
            const Divider(),
            SwitchListTile(
              key: const Key('weekly-notification-switch'),
              contentPadding: EdgeInsets.zero,
              value: preferences.weeklyEnabled,
              onChanged: canEdit
                  ? (enabled) => unawaited(
                        controller.setWeeklyEnabled(
                          enabled,
                          goalName: goalName,
                        ),
                      )
                  : null,
              title: const Text('ดูสรุปสัปดาห์'),
              subtitle: const Text('เช้าวันจันทร์ สัปดาห์ละครั้ง'),
            ),
            ListTile(
              key: const Key('weekly-notification-time'),
              contentPadding: EdgeInsets.zero,
              enabled: canEdit,
              leading: const Icon(Icons.calendar_view_week_outlined),
              title: const Text('เวลาสรุปวันจันทร์'),
              trailing: Text(
                formatReminderTime(preferences.weeklyTime),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: canEdit
                  ? () => unawaited(_pickTime(context, daily: false))
                  : null,
            ),
            if (controller.errorMessage case final message?) ...[
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
              TextButton(
                onPressed: controller.clearErrorMessage,
                child: const Text('รับทราบ'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _permissionMessage(NotificationPreferences preferences) {
    if (preferences.permissionGranted) {
      return 'ทำงานในเครื่องเท่านั้น ไม่มี push server และไม่ส่งข้อมูลออกไป';
    }
    if (preferences.permissionPromptHandled) {
      return 'ปิดการแจ้งเตือนอยู่ แอปจะไม่ถามสิทธิ์ซ้ำและยังใช้งานได้ตามปกติ';
    }
    return 'เราจะอธิบายและขอสิทธิ์หลังคุณบันทึกรายการแรกสำเร็จ';
  }

  Future<void> _pickTime(
    BuildContext context, {
    required bool daily,
  }) async {
    final current = daily
        ? controller.preferences.dailyTime
        : controller.preferences.weeklyTime;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: daily ? 'เลือกเวลาเตือนประจำวัน' : 'เลือกเวลาสรุปวันจันทร์',
      cancelText: 'ยกเลิก',
      confirmText: 'บันทึกเวลา',
    );
    if (selected == null) return;
    final time = ReminderTime(hour: selected.hour, minute: selected.minute);
    if (daily) {
      await controller.setDailyTime(time, goalName: goalName);
    } else {
      await controller.setWeeklyTime(time, goalName: goalName);
    }
  }
}
