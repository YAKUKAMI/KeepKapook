import 'parser_models.dart';

class KeywordRule<T> {
  const KeywordRule({
    required this.keywords,
    required this.value,
    this.excludedKeywords = const <String>[],
  });

  final List<String> keywords;
  final T value;
  final List<String> excludedKeywords;

  bool matches(String input) =>
      keywords.any(input.contains) && !excludedKeywords.any(input.contains);
}

class CategoryRule {
  const CategoryRule({
    required this.keywords,
    required this.category,
    required this.impliedType,
    this.confidence = 0.98,
    this.excludedKeywords = const <String>[],
  });

  final List<String> keywords;
  final String category;
  final ParsedEntryType impliedType;
  final double confidence;
  final List<String> excludedKeywords;

  bool matches(String input) =>
      keywords.any(input.contains) && !excludedKeywords.any(input.contains);
}

// Alias ถูก normalize ก่อน extract ตัวเลข เพื่อไม่ให้ 7-11 กลายเป็นยอด 7 และ 11
const normalizationAliases = <String, String>{
  '7-11': 'เซเว่น',
};

// เรียงคำเฉพาะก่อนคำกว้าง เพราะใช้ first match
const typeKeywordRules = <KeywordRule<ParsedEntryType>>[
  KeywordRule(
    keywords: [
      'เก็บใส่กระปุก',
      'หยอดกระปุก',
      'ใส่กระปุก',
      'เข้ากระปุก',
      'เก็บเงิน',
      'ออม',
      'เก็บ',
    ],
    value: ParsedEntryType.goalDeposit,
    excludedKeywords: ['เก็บของ', 'เก็บกวาด'],
  ),
  KeywordRule(
    keywords: [
      'ถูกหวย',
      'ขายของได้',
      'ได้เงินเดือน',
      'เงินเดือน',
      'ได้โบนัส',
      'ได้ค่าขนม',
      'แม่ให้',
      'ได้มา',
    ],
    value: ParsedEntryType.income,
  ),
  KeywordRule(
    keywords: ['จ่าย', 'ซื้อ', 'กิน', 'เติม', 'ค่า'],
    value: ParsedEntryType.expense,
  ),
];

