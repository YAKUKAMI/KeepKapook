# AGENTS.md — KeepKapook (Flutter)

Context สำหรับ AI coding agent (Codex, Claude ฯลฯ) ที่มาทำงานต่อในโปรเจกต์นี้
อ่านให้จบก่อนแตะโค้ด โดยเฉพาะหัวข้อ **ห้ามทำ** และ **Definition of Done**

---

## 1. ภาพรวม

KeepKapook = แอปสร้างนิสัยการออมเงินสำหรับวัยรุ่น/ผู้เริ่มออม (โค้ชการออม)
พอร์ตมาจากเวอร์ชันเว็บ (Next.js) ที่ deploy บน Firebase (project `keepkapook-8fa2d2`) ใช้เป็นตัวโปรโมท

**ไม่เชื่อมบัญชีธนาคาร ไม่ถือเงินจริง** — ทุกยอดคือข้อมูลที่ผู้ใช้บันทึกเอง (tracking/mock)
ฟีเจอร์ "โอน / ล็อกเงิน / ออมด้วยกัน / ถอนออก" เป็นการ **จำลอง** ทั้งหมด ไม่มีเงินเคลื่อนไหวจริง

**Positioning:** ไม่แข่ง MAKE by KBank เรื่องธุรกรรมจริง
จุดขายคือความเชื่อมโยงระหว่าง **บันทึกรายรับรายจ่าย** กับ **การออมเพื่อเป้าหมาย** —
ทำให้ผู้ใช้รู้ว่าเงินหายไปไหน แล้วพฤติกรรมนั้นทำให้ถึงเป้าเร็วหรือช้าลงเท่าไร
ห้ามสื่อสารว่าเป็นแอปสองอย่างแยกกัน และทุกฟีเจอร์ใหม่ต้องทำให้ความเชื่อมโยงนี้หรือ habit loop ชัดขึ้น

---

## 2. Stack

| ส่วน | ใช้อะไร |
|---|---|
| Framework | Flutter 3.47.1 / Dart 3.13.1 (`pubspec.yaml`: Dart `>=3.3.0 <4.0.0`) |
| State | `provider` (ChangeNotifier) — `lib/state/app_state.dart` |
| Persist | `shared_preferences` (serialize state ทั้งก้อนเป็น JSON) |
| กราฟ | `fl_chart` |
| ฟอนต์ | `google_fonts` (Prompt) — ดูข้อควรระวังใน §8 |
| อื่นๆ | `intl`, `uuid`, `image_picker`, `file_selector`, `share_plus`, `package_info_plus`, `flutter_local_notifications`, `timezone` |

ก่อนใช้ API ใดๆ ให้เช็ก constraint ใน `pubspec.yaml` จริง อย่าเดาจากเวอร์ชันในตารางนี้

---

## 3. โครงสร้าง

```
lib/
├─ main.dart                 shell: onboarding gate + bottom nav 5 แท็บ + FAB
├─ theme/app_theme.dart      สีแบรนด์ (AppColors) + ThemeData
├─ models/models.dart        Goal, SavingTransaction, LedgerEntry, Quest,
│                            AchievementBadge, AppUser + enums
├─ state/app_state.dart      AppState (ChangeNotifier): action หลัก + persist + _initEmpty()
├─ state/conversational_entries.dart  part: save/undo + แก้ไข/ลบประวัติ
├─ state/quick_entries.dart  part: ออม/รายจ่ายเร็ว + snapshot undo ทั้ง state
├─ state/next_goal_actions.dart part: orchestrate ข้อเสนอเป้าหมายถัดไปหลังฉลอง
├─ state/weekly_reviews.dart part: weekly report orchestration + quest completion
├─ state/local_metrics_actions.dart part: orchestrate ตัวนับการใช้งานในเครื่อง
├─ state/migrations.dart     schemaVersion + framework ต่อขั้น (ปัจจุบัน v1→v2→v3→v4→v5→v6)
├─ state/backup.dart         สร้าง/validate backup + preview ก่อน import
├─ services/backup_file_service.dart  เลือก/แชร์ไฟล์ JSON ข้าม web/mobile
├─ services/notifications/  controller + preference store + conditional mobile implementation/web stub
├─ services/quick_entry/    controller + SharedPreferences ของจำนวนลัด/หมวดล่าสุด
├─ utils/format.dart         money / date(พ.ศ.) / level-EXP / เพดาน / หมวดหมู่
├─ utils/financial_summary.dart  pure summaries: goal totals/progress, monthly ledger,
│                            7-day saving series + period/category/goal-pace/expense-goal metrics
├─ utils/habit_streak.dart   pure local-day/streak/grace/calendar/reward summaries
├─ utils/weekly_review.dart  pure weekly report + first-week/weekly period history
├─ utils/notification_schedule.dart  pure daily/weekly schedule + reminder copy
├─ utils/quick_entry.dart    pure preset validation + goal selection + feedback progress
├─ utils/next_goal_offer.dart pure selector เป้าถัดไป + จำนวน unallocated ที่ย้ายได้
├─ utils/local_metrics.dart  pure local counters + W4 retention + parser corpus policy
├─ utils/coach.dart          planStatus + recoveryOptions (Recovery Plan)
├─ utils/parser/             pure-Dart parser + models + dictionary
├─ widgets/                  goal_card, celebration, simulation_notice,
│                            conversational_entry_sheet, habit_calendar_card,
│                            notification_settings_card, quick_record_sheet,
│                            quick_amount_settings, local_metrics_card
└─ screens/                  dashboard, goals, goal_detail, new_goal, add_saving,
                             scan_slip, quests, achievements, history, unallocated,
                             settings, ledger, onboarding, weekly_review
test/
├─ fixtures/schema/v1.json ... v5.json  state จริงของทุก schema เก่าสำหรับ I14
├─ smoke_test.dart           boot→onboarding + ทุกหน้าจอ build ไม่ crash
├─ models_serialization_test.dart
├─ migrations_test.dart
├─ app_state_persistence_test.dart
├─ money_test.dart
├─ coach_test.dart
├─ backup_test.dart
├─ app_state_money_test.dart
├─ financial_summary_test.dart  parity ของ goal/month/7-day pure summaries
├─ transaction_flow_test.dart   flow + source/destination + legacy edit guard
├─ invariants/transaction_flow_invariant_test.dart  I13 canonical TxType/flow
├─ invariants/migration_chain_invariant_test.dart  I14 full-chain + TOTAL
├─ parser_test.dart          parser unit tests รายพฤติกรรม
├─ conversational_entry_test.dart  tier/undo/FAB/inline edit
├─ notification_schedule_test.dart / notification_controller_test.dart
├─ notification_ui_test.dart       schedule, permission-on-first-save, Settings/web stub
├─ quick_entry_rules_test.dart      pure preset/goal-selection/feedback rules
├─ quick_record_test.dart           quick saving/expense/undo/Settings/category memory
├─ weekly_review_test.dart          pure report/period/projection/expense-goal connector
├─ weekly_review_widget_test.dart   Dashboard launcher/history/disclaimer/quest progress
├─ local_metrics_test.dart          pure counters/W4/corpus/privacy/round-trip
├─ local_metrics_migration_test.dart / local_metrics_state_test.dart
├─ local_metrics_settings_test.dart Settings แสดงตัวเลข/สวิตช์/ล้าง corpus
├─ historical_edit_test.dart       edit/delete history + ledger
└─ fixtures/parser_edge_cases.dart synthetic regression 78 เคสที่เจ้าของภาษา
                                      ในกลุ่มเป้าหมายตรวจแล้ว (pure Dart; ยังไม่ใช่ test entrypoint)
```

