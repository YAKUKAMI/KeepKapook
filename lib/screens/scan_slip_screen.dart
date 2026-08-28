import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

// Phase 3: อัปโหลดรูปสลิป + กรอกข้อมูลเอง (OCR ML Kit จะเสริมภายหลัง mobile-only)
class ScanSlipScreen extends StatefulWidget {
  final String? presetGoalId;
  const ScanSlipScreen({super.key, this.presetGoalId});
  @override
  State<ScanSlipScreen> createState() => _ScanSlipScreenState();
}

class _ScanSlipScreenState extends State<ScanSlipScreen> {
  Uint8List? _image;
  final _amount = TextEditingController();
  String _bank = 'ธนาคารกสิกรไทย';
  String _dest = 'unallocated';
  bool _confirmed = false;

  static const _banks = [
    'ธนาคารกสิกรไทย',
    'ธนาคารไทยพาณิชย์',
    'ธนาคารกรุงเทพ',
    'ธนาคารกรุงไทย',
    'ธนาคารกรุงศรีอยุธยา',
    'ธนาคารทหารไทยธนชาต',
    'พร้อมเพย์ / อื่น ๆ',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.presetGoalId != null) _dest = widget.presetGoalId!;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() => _image = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final amountSatang = parseMoneyToSatang(_amount.text);
    final inputError =
        _amount.text.trim().isEmpty ? null : moneyInputError(_amount.text);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('สแกนสลิป'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warmYellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
                'รูปสลิปอาจมีข้อมูลส่วนบุคคล โปรดปิดบังข้อมูลที่ไม่จำเป็นก่อนอัปโหลด — ผู้ใช้ต้องตรวจสอบและยืนยันข้อมูลก่อนบันทึก',
                style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pick,
            child: Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.black26,
                    style: BorderStyle.solid,
                    width: 1.5),
              ),
              child: _image == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 40, color: AppColors.mint),
                        SizedBox(height: 8),
                        Text('แตะเพื่อเลือกรูปสลิป'),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_image!, fit: BoxFit.contain),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('จำนวนเงิน',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '฿ ',
              errorText: inputError,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          const Text('ธนาคาร', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              underline: const SizedBox(),
              value: _bank,
              items: _banks
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _bank = v ?? _bank),
            ),
          ),
          const SizedBox(height: 12),
          const Text('เข้ากระปุก',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          _destTile('💼 เงินที่ยังไม่จัดสรร', _dest == 'unallocated',
              () => setState(() => _dest = 'unallocated')),
          ...app.activeGoals.map((g) => _destTile('${g.emoji} ${g.name}',
              _dest == g.id, () => setState(() => _dest = g.id))),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            onChanged: (v) => setState(() => _confirmed = v ?? false),
            title: const Text('ฉันตรวจสอบและยืนยันว่าข้อมูลถูกต้องแล้ว',
                style: TextStyle(fontSize: 14)),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.mint,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed:
                (!_confirmed || amountSatang == null || amountSatang <= 0)
                    ? null
                    : () {
                        final res = app.addSaving(
                          amountSatang: amountSatang,
                          goalId: _dest == 'unallocated' ? null : _dest,
                          note: 'จากสลิป $_bank',
                          source: TxType.slip,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'บันทึกจากสลิป ${formatMoney(amountSatang)}${res.exp > 0 ? ' · +${res.exp} EXP' : ''}'),
                            backgroundColor: AppColors.deepGreen));
                        Navigator.pop(context);
                      },
            child: const Text('บันทึกรายการ'),
          ),
        ],
      ),
    );
  }

  Widget _destTile(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.mint.withValues(alpha: 0.1)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: active ? AppColors.mint : Colors.black12),
            ),
            child: Text(label),
          ),
        ),
      );
}
