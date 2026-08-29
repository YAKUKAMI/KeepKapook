import 'package:keepkapook/utils/parser/parser.dart';

// ชุดสังเคราะห์ที่เจ้าของภาษาในกลุ่มเป้าหมายตรวจแล้ว ใช้เป็น regression gate
// เท่านั้น ห้ามรายงานผลจากไฟล์นี้ว่าเป็น accuracy กับผู้ใช้จริง
// accuracy ผู้ใช้จริงต้องวัดจากข้อความผู้ใช้จริงอย่างน้อย 50 ประโยค
// ซึ่งจะเก็บแยกหลังมี event tracking รอบ 14

class ExpectedParserItem {
  const ExpectedParserItem(
    this.amountSatang,
    this.type,
    this.category, {
    this.dayOffset = 0,
  });

  final int amountSatang;
  final ParsedEntryType type;
  final String category;
  final int dayOffset;
}

class ParserCorpusCase {
  const ParserCorpusCase({
    required this.input,
    required this.expectedTier,
    this.expectedItems = const [],
    this.expectedDetectedAmounts = const [],
    this.knownLimitation = false,
    this.limitationReason,
  });

  final String input;
  final ParseTier expectedTier;
  final List<ExpectedParserItem> expectedItems;
  final List<int> expectedDetectedAmounts;
  final bool knownLimitation;
  final String? limitationReason;
}

const expense = ParsedEntryType.expense;
const income = ParsedEntryType.income;
const goal = ParsedEntryType.goalDeposit;

