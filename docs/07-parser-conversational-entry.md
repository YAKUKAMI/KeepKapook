# Thai parser และ conversational entry

## ขอบเขต

Parser ใต้ `lib/utils/parser/` เป็น pure Dart และไม่ import Flutter/network/LLM จึง deterministic และเทสได้เร็ว

## Data contract

`ParseResult` มี original/normalized input, รายการที่ parse ได้, จำนวนที่ตรวจพบพร้อมตำแหน่ง, confidence รวม, tier, reject reason หรือคำถาม

แต่ละ `ParsedLedgerItem` มี `amountSatang`, `ParsedEntryType`, category, date, description และ `FieldConfidence` แยก amount/type/category/date

Tier:

- high: amount ≥ .98, type ≥ .95, category ≥ .90, date ≥ .70
- medium: amount ≥ .98 และ type ≥ .95
- low: กำกวมและต้องถาม
- reject: ข้อมูลใช้ไม่ได้ เช่นไม่มีเงิน, ≤0, เกินเพดาน หรือ operator ผิด

## Pipeline

1. `normalizeThaiLedgerInput`: trim/space, เลขไทย, comma, ฿/บ./บาท, alias และคำจำนวนไทย
2. `extractDetectedAmounts`: หาเงินทุกตัว เก็บ raw/start/end/satang และ flag operand
3. `parseLedgerDate`: วันนี้, เมื่อวาน, เมื่อวานซืน และวันในสัปดาห์ที่แล้วเทียบ `referenceDate`
4. reject ค่าไม่ปลอดภัย
5. ตรวจ ambiguity เช่นโอน, ยืมเพื่อน, คืนเงินเพื่อน
6. operator: `ลดเหลือ`, `จ่ายไป`, `x/×`, `หาร`; การหารปัด half-up
7. classify type/category ด้วย dictionary กลาง
8. สร้าง item/confidence/tier หรือคำถาม

## จำนวนไทย

Normalizer รองรับ alias และโครงจำนวนไทย รวมหน่วย พัน/หมื่น/แสน/ล้าน, ตัวคูณนำหน้า, เลขอารบิกผสม และจำนวนคำล้วนตาม regression fixtures. `7-11`, `เซเวน` ถูก normalize เป็น `เซเว่น` ก่อน extract เพื่อไม่ให้เลขร้านกลายเป็นเงินสองก้อน

## Dictionary

`parser_dictionary.dart` เป็นจุดเดียวสำหรับ:

- `normalizationAliases`
- `typeKeywordRules`
- `categoryKeywordRules`
- คำถามโอน/ยืม/คืนเงิน/ไม่ทราบประเภท

หมวดปัจจุบันครอบคลุม เงินเดือน, รายได้เสริม, รายได้พิเศษ, ค่าขนม, เป้าหมายการออม, ที่พัก, อาหาร, เดินทาง, การศึกษา, สุขภาพ, ดูแลตัวเอง, บันเทิง และของใช้

## Ambiguity policy

- ไม่ทราบ type → low พร้อมตัวเลือก รายจ่าย/รายรับ/เข้าเป้าหมาย/ยกเลิก
- “ออม” และมีกระปุกหลายใบ → low พร้อมรายชื่อกระปุก
- พบหลายจำนวน → low ถามแยก/รวม/ยกเลิก แม้แยก item ได้
- โอน/ยืม/คืนเงินที่ทิศทางไม่ชัด → low; ไม่เดา
- tier high ที่ผลผิดต้องเป็นศูนย์ตาม regression gate

## การต่อ UI

`ConversationalEntrySheet` รับข้อความแล้วเรียก parser:

- high: save ทันทีและ snackbar undo 5 วินาที
- medium: save ทันทีแล้วแสดง chip หมวด/วันที่แก้ในบรรทัดเดิม
- low: ไม่สร้างรายการ; แสดงคำถามเดียวจาก `ParseQuestion`
- reject: แสดงเหตุผลว่าต้องเพิ่ม/แก้อะไร

เมื่อผู้ใช้ตอบคำถาม low, sheet สร้างผลที่ชัดขึ้นหรือเลือก goal แล้วจึง save. ทุก state mutation ผ่าน `AppState.saveParsedEntries`

## Regression fixtures

`test/fixtures/parser_edge_cases.dart` เป็นประโยคสังเคราะห์ที่เจ้าของภาษากลุ่มเป้าหมายตรวจ ใช้เป็น regression gate เชิงโครงสร้าง ไม่เรียกว่า accuracy ผู้ใช้จริง. Accuracy จริงต้องใช้ข้อความจากผู้ใช้จริงอย่างน้อย 50 ประโยคซึ่งเก็บแบบสมัครใจ/local-only จาก low/reject และรายการที่แก้หลังบันทึก

