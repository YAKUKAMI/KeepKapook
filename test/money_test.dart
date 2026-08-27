import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/utils/format.dart';

void main() {
  group('parseMoneyToSatang', () {
    test('parse บาทและสตางค์โดยไม่ใช้ floating point', () {
      expect(parseMoneyToSatang('12,500'), 1250000);
      expect(parseMoneyToSatang('0.01'), 1);
      expect(parseMoneyToSatang('1.004'), 100);
      expect(parseMoneyToSatang('1.005'), 101);
      expect(parseMoneyToSatang('2.675'), 268);
    });

    test('ปฏิเสธค่าติดลบ รูปแบบผิด และค่าที่เกินเพดาน', () {
      expect(parseMoneyToSatang('-1'), isNull);
      expect(parseMoneyToSatang('หนึ่งร้อย'), isNull);
      expect(parseMoneyToSatang('1,2'), isNull);
      expect(parseMoneyToSatang('100000000'), maxMoneyInputSatang);
      expect(parseMoneyToSatang('100000000.01'), isNull);
    });
  });

  test('formatMoney แปลงจากสตางค์เฉพาะตอนแสดงผล', () {
    expect(formatMoney(0), '฿0');
    expect(formatMoney(1), '฿0.01');
    expect(formatMoney(100), '฿1');
    expect(formatMoney(125050), '฿1,250.50');
  });

  test('เพดานออมรายวันคืนค่าเป็นสตางค์', () {
    expect(dailyDepositCapSatang('child', 1), 5000);
    expect(dailyDepositCapSatang('adult', 4), 100000);
  });
}
