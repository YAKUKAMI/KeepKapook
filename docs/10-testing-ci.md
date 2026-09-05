# การทดสอบ, invariant และ CI

## Definition of Done

ทุก PR ต้องผ่าน:

```bash
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build web
```

GitHub Actions workflow `.github/workflows/definition-of-done.yml` รันบน pull request ด้วย Flutter 3.47.1 และบังคับทั้งสามคำสั่งก่อน merge

## Invariant I1–I14

| รหัส | สิ่งที่ป้องกัน | ไฟล์หลัก |
|---|---|---|
| I1 | internal operation รักษา TOTAL | money_flow |
| I2 | external inflow เพิ่ม TOTAL เท่ากับ X | money_flow |
| I3 | flexible รับได้ไม่จำกัด | money_flow/flexible |
| I4 | goal ปกติ overflow เข้า unallocated | money_flow |
| I5 | invalid amount ถูกปฏิเสธแบบ atomic | invalid_amount |
| I6 | EXP เฉพาะ inflow; milestone ไม่ยิงซ้ำ | exp_and_chart |
| I7 | กราฟนับเฉพาะ externalIn | exp_and_chart |
| I8 | model JSON exact round trip | serialization |
| I9 | corrupt JSON มี backup และข้อความ | serialization/recovery |
| I10 | ลบ goal แล้ว history ยังมีชื่อ | history/gamification |
| I11 | quest/badge ทุกตัวมี handler | history/gamification |
| I12 | undo คืน TOTAL/EXP/quest/badge | undo |
| I13 | TxType ↔ flow canonical | transaction_flow |
| I14 | migration fixture ทุก version เดินถึง current | migration_chain |

## Test suite แยกตามหัวข้อ

### เงินและ state

- `app_state_money_test.dart`: transfer loop, overflow หนึ่งสตางค์, validation, edit/delete, local month
- `flexible_pocket_test.dart`: unlimited, no milestone/progress, allocate/transfer/withdraw และ widget display
- `money_test.dart`: parse/format/cap แบบ integer
- `transaction_flow_test.dart`: flow/source/destination/note และ legacy transfer
- `historical_edit_test.dart`: edit/delete ผ่าน UI

### Persistence/backup/migration

- `app_state_persistence_test.dart`: v1 load, corrupt/newer schema, debounce/queue/error
- `backup_test.dart`: export metadata, preview, invalid file, restore/pre-import backup
- `migrations_test.dart`: missing/newer version และแต่ละ migration
- `migration_chain_invariant_test.dart`: fixture v1–v5 → v6 + TOTAL
- `models_serialization_test.dart`: round-trip/default field
- `local_metrics_migration_test.dart`: v5→v6

### Habit/weekly/gamification

- `habit_streak_test.dart`: ต่อเนื่อง, grace, reset, เดือน/ปี,ย้อนหลัง, Bangkok day
- `habit_calendar_widget_test.dart`: status และ drill-down รายวัน
- `habit_rewards_test.dart`: quest/badge handlers และไม่ริบ reward
- `weekly_review_test.dart`: no/sparse data, boundary, projection และ expense-goal link ทุก guard
- `weekly_review_widget_test.dart`: dashboard CTA/history/quest/disclaimer
- `coach_test.dart`: plan/recovery integer math
- `celebration_next_goal_test.dart`: next offer/allocate/ไว้ก่อน

### Quick/parser/UI

- `quick_entry_rules_test.dart`: preset/goal selection/feedback pure functions
- `quick_record_test.dart`: saving/expense/undo/dashboard/tap path/settings/category memory
- `parser_test.dart`: date, normalize, amount, goal ambiguity, reject, confidence, pure Dart
- `conversational_entry_test.dart`: high/medium/low, undo, goal question, FAB
- `smoke_test.dart`: onboarding disclaimer และหน้าหลัก build ไม่ crash

### Notification/metrics

- `notification_schedule_test.dart`: pure dates/defaults/one schedule per type
- `notification_controller_test.dart`: permission lifecycle, persistence, web stub
- `notification_ui_test.dart`: first-save prompt/settings/web hidden
- `local_metrics_test.dart`: counters, W4, corpus privacy, serialization
- `local_metrics_state_test.dart` และ `local_metrics_settings_test.dart`: wiring/export/UI

## Parser fixtures

`parser_edge_cases.dart` เป็น fixture data ไม่ใช่ test entrypoint โดยตัวมันเอง; parser test จะต้องเลือกใช้เคสตาม contract. ชุดสังเคราะห์ใช้ regression ไม่ใช่ user accuracy

## Testability seams

- เวลา inject ผ่าน `now`, `asOf`, `referenceDate`
- persistence inject ผ่าน writer/store interface
- notification inject platform/store
- undo ใช้ snapshot receipt
- pure function อยู่ใน `utils/` และไม่ต้องสร้าง AppState

