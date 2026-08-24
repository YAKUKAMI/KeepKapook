import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class NewGoalScreen extends StatefulWidget {
  const NewGoalScreen({super.key});
  @override
  State<NewGoalScreen> createState() => _NewGoalScreenState();
}

class _NewGoalScreenState extends State<NewGoalScreen> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 90));
  String _emoji = '🎯';
  GoalCategory _cat = GoalCategory.other;
  bool _pocket = false; // Cloud Pocket ยืดหยุ่น (ไม่มีเป้าหมาย)

  static const _emojis = ['🎯', '✈️', '💻', '🏠', '🚗', '🎓', '🎁', '🛟'];

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: Text(_pocket ? 'สร้าง Cloud Pocket' : 'สร้างกระปุกใหม่'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pocket,
              activeColor: AppColors.mint,
              title: const Text('กระเป๋าใช้จ่าย (ไม่มีเป้าหมาย)'),
              subtitle: const Text('ยืดหยุ่น เข้า-ออกได้ตลอด',
                  style: TextStyle(fontSize: 12)),
              onChanged: (v) => setState(() {
                _pocket = v;
                if (v) _emoji = '👛';
              }),
            ),
          ),
          const SizedBox(height: 12),
          _field('ชื่อ${_pocket ? 'กระเป๋า' : 'กระปุก'}', _name,
              hint: _pocket ? 'เช่น ค่ากินเที่ยว' : 'เช่น เที่ยวญี่ปุ่น'),
          const SizedBox(height: 12),
          if (!_pocket) ...[
            _field('จำนวนเงินเป้าหมาย', _target, number: true, prefix: '฿ '),
            const SizedBox(height: 12),
            const Text('วันที่ต้องการสำเร็จ',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (d != null) setState(() => _date = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Text('${_date.day}/${_date.month}/${_date.year + 543}'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text('Emoji', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
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
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('กรุณากรอกชื่อ')));
                return;
              }
              if (_pocket) {
                app.createPocket(name: _name.text.trim(), emoji: _emoji);
                Navigator.pop(context);
                return;
              }
              final target =
                  double.tryParse(_target.text.replaceAll(',', '')) ?? 0;
              if (target <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('กรุณากรอกจำนวนเงินเป้าหมาย')));
                return;
              }
              app.addGoal(
                name: _name.text.trim(),
                target: target,
                targetDate: _date,
                emoji: _emoji,
                category: _cat,
              );
              Navigator.pop(context);
            },
            child: Text(_pocket ? 'สร้างกระเป๋า' : 'สร้างกระปุก'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {String? hint, bool number = false, String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