const categoryKeywordRules = <CategoryRule>[
  CategoryRule(
    keywords: ['เงินเดือน'],
    category: 'เงินเดือน',
    impliedType: ParsedEntryType.income,
  ),
  CategoryRule(
    keywords: ['ขายของได้', 'ขายของ', 'ได้มา'],
    category: 'รายได้เสริม',
    impliedType: ParsedEntryType.income,
  ),
  CategoryRule(
    keywords: ['ได้โบนัส', 'โบนัส', 'ถูกหวย'],
    category: 'รายได้พิเศษ',
    impliedType: ParsedEntryType.income,
  ),
  CategoryRule(
    keywords: ['ได้ค่าขนม', 'ค่าขนม', 'แม่ให้'],
    category: 'ค่าขนม',
    impliedType: ParsedEntryType.income,
  ),
  CategoryRule(
    keywords: [
      'เก็บใส่กระปุก',
      'หยอดกระปุก',
      'ใส่กระปุก',
      'เข้ากระปุก',
      'เก็บเงิน',
      'ออม',
      'เก็บ',
    ],
    category: 'เป้าหมายการออม',
    impliedType: ParsedEntryType.goalDeposit,
    excludedKeywords: ['เก็บของ', 'เก็บกวาด'],
  ),
  CategoryRule(
    keywords: ['ค่าน้ำค่าไฟ', 'ค่าเช่า', 'ค่าไฟ', 'ค่าน้ำ', 'ค่าห้อง'],
    category: 'ที่พัก',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: [
      'ข้าวขาหมู',
      'ข้าวมันไก่',
      'หมูกระทะ',
      'ชานม',
      'กาแฟ',
      'กินข้าว',
      'ข้าว',
    ],
    category: 'อาหาร',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: ['ขาวมันไก่', 'ค่าอาหาน'],
    category: 'อาหาร',
    impliedType: ParsedEntryType.expense,
    confidence: 0.8,
  ),
  CategoryRule(
    keywords: [
      'เติมน้ำมัน',
      'ค่ารถเมล์',
      'รถเมล์',
      'แกร็บ',
      'วินมอไซค์',
      'วินมอเตอร์ไซค์'
    ],
    category: 'เดินทาง',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: ['วิน'],
    category: 'เดินทาง',
    impliedType: ParsedEntryType.expense,
    confidence: 0.8,
  ),
  CategoryRule(
    keywords: ['ค่าเทอม', 'ค่าเรียน', 'หนังสือเรียน'],
    category: 'การศึกษา',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: ['หมอฟัน', 'หมอ', 'ยา', 'โรงพยาบาล'],
    category: 'สุขภาพ',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: ['ตัดผม', 'ทำผม', 'สกินแคร์'],
    category: 'ดูแลตัวเอง',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: ['เติมเกม', 'เกม', 'หวย'],
    category: 'บันเทิง',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: ['ซื้อเสื้อ', 'เสื้อ'],
    category: 'เสื้อผ้า',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: [
      'เซเว่น',
      'ค่าส่ง',
      'ซื้อของ',
      'โน้ตบุ๊ค',
      'ของใช้',
    ],
    category: 'ของใช้',
    impliedType: ParsedEntryType.expense,
  ),
  CategoryRule(
    keywords: ['เซเวน'],
    category: 'ของใช้',
    impliedType: ParsedEntryType.expense,
    confidence: 0.8,
  ),
];

const transferQuestion = ParseQuestion(
  prompt: 'ต้องการบันทึกการโอนเป็นอะไร?',
  options: [
    ParseOption(id: 'expense', label: 'รายจ่าย'),
    ParseOption(id: 'goal_deposit', label: 'ย้ายเข้ากระปุก'),
    ParseOption(id: 'cancel', label: 'ยกเลิก'),
  ],
);

const lendingQuestion = ParseQuestion(
  prompt: 'คำว่า “ยืมเพื่อน” หมายถึงแบบไหน?',
  options: [
    ParseOption(id: 'lend_to_friend', label: 'เราให้เพื่อนยืม'),
    ParseOption(id: 'borrow_from_friend', label: 'เรายืมจากเพื่อน'),
    ParseOption(id: 'cancel', label: 'ยกเลิก'),
  ],
);

const repaymentQuestion = ParseQuestion(
  prompt: 'รายการคืนเงินเกิดขึ้นทางไหน?',
  options: [
    ParseOption(id: 'repay_friend', label: 'เราคืนให้เพื่อน'),
    ParseOption(id: 'friend_repaid', label: 'เพื่อนคืนให้เรา'),
    ParseOption(id: 'cancel', label: 'ยกเลิก'),
  ],
);

const frontedPaymentQuestion = ParseQuestion(
  prompt: 'รายการจ่ายแทนเพื่อนต้องการบันทึกแบบไหน?',
  options: [
    ParseOption(id: 'expense', label: 'เป็นรายจ่ายของเรา'),
    ParseOption(id: 'reimbursable', label: 'รอเพื่อนคืนเงิน'),
    ParseOption(id: 'cancel', label: 'ยกเลิก'),
  ],
);

const unknownTypeQuestion = ParseQuestion(
  prompt: 'ต้องการบันทึกรายการนี้เป็นอะไร?',
  options: [
    ParseOption(id: 'expense', label: 'รายจ่าย'),
    ParseOption(id: 'income', label: 'รายรับ'),
    ParseOption(id: 'goal_deposit', label: 'เข้าเป้าหมาย'),
    ParseOption(id: 'cancel', label: 'ยกเลิก'),
  ],
);