**หนี้โครงสร้างที่รู้ตัว:** `app_state.dart` ยังยาว 850 บรรทัดแม้แยก conversational และ
quick-entry action เป็น part แล้ว; `models.dart` ยังรวมทุก entity ไว้ไฟล์เดียว
ถ้าไฟล์ไหนเกิน ~800 บรรทัด ให้แตกก่อนเพิ่มโค้ดใหม่
(`models/` แยกตาม entity, `state/` แยกเป็น mixin/part ตามโดเมน: goal / ledger / gamification)

---

## 4. Data & Persistence — อ่านก่อนแตะ model ทุกครั้ง

นี่คือจุดที่พังแล้วเจ็บที่สุด เพราะพังแบบเงียบและกู้ไม่ได้

- SharedPreferences key: `keepkapook_state_v1`
- Corrupt backup key: `keepkapook_state_v1_corrupt_backup`
- Pre-import backup key: `keepkapook_state_v1_pre_import_backup` — เก็บ state ปัจจุบันก่อนกู้คืนทับทุกครั้ง
- การตั้งค่า local notification ใช้ SharedPreferences keys prefix `keepkapook_notification_` แยกจาก state JSON; ไม่มีข้อมูลการเงินและไม่ทำให้ schemaVersion เปลี่ยน
- การตั้งค่าบันทึกเร็วใช้ key `keepkapook_quick_saving_amounts_satang` และ `keepkapook_quick_expense_category` แยกจาก state JSON; ค่าเริ่มต้น 20/50/100 บาทถูกเก็บเป็น 2,000/5,000/10,000 สตางค์ และไม่ทำให้ schemaVersion เปลี่ยน
- ตัวนับการใช้งานอยู่ใน field `metrics` ของ state JSON ก้อนเดิม ไม่มี analytics SDK และไม่มีการส่งออกอัตโนมัติ; เก็บเฉพาะตัวนับ/วันที่ ส่วน parser corpus เก็บข้อความดิบเมื่อได้ `low`/`reject` หรือถูกแก้ พร้อมสวิตช์ปิดและปุ่มล้างใน Settings
- รูปแบบปัจจุบัน: JSON object ก้อนเดียว มี `schemaVersion: 6` และ migration framework ที่ `lib/state/migrations.dart`

ตัวอย่างย่อของ JSON ที่ persist จริงในปัจจุบัน:

```json
{
  "schemaVersion": 6,
  "user": {"name": "...", "emoji": "🐷", "exp": 0,
    "consistencyWeeks": 0, "mode": "adult", "onboarded": true},
  "goals": [{
    "id": "g-...", "name": "...", "description": "",
    "targetSatang": 1000000, "currentSatang": 50000,
    "startDate": "2026-08-24T00:00:00.000", "targetDate": "2027-08-24T00:00:00.000",
    "category": "other", "priority": "medium", "emoji": "🎯",
    "themeColor": 4283615141, "status": "active", "completedDate": null,
    "flexible": false, "locked": false, "lockUntil": null, "shared": false,
    "members": [], "highestMilestonePercent": 0
  }],
  "transactions": [{"id": "...", "type": "deposit", "flow": "externalIn",
    "amountSatang": 50000, "date": "2026-08-24T00:00:00.000",
    "goalId": null, "destinationGoalId": "g-...",
    "sourceGoalNameSnapshot": null,
    "destinationGoalNameSnapshot": "เงินฉุกเฉิน", "note": "",
    "expAwarded": 10, "isPossibleDuplicate": false}],
  "quests": [{"id": "q-deposit", "title": "...", "description": "...", "period": "daily", "target": 1, "progress": 0, "expReward": 15, "claimed": false}],
  "badges": [{"id": "b-first-drop", "name": "...", "description": "...", "emoji": "💧", "condition": "...", "unlocked": false, "progress": 0.0}],
  "ledger": [{"id": "...", "type": "income", "amountSatang": 100000, "category": "อื่น ๆ", "note": "", "date": "2026-08-24T00:00:00.000"}],
  "metrics": {"installedDay": "2026-08-24", "recordingDays": ["2026-08-24"],
    "quickEntryTierCounts": {"high": 1, "medium": 0, "low": 0, "reject": 0},
    "undoCount": 0, "correctionCount": 0, "weeklyReviewOpenCount": 0,
    "recoveryPlanAcceptedCount": 0, "nextGoalOfferAcceptedCount": 0,
    "nextGoalOfferDeferredCount": 0, "savingRecordCount": 1,
    "expenseRecordCount": 0, "parserCorpusCollectionEnabled": true, "parserCorpus": []},
  "unallocatedSatang": 0
}
```

- สถานะการโหลดปัจจุบัน: ข้อมูลไม่มี `schemaVersion` ถือเป็น v1 แล้วเขียนกลับพร้อม version; ถ้า parse ไม่ผ่านหรือ version ใหม่กว่าแอป จะสำรอง raw JSON และแสดง `MaterialBanner` ภาษาไทยก่อนใช้ state ว่าง
- ชื่อ key ลงท้าย `_v1` เป็นชื่อ storage key เดิมเพื่อรักษาความเข้ากันได้ ไม่ใช่เลข schema ปัจจุบัน; schema ใน JSON คือ v6
- **ทุกครั้งที่เพิ่ม/เปลี่ยน/ลบ field ใน model ต้องเพิ่ม `schemaVersion` และเขียน migration**
  ค่า version ปัจจุบันและ migration steps อยู่ใน `lib/state/migrations.dart`
- ก่อน bump schema จาก vN เป็น vN+1 ต้องเพิ่ม fixture ของ vN ที่ `test/fixtures/schema/vN.json` เสมอ; I14 ต้อง migrate fixture ทุก version ถึง current schema โดยรักษา goal, transaction, EXP, unlocked badge และ TOTAL
- `fromJson` ทุกตัวต้องทนข้อมูลเก่า: field ที่เพิ่มใหม่ต้องมี default ไม่ใช่ `!`
- โหลดตอนเปิดแอปต้องอยู่ใน try/catch — parse ไม่ผ่านห้าม crash ให้ fallback + แจ้งผู้ใช้ ไม่ใช่ล้างข้อมูลเงียบๆ
- `SavingTransaction.flow` แยกทิศทางเงินออกจาก `TxType`: `externalIn`, `externalOut`, `internal`, `adjustment`; `goalId` คือ source และ `destinationGoalId` คือ destination (nullable ทั้งคู่)
- migration v2→v3 ย้าย destination ของ deposit/slip/adjust ไป `destinationGoalId` และกู้ปลายทาง transfer จากชื่อใน note เฉพาะเมื่อ exact match ได้หนึ่ง goal เท่านั้น; ชื่อซ้ำ/หาไม่พบต้องคง null และห้าม parse note นอก migration
- ข้อจำกัดของข้อมูล v2: allocate เคย persist เป็น `TxType.deposit` และ withdraw ไม่ได้ persist ค่า `toUnallocated`; migration จึง map flow ตาม `TxType` ที่เก็บไว้เท่านั้น (`deposit`→`externalIn`, `withdraw`→`externalOut`) และไม่เดาจากยอดหรือลำดับรายการ
- migration v3→v4 canonicalize คู่ type/flow เดิม (`deposit/internal`→`allocate`, `withdraw/internal`→`deallocate`) และเติม `Goal.highestMilestonePercent` เพื่อกัน milestone EXP ซ้ำ โดยไม่แก้หรือลด `user.exp` เดิม
- migration v4→v5 เติม `sourceGoalNameSnapshot`/`destinationGoalNameSnapshot` จาก goal ที่ยังอยู่, ถอน quest/badge ที่ไม่มี handler และคง retired badge ที่ unlock แล้ว โดยไม่แก้หรือลด `user.exp`
- migration v5→v6 เพิ่ม local metrics: อนุมานวันติดตั้งจาก timestamp เก่าสุดที่มี, สร้างวันบันทึก/จำนวนการออม/รายจ่ายจากรายการเดิม และเริ่มตัวนับอื่นเป็นศูนย์; state ว่างที่ไม่มี timestamp ใช้วันที่ local ตอนโหลด
- `note` ของ transaction ใหม่เป็นข้อความที่ผู้ใช้กรอกเท่านั้น ห้ามซ่อน source/destination หรือข้อมูลโครงสร้างไว้ในข้อความ

### กฎ Flow / EXP / Summary

