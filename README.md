# 🐷 KeepKapook — Flutter

เวอร์ชัน native (iOS/Android) ของ KeepKapook พอร์ตจากเว็บ (Next.js) — **Phase 1**

## สถานะ (Phase 1 + 2 — compile ผ่าน `flutter build web`)
- Theme + สีแบรนด์ + ฟอนต์ Prompt (google_fonts)
- Models + State (`ChangeNotifier`) + persist ด้วย `shared_preferences`
- Dashboard: hero + EXP bar + ยอดรวม + กราฟ 7 วัน (fl_chart) + กระปุก
- Goals: list + tabs + สร้าง/ดู/ลบกระปุก
- Add saving (เข้ากระปุก/ยังไม่จัดสรร) + EXP/milestone/overflow
- Quests (รับรางวัล EXP), Achievements (level + badge)
- History (รายการ + กระปุกสำเร็จ)
- Unallocated (จัดสรรเข้ากระปุก)
- Settings (ชื่อ, โหมดเด็ก/ผู้ใหญ่, ทางลัด, reset demo)
- Celebration dialog เมื่อทำเป้าหมายสำเร็จ
- Bottom nav 5 แท็บ: ภาพรวม/กระปุก/ภารกิจ/ประวัติ/ตั้งค่า

## Phase 3 (เพิ่มแล้ว — compile ผ่าน)
- **Onboarding** wizard (ชื่อ+โหมด → สร้างกระปุกแรก) แสดงเมื่อยังไม่ onboarded
- **Recovery Plan** ในหน้ากระปุก (ตามแผนไม่ทัน → ออมเพิ่ม/เลื่อนวัน/ลดเป้า)
- **สแกนสลิป** (image_picker เลือกรูป + กรอกข้อมูลเอง + ยืนยันก่อนบันทึก)
- ปุ่มเพิ่มเงิน/สแกนสลิปใน dashboard hero

## Phase 4 — MAKE-style (เพิ่มแล้ว, compile ผ่าน)
- **รายรับ-รายจ่าย** (ledger): สรุปเดือน (รับ/จ่าย/คงเหลือ) + หมวดหมู่ + เพิ่ม/ลบ — การ์ดใน dashboard → LedgerScreen
- **Cloud Pocket ยืดหยุ่น**: กระเป๋าใช้จ่าย (ไม่มีเป้าหมาย) สร้างจาก NewGoalScreen (toggle)
- **โอนระหว่างกระปุก/กระเป๋า** (transfer)
- **ล็อกเงิน** (lock 7/30/90 วัน กันถอน) + ปลดล็อก
- **ออมด้วยกัน / แชร์** (สมาชิก mock) — chip + จัดการสมาชิก
- **ถอนออก** (withdraw ไปยังไม่จัดสรร)

## ยังไม่ได้ทำ
- **OCR อ่านสลิปอัตโนมัติ** (google_mlkit_text_recognition — mobile-only, จะพัง web build → ทำแยกตอน build มือถือ)
- Goal Album (รูปในกระปุก), animation เพิ่ม, edit goal, insight/กราฟหมวดรายจ่าย

## หมายเหตุ Windows
build ที่ใช้ plugin (image_picker/shared_preferences) แนะนำเปิด **Developer Mode**
(`start ms-settings:developers`) เพื่อให้ symlink plugin ทำงาน — web build ไม่ต้อง

## รัน
ต้องมี Flutter SDK ก่อน (https://docs.flutter.dev/get-started/install)

```bash
cd keepkapook_flutter
flutter create .          # สร้าง android/ ios/ web/ platform files ครั้งแรก
flutter pub get
flutter run               # เลือก device/emulator
```

> `flutter create .` จะเติมโฟลเดอร์ platform (android/ios/web) โดยไม่ทับ lib/ ที่มีอยู่

## Build
```bash
flutter build apk         # Android APK
flutter build appbundle   # Play Store
flutter build ios         # ต้องใช้ macOS + Xcode
```

## โครงสร้าง
```
lib/
├─ main.dart              # shell + bottom nav + FAB
├─ theme/app_theme.dart   # สี + ThemeData
├─ models/models.dart     # Goal, SavingTransaction, AppUser
├─ state/app_state.dart   # ChangeNotifier + persist + mock + actions
├─ utils/format.dart      # money/date/level/cap
├─ widgets/goal_card.dart
└─ screens/               # dashboard, goals, goal_detail, add_saving, new_goal
```

## หมายเหตุ
- ยอดเงินเป็นข้อมูลที่ผู้ใช้บันทึกเอง ไม่เชื่อมบัญชีธนาคาร
- logic ตรงกับเว็บ (EXP, level threshold, เพดานต่อวัน) พอร์ตใน `utils/format.dart` + `state/app_state.dart`