// Brief §7 เรียกชุดนี้ว่า 35 ประโยค แต่รายการจริงมี 37 ประโยค
// (รวม 2 เคสซับซ้อนท้าย section) จึงเก็บครบโดยไม่ทิ้งเคสเงียบ ๆ
const parserCorpus = <ParserCorpusCase>[
  // ง่าย
  ParserCorpusCase(
      input: 'ข้าวขาหมู150',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(15000, expense, 'อาหาร')]),
  ParserCorpusCase(
      input: 'กาแฟ 65',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(6500, expense, 'อาหาร')]),
  ParserCorpusCase(
      input: 'เงินเดือน 25000',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(2500000, income, 'เงินเดือน')]),
  ParserCorpusCase(
      input: 'ขายของได้500',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(50000, income, 'รายได้เสริม')]),
  ParserCorpusCase(
      input: 'เติมน้ำมัน 500 บาท',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(50000, expense, 'เดินทาง')]),
  ParserCorpusCase(
      input: 'ค่ารถเมล์ 8',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(800, expense, 'เดินทาง')]),
  ParserCorpusCase(
      input: 'แกร็บ 120',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(12000, expense, 'เดินทาง')]),
  ParserCorpusCase(
      input: 'วินมอไซค์20',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(2000, expense, 'เดินทาง')]),
  ParserCorpusCase(
      input: '7-11 89',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(8900, expense, 'ของใช้')]),
  ParserCorpusCase(
      input: 'เซเว่น 89',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(8900, expense, 'ของใช้')]),
  ParserCorpusCase(
      input: 'ค่าเทอม 15000',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(1500000, expense, 'การศึกษา')]),
  ParserCorpusCase(
      input: 'หมอฟัน 800',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(80000, expense, 'สุขภาพ')]),
  ParserCorpusCase(
      input: 'ตัดผม 150',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(15000, expense, 'ดูแลตัวเอง')]),
  ParserCorpusCase(
      input: 'เติมเกม 100',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(10000, expense, 'บันเทิง')]),
  ParserCorpusCase(
      input: 'ค่าส่ง 40',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(4000, expense, 'ของใช้')]),

  // รูปแบบตัวเลข
  ParserCorpusCase(
      input: 'ค่าน้ำค่าไฟ 1,200',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(120000, expense, 'ที่พัก')]),
  ParserCorpusCase(
      input: 'ได้โบนัส 2 หมื่น',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(2000000, income, 'รายได้พิเศษ')]),
  ParserCorpusCase(
      input: 'ได้ค่าขนม ๕๐๐',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(50000, income, 'ค่าขนม')]),
  ParserCorpusCase(
      input: 'ชานม 45x2',
      expectedTier: ParseTier.medium,
      expectedItems: [ExpectedParserItem(9000, expense, 'อาหาร')]),
  ParserCorpusCase(
      input: 'หมูกระทะ 350 หาร 4',
      expectedTier: ParseTier.medium,
      expectedItems: [ExpectedParserItem(8750, expense, 'อาหาร')]),
  ParserCorpusCase(
      input: 'ซื้อเสื้อ 590 ลดเหลือ 490',
      expectedTier: ParseTier.medium,
      expectedItems: [ExpectedParserItem(49000, expense, 'เสื้อผ้า')]),

  // วันที่
  ParserCorpusCase(
      input: 'กาแฟ 65 เมื่อวาน',
      expectedTier: ParseTier.high,
      expectedItems: [
        ExpectedParserItem(6500, expense, 'อาหาร', dayOffset: -1)
      ]),
  ParserCorpusCase(
      input: 'เมื่อวานกินข้าว 60',
      expectedTier: ParseTier.high,
      expectedItems: [
        ExpectedParserItem(6000, expense, 'อาหาร', dayOffset: -1)
      ]),
  ParserCorpusCase(
      input: 'ค่าไฟเดือนนี้จ่ายไป 850 บาทแล้ว',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(85000, expense, 'ที่พัก')]),

  // หลายรายการ — parse candidate ได้ แต่ต้องถามก่อนบันทึกตาม tier ต่ำใน brief
  ParserCorpusCase(
    input: 'ข้าว 50 กาแฟ 40',
    expectedTier: ParseTier.low,
    expectedItems: [
      ExpectedParserItem(5000, expense, 'อาหาร'),
      ExpectedParserItem(4000, expense, 'อาหาร'),
    ],
  ),

  // เข้าเป้าหมาย
  ParserCorpusCase(
      input: 'ออม 300',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(30000, goal, 'เป้าหมายการออม')]),
  ParserCorpusCase(
      input: 'เก็บใส่กระปุก 500',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(50000, goal, 'เป้าหมายการออม')]),

  // คำเดียวกันคนละทิศ
  ParserCorpusCase(
      input: 'หวย 100',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(10000, expense, 'บันเทิง')]),
  ParserCorpusCase(
      input: 'ถูกหวย 2000',
      expectedTier: ParseTier.high,
      expectedItems: [ExpectedParserItem(200000, income, 'รายได้พิเศษ')]),

  // กำกวม ต้องถาม
  ParserCorpusCase(
      input: 'โอน500',
      expectedTier: ParseTier.low,
      expectedDetectedAmounts: [50000]),
  ParserCorpusCase(
      input: 'ยืมเพื่อน 200',
      expectedTier: ParseTier.low,
      expectedDetectedAmounts: [20000]),
  ParserCorpusCase(
      input: 'คืนเงินเพื่อน 200',
      expectedTier: ParseTier.low,
      expectedDetectedAmounts: [20000]),

  // ต้องปฏิเสธ/ถาม
  ParserCorpusCase(input: 'ข้าว', expectedTier: ParseTier.reject),
  ParserCorpusCase(
      input: '150',
      expectedTier: ParseTier.reject,
      expectedDetectedAmounts: [15000]),
  ParserCorpusCase(input: 'กาแฟ -50', expectedTier: ParseTier.reject),

  // ซับซ้อน — parser v1 รองรับทั้งสองเคส จึงไม่ต้อง mark known limitation
  ParserCorpusCase(
      input: 'กินหมูกระทะกับเพื่อน 350 แต่จ่ายไป 100',
      expectedTier: ParseTier.medium,
      expectedItems: [ExpectedParserItem(10000, expense, 'อาหาร')]),
  ParserCorpusCase(
      input: 'จ่ายค่าเช่า4500ทุกเดือน',
      expectedTier: ParseTier.medium,
      expectedItems: [ExpectedParserItem(450000, expense, 'ที่พัก')]),
];