- `transactionFlowByType` ใน `models.dart` เป็น source of truth เดียวของ `TxType → TransactionFlow`; constructor ต้องปฏิเสธคู่ที่ไม่ canonical
- `deposit`, `unallocated`, `slip` = `externalIn`; `withdraw` = `externalOut`; `transfer`, `allocate`, `deallocate` = `internal`; `adjust` = `adjustment`
- base EXP และ milestone EXP ให้เฉพาะ `externalIn`; transfer/allocate/deallocate ไม่ให้ EXP จากการเคลื่อนเงินซ้ำ
- ฝากเข้า unallocated เป็น `externalIn` และได้ base EXP ทันที; `q-allocate` เพิ่ม progress ตอนจัดสรร แต่ไม่แจก EXP อัตโนมัติ (EXP quest ได้เมื่อผู้ใช้ claim ตามกติกาเดิม)
- goal บันทึก milestone สูงสุดที่เคยถึงแบบ monotonic แม้ยอดไหลออกภายหลัง เพื่อไม่ให้ 25/50/75/100% ยิงซ้ำเมื่อเงินเดิมไหลกลับ
- กราฟ/ค่าเฉลี่ยที่สรุปเงินเข้าอ่าน `flow == externalIn` จาก helper กลาง ห้ามกรองด้วย `TxType` กระจาย
- **ห้ามหัก EXP ย้อนหลัง:** migration และการแก้กฎรางวัลมีผลกับรายการใหม่เท่านั้น EXP ที่ผู้ใช้เคยได้ให้คงเดิมตามหลัก “ห้ามลงโทษผู้ใช้”

### กฎเรื่องจำนวนเงิน

- เก็บเป็น **`int` หน่วยสตางค์** แปลงเป็นบาทตอนแสดงผลเท่านั้น
- ห้ามใช้ `double` กับยอดเงิน — การโอน/แบ่งกระปุก/overflow จะสะสม error จนยอดเพี้ยนแบบหาไม่เจอ
- field ปัจจุบันคือ `amountSatang`, `targetSatang`, `currentSatang`, `unallocatedSatang` และ `overflowSatang`
- Input เงินต้องผ่าน `parseMoneyToSatang()` ตั้งแต่จุดรับค่า และต้องไม่ติดลบ/ไม่เกิน **฿100,000,000 ต่อรายการ** (`10,000,000,000` สตางค์)
- กฎปัดเศษเดียวทั้ง input และ migration v1→v2 คือ **ปัดครึ่งขึ้น (half-up)**: อ่านทศนิยมบาทหลักที่ 3 ถ้า `>= 5` ให้เพิ่ม 1 สตางค์ เช่น `1.004 → 100`, `1.005 → 101`, `2.675 → 268` สตางค์ โดยห้ามคำนวณผ่าน floating point
- migration v1→v2 แปลง field เงินหน่วยบาทเดิมทุกตำแหน่งเป็น field `...Satang`; ข้อมูลที่ไม่มี `schemaVersion` ถือเป็น v1 และต้องเปิดใช้ได้โดยยอดไม่เปลี่ยน
- `Goal.flexible == true` คือกระเป๋าไม่มีเป้าหมาย: รับเงินได้ไม่จำกัด, ไม่มี overflow, progress/remaining ไม่ใช้เป็นความจุ, ไม่ได้ milestone EXP และไม่มีสถานะ completed; UI ต้องแสดง "ยอดสะสม" แทนเปอร์เซ็นต์

### Export / Import

- ไฟล์สำรองเป็น JSON state ทั้งก้อน พร้อม `backupFormat: "keepkapook-backup"`, `schemaVersion`, `exportedAt` (UTC) และ `appVersion`
- ชื่อไฟล์ `keepkapook-backup-YYYYMMDD.json`; ผู้ใช้เป็นคนเลือกบันทึก/แชร์เอง แอปไม่มี backend และไม่อัปโหลดไฟล์อัตโนมัติ
- Import ต้อง validate ตัวระบุไฟล์ + metadata + โครงสร้าง state → ผ่าน migration → แสดง preview → ขอคำยืนยัน → สำรอง state ปัจจุบันใน pre-import key → จึงเขียนทับ
- ไฟล์ JSON พัง, ไม่ใช่ backup ของ KeepKapook, ข้อมูลไม่ครบ หรือ schema ใหม่กว่า ต้องหยุดก่อนเขียนและแจ้งภาษาไทย

### กฎเรื่องวันและเวลา

- เก็บ timestamp เป็น **UTC** เสมอ แสดงผลเป็น local
- นิยาม "วัน" = local midnight (Asia/Bangkok) ใช้ helper ตัวเดียวกันทั้งแอป ห้ามคำนวณ `DateTime.now().difference()` ตรงๆ ในหน้าจอ
- ฟีเจอร์ที่ผูกกับวัน: กราฟ 7 วัน, streak, ล็อกเงิน 7/30/90 วัน, quest รายวัน
- streak คำนวณจาก timestamp ของ ledger และ `externalIn` ที่เข้า goal ผ่าน `habit_streak.dart`; grace day รักษาจำนวนเดิมแต่ไม่นับวันที่ขาดเพิ่ม และไม่มี cache/field persistence จึงไม่ต้อง bump schema
- local notification ใช้เวลา Asia/Bangkok จาก `notification_schedule.dart`: รายวันค่าเริ่มต้น 20:00 และสรุปวันจันทร์ 09:00; ใช้ schedule id คงที่ประเภทละหนึ่ง id เพื่อไม่ให้ตั้งซ้ำ
- weekly review ใช้ช่วง `[start, end)` ตามวันไทยจาก `habit_streak.dart`, รับเวลา `asOf` จาก caller, สร้าง first-week review เมื่อครบวันที่ 7 และรายงานสัปดาห์จันทร์-อาทิตย์ย้อนหลังโดยไม่ persist snapshot; วันเริ่มใช้งานอนุมานจาก `Goal.startDate`/รายการแรกเพราะ onboarding สร้าง goal แรกทันที
- ล็อกเงินต้องเทียบกับ `unlockAt` ที่บันทึกไว้ ไม่ใช่นับถอยหลังจากเวลาปัจจุบัน (กันผู้ใช้หมุนนาฬิกาเครื่อง)
- **สถานะโค้ดปัจจุบันยังไม่ทำตามกฎนี้ครบ:** timestamp บาง action ยังสร้างจาก local `DateTime.now()`; สูตรกราฟ 7 วันอยู่ใน `financial_summary.dart`, รับ `now` และนับเฉพาะ `externalIn` แล้ว แต่ยังเทียบ `t.date` ตรงๆ โดยไม่แปลง timezone

