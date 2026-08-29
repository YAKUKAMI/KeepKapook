// test/fixtures/parser_edge_cases.dart
//
// ชุดทดสอบ "ความถูกต้องเชิงโครงสร้าง" ของ parser — สังเคราะห์ขึ้นทั้งหมด
//
// ⚠️ ไฟล์นี้ไม่ใช่ corpus และห้ามใช้วัด accuracy
//    ตามกฎใน AGENTS.md ประโยคที่ AI หรือทีมแต่งเองห้ามนับเป็น corpus จริง
//    เพราะมันสะท้อนจินตนาการของคนเขียน ไม่ใช่วิธีพิมพ์ของผู้ใช้จริง
//
//    ไฟล์นี้ตอบคำถามว่า "parser จัดการเคสเชิงตรรกะนี้ได้ไหม"
//    ส่วน test/fixtures/parser_corpus.dart (ประโยคจริงเท่านั้น)
//    ตอบคำถามว่า "แม่นแค่ไหนกับของจริง" และเป็นตัวเดียวที่ผูกกับเกณฑ์ 98/95/80
//
// วิธีใช้: เทสต้องผ่านทุกเคสที่ไม่ได้ mark เป็น knownLimitation
//          เคสที่ tier=high แต่ผลลัพธ์ผิด ต้องเป็น 0 เสมอ ไม่มีข้อยกเว้น
//
// pure Dart ห้าม import Flutter

enum ExpectedTier { high, medium, low, reject }

enum ExpectedType { saving, expense, income }

class ParserCase {
  const ParserCase({
    required this.group,
    required this.input,
    required this.tier,
    this.amountSatang,
    this.type,
    this.category,
    this.dayOffset,
    this.entryCount = 1,
    this.contextDependent = false,
    this.knownLimitation = false,
    required this.note,
  });

  /// หมวดของเคส ใช้จัดกลุ่มตอนรายงานผล
  final String group;

  /// ข้อความที่ผู้ใช้พิมพ์
  final String input;

  /// tier ที่ควรได้ — ตัวนี้สำคัญที่สุด
  final ExpectedTier tier;

  /// จำนวนเงินหน่วยสตางค์ที่ควรได้ (null = ไม่ได้ระบุเพราะ tier=low/reject)
  final int? amountSatang;

  final ExpectedType? type;

  /// ชื่อหมวดหมู่ที่ควรได้ — เกณฑ์หย่อนที่สุด (80%) แก้ง่าย ผิดได้บ้าง
  final String? category;

  /// 0 = วันนี้ · -1 = เมื่อวาน · -2 = เมื่อวานซืน · null = ไม่ได้ระบุ (ควร default เป็นวันนี้)
  final int? dayOffset;

  /// จำนวนรายการที่ควรถูกสร้างจากข้อความเดียว
  final int entryCount;

  /// ผลลัพธ์ขึ้นกับ state ปัจจุบัน เช่นมีกี่กระปุก — เทสต้องเซ็ต state ก่อน
  final bool contextDependent;

  /// ยอมรับได้ถ้ายังทำไม่ได้ใน v1 แต่ **ห้ามตกไปอยู่ tier=high**
  final bool knownLimitation;

  /// เคสนี้ทดสอบอะไร เขียนให้คนอ่านรู้ว่าทำไมต้องมี
  final String note;
}

