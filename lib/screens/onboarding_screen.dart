import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

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
    if (step == 0) return _name.text.trim().isNotEmpty;
    if (step == 1) {
      return _goalName.text.trim().isNotEmpty &&
          (double.tryParse(_target.text.replaceAll(',', '')) ?? 0) > 0;
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
                    2,
                    (i) => Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i <= step
                                  ? AppColors.mint
                                  : Colors.black12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        )),
              ),
              const SizedBox(height: 24),
              Expanded(child: step == 0 ? _step0() : _step1()),
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
                            if (step == 0) {
                              setState(() => step = 1);
                            } else {
                              context.read<AppState>().completeOnboarding(
                                    name: _name.text.trim(),
                                    mode: _mode,
                                    goalName: _goalName.text.trim(),
                                    target: double.parse(
                                        _target.text.replaceAll(',', '')),
                                    targetDate: _date,
                                    emoji: _emoji,
                                  );
                            }
                          },
                    child: Text(step == 0 ? 'ถัดไป' : 'เริ่มออมเลย'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step0() => ListView(
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
                      backgroundColor:
                          active ? AppColors.mint.withOpacity(0.15) : null,
                      side: BorderSide(
                          color: active ? AppColors.mint : Colors.black12),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => setState(() => _mode = m),
                    child: Text(m == SaverMode.child ? '🧒 เด็ก' : '🧑 ผู้ใหญ่'),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text(
              'โหมดกำหนดเป้าหมายเงินออมแนะนำต่อวัน (บันทึกเงินจริงได้ไม่จำกัด)',
              style: TextStyle(fontSize: 11, color: AppColors.mutedText)),
        ],
      );

  Widget _step1() => ListView(
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
            decoration: const InputDecoration(
                labelText: 'จำนวนเงินเป้าหมาย', prefixText: '฿ '),
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
                        ? AppColors.mint.withOpacity(0.2)
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