---

## 5. ฟีเจอร์ที่ทำแล้ว (Phase 1-4)

- **กระปุกเป้าหมาย (goal):** สร้าง / ดู / ลบ, progress, milestone EXP, overflow → ยังไม่จัดสรร
- **Gamification:** EXP/level (สูตรใน `format.dart`), quests (รับรางวัล), badges (auto-unlock), celebration dialog
- **Dashboard:** hero + EXP bar, ยอดรวม vs เป้าหมาย, กราฟ 7 วัน, การ์ดรายรับจ่าย
- **Onboarding wizard:** ชื่อ + โหมด → กระปุกแรก (โผล่เมื่อ `!user.onboarded`)
- **Recovery Plan** (goal detail): ตามแผนไม่ทัน → ออมเพิ่ม / เลื่อนวัน / ลดเป้า
- **Scan slip:** image_picker + กรอกเอง (ยังไม่มี OCR อัตโนมัติ)
- **MAKE-style (จำลองทั้งหมด):** รายรับ-รายจ่าย (ledger + หมวดหมู่ + สรุปเดือน), Cloud Pocket ยืดหยุ่น, โอนระหว่างกระปุก, ล็อกเงิน 7/30/90 วัน, ออมด้วยกัน/แชร์ (mock members), ถอนออก
- **ไม่มีข้อมูล mock** — เริ่มว่างเปล่าผ่าน onboarding, Settings มี "ล้างข้อมูลทั้งหมด"
- **สำรอง/กู้คืนข้อมูล:** export JSON ออกนอกแอปและ import พร้อม preview/ยืนยัน โดยทำงานบน web และ mobile
- **Conversational Ledger:** deterministic pure-Dart parser, confidence tier, บันทึกทันทีพร้อม undo, chip แก้ field, คำถามเมื่อกำกวม และแก้/ลบย้อนหลังจาก History/Ledger
- **Streak + ปฏิทิน:** current/longest streak, ผ่อนผัน 1 วัน, ปฏิทินเดือนและรายการรายวันบน Dashboard; คำนวณใหม่จากประวัติ ไม่หัก EXP เมื่อขาด
- **Local notification:** เตือนบันทึกประจำวัน + ดูสรุปเช้าวันจันทร์ ปรับเวลา/ปิดแยกได้, ขอสิทธิ์หลังบันทึกแรก, ทำงานในเครื่อง; web ใช้ stub และซ่อนเมนู
- **Quick Record:** FAB + Dashboard เข้าถึงออมเร็ว/รายจ่ายเร็วได้โดยไม่เปลี่ยนแท็บ, จำนวนลัด 20/50/100 แก้ได้ใน Settings, จำหมวดรายจ่ายล่าสุด, แสดง progress/ยอดเดือนทันที และ undo ทั้ง state ภายใน 5 วินาที
- **Weekly Review:** first-week วันที่ 7 + รอบจันทร์-อาทิตย์ย้อนหลัง, สรุปวันบันทึก/streak/ออม/รายจ่าย/หมวด/วันถึงเป้า และเชื่อมส่วนต่างรายจ่ายจริงกับวันที่ถึงเป้า; สูตรอยู่ใน pure utils และไม่เก็บ snapshot
- **Next-goal CTA:** celebration เสนอเป้าค้างที่ใกล้ถึงที่สุดหรือทางลัดสร้างเป้าใหม่ใน dialog เดียวกัน; ย้ายยอดยังไม่จัดสรรเข้าเป้าถัดไปได้ครั้งเดียว และ “ไว้ก่อน” ไม่เปลี่ยน state/EXP/streak พร้อม event accepted/deferred ในเครื่อง
- quest ปัจจุบันมี `q-deposit`, `q-allocate`, `q-weekly-consistency`, `q-weekly-review` พร้อม event handler; badge default 5 ตัวรวม `b-rhythm` มีเงื่อนไขครบ ส่วน `GoalPriority` persist ได้แต่ยังไม่มี logic/UI นำไปใช้

---

## 6. รัน / test / build

```bash
flutter pub get
flutter run -d chrome        # หรือ device/emulator

# คำสั่งบังคับใน CI ทุก PR — ทั้งสามต้องเขียวก่อน merge
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build web

# ตรวจ platform release ในเครื่องเมื่อแตะ config/plugin/platform
flutter build apk --release
```

Workflow: `.github/workflows/definition-of-done.yml` ใช้ Flutter 3.47.1 และรันบน `pull_request`; `analysis_options.yaml` เปิด `unawaited_futures` เพื่อจับ Future ที่หลุดจากการรอโดยไม่ตั้งใจ

### Definition of Done — บังคับทุกงาน

งานถือว่าเสร็จก็ต่อเมื่อครบทุกข้อ ห้ามรายงานว่าเสร็จถ้าข้อใดข้อหนึ่งไม่ผ่าน:

