# KeepKapook Release Checklist

สถานะ config ที่ตรวจแล้วเมื่อ 31 สิงหาคม 2026:

- Android application ID: `com.keepkapook`
- iOS bundle ID: `com.keepkapook`
- ชื่อแอปที่แสดง: `KeepKapook`
- เวอร์ชันเริ่มต้น: `1.0.0+1`
- Android SDK: compile/target SDK 36, min SDK 24
- App icon: Android (legacy + adaptive), iOS และ web ใช้ภาพต้นฉบับเดียวกันแล้ว
- `flutter build apk --release` ผ่านและเซ็นด้วย KeepKapook release certificate จริง
- SHA-256 certificate: `36:2C:32:A8:B7:5A:4C:A2:F8:D5:34:87:32:E9:86:CF:68:AC:A2:75:F1:01:52:BC:3D:A4:7E:BD:2F:F0:9A:80`

## 1. Signing — ต้องทำก่อนสร้างไฟล์ส่ง Store

- [x] สร้าง Android release keystore และเก็บไว้นอก repository
- [x] สร้าง `android/key.properties` เฉพาะในเครื่อง ห้าม commit ค่า path/password/alias
- [x] เปลี่ยน release signing config จาก debug certificate เป็น release key
- [x] ยืนยันว่า `key.properties`, `*.jks` และ `*.keystore` ถูก `.gitignore`
- [ ] สำรอง keystore และไฟล์กู้คืนในที่ปลอดภัยอย่างน้อย 2 แห่ง
- [ ] เปิดใช้ Play App Signing และเก็บ upload key แยกจาก app signing key
- [ ] สร้างไฟล์ส่ง Play Store ด้วย `flutter build appbundle --release`
- [ ] สำหรับ iOS สร้าง App ID `com.keepkapook`, Distribution Certificate และ provisioning profile ใน Apple Developer

## 2. Android Developer Console — Limited distribution

- [x] สร้างบัญชี Personal แบบ Limited distribution ชื่อ KeepKapook
- [x] ส่งลงทะเบียน package `com.keepkapook` พร้อม release certificate SHA-256
- [ ] รอ Google เปลี่ยนสถานะ package จาก “อยู่ระหว่างการตรวจสอบ” เป็น “ลงทะเบียนแล้ว”
- [ ] อนุญาตอุปกรณ์ทดสอบผ่านลิงก์/QR สูงสุด 20 เครื่อง
- [ ] ทดลองติดตั้ง APK ที่เซ็นจริงและทดสอบอัปเดตทับด้วย certificate เดิม

## 3. Google Play Console

- [ ] สร้างแอปใหม่และยืนยัน package name `com.keepkapook` ก่อนอัปโหลดครั้งแรก
- [ ] กรอก Store listing: ชื่อ คำอธิบายสั้น/ยาว ไอคอน feature graphic ภาพหน้าจอ และช่องทางติดต่อ
- [ ] กรอก App content: นโยบายความเป็นส่วนตัว, Data safety, กลุ่มอายุเป้าหมาย, content rating และสถานะโฆษณา
- [ ] ระบุให้ชัดว่า KeepKapook เป็นเครื่องมือบันทึก/ตั้งเป้าการออม ไม่ใช่ธนาคาร ไม่ถือเงินจริง และฟีเจอร์การเงินเป็นการจำลอง
- [ ] อัปโหลด AAB ที่เซ็นด้วย upload key ไป Internal testing ก่อน Production
- [ ] ทดสอบติดตั้งและอัปเดตผ่าน Play Internal testing บนอุปกรณ์จริงอย่างน้อยหนึ่งเครื่อง

## 4. Privacy policy URL

- [ ] จัดทำหน้า Privacy Policy ภาษาไทยบน HTTPS URL สาธารณะ เปิดได้โดยไม่ต้องล็อกอิน
- [ ] อธิบายข้อมูลที่เก็บในเครื่อง: โปรไฟล์ เป้าหมาย ยอดบันทึก รายรับรายจ่าย ประวัติ และการตั้งค่า
- [ ] อธิบายว่ารูปสลิปเข้าถึงเฉพาะรูปที่ผู้ใช้เลือก และไม่มีการอัปโหลดออกจากเครื่อง
- [ ] อธิบายการ export/import JSON ว่าไฟล์ออกจากแอปเมื่อผู้ใช้เลือกแชร์หรือบันทึกเอง
- [ ] อธิบายวิธีล้างข้อมูล ระยะเวลาการเก็บ และช่องทางติดต่อเจ้าของแอป
- [ ] ใส่ URL เดียวกันใน Play Console, App Store Connect และหน้าเกี่ยวกับแอป

## 5. ตรวจรับก่อนปล่อย

- [ ] ตรวจไอคอนบน launcher แบบวงกลม สี่เหลี่ยม และ adaptive mask บนอุปกรณ์จริง
- [ ] ทดสอบ onboarding/disclaimer, สร้างกระปุก, โอน/ถอนแบบจำลอง, เลือกรูปสลิป และสำรอง/กู้คืนข้อมูล
- [ ] ทดสอบอัปเกรดจากข้อมูล schema v1 ผ่าน v2/v3/v4 ถึง v5 โดยข้อมูล ยอดเงิน EXP และ badge ที่ unlock แล้วไม่ลดลง
- [ ] แก้ analyzer info เดิมให้สะอาดก่อน release gate ขั้นสุดท้าย
- [ ] พิจารณา bundle ฟอนต์ Prompt เพื่อไม่ต้องพึ่งการดาวน์โหลดครั้งแรก
- [ ] เพิ่ม GitHub remote แล้ว push branch/commit หลังทดสอบผ่าน โดยตรวจว่าไม่มี secret ใน staged files
