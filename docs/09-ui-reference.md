# หน้าจอ, widget และ navigation

## App shell

`HomeShell` ดูแล onboarding gate, 5 tabs, FAB quick record, persistence banner และ notification permission offer หลังบันทึกแรก

## หน้าจอ

| ไฟล์/หน้าจอ | หน้าที่และ action สำคัญ |
|---|---|
| `onboarding_screen.dart` | disclaimer ที่ข้ามไม่ได้ → ชื่อ/โหมด → goal แรก → `completeOnboarding` |
| `dashboard_screen.dart` | hero, quick actions, totals, EXP, goal status, streak calendar, weekly review CTA, 7-day chart, ledger link |
| `goals_screen.dart` | tabs goal active/completed, เปิด detail, สร้าง goal/pocket |
| `new_goal_screen.dart` | form goal หรือ toggle flexible pocket; เลือก category/priority/emoji/date |
| `goal_detail_screen.dart` | ยอด/progress, recovery plan, history, เพิ่ม, ถอน, โอน, lock, shared, delete |
| `add_saving_screen.dart` | ฝากเข้า goal/unallocated, celebration, next-goal action |
| `unallocated_screen.dart` | แสดง pool และ dialog จัดสรรเข้ากระปุก |
| `ledger_screen.dart` | สรุปรายเดือน, เพิ่ม/แก้/ลบรายรับรายจ่าย |
| `history_screen.dart` | transaction history, flow icon/prefix, แก้/ลบ; legacy transfer แจ้งเหตุผลที่แก้ไม่ได้ |
| `quests_screen.dart` | progress และ claim quest reward |
| `achievements_screen.dart` | level และ badge cards |
| `weekly_review_screen.dart` | รายงานล่าสุดและย้อนหลัง, metric/projection/link/disclaimer |
| `scan_slip_screen.dart` | เลือกรูป, กรอกยอดและปลายทาง, ยืนยันบันทึก |
| `settings_screen.dart` | mode, quick amount, notification, local metrics, backup/import, about/disclaimer, reset |

## Widget ที่ใช้ซ้ำ

### `GoalCard`

Goal ปกติแสดง current/target/progress; flexible แสดงยอดสะสมโดยไม่ใช้เปอร์เซ็นต์หรือคำว่าถึงเป้า

### `HabitCalendarCard`

แสดง current/longest streak, สถานะ active/grace/restart, เดือนพร้อมวันที่ active; แตะวันเปิดรายการของวันนั้น

### `QuickRecordSheet`

โหมด saving/expense ใน sheet เดียว Saving ใช้ปุ่ม preset และเลือก goal ในพื้นที่เดียว Expense ใช้จำนวน+หมวด+note optional. เมื่อ save ปิด sheet พร้อม receipt แล้ว launcher แสดง snackbar undo 5 วินาที

### `ConversationalEntrySheet`

UI parser แบบ progressive disclosure: input → result/tier → save feedback/chips/question. เปิดได้จาก dashboard และ launcher โดยไม่เปลี่ยนแท็บ

### `Celebration`

Dialog ฉลองไม่บล็อกการปิด. `NextGoalInvitation` แสดง goal ที่แนะนำหรือทางลัดสร้างใหม่; หากมี unallocated เสนอจัดสรรหนึ่งคลิก; `ไว้ก่อน` ไม่แก้ state/EXP/streak

### `SimulationNotice`

ข้อความกลางใช้กับ transfer, lock, shared และ withdraw เพื่อบอกว่าเป็นการจำลอง. Lock ระบุว่าเป็นการเตือนใจ ไม่ได้ล็อกเงินจริงและยกเลิกได้

### Settings widgets

- `QuickAmountSettings`: dialog แก้ preset 3 ค่า
- `NotificationSettingsCard`: เปิดปิดสองประเภทและเลือกเวลา
- `LocalMetricsCard`: แสดงตัวนับ/W4/corpus อย่างโปร่งใส

## Feedback และ error

- Domain validation exception ถูก UI แปลงเป็นข้อความที่ผู้ใช้แก้ได้
- การบันทึกสำเร็จแสดงยอด/progress/EXP ใน flow เดิม
- destructive action เช่นลบ history/import/reset มี dialog ยืนยัน
- save/load/notification error ไม่ crash และมีข้อความไทย
- low parser ไม่สร้าง state; reject บอกข้อมูลที่ขาด

## เวลาแตะของ quick record

Dashboard/FAB เปิด sheet 1 ครั้งและกดจำนวน/บันทึกอีกครั้งในเส้นทางปกติ กระปุกเดียวจึงบันทึกออมได้ราว 2 taps; หลายกระปุกยังเลือกใน sheet เดียว ไม่ผลักไป route ใหม่