1. `flutter analyze --fatal-infos --fatal-warnings` — ต้อง 0 diagnostics ห้ามปิด flag หรือ ignore กว้างทั้งโปรเจกต์
2. `flutter test` — เขียวทั้งหมด
3. `flutter build web` — ผ่าน
4. PR ต้องมี check `Analyze, test, and build web` เป็นสีเขียวก่อน merge
5. ถ้าแตะ logic ที่คำนวณตัวเลข (เงิน, EXP, วัน, แผน) → **ต้องมี unit test ใหม่ที่ fail ก่อนแก้และ pass หลังแก้**
6. ถ้าแตะ model/persist → บอกใน summary ว่า schemaVersion เปลี่ยนเป็นเท่าไรและ migration อยู่ไฟล์ไหน
7. สรุปท้ายงาน: แก้ไฟล์อะไร / ตัดสินใจอะไรที่ไม่ชัดในโจทย์ / อะไรที่ยังไม่ได้ทำ

---

## 7. ห้ามทำ (hard rules)

- ❌ **ห้ามเปลี่ยน `applicationId` / bundle id** โดยไม่ได้รับคำสั่งชัดเจน (เปลี่ยนหลังปล่อยสโตร์ไม่ได้)
- ❌ **ห้ามเพิ่ม dependency ที่ไม่รองรับ web** โดยไม่ทำ conditional import + stub — จะพัง `flutter build web` ซึ่งเป็น gate เดียวที่เรามีตอนนี้ (เช่น `google_mlkit_text_recognition` เป็น mobile-only)
- ❌ **ห้ามแก้/ลบ field ใน model โดยไม่เขียน migration** (§4)
- ❌ **ห้ามใส่ข้อมูล mock/seed กลับเข้าไปในแอป** — แอปต้องเริ่มว่างเปล่าผ่าน onboarding เสมอ
- ❌ **ห้ามใช้ `double` กับยอดเงิน**
- ❌ **logic ใหม่ทุกตัวใน Phase 1 ต้องเป็น pure function ใน `lib/utils/`** และต้องเทสได้โดยไม่สร้าง `AppState`; `AppState` มีหน้าที่ validate/orchestrate/apply/persist เท่านั้น ห้ามเพิ่มสูตรคำนวณใน `AppState` หรือคลาส widget แม้แต่บรรทัดเดียว
- ประโยคสังเคราะห์ที่ผ่านการตรวจโดยเจ้าของภาษาในกลุ่มเป้าหมายใช้เป็น regression gate ได้ และผูกกับเกณฑ์ amount 98% / type 95% / category 80%; หน้าที่คือกันไม่ให้พฤติกรรมที่เคยทำได้พังตอนแก้โค้ดรอบหลัง
- ❌ **ห้ามเรียกตัวเลขจากชุดสังเคราะห์ว่า accuracy กับผู้ใช้จริง** — accuracy จริงวัดได้เมื่อมีประโยค verbatim จากผู้ใช้จริงอย่างน้อย 50 ประโยค ซึ่งสะสมในเครื่องจาก local event tracking รอบ 14 หลังปล่อย: เคส tier `low`/`reject` และรายการ parser ที่ผู้ใช้แก้หลังบันทึก (ผู้ใช้ปิดหรือล้างได้; ลบ PII ได้แต่ห้ามปรับสำนวนให้ parser ง่ายขึ้น)
- เมื่อข้อความจริงครบอย่างน้อย 50 ประโยค ให้คำนวณ accuracy ใหม่แล้วเทียบกับชุดสังเคราะห์; ถ้าต่ำกว่ากันมาก แปลว่าชุดสังเคราะห์มีจุดบอด ต้องเติม regression case จากของจริง และห้ามลด threshold เพื่อทำให้เทสผ่าน
- ❌ **ห้ามลบหรือลดความชัดของข้อความ disclaimer / label "จำลอง"** บนฟีเจอร์ โอน / ล็อก / ออมด้วยกัน / ถอนออก (§1 และ `simulation_notice.dart`)
- ❌ ห้าม refactor ใหญ่พ่วงมากับงานฟีเจอร์ — แยกคนละรอบ
- ❌ ห้าม commit ไฟล์ signing key, `.env`, หรือ google-services.json ที่มี secret

---

## 8. Conventions

### ภาษาและรูปแบบ
- UI/ข้อความทั้งหมดเป็นภาษาไทย
- เงิน: `฿12,500` ผ่าน `formatMoney()` เท่านั้น ห้ามต่อ string เอง
- วันที่: พ.ศ. ผ่าน `formatThaiDate()` เท่านั้น
- ชื่อ model `AchievementBadge` (เลี่ยงชนกับ `Badge` ของ material)

