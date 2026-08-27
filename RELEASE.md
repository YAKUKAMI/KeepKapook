# KeepKapook Release Checklist

สถานะ config ที่ตรวจแล้วเมื่อ 27 สิงหาคม 2026:

- Android application ID: `com.keepkapook`
- iOS bundle ID: `com.keepkapook`
- ชื่อแอปที่แสดง: `KeepKapook`
- เวอร์ชันเริ่มต้น: `1.0.0+1`
- Android SDK: compile/target SDK 36, min SDK 24
- App icon: Android (legacy + adaptive), iOS และ web ใช้ภาพต้นฉบับเดียวกันแล้ว
- `flutter build apk --release` ผ่าน แต่ APK ปัจจุบันยังเซ็นด้วย **debug certificate** ใช้ทดสอบเท่านั้น ห้ามอัปโหลดขึ้น Store

## 1. Signing — ต้องทำก่อนสร้างไฟล์ส่ง Store

- [ ] สร้าง Android upload keystore และเก็บไว้นอก repository พร้อมสำรองในที่ปลอดภัย
- [ ] สร้าง `android/key.properties` เฉพาะในเครื่อง ห้าม commit ค่า path/password/alias
- [ ] เปลี่ยน release signing config จาก debug certificate เป็น upload key
- [ ] ยืนยันว่า `key.properties`, `*.jks` และ `*.keystore` ยังถูก `.gitignore`
- [ ] เปิดใช้ Play App Signing และเก็บ upload key แยกจาก app signing key
- [ ] สร้างไฟล์ส่ง Play Store ด้วย `flutter build appbundle --release`
- [ ] สำหรับ iOS สร้าง App ID `com.keepkapook`, Distribution Certificate และ provisioning profile ใน Apple Developer

## 2. Google Play Console

- [ ] สร้างแอปใหม่และยืนยัน package name `com.keepkapook` ก่อนอัปโหลดครั้งแรก
- [ ] กรอก Store listing: ชื่อ คำอธิบายสั้น/ยาว ไอคอน feature graphic ภาพหน้าจอ และช่องทางติดต่อ
- [ ] กรอก App content: นโยบายความเป็นส่วนตัว, Data safety, กลุ่มอายุเป้าหมาย, content rating และสถานะโฆษณา
- [ ] ระบุให้ชัดว่า KeepKapook เป็นเครื่องมือบันทึก/ตั้งเป้าการออม ไม่ใช่ธนาคาร ไม่ถือเงินจริง และฟีเจอร์การเงินเป็นการจำลอง
- [ ] อัปโหลด AAB ที่เซ็นด้วย upload key ไป Internal testing ก่อน Production
- [ ] ทดสอบติดตั้งและอัปเดตผ่าน Play Internal testing บนอุปกรณ์จริงอย่างน้อยหนึ่งเครื่อง

## 3. Privacy policy URL

- [ ] จัดทำหน้า Privacy Policy ภาษาไทยบน HTTPS URL สาธารณะ เปิดได้โดยไม่ต้องล็อกอิน
- [ ] อธิบายข้อมูลที่เก็บในเครื่อง: โปรไฟล์ เป้าหมาย ยอดบันทึก รายรับรายจ่าย ประวัติ และการตั้งค่า
- [ ] อธิบายว่ารูปสลิปเข้าถึงเฉพาะรูปที่ผู้ใช้เลือก และไม่มีการอัปโหลดออกจากเครื่อง
- [ ] อธิบายการ export/import JSON ว่าไฟล์ออกจากแอปเมื่อผู้ใช้เลือกแชร์หรือบันทึกเอง
- [ ] อธิบายวิธีล้างข้อมูล ระยะเวลาการเก็บ และช่องทางติดต่อเจ้าของแอป
- [ ] ใส่ URL เดียวกันใน Play Console, App Store Connect และหน้าเกี่ยวกับแอป

## 4. ตรวจรับก่อนปล่อย

- [ ] ตรวจไอคอนบน launcher แบบวงกลม สี่เหลี่ยม และ adaptive mask บนอุปกรณ์จริง
- [ ] ทดสอบ onboarding/disclaimer, สร้างกระปุก, โอน/ถอนแบบจำลอง, เลือกรูปสลิป และสำรอง/กู้คืนข้อมูล
- [ ] ทดสอบอัปเกรดจากข้อมูล schema v1 เป็น v2 โดยข้อมูลและยอดเงินไม่เปลี่ยน
- [ ] แก้ analyzer info เดิมให้สะอาดก่อน release gate ขั้นสุดท้าย
- [ ] พิจารณา bundle ฟอนต์ Prompt เพื่อไม่ต้องพึ่งการดาวน์โหลดครั้งแรก
- [ ] เพิ่ม GitHub remote แล้ว push branch/commit หลังทดสอบผ่าน โดยตรวจว่าไม่มี secret ใน staged files
