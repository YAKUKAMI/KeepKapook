# Build, signing, release และ security

## Identity

| ค่า | ปัจจุบัน |
|---|---|
| App name | KeepKapook |
| Android applicationId/namespace | `com.keepkapook` |
| iOS bundle ID | `com.keepkapook` |
| Version | `1.0.0+1` |
| Android min SDK | ค่าจาก Flutter SDK; release checklist ระบุ 24 |
| Android compile/target | ค่าจาก Flutter SDK; release checklist ระบุ 36 |
| Java/Kotlin target | 17 |

## Build commands

```bash
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build web
flutter build apk --release
flutter build appbundle --release
```

iOS release ต้องใช้ macOS, Xcode, Apple Developer certificate และ provisioning profile

## Android signing

`android/app/build.gradle.kts` อ่าน `android/key.properties` เฉพาะในเครื่อง หาก release task ไม่มี config จะ fail ชัดเจน ไม่ fallback ไป debug key. Keystore, key.properties และ secret ต้องไม่ commit

Release certificate SHA-256 ที่บันทึกใน `RELEASE.md`:

`36:2C:32:A8:B7:5A:4C:A2:F8:D5:34:87:32:E9:86:CF:68:AC:A2:75:F1:01:52:BC:3D:A4:7E:BD:2F:F0:9A:80`

Fingerprint เป็นข้อมูลยืนยันตัวแอป ไม่ใช่ private key. Private keystore/password ต้องสำรองภายนอกอย่างน้อยสองแห่ง

## Permissions

Android ขอ `RECEIVE_BOOT_COMPLETED` เพื่อคืน local reminder หลัง reboot และใช้ notification receivers ของ plugin ไม่มี broad storage/network permission ใน manifest

iOS มี `NSPhotoLibraryUsageDescription` ภาษาไทย ชี้ว่าเข้าถึงเฉพาะรูปที่เลือกและไม่ upload

## Web/PWA

`web/manifest.json` กำหนด standalone, portrait, icon 192/512 และ maskable. Web ไม่มี local notification menu ผ่าน stub. CI build web เพื่อกัน dependency ที่รองรับเฉพาะ mobile ทำ pipeline พัง

## Release checklist ที่ยังเป็นงาน manual

- สำรอง keystore/recovery material
- เปิด Play App Signing และแยก upload key
- สร้าง AAB และ Internal testing
- จัด store listing, screenshots, content rating, Data safety
- ทำ privacy policy HTTPS สาธารณะ
- ทดสอบ install/update บนอุปกรณ์จริง
- สำหรับ iOS จัด certificate/profile และ App Store Connect

ติดตาม checkbox ล่าสุดใน `RELEASE.md`

## Security/privacy boundaries

- ไม่เชื่อมธนาคารและไม่ถือเงินจริง
- ไม่มี analytics SDK บุคคลที่สาม
- ไม่มี automatic upload
- backup ออกนอกแอปเมื่อผู้ใช้เลือกเอง
- parser local deterministic ไม่มี LLM/network
- ห้าม commit token, keystore, password หรือ config ที่มี key