### State
- ทุก action ที่แก้ state ต้องจบด้วย `_save()` + `notifyListeners()`
- **Validation failure ใช้ `DomainValidationException` แบบเดียวกันทั้งโปรเจกต์** — จำนวนเงินผิด, id ไม่มี, หรือโอนเข้าตัวเองต้อง throw ก่อนแตะ state; ห้าม return เงียบหรือใช้ Result แทน validation error
- Result object ใช้ได้เฉพาะผลลัพธ์ของ input ที่ valid แล้วหรือ business conflict ที่คาดว่าจะเกิดได้ (เช่น แก้ประวัติไม่ได้เพราะยอดถูกใช้ไป) ไม่ใช้แทน input validation
- money action boundary รับ `num` เพื่อให้ domain ตรวจ `NaN`/infinity ได้เอง แต่ค่าที่ผ่านต้องเป็น `int` หน่วยสตางค์, `> 0` และไม่เกิน `maxMoneyInputSatang`
- ทุก action ต้อง **validate ให้ครบก่อน แล้วค่อย apply state**; ถ้าต้องแก้หลาย field ให้แยกช่วง validate/preflight ออกจาก apply ห้าม rollback หลังเขียนบางส่วนเป็นกลไกหลัก
- UI validation ต้องคงไว้เพื่อ UX; domain validation เป็นชั้นบังคับความถูกต้องและห้ามพึ่ง UI เพียงชั้นเดียว
- สถานะปัจจุบันของ `_save()`: debounce 300ms, snapshot ตอน mutation, เขียนผ่าน ordered queue และรายงาน failure ด้วย `MaterialBanner`; mutation แจ้ง UI ได้ทันทีเพราะคิวรับประกันว่า snapshot เก่าจะไม่เขียนทับ snapshot ใหม่
- ระวัง null-promotion ใน closure (ใช้ `x!` หรือแยกเป็น method)
- logic/สูตรคำนวณใหม่ใน Phase 1 อยู่ใน pure function ภายใต้ `lib/utils/` เท่านั้นและห้าม import Flutter; `AppState` เรียก helper เพื่อ orchestrate แล้ว apply state ส่วนหน้าจอ/widget รับผลลัพธ์ไปแสดง ห้ามคำนวณเงิน/วัน/EXP หรือสูตรโดเมนเอง

### UI
- ใช้ `.withValues(alpha: x)` ไม่ใช่ `.withOpacity(x)` (deprecated)
- ทดสอบด้วย text scale ใหญ่ (1.3x) — ตัวเลขเงินยาว ล้นง่าย
- `google_fonts` โหลดฟอนต์จากเน็ตครั้งแรก → **ควร bundle Prompt เข้า `assets/fonts/` ให้เปิดแอปครั้งแรกแบบออฟไลน์ได้** (P2)

### Git
- 1 งาน = 1 branch = 1 PR, prefix: `feat/`, `fix/`, `chore/`, `refactor/`
- commit message ภาษาอังกฤษ imperative สั้นๆ เช่น `feat: add saving streak counter`

---

## 9. Recipes — จะทำ X ต้องแตะไฟล์ไหน

**เพิ่มหน้าจอใหม่**
`screens/xxx_screen.dart` → route/nav ใน `main.dart` → (ถ้ามีปุ่มเข้า) หน้าจอต้นทาง → เพิ่มเคสใน `test/smoke_test.dart`

**เพิ่ม action ที่แก้ข้อมูล**
เขียน pure function + unit test ใน `utils/` ก่อน → เพิ่ม method ใน `state/app_state.dart` ให้ validate/orchestrate/apply เท่านั้น (จบด้วย `_save()` + `notifyListeners()`) → ต่อ UI; ห้ามเริ่มจากเขียนสูตรใน `AppState` แล้วค่อยสัญญาว่าจะย้ายภายหลัง

**เพิ่ม field ใน model**
`models/models.dart` (ใส่ default ใน `fromJson`) → bump `schemaVersion` → เขียน migration → รันแอปด้วยข้อมูลเก่าดูว่าไม่พัง → unit test round-trip `toJson`/`fromJson`

**เพิ่ม schema version ถัดไป**
เพิ่ม `currentSchemaVersion` ใน `state/migrations.dart` → เขียน `_migrateVNToVNPlus1` → เพิ่ม step โดยใช้ version ต้นทางเป็น key → เพิ่ม fixture ของ current version ก่อน bump → เขียน unit test ของ step ใหม่และทดสอบ migrate ต่อขั้นจาก v1 ถึง version ล่าสุด

**เพิ่ม quest หรือ badge**
เพิ่ม definition + เงื่อนไข unlock (เป็น pure function) → unit test เงื่อนไข → เช็กว่า celebration dialog ไม่เด้งซ้ำ

**โครง action ใหม่ (ปรับชื่อ field/method ให้ตรงโดเมนจริงก่อนใช้)**
```dart
void someAction(...) {
  // 1) validate input
  // 2) คำนวณด้วย pure function ที่เทสได้เมื่อมี logic ตัวเลข
  // 3) อัปเดต public state ของ AppState
  // 4) persist + แจ้ง UI ตาม convention ปัจจุบัน
  _save();
  notifyListeners();
}
```

---

## 10. Backlog

### P0 — ต้องเสร็จก่อนปล่อยผู้ใช้จริง
- [ ] สะสม parser corpus แบบ verbatim จากผู้ใช้จริงอย่างน้อย 50 ประโยคแล้ววัด accuracy จริง; synthetic 78 เคสใน `parser_edge_cases.dart` ใช้ regression gate ได้แต่ห้ามเรียกว่า user accuracy
- [x] `schemaVersion` + migration framework (`lib/state/migrations.dart`, current v6)
- [x] เปลี่ยนยอดเงินเป็น `int` สตางค์ + migration v1→v2
- [x] Export / Import ข้อมูลเป็นไฟล์ JSON พร้อม validate, migration, preview และ pre-import backup
- [x] Disclaimer "ไม่ใช่แอปธนาคาร ไม่มีเงินจริง" ใน onboarding + Settings
      และ label "จำลอง" บนหน้าจอ โอน / ล็อก / ออมด้วยกัน / ถอนออก