const parserEdgeCases = <ParserCase>[
  // ─────────────────────────────────────────────────────────────
  // A · รูปแบบตัวเลขและสกุลเงิน
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'A-number-format',
    input: 'กาแฟ 65',
    tier: ExpectedTier.high,
    amountSatang: 6500,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'เคสพื้นฐานที่สุด ถ้าอันนี้ไม่ผ่านไม่ต้องดูอันอื่น',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'กาแฟ65',
    tier: ExpectedTier.high,
    amountSatang: 6500,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'ไม่เว้นวรรคระหว่างคำกับตัวเลข — ภาษาไทยไม่เว้นวรรคเป็นปกติ',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'กาแฟ ฿65',
    tier: ExpectedTier.high,
    amountSatang: 6500,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'สัญลักษณ์บาทนำหน้าตัวเลข',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'กาแฟ 65 บาท',
    tier: ExpectedTier.high,
    amountSatang: 6500,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'คำว่าบาทต่อท้าย ต้องไม่ถูกอ่านเป็นส่วนหนึ่งของชื่อรายการ',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'กาแฟ 65บ.',
    tier: ExpectedTier.high,
    amountSatang: 6500,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'ตัวย่อ บ. ติดกับตัวเลข',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'ค่าน้ำค่าไฟ 1,200',
    tier: ExpectedTier.high,
    amountSatang: 120000,
    type: ExpectedType.expense,
    category: 'ที่พัก',
    note: 'comma คั่นหลักพัน ห้ามอ่านเป็นสองจำนวน',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'ได้ค่าขนม ๕๐๐',
    tier: ExpectedTier.high,
    amountSatang: 50000,
    type: ExpectedType.income,
    note: 'เลขไทย ๐-๙ ต้อง normalize ก่อน',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'ได้โบนัส สองหมื่น',
    tier: ExpectedTier.high,
    amountSatang: 2000000,
    type: ExpectedType.income,
    note: 'คำบอกจำนวนเขียนเต็ม — 20,000 บาท',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'ได้โบนัส 2หมื่น',
    tier: ExpectedTier.high,
    amountSatang: 2000000,
    type: ExpectedType.income,
    note: 'เลขอารบิกติดคำบอกจำนวน รูปแบบที่พิมพ์เร็ว',
  ),

  // ── A2 · รูปแบบ <หน่วย><หลักถัดไป> — ไทยแท้ ห้ามพลาด ────────────
  //
  // กฎ: <หน่วย> ตามด้วยตัวเลขหลักเดียว = หน่วยนั้น + (เลข × หน่วย/10)
  //
  //     พันห้า    = 1,000   + 500     = 1,500
  //     หมื่นห้า   = 10,000  + 5,000   = 15,000
  //     แสนสอง    = 100,000 + 20,000  = 120,000
  //     ล้านสอง   = 1,000,000 + 200,000 = 1,200,000
  //
  // มีตัวคูณนำหน้าได้ด้วย: สองหมื่นห้า = 25,000
  // เขียนด้วยเลขอารบิกก็ได้: หมื่น5 = หมื่นห้า
  //
  // ⚠️ คนไทยไม่พูด "1.5 หมื่น" — ห้ามออกแบบ parser โดยคิดแบบทศนิยม
  ParserCase(
    group: 'A2-thai-number',
    input: 'ซื้อของ หมื่นห้า',
    tier: ExpectedTier.high,
    amountSatang: 1500000,
    type: ExpectedType.expense,
    note: 'หมื่น + ห้าพัน = 15,000 บาท · รูปแบบหลักที่คนไทยใช้พูดจำนวนเงิน',
  ),
  ParserCase(
    group: 'A2-thai-number',
    input: 'ค่าเทอม หมื่น5',
    tier: ExpectedTier.high,
    amountSatang: 1500000,
    type: ExpectedType.expense,
    category: 'การศึกษา',
    note: 'เขียนย่อด้วยเลขอารบิก = หมื่นห้า · ตัวเลขท้ายไม่ใช่จำนวนเงินเดี่ยวๆ',
  ),
  ParserCase(
    group: 'A2-thai-number',
    input: 'ได้มา พันห้า',
    tier: ExpectedTier.high,
    amountSatang: 150000,
    type: ExpectedType.income,
    note: 'พัน + ห้าร้อย = 1,500 บาท',
  ),
  ParserCase(
    group: 'A2-thai-number',
    input: 'โน้ตบุ๊ค สองหมื่นห้า',
    tier: ExpectedTier.high,
    amountSatang: 2500000,
    type: ExpectedType.expense,
    note: 'มีตัวคูณนำหน้า = 25,000 บาท',
  ),
  ParserCase(
    group: 'A2-thai-number',
    input: 'ค่าเช่า แสนสอง',
    tier: ExpectedTier.high,
    amountSatang: 12000000,
    type: ExpectedType.expense,
    category: 'ที่พัก',
    note: 'แสน + สองหมื่น = 120,000 บาท · หน่วยใหญ่ก็ใช้กฎเดียวกัน',
  ),
  ParserCase(
    group: 'A2-thai-number',
    input: 'ข้าว ห้าสิบ',
    tier: ExpectedTier.high,
    amountSatang: 5000,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'จำนวนเขียนเป็นคำล้วน ไม่มีตัวเลขอารบิกเลย',
  ),
  ParserCase(
    group: 'A2-thai-number',
    input: 'กาแฟ หกสิบห้า',
    tier: ExpectedTier.high,
    amountSatang: 6500,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'เลขสองหลักเขียนเป็นคำ',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'กาแฟ 65.50',
    tier: ExpectedTier.high,
    amountSatang: 6550,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'ทศนิยมสองตำแหน่ง ต้องไม่ปัดทิ้ง เพราะเก็บเป็นสตางค์อยู่แล้ว',
  ),
  ParserCase(
    group: 'A-number-format',
    input: 'เงินเดือน 25000',
    tier: ExpectedTier.high,
    amountSatang: 2500000,
    type: ExpectedType.income,
    category: 'เงินเดือน',
    note: 'จำนวนหลักหมื่นไม่มี comma',
  ),

  // ─────────────────────────────────────────────────────────────
  // B · ตัวดำเนินการทางเลข
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'B-operator',
    input: 'ชานม 45x2',
    tier: ExpectedTier.medium,
    amountSatang: 9000,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'คูณจำนวนชิ้น — ต้องได้ 90 ไม่ใช่ 45 หรือ 452',
  ),
  ParserCase(
    group: 'B-operator',
    input: 'ชานม 45 x 2',
    tier: ExpectedTier.medium,
    amountSatang: 9000,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'เหมือนบน แต่มีช่องว่างคั่น',
  ),
  ParserCase(
    group: 'B-operator',
    input: 'หมูกระทะ 350 หาร 4',
    tier: ExpectedTier.medium,
    amountSatang: 8750,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'หารกับเพื่อน — 87.50 บาท · กฎปัดเศษต้องเขียนไว้ใน AGENTS.md',
  ),
  ParserCase(
    group: 'B-operator',
    input: 'ซื้อเสื้อ 590 ลดเหลือ 490',
    tier: ExpectedTier.medium,
    amountSatang: 49000,
    type: ExpectedType.expense,
    category: 'เสื้อผ้า',
    note: 'สองจำนวนในประโยค ต้องเลือกตัวที่จ่ายจริง ไม่ใช่ตัวแรก',
  ),
  ParserCase(
    group: 'B-operator',
    input: 'กินหมูกระทะกับเพื่อน 350 แต่จ่ายไป 100',
    tier: ExpectedTier.medium,
    amountSatang: 10000,
    type: ExpectedType.expense,
    category: 'อาหาร',
    knownLimitation: true,
    note: 'ยอดรวม vs ยอดที่จ่ายจริง — ถ้าทำไม่ได้ต้องตกไป low ห้ามเดาเป็น 350',
  ),

  // ─────────────────────────────────────────────────────────────
  // C · วันที่
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'C-date',
    input: 'กาแฟ 65 เมื่อวาน',
    tier: ExpectedTier.high,
    amountSatang: 6500,
    type: ExpectedType.expense,
    category: 'อาหาร',
    dayOffset: -1,
    note: 'คำวันที่ต่อท้าย',
  ),
  ParserCase(
    group: 'C-date',
    input: 'เมื่อวานกินข้าว 60',
    tier: ExpectedTier.high,
    amountSatang: 6000,
    type: ExpectedType.expense,
    category: 'อาหาร',
    dayOffset: -1,
    note: 'คำวันที่นำหน้า ตำแหน่งไม่ตายตัว',
  ),
  ParserCase(
    group: 'C-date',
    input: 'ข้าว 60 เมื่อวานซืน',
    tier: ExpectedTier.high,
    amountSatang: 6000,
    type: ExpectedType.expense,
    category: 'อาหาร',
    dayOffset: -2,
    note: 'เมื่อวานซืน ต้องไม่ถูกจับเป็น เมื่อวาน',
  ),
  ParserCase(
    group: 'C-date',
    input: 'จ่ายค่าไฟ 850 วันจันทร์ที่แล้ว',
    tier: ExpectedTier.medium,
    amountSatang: 85000,
    type: ExpectedType.expense,
    category: 'ที่พัก',
    knownLimitation: true,
    note:
        'ชื่อวันย้อนหลัง — ถ้าคำนวณไม่ได้ ให้ default วันนี้แล้วให้ผู้ใช้แก้ ห้ามเดาผิดวัน',
  ),
  ParserCase(
    group: 'C-date',
    input: 'ค่าไฟเดือนนี้จ่ายไป 850 บาทแล้ว',
    tier: ExpectedTier.high,
    amountSatang: 85000,
    type: ExpectedType.expense,
    category: 'ที่พัก',
    dayOffset: 0,
    note: 'ประโยคยาวแบบพูด มีคำรบกวนเยอะ แต่จำนวนกับประเภทยังชัด',
  ),

  // ─────────────────────────────────────────────────────────────
  // D · การออม — สำคัญเป็นพิเศษเพราะเป็นแกนของผลิตภัณฑ์
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'D-saving',
    input: 'ออม 300',
    tier: ExpectedTier.high,
    amountSatang: 30000,
    type: ExpectedType.saving,
    contextDependent: true,
    note:
        'มีกระปุกเดียว → บันทึกเลย · ถ้ามีหลายกระปุกต้องกลายเป็น low (ดูเคสใน G)',
  ),
  ParserCase(
    group: 'D-saving',
    input: 'เก็บ 500',
    tier: ExpectedTier.high,
    amountSatang: 50000,
    type: ExpectedType.saving,
    contextDependent: true,
    note: 'คำว่า เก็บ ต้องแยกจาก เก็บของ หรือ เก็บกวาด',
  ),
  ParserCase(
    group: 'D-saving',
    input: 'หยอดกระปุก 100',
    tier: ExpectedTier.high,
    amountSatang: 10000,
    type: ExpectedType.saving,
    contextDependent: true,
    note: 'คำเรียกที่คนไทยใช้จริงกับการออม',
  ),
  ParserCase(
    group: 'D-saving',
    input: 'ใส่กระปุก 200',
    tier: ExpectedTier.high,
    amountSatang: 20000,
    type: ExpectedType.saving,
    contextDependent: true,
    note: 'อีกคำเรียกของการออม',
  ),
  ParserCase(
    group: 'D-saving',
    input: 'เก็บเงิน 50',
    tier: ExpectedTier.high,
    amountSatang: 5000,
    type: ExpectedType.saving,
    contextDependent: true,
    note: 'จำนวนน้อยก็ต้องรับได้ การออมวันละ 20-50 คือพฤติกรรมเป้าหมาย',
  ),

  // ─────────────────────────────────────────────────────────────
  // E · รายรับ และคำที่ไปได้สองทาง
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'E-income',
    input: 'ขายของได้ 500',
    tier: ExpectedTier.high,
    amountSatang: 50000,
    type: ExpectedType.income,
    category: 'รายได้เสริม',
    note: 'คำว่า ได้ เป็นสัญญาณของรายรับ',
  ),
  ParserCase(
    group: 'E-income',
    input: 'แม่ให้ 500',
    tier: ExpectedTier.high,
    amountSatang: 50000,
    type: ExpectedType.income,
    note: 'แหล่งรายได้หลักของกลุ่มเป้าหมายที่อายุต่ำกว่า 18',
  ),
  ParserCase(
    group: 'E-income',
    input: 'ถูกหวย 2000',
    tier: ExpectedTier.high,
    amountSatang: 200000,
    type: ExpectedType.income,
    note: 'คู่กับเคสถัดไป — คำว่า หวย เหมือนกันแต่คนละทิศ',
  ),
  ParserCase(
    group: 'E-income',
    input: 'หวย 100',
    tier: ExpectedTier.high,
    amountSatang: 10000,
    type: ExpectedType.expense,
    note: 'ซื้อหวย = รายจ่าย · ถ้า parser จับคำว่า หวย อย่างเดียวจะพลาดคู่นี้',
  ),
  ParserCase(
    group: 'E-income',
    input: 'ได้ค่าขนม 1000',
    tier: ExpectedTier.high,
    amountSatang: 100000,
    type: ExpectedType.income,
    note: 'ค่าขนม = รายรับ ไม่ใช่ค่าอาหาร แม้จะมีคำว่า ค่า',
  ),

  // ─────────────────────────────────────────────────────────────
  // F · หมวดหมู่และคำเรียกหลายแบบ
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'F-category',
    input: '7-11 89',
    tier: ExpectedTier.high,
    amountSatang: 8900,
    type: ExpectedType.expense,
    category: 'ของใช้',
    note: 'ตัวเลขในชื่อร้านต้องไม่ถูกอ่านเป็นจำนวนเงิน',
  ),
  ParserCase(
    group: 'F-category',
    input: 'เซเว่น 89',
    tier: ExpectedTier.high,
    amountSatang: 8900,
    type: ExpectedType.expense,
    category: 'ของใช้',
    note: 'คำเรียกเดียวกับ 7-11 ต้อง map ไปหมวดเดียวกัน',
  ),
  ParserCase(
    group: 'F-category',
    input: 'เซเวน 89',
    tier: ExpectedTier.medium,
    amountSatang: 8900,
    type: ExpectedType.expense,
    category: 'ของใช้',
    note: 'สะกดอีกแบบที่พบบ่อย dictionary ต้องรองรับหลายรูป',
  ),
  ParserCase(
    group: 'F-category',
    input: 'แกร็บ 120',
    tier: ExpectedTier.high,
    amountSatang: 12000,
    type: ExpectedType.expense,
    category: 'เดินทาง',
    note: 'ชื่อแบรนด์ทับศัพท์',
  ),
  ParserCase(
    group: 'F-category',
    input: 'วินมอไซค์ 20',
    tier: ExpectedTier.high,
    amountSatang: 2000,
    type: ExpectedType.expense,
    category: 'เดินทาง',
    note: 'คำเฉพาะไทย',
  ),
  ParserCase(
    group: 'F-category',
    input: 'วิน 20',
    tier: ExpectedTier.medium,
    amountSatang: 2000,
    type: ExpectedType.expense,
    category: 'เดินทาง',
    note: 'ตัวย่อของ วินมอไซค์ — สั้นจนกำกวม ควรให้แก้หมวดได้',
  ),
  ParserCase(
    group: 'F-category',
    input: 'ค่ารถเมล์ 8',
    tier: ExpectedTier.high,
    amountSatang: 800,
    type: ExpectedType.expense,
    category: 'เดินทาง',
    note: 'จำนวนหลักหน่วย ต้องไม่ถูกมองว่าน้อยเกินจนถูกปฏิเสธ',
  ),
  ParserCase(
    group: 'F-category',
    input: 'เติมน้ำมัน 500 บาท',
    tier: ExpectedTier.high,
    amountSatang: 50000,
    type: ExpectedType.expense,
    category: 'เดินทาง',
    note: 'คำว่า เติม ใช้กับทั้งน้ำมันและเกม ต้องดูคำถัดไป',
  ),
  ParserCase(
    group: 'F-category',
    input: 'เติมเกม 100',
    tier: ExpectedTier.high,
    amountSatang: 10000,
    type: ExpectedType.expense,
    category: 'บันเทิง',
    note: 'คู่กับเคสบน คำว่า เติม เหมือนกันแต่คนละหมวด',
  ),
  ParserCase(
    group: 'F-category',
    input: 'หมอฟัน 800',
    tier: ExpectedTier.high,
    amountSatang: 80000,
    type: ExpectedType.expense,
    category: 'สุขภาพ',
    note: 'หมวดสุขภาพ',
  ),
  ParserCase(
    group: 'F-category',
    input: 'ตัดผม 150',
    tier: ExpectedTier.high,
    amountSatang: 15000,
    type: ExpectedType.expense,
    category: 'ดูแลตัวเอง',
    note: 'หมวดดูแลตัวเอง',
  ),
  ParserCase(
    group: 'F-category',
    input: 'ค่าเทอม 15,000',
    tier: ExpectedTier.high,
    amountSatang: 1500000,
    type: ExpectedType.expense,
    category: 'การศึกษา',
    note: 'รายจ่ายก้อนใหญ่ของกลุ่มเป้าหมาย',
  ),
  ParserCase(
    group: 'F-category',
    input: 'ค่าส่ง 40',
    tier: ExpectedTier.high,
    amountSatang: 4000,
    type: ExpectedType.expense,
    category: 'ของใช้',
    note: 'ค่าส่งของออนไลน์',
  ),

  // ─────────────────────────────────────────────────────────────
  // G · กำกวมจริง — ต้องถาม ห้ามเดา
  //     เคสกลุ่มนี้มีค่าที่สุด เพราะ "คำตอบที่ถูก" คือการยอมรับว่าไม่รู้
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'G-ambiguous',
    input: 'โอน 500',
    tier: ExpectedTier.low,
    note: 'จ่ายให้คนอื่น หรือ ย้ายเข้ากระปุก — ต้องถามพร้อมปุ่มตัวเลือก',
  ),
  ParserCase(
    group: 'G-ambiguous',
    input: 'ยืมเพื่อน 200',
    tier: ExpectedTier.low,
    note: 'เราให้เขายืม หรือ เรายืมเขามา — ทิศตรงข้ามกันเลย',
  ),
  ParserCase(
    group: 'G-ambiguous',
    input: 'คืนเงินเพื่อน 200',
    tier: ExpectedTier.low,
    note: 'คืนให้เขา หรือ เขาคืนเรา',
  ),
  ParserCase(
    group: 'G-ambiguous',
    input: 'จ่ายแทนเพื่อน 300',
    tier: ExpectedTier.low,
    note: 'เป็นรายจ่ายจริง หรือเป็นเงินที่จะได้คืน',
  ),
  ParserCase(
    group: 'G-ambiguous',
    input: 'ออม 300',
    tier: ExpectedTier.low,
    contextDependent: true,
    note:
        'เคสนี้ตั้ง state ให้มีหลายกระปุก → ต้องถามว่ากระปุกไหน ห้ามเลือกให้เอง',
  ),
  ParserCase(
    group: 'G-ambiguous',
    input: 'จ่ายค่าเช่า 4500 ทุกเดือน',
    tier: ExpectedTier.medium,
    amountSatang: 450000,
    type: ExpectedType.expense,
    category: 'ที่พัก',
    note: 'บันทึกได้ แต่คำว่า ทุกเดือน ควรเสนอให้ตั้งเป็นรายการประจำ',
  ),

  // ─────────────────────────────────────────────────────────────
  // H · ต้องปฏิเสธ
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'H-reject',
    input: 'ข้าว',
    tier: ExpectedTier.reject,
    note: 'ไม่มีจำนวนเงิน ห้ามสร้างรายการเด็ดขาด',
  ),
  ParserCase(
    group: 'H-reject',
    input: '150',
    tier: ExpectedTier.reject,
    note: 'มีแต่ตัวเลข ไม่รู้ว่าอะไร ต้องถามว่าเป็นรายการอะไร',
  ),
  ParserCase(
    group: 'H-reject',
    input: 'กาแฟ -50',
    tier: ExpectedTier.reject,
    note: 'ค่าติดลบ ต้องถูกปฏิเสธที่ domain ด้วย (I5)',
  ),
  ParserCase(
    group: 'H-reject',
    input: '',
    tier: ExpectedTier.reject,
    note: 'ข้อความว่าง',
  ),
  ParserCase(
    group: 'H-reject',
    input: '   ',
    tier: ExpectedTier.reject,
    note: 'ช่องว่างล้วน ต้อง normalize แล้วปฏิเสธ',
  ),
  ParserCase(
    group: 'H-reject',
    input: 'กาแฟ 999999999999',
    tier: ExpectedTier.reject,
    note: 'เกินเพดานที่นิยามใน format.dart',
  ),
  ParserCase(
    group: 'H-reject',
    input: 'asdfgh',
    tier: ExpectedTier.reject,
    note: 'ไม่มีทั้งคำที่รู้จักและตัวเลข',
  ),
  ParserCase(
    group: 'H-reject',
    input: 'กาแฟ 65 65 65',
    tier: ExpectedTier.low,
    note: 'จำนวนซ้ำหลายตัวโดยไม่มี operator — ต้องถาม ไม่ใช่เดาว่าเอาตัวไหน',
  ),

  // ─────────────────────────────────────────────────────────────
  // I · ทนคำสะกดผิด
  //     มีหลักฐานจริงจากแบบสอบถามว่ากลุ่มเป้าหมายพิมพ์ผิดบ่อย
  //     (เช่น "ตอนขึันมหาลัย") จึงไม่ใช่เรื่องที่ไว้ทำทีหลัง
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'I-typo',
    input: 'กาแฟ 65 บาด',
    tier: ExpectedTier.high,
    amountSatang: 6500,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'บาด/บาท — สระผิดตัวเดียว ห้ามทำให้ทั้งประโยคพัง',
  ),
  ParserCase(
    group: 'I-typo',
    input: 'ขาวมันไก่ 50',
    tier: ExpectedTier.medium,
    amountSatang: 5000,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'ขาว/ข้าว — จำนวนเงินยังต้องถูก แม้หมวดจะไม่มั่นใจ',
  ),
  ParserCase(
    group: 'I-typo',
    input: 'ค่าอาหาน 120',
    tier: ExpectedTier.medium,
    amountSatang: 12000,
    type: ExpectedType.expense,
    category: 'อาหาร',
    note: 'อาหาน/อาหาร — ตัวสะกดผิดท้ายคำ',
  ),

  // ─────────────────────────────────────────────────────────────
  // J · หลายรายการในข้อความเดียว
  // ─────────────────────────────────────────────────────────────
  ParserCase(
    group: 'J-multi',
    input: 'ข้าว 50 กาแฟ 40',
    tier: ExpectedTier.medium,
    entryCount: 2,
    type: ExpectedType.expense,
    knownLimitation: true,
    note: 'สองรายการในบรรทัดเดียว — ถ้าแยกไม่ได้ต้องตกไป low และถาม '
        'ห้ามบันทึกเป็นรายการเดียว 90 บาท',
  ),
  ParserCase(
    group: 'J-multi',
    input: 'ข้าว 50 + กาแฟ 40',
    tier: ExpectedTier.medium,
    entryCount: 2,
    type: ExpectedType.expense,
    knownLimitation: true,
    note: 'มีเครื่องหมายคั่นชัดเจน ควรแยกง่ายกว่าเคสบน',
  ),
];

/// เคสที่ต้องผ่านเสมอ ไม่ยกเว้นให้
Iterable<ParserCase> get mandatoryCases =>
    parserEdgeCases.where((c) => !c.knownLimitation);

/// เคสที่ยอมให้ยังทำไม่ได้ แต่ห้ามตกไปอยู่ tier=high
Iterable<ParserCase> get knownLimitationCases =>
    parserEdgeCases.where((c) => c.knownLimitation);
