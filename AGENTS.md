# AGENTS.md — KeepKapook (Flutter)

Context สำหรับ AI coding agent (Codex ฯลฯ) ที่มาทำงานต่อในโปรเจกต์นี้.

## ภาพรวม
KeepKapook = แอปสร้างนิสัยการออมเงินสำหรับวัยรุ่น/ผู้เริ่มออม (โค้ชการออม)
พอร์ตมาจากเวอร์ชันเว็บ (Next.js). **ไม่เชื่อมบัญชีธนาคาร ไม่ถือเงินจริง** — ทุกยอดเป็นข้อมูลที่ผู้ใช้บันทึกเอง (tracking/mock).

Positioning: ไม่แข่ง MAKE by KBank เรื่องธุรกรรมจริง แต่เน้น "วันนี้ควรออมเท่าไร / ไม่เลิกกลางทาง / ถึงเป้าเมื่อไร" + gamification. ภายหลังผู้ใช้ให้เพิ่มฟีเจอร์แบบ MAKE (รายรับจ่าย, pocket, โอน, ล็อก, แชร์) แบบ tracking.

## Stack
- Flutter 3.47 / Dart 3
- State: `provider` (ChangeNotifier) — `lib/state/app_state.dart`
- Persist: `shared_preferences` (JSON ทั้ง state)
- กราฟ: `fl_chart` · ฟอนต์: `google_fonts` (Prompt) · `intl` · `uuid` · `image_picker`

## โครงสร้าง
```
lib/
├─ main.dart                 shell: onboarding gate + bottom nav 5 แท็บ + FAB
├─ theme/app_theme.dart      สีแบรนด์ (AppColors) + ThemeData
├─ models/models.dart        Goal, SavingTransaction, LedgerEntry, Quest, AchievementBadge, AppUser + enums
├─ state/app_state.dart      AppState (ChangeNotifier): ทุก action + persist + _initEmpty()
├─ utils/format.dart         money/date(พ.ศ.)/level-EXP/เพดาน/หมวดหมู่
├─ utils/coach.dart          planStatus + recoveryOptions (Recovery Plan)
├─ widgets/                  goal_card, celebration
└─ screens/                  dashboard, goals, goal_detail, new_goal, add_saving,
                             scan_slip, quests, achievements, history, unallocated,
                             settings, ledger, onboarding
test/smoke_test.dart         9 tests: boot→onboarding + ทุกหน้าจอ build ไม่ crash
```

## ฟีเจอร์ที่ทำแล้ว (Phase 1-4)
- กระปุกเป้าหมาย (goal): สร้าง/ดู/ลบ, progress, milestone EXP, overflow→ยังไม่จัดสรร
- Gamification: EXP/level (สูตรใน format.dart), quests (รับรางวัล), badges (auto-unlock), celebration dialog
- Dashboard: hero+EXP bar, ยอดรวม vs เป้าหมาย, กราฟ 7 วัน, การ์ดรายรับจ่าย
- Onboarding wizard (ชื่อ+โหมด→กระปุกแรก) — โผล่เมื่อ `!user.onboarded`
- Recovery Plan (goal detail): ตามแผนไม่ทัน→ออมเพิ่ม/เลื่อนวัน/ลดเป้า
- Scan slip: image_picker + กรอกเอง (ยังไม่มี OCR อัตโนมัติ)
- **MAKE-style**: รายรับ-รายจ่าย (ledger + หมวดหมู่ + สรุปเดือน), Cloud Pocket ยืดหยุ่น (flexible), โอนระหว่างกระปุก, ล็อกเงิน (7/30/90 วัน), ออมด้วยกัน/แชร์ (mock members), ถอนออก
- **ไม่มีข้อมูล mock** — เริ่มว่างเปล่าผ่าน onboarding. Settings มี "ล้างข้อมูลทั้งหมด"

## รัน / test / build
```bash
flutter pub get
flutter run -d chrome        # หรือ device/emulator
flutter test                 # 9 smoke tests
flutter analyze lib          # ไม่มี error (เหลือแค่ info: withOpacity deprecated)
flutter build web            # ✓ ผ่าน (ใช้ verify compile — ไม่มี Android SDK ในเครื่องนี้)
```

## ยังไม่ได้ทำ / ข้อควรระวัง
- **OCR อ่านสลิปอัตโนมัติ** — google_mlkit_text_recognition เป็น **mobile-only** จะพัง `flutter build web` → เพิ่มแบบ conditional import ตอน build มือถือ
- ยังไม่มี Android SDK/Xcode ในเครื่อง dev → ยังไม่เคย build APK/iOS
- Store-ready ยังขาด: app icon, `applicationId` (ยัง `com.example.keepkapook`), signing, privacy policy, disclaimer "ไม่ใช่แอปธนาคาร", label ฟีเจอร์ mock (โอน/ล็อก/แชร์) ว่าเป็น simulate
- Goal Album (รูป), edit goal, insight กราฟหมวดรายจ่าย — ยังไม่ทำ

## conventions
- UI/ข้อความเป็นภาษาไทย · เงินรูปแบบ `฿12,500` (formatMoney) · วันที่ พ.ศ. (formatThaiDate)
- ทุก action ที่แก้ state ต้อง `_save()` + `notifyListeners()`
- ระวัง null-promotion ใน closure (ใช้ `x!` หรือแยก method)
- ชื่อ model `AchievementBadge` (เลี่ยงชนกับ `Badge` ของ material)
- เวอร์ชันเว็บ deploy อยู่ที่ Firebase (project keepkapook-8fa2d2) เป็นตัวโปรโมท
