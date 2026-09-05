# ข้อจำกัดและ backlog ที่ยืนยันจากโค้ด

เอกสารนี้แยกสิ่งที่ “ยังไม่มีจริง” ออกจากฟีเจอร์ที่ทำแล้ว เพื่อไม่ให้เอกสารการตลาดกล่าวเกินโค้ด

## ยังไม่มีหรือยังจำลอง

- ไม่เชื่อมธนาคาร, e-wallet หรือเงินจริง
- shared saving/member เป็นข้อมูลจำลองในเครื่อง ไม่มี sync ระหว่างผู้ใช้
- slip เลือกรูปและกรอกเอง ยังไม่มี OCR
- ไม่มี cloud backup/account sync; เปลี่ยนเครื่องต้อง export/import เอง
- ไม่มี backend, push server หรือ third-party analytics
- goal album ยังไม่มี
- parser เป็น deterministic convenience ไม่ใช่ภาษาธรรมชาติแบบเปิดกว้าง และ dictionary ยังจำกัด

## Platform/release

- iOS ยังต้อง build/sign และทดสอบจริงบน macOS/Xcode
- Google Play/App Store listing, privacy URL, Data safety และ reviewer flow เป็นงาน manual ตาม `RELEASE.md`
- Android limited distribution/package verification ขึ้นกับการอนุมัติของ Google และอุปกรณ์ tester

## Technical notes

- `AppState` ยังเป็นไฟล์ใหญ่และรวม mutation หลาย domain แม้ pure calculation แยกออกแล้ว
- storage key ลงท้าย `_v1` แต่ schema จริง v6; ห้ามตีความ version จากชื่อ key
- `Goal.isLockedNow` ยังอ่าน `DateTime.now()` ใน getter; logic ที่ต้อง deterministic ควรรับเวลาแทนเมื่อมีการแก้รอบถัดไป
- fixture parser เป็นข้อมูลสังเคราะห์ ไม่ใช่ measured user accuracy
- README เดิมเคยใช้คำ “Phase” และบางรายการล้าสมัย; เอกสารใน `docs/` คือ reference ปัจจุบัน

## กฎเมื่อขยายระบบ

- model/persisted field เปลี่ยนต้อง bump schema, เพิ่ม step migration และ fixture version ก่อนหน้า
- transaction ใหม่ต้องผ่าน canonical TxType→flow และ I13
- quest/badge ใหม่ต้องมี reachable handler และ I11
- สูตรใหม่ต้องเป็น pure function ใน `utils/`
- เงินต้องคงเป็น int satang และผ่าน domain validation ก่อน mutation
- dependency ใหม่ต้องไม่ทำ `flutter build web` พัง
- ข้อมูลที่แอปไม่รู้จริงห้ามเอาไปสร้างคำแนะนำที่ดูแม่นยำ

