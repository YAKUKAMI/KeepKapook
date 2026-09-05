# Local metrics, W4 retention และ parser corpus

## เป้าหมาย

โมดูลนี้ตอบว่าผู้ใช้กลับมาบันทึกหรือไม่ และ loop การออมหรือรายจ่ายทำงานหรือไม่ โดยไม่ติด analytics SDK และไม่ส่งข้อมูลออกจากเครื่องอัตโนมัติ

## LocalMetrics fields

| Field | ความหมาย |
|---|---|
| `installedDay` | วันติดตั้ง/วันแรกที่อนุมานได้ รูป `YYYY-MM-DD` |
| `recordingDays` | set ของวันที่มีการบันทึก; วันเดียวไม่ถูกนับซ้ำ |
| `quickEntryTierCounts` | จำนวน high/medium/low/reject |
| `undoCount` | จำนวน undo |
| `correctionCount` | จำนวนแก้ไขย้อนหลัง |
| `weeklyReviewOpenCount` | จำนวนเปิด weekly review |
| `recoveryPlanAcceptedCount` | จำนวนรับ Recovery Plan |
| `nextGoalOfferAcceptedCount` | จำนวนรับข้อเสนอเป้าถัดไป |
| `nextGoalOfferDeferredCount` | จำนวนกดไว้ก่อน |
| `savingRecordCount` | จำนวนการบันทึกออม |
| `expenseRecordCount` | จำนวนการบันทึกรายจ่าย |
| `parserCorpusCollectionEnabled` | สวิตช์เก็บข้อความ corpus |
| `parserCorpus` | ข้อความ low/reject/corrected แบบจำกัดสูงสุด 200 ตัวอย่าง |

`nextGoalOfferAcceptanceRate/Percent` คำนวณจาก accepted ÷ (accepted+deferred); ไม่มี decision คืน 0

## Reducer functions

- `recordLoggingActivity`: เพิ่มวันและ counter saving/expense ตาม kind
- `recordQuickEntryAttempt`: เพิ่ม tier; low/reject อาจเพิ่ม corpus
- `recordUndo`: เพิ่ม undo
- `recordCorrection`: เพิ่ม correction และอาจเก็บ parser input
- `recordWeeklyReviewOpen`: เพิ่มจำนวนเปิด report
- `recordRecoveryPlanAccepted`: เพิ่ม action recovery
- `recordNextGoalOfferDecision`: แยก accepted/deferred
- `summarizeLocalMetrics`: สร้าง logging day count, active week numbers และ W4 status

ทุก reducer คืน object ใหม่ผ่าน `copyWith`; AppState เป็นผู้ persist และ notify

## W4 logging retention

เลขสัปดาห์คำนวณจาก `(recordingDay - installedDay) ~/ 7 + 1`. เมื่อยังไม่ครบ 28 วัน สถานะเป็น `waiting`; หลังครบแล้ว ถ้ามีวันบันทึกอยู่ใน week 4 เป็น `retained` มิฉะนั้น `notRetained`

ดังนั้น W4 ใช้เพียง:

- `installedDay`
- `recordingDays`
- `asOf` ที่ UI ส่งเข้า summary

ไม่ใช้ยอดเงินหรือชื่อรายการ

## Corpus privacy

`ParserCorpusSample` เก็บ `input`, `reason` และ `recordedDay`. Reason มี low/reject/corrected. การเพิ่มตัวอย่าง:

- ทำเฉพาะเมื่อสวิตช์เปิดและข้อความหลัง trim ไม่ว่าง
- deduplicate ข้อความ+reason+วันเดียวกัน
- เก็บล่าสุดไม่เกิน 200
- ไม่สร้าง structured amount/category/note event เพิ่ม
- ผู้ใช้ดู ปิด และล้างได้ใน Settings

ข้อความอยู่ใน state JSON และรวมไปกับ backup export เพื่อให้ผู้ทดสอบเลือกส่งไฟล์เอง ไม่มี background upload

## Migration v5 → v6

สร้าง metrics จากวันแรกที่พบใน goal/ledger/transaction, สร้าง recording days จากรายการที่นับเป็น habit, และนับ saving/expense จากข้อมูลเดิมแบบ conservative. Migration ไม่สร้าง corpus ย้อนหลังและไม่เก็บยอดเงินราย event

