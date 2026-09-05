# AppState และคำสั่งที่เปลี่ยนข้อมูล

## ข้อมูลที่ AppState ถือ

`user`, `goals`, `transactions`, `quests`, `badges`, `ledger`, `unallocatedSatang`, `localMetrics` รวมถึงสถานะโหลด/error และ `recordSavedSerial` สำหรับตรวจว่ามีการบันทึกสำเร็จครั้งแรก

## รูปแบบ error

Domain เลือกใช้ exception แบบเดียวกันผ่าน `DomainValidationException`. จำนวนเงินตรวจที่ต้น method ก่อนแก้ state: ต้องเป็น int, finite, > 0 และไม่เกิน `maxMoneyInputSatang` (100,000,000 บาทต่อรายการ). ID ที่ไม่มี, โอนเข้าตัวเอง และ action ที่ห้ามทำมี code/message เฉพาะ

## Ledger actions

### `addLedger(...)`

ตรวจ amount → สร้าง `LedgerEntry` ด้วย UUID/UTC → insert ด้านหน้า → นับ local metric ตาม income/expense → refresh habit rewards → เพิ่ม serial → save/notify

### `deleteLedger(id)`

ตรวจว่ามี entry → ลบ → refresh habit reward → save/notify

### `ledgerMonthSummary(now:)`

เรียก pure helper `summarizeLedgerMonth`; getters รายรับ/รายจ่ายรายเดือนอ่านจาก summary เดียวกัน

## Goal และ pocket actions

### `createPocket(...)`

สร้าง `Goal` แบบ `flexible=true`, `targetSatang=0`, active และไม่มี target date. เลข 0 เป็น sentinel ของ “ไม่มีเป้า” ไม่ใช่เพดานรับเงิน

### `addGoal(...)`

ตรวจ target ก่อนสร้าง goal ปกติ แล้วเพิ่มลงรายการและ save

### `updateGoal(goal)`

ตรวจ ID, รักษา milestone สูงสุดไม่ให้ลด, ปรับ completedDate/status ตามยอด แล้วแทน object เดิม

### `deleteGoal(id)`

ก่อนลบ snapshot ชื่อ goal ลง transaction ที่เกี่ยวข้องทั้ง source/destination จากนั้นลบ goal จริง ทำให้ history ยังอ่านชื่อได้

## Money movement

### `addSaving(...)`

เป็น external inflow. Flexible รับเต็มจำนวน ไม่มี overflow/milestone/completed. Goal ปกติรับ `min(amount, remaining)` และส่งส่วนเกินไป `unallocatedSatang`. ให้ EXP ฐาน 10 และ milestone ใหม่, progress `q-deposit`, metrics และ habit

คืน `SavingResult(exp, completed, overflowSatang)` เพื่อให้ UI แสดง feedback/celebration

### `allocateUnallocated(amount, goalId)`

ตรวจยอดและ goal ก่อนแตะ state, ตรวจยอดใน pool เพียงพอ → หัก pool → เรียก `_addSaving` ด้วย source `allocate` และ `externalIn=false`. จึงรักษา TOTAL และไม่ให้ EXP ฐาน แต่เพิ่ม progress `q-allocate`

### `transfer(fromId, toId, amount)`

ตรวจจำนวน, ID และ from != to ก่อนแก้ state. ถ้าต้นทางล็อกจะไม่ทำรายการ. ยอดจริงถูก cap ด้วยยอดต้นทางและ capacity ของปลายทาง; flexible ไม่มี capacity limit. สร้าง transaction `type=transfer`, `flow=internal` พร้อม source/destination ID และ snapshot ชื่อ

### `withdrawFromGoal(id, amount, toUnallocated:)`

ตรวจจำนวน/goal ก่อน; goal ล็อกจะไม่ถอน. ยอดจริงไม่เกินยอดปัจจุบัน. ถ้า `toUnallocated=true` เป็น `deallocate/internal` และเพิ่ม pool; มิฉะนั้นเป็น `withdraw/externalOut`

### `setLock(id, until)` / `toggleShared(...)`

อัปเดตสถานะ lock หรือ shared/members แล้ว save. Lock เป็น UX reminder ไม่ใช่ข้อจำกัดเงินจริงที่แก้ไม่ได้

## Quick entry

- `quickSave`: snapshot ก่อน action → require goal → `addSaving` → สร้าง feedback pure → คืน receipt สำหรับ undo
- `quickExpense`: snapshot → add ledger expense → คืน monthly expense summary
- `undoQuickRecord`: restore snapshot ทั้งก้อนครั้งเดียวและนับ undo metric

## Conversational entry

- `saveParsedEntries`: validate รายการทั้งหมดก่อน mutation; snapshot; route goalDeposit ไป `_addSaving`, income/expense ไป ledger; ให้ ledger parsed entry 5 EXP; หากเกิด exception restore snapshot
- `undoConversationalSave`: receipt ใช้ได้ครั้งเดียวและ restore state ทั้งก้อน
- update ledger รองรับแก้เต็มรายการ, เฉพาะหมวด หรือวันที่
- update/delete saving transaction ใช้ `_applyTransactionDelta` ย้อนผลเก่าแล้วลงผลใหม่อย่าง atomic
- transfer legacy ที่ไม่มี destination ID คืน failure ภาษาไทยแทนการ parse note หรือเดา

## Gamification actions

- `_progressQuest(id)` เพิ่มครั้งละ 1 ถึง target
- `_refreshHabitRewards(asOf:)` คำนวณ streak ใหม่และอัปเดต quest/badge
- `_awardNewMilestones(goal)` ให้ 20/30/40/100 EXP ที่ 25/50/75/100% และจำระดับสูงสุดเพื่อกันยิงซ้ำ
- `claimQuest(id)` ให้รางวัลเมื่อ complete และยังไม่ claimed
- `_recomputeBadges(...)` unlock แบบ monotonic: ไม่เอาคืนเมื่อยอด/streak ลด

## Profile และ lifecycle

- `setName`, `setMode`: เปลี่ยน user preference
- `completeOnboarding`: สร้าง user onboarded และ goal แรกบน state ว่าง
- `resetDemo`: คืน empty state
- `_ensureGamificationDefinitions`: merge default definitions ปัจจุบันกับ progress/unlocked เดิมที่รองรับ

## การ save

ทุก mutation เรียก `_saveAndNotify()` ซึ่งจับ JSON snapshot ก่อน, debounce 300 ms, serialize write เป็นคิว และแจ้ง listener. `flushPendingSaves()` ใช้ในเทส/import เพื่อรอให้ทุก write จบ