- [x] Unit test ของ money parser/format, เพดาน, `coach.dart`, โอน, overflow, edit/delete และยอดรวมไม่เพี้ยน
- [ ] เพิ่ม unit test ที่ยังขาด: EXP/level boundary, lock และ withdraw โดยตรง
- [x] `applicationId` / bundle id เป็น `com.keepkapook` + app icon Android/iOS/web
- [x] `flutter build apk --release` เคยผ่าน (ปัจจุบันยังเซ็นด้วย debug certificate)
- [ ] ทำ release signing/upload key จริง ห้าม commit secret/keystore
- [ ] Privacy policy + นโยบายรูปสลิป (มี PII: เลขบัญชี/ชื่อ) — ไม่อัปโหลดออกนอกเครื่อง, ขอ permission ให้ถูก

### P1 — ฟีเจอร์ที่ควรมี เรียงตามผลต่อ retention
- [x] **Streak + ปฏิทินการออม** — current/longest + grace 1 วัน + ดูรายการตามวันบน Dashboard
- [x] **Local notification เตือนออม** (`flutter_local_notifications`, ทำงาน offline) — รายวัน + สรุปวันจันทร์, conditional mobile/web stub
- [ ] **แก้ไขเป้าหมาย** — ส่วนแก้/ลบรายการย้อนหลังและ undo ของ conversational entry ทำแล้ว
- [x] **Insight รายจ่ายที่แปลงเป็นเวลา** — Weekly Review ใช้เฉพาะส่วนต่างจากสัปดาห์ก่อนที่วัดได้จริง แล้วบอกผลต่อวันถึงเป้า; ข้อมูลไม่พอ/ผลต่ำกว่า 1 วันไม่แสดง
- [ ] **Challenge การออม** — ออม 365 วันทวีคูณ / สัปดาห์ไม่ใช้เงิน / เก็บเศษสตางค์ (ต่อยอด quest+badge ที่มีอยู่)
- [ ] **สรุปรายเดือน + แชร์เป็นรูป** — Weekly Review และประวัติรายสัปดาห์ทำแล้ว; monthly/shareable card ยังไม่ทำ
- [x] debounce 300ms + ordered write queue + error reporting ใน `_save()`
- [x] CI (GitHub Actions): fatal analyze + test + build web ทุก PR (`.github/workflows/definition-of-done.yml`)
- [x] Local metrics + W4 logging retention + parser corpus opt-out/clear/export (`schemaVersion` v6)
- [x] แยก flexible pocket ให้รับเงินไม่จำกัด ไม่มี overflow/progress/milestone/completed
- [x] แก้กราฟ 7 วันและค่าเฉลี่ยเงินออมให้นับจาก `TransactionFlow.externalIn`
- [x] `q-allocate` มี handler จาก event จัดสรรจริง และไม่แจก base/milestone EXP ซ้ำ
- [x] คืน `q-weekly-review` ในรอบ 12 พร้อม completion event ตอนเปิดรายงานและ I11 handler
- [x] คืน `q-weekly-consistency` เมื่อระบบ streak มี event source และเทส progress จริง
- [x] คืน `b-rhythm` เมื่อ streak 7 วัน unlock ได้จริง; badge ที่เคย unlock ยังคงอยู่
- [ ] พิจารณา `b-memory` ใหม่เมื่อมี Album subsystem ที่อนุมัติเข้าแผนหลัง Phase 2 และมี unlock event/test; ตอนนี้ลบจาก default และถอนเฉพาะตัวที่ยังไม่ unlock ใน schema v5
- [ ] เพิ่ม category selector ใน NewGoal และกำหนดพฤติกรรมของ `GoalPriority` (ปัจจุบัน persist อย่างเดียว)
- [x] เพิ่ม `TransactionFlow` + `destinationGoalId` และ migration v2→v3; transaction ใหม่ไม่เก็บข้อมูลโครงสร้างใน `note`
- [ ] รวม date/time calculation ไว้ helper กลางและทำ UTC/local boundary ให้สม่ำเสมอ

### P2
- [x] Quick Record ในแอป + ปุ่มจำนวนที่ใช้บ่อย 20/50/100 + ตั้งค่าเอง + รายจ่ายเร็ว
- [ ] OS home screen widget สำหรับ quick add (งานคนละส่วนกับ Quick Record ในแอป)
- [ ] PIN / biometric lock
- [ ] Cloud sync + login ผ่าน Firebase (ทำหลังมี export แล้ว)
- [ ] Goal Album (รูปเป้าหมาย)
- [ ] bundle ฟอนต์ Prompt เข้า assets
- [ ] crash reporting + analytics (รู้ว่าผู้ใช้เลิกตรงไหน)
- [ ] แตก god file `models.dart` / `app_state.dart` ต่อ (`app_state.dart` ยัง 850 บรรทัด; conversational/quick-entry part แยกแล้ว)
- [ ] OCR อ่านสลิปอัตโนมัติ — `google_mlkit_text_recognition` mobile-only ต้อง conditional import + stub สำหรับ web ไม่งั้น `flutter build web` พัง

### ไม่ทำ (out of scope)
- เชื่อมบัญชีธนาคารจริง / ถือเงินจริง / e-wallet — คนละ regulatory league
- แข่งกับ MAKE เรื่องความเร็วธุรกรรม

---

## 11. เมื่อไม่แน่ใจ

- โจทย์กำกวมเรื่อง **เงิน วันที่ หรือ migration** → หยุดถาม อย่าเดา
- โจทย์กำกวมเรื่อง UI/ถ้อยคำ → เลือกทางที่เรียบง่ายที่สุด ทำให้เสร็จ แล้วบอกในสรุปว่าตัดสินใจอะไรไป
- เจอบั๊กนอกขอบเขตงาน → จดลง Backlog §10 อย่าแก้พ่วง
