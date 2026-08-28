import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum SimulationNoticeKind {
  general,
  transfer,
  lock,
  sharedSaving,
  withdrawal,
}

class SimulationNotice extends StatelessWidget {
  const SimulationNotice({
    super.key,
    this.kind = SimulationNoticeKind.general,
    this.compact = false,
  });

  static const generalTitle = 'KeepKapook ช่วยบันทึก ไม่ได้เก็บเงินจริง';
  static const generalMessage =
      'KeepKapook เป็นเครื่องมือบันทึกและตั้งเป้าการออม ไม่ใช่แอปธนาคาร '
      'ไม่มีการเชื่อมบัญชีธนาคารหรือเก็บรักษาเงินจริง '
      'ทุกยอดเป็นตัวเลขที่คุณบันทึกเอง';
  static const lockMessage =
      'ล็อกเป็นการเตือนใจ ไม่ได้ล็อกเงินจริง สามารถยกเลิกได้';

  final SimulationNoticeKind kind;
  final bool compact;

  String get _title => switch (kind) {
        SimulationNoticeKind.general => generalTitle,
        SimulationNoticeKind.transfer => 'โอนระหว่างกระปุกแบบจำลอง',
        SimulationNoticeKind.lock => 'ล็อกเงินแบบจำลอง',
        SimulationNoticeKind.sharedSaving => 'ออมด้วยกันแบบจำลอง',
        SimulationNoticeKind.withdrawal => 'ถอนออกแบบจำลอง',
      };

  String get _message => switch (kind) {
        SimulationNoticeKind.general => generalMessage,
        SimulationNoticeKind.transfer =>
          'การโอนนี้เป็นการย้ายตัวเลขที่คุณบันทึกระหว่างกระปุก '
              'ไม่มีเงินจริงเคลื่อนไหว',
        SimulationNoticeKind.lock => lockMessage,
        SimulationNoticeKind.sharedSaving =>
          'ออมด้วยกันใช้บันทึกเป้าหมายและรายชื่อร่วมกันเท่านั้น '
              'ไม่มีบัญชีร่วมหรือเงินจริงในแอป',
        SimulationNoticeKind.withdrawal =>
          'การถอนนี้เป็นการย้ายตัวเลขไปยัง “เงินที่ยังไม่จัดสรร” '
              'ไม่มีเงินจริงถูกถอน',
      };

  IconData get _icon => switch (kind) {
        SimulationNoticeKind.general => Icons.info_outline,
        SimulationNoticeKind.transfer => Icons.swap_horiz,
        SimulationNoticeKind.lock => Icons.lock_outline,
        SimulationNoticeKind.sharedSaving => Icons.group_outlined,
        SimulationNoticeKind.withdrawal => Icons.remove_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Semantics(
        label: '$_title: $_message',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.warmYellow.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.warmYellow.withValues(alpha: 0.8),
            ),
          ),
          child: const Text(
            'จำลอง',
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: '$_title: $_message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warmYellow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.warmYellow.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: AppColors.deepGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SimulationNotice(kind: kind, compact: true),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _message,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
