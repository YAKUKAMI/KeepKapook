import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/simulation_notice.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  final _name = TextEditingController();
  SaverMode _mode = SaverMode.adult;
  final _goalName = TextEditingController();
  final _target = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 90));
  String _emoji = '🎯';

  static const _emojis = ['🎯', '✈️', '💻', '🏠', '🚗', '🎓'];

  @override
  void dispose() {
    _name.dispose();
    _goalName.dispose();
    _target.dispose();
    super.dispose();
  }

  bool get _canNext {
    if (step == 0) return true;
    if (step == 1) return _name.text.trim().isNotEmpty;
    if (step == 2) {
      return _goalName.text.trim().isNotEmpty &&
          (parseMoneyToSatang(_target.text) ?? 0) > 0;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                    3,
                    (i) => Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color:
                                  i <= step ? AppColors.mint : Colors.black12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        )),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: switch (step) {
                  0 => _disclaimerStep(),
                  1 => _profileStep(),
                  _ => _goalStep(),
                },
              ),
              Row(
                children: [
                  if (step > 0)
                    TextButton(
                        onPressed: () => setState(() => step--),
                        child: const Text('ย้อนกลับ')),
                  const Spacer(),
                  FilledButton(
                    onPressed: !_canNext
                        ? null
                        : () {
                            if (step < 2) {
                              setState(() => step++);
                            } else {
                              context.read<AppState>().completeOnboarding(
                                    name: _name.text.trim(),
                                    mode: _mode,
                                    goalName: _goalName.text.trim(),
                                    targetSatang:
                                        parseMoneyToSatang(_target.text)!,
                                    targetDate: _date,
                                    emoji: _emoji,
                                  );
                            }
                          },
                    child: Text(switch (step) {
                      0 => 'เข้าใจแล้ว',
                      1 => 'ถัดไป',
                      _ => 'เริ่มบันทึกการออม',
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disclaimerStep() => ListView(
        key: const Key('onboarding-disclaimer-page'),
        children: const [
          Icon(
            Icons.savings_outlined,
            size: 56,
            color: AppColors.deepGreen,
          ),
          SizedBox(height: 16),
          Text(
            'ก่อนเริ่มใช้งาน',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'เก็บเงินจริงไว้กับคุณ ใช้ KeepKapook ช่วยติดตามเป้าหมาย',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText),
          ),
          SizedBox(height: 20),
          SimulationNotice(key: Key('onboarding-disclaimer')),
        ],
      );

  Widget _profileStep() => ListView(
        children: [
          const Text('มาทำความรู้จักกัน',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('เราจะเรียกคุณว่าอะไรดี?',
              style: TextStyle(color: AppColors.mutedText)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'ชื่อเล่น', hintText: 'เช่น กัปตัน'),
          ),
          const SizedBox(height: 20),
          const Text('โหมดผู้ออม',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: SaverMode.values.map((m) {
              final active = _mode == m;
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => setState(() => _mode = m),
                    child:
                        Text(m == SaverMode.child ? '🧒 เด็ก' : '🧑 ผู้ใหญ่'),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text(
              'โหมดนี้ใช้กำหนดเป้าหมายเงินออมแนะนำต่อวัน '
              'ยอดทั้งหมดเป็นตัวเลขที่คุณบันทึกเอง',
              style: TextStyle(fontSize: 11, color: AppColors.mutedText)),
        ],
      );

  Widget _goalStep() => ListView(
        children: [
          const Text('สร้างกระปุกแรก',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _goalName,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'ชื่อเป้าหมาย', hintText: 'เช่น เที่ยวญี่ปุ่น'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'จำนวนเงินเป้าหมาย',
              prefixText: '฿ ',
              errorText: _target.text.trim().isEmpty
                  ? null
                  : moneyInputError(_target.text),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('วันที่ต้องการสำเร็จ'),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year + 543}'),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _emojis.map((e) {
              final active = _emoji == e;
              return GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.mint.withValues(alpha: 0.2)
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: active
                        ? Border.all(color: AppColors.mint, width: 2)
                        : null,
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 20)),
                ),
              );
            }).toList(),
          ),
        ],
      );
}
