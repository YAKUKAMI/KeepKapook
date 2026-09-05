# ดัชนีฟังก์ชันแยกตามไฟล์

เอกสารนี้เป็นแผนที่สำหรับค้นโค้ด รายละเอียดกฎอยู่ในเอกสารหัวข้อเฉพาะ

## `lib/main.dart`

- `main`: bootstrap providers
- `KeepKapookApp.build`: theme/MaterialApp
- `HomeShell`: load/onboarding/tab/FAB/error/permission orchestration
- `_maybeOfferNotificationPermission`: รอ undo window แล้วเสนอ permission ครั้งเดียว

## `lib/models/models.dart`

- JSON coercion helpers: string/int/double/bool/date/enum defaults
- `transactionFlowForType`: canonical flow map
- `toJson/fromJson` ของ LedgerEntry, Goal, SavingTransaction, Quest, AchievementBadge, AppUser
- Goal getters: target/completed/progress/remaining/lock

## `lib/state/app_state.dart`

- lifecycle: `load`, `_save`, `_enqueuePendingSave`, `flushPendingSaves`, `_fromJson`, `toJson/fromJson`, `dispose`
- recovery: clear error, corrupt/pre-import backup, replace/restore
- ledger: `addLedger`, `deleteLedger`, month summary
- goals: lookup/require, `createPocket`, `addGoal`, `updateGoal`, `deleteGoal`
- money: `addSaving`, `_addSaving`, `allocateUnallocated`, `transfer`, `withdrawFromGoal`
- feature state: `setLock`, `toggleShared`
- derived: goal/dashboard/habit/weekly summaries
- gamification: progress quest, refresh habit, milestones, claim, recompute badges
- user: set name/mode, onboarding, reset/init/ensure definitions

## State part files

- `domain_validation.dart`: exception factories + `validateMoneyAmountSatang`
- `quick_entries.dart`: quick save/expense/undo receipts
- `conversational_entries.dart`: batch save, undo, ledger edit, transaction edit/delete/delta
- `weekly_reviews.dart`: periods/report/complete
- `next_goal_actions.dart`: selector adapter
- `local_metrics_actions.dart`: counters/corpus setting and internal hooks
- `backup.dart`: create filename/JSON, validate, preview, exceptions
- `migrations.dart`: step functions, schema reader, chain runner และ legacy helpers

## Utility files

- `format.dart`: parse/validate/format money, Thai date, day-left, level, daily cap
- `financial_summary.dart`: goal/ledger/chart/period/category/projection/link summaries
- `habit_streak.dart`: Bangkok day, collect entries, streak, calendar
- `weekly_review.dart`: period availability, first-use derivation, report/projection/link
- `coach.dart`: plan status, recovery options, average deposit
- `quick_entry.dart`: preset validation, goal selection, feedback
- `next_goal_offer.dart`: offer selection after completion
- `notification_schedule.dart`: preferences, next trigger, reminder plan/message
- `local_metrics.dart`: metrics models, record reducers, W4 summary, corpus sanitation

## Parser files

- `parser.dart`: barrel export
- `parser_models.dart`: result/item/confidence/question/amount contracts
- `parser_dictionary.dart`: alias, keyword rules, ambiguity questions
- `normalizer.dart`: Thai digit/money/unit/word normalization
- `money_extractor.dart`: detected money and positions
- `date_parser.dart`: relative Thai date
- `thai_ledger_parser.dart`: orchestration, operator, classify, tier, reject

## Services

- `backup_file_service.dart`: package version, pick, share
- `quick_entry_controller.dart`: load/update/remember/rollback
- `quick_entry_preferences_store.dart`: shared_preferences adapter
- `notification_controller.dart`: permission/settings/schedule/error
- `notification_preferences_store.dart`: keys/load/save/bounds
- `local_notification_platform_contract.dart`: interface/request/repeat
- `local_notification_platform_mobile.dart`: Android/iOS plugin adapter
- `local_notification_platform_stub.dart`: web no-op
- `local_notification_platform.dart`: conditional export/import selector

## Screens/widgets

ไฟล์หน้าจอแต่ละตัวมี `build` เป็นตัวประกอบ UI; private methods รับผิดชอบ dialog/sheet และส่ง action เข้า AppState. จุดสำคัญ:

- dashboard: `_stat`, `_card`
- goal detail: recovery card, withdraw/transfer/lock/share dialogs
- ledger/history: edit/delete dialogs
- settings: export/import/confirm/preview
- add saving: celebration action router
- weekly review: expense/projection/link text formatters
- conversational sheet: submit, answer low, save, undo, category/date edit
- quick sheet: saving/expense content, save handlers, finish receipt
- calendar: month build, day details, status text

