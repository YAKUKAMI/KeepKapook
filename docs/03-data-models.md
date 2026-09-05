# โมเดลข้อมูลและกฎ JSON

## กฎร่วม

- เงินใช้ `int` หน่วยสตางค์ทุก field เช่น `amountSatang`, `targetSatang`, `currentSatang`.
- `fromJson` ทุกโมเดลมี default และไม่ใช้ `!` กับค่าจาก JSON.
- enum ที่อ่านไม่ได้ fallback เป็นค่าปลอดภัยของแต่ละโมเดล.
- วันที่ serialize ด้วย ISO-8601.
- `AchievementBadge.progress` เป็น `double` เพราะเป็นสัดส่วน ไม่ใช่จำนวนเงิน.

## Enum

| Enum | ค่า |
|---|---|
| `GoalCategory` | shopping, education, travel, emergency, investment, other |
| `GoalPriority` | low, medium, high |
| `GoalStatus` | active, completed |
| `SaverMode` | child, adult |
| `TxType` | deposit, unallocated, withdraw, transfer, allocate, deallocate, adjust, slip |
| `TransactionFlow` | externalIn, externalOut, internal, adjustment |
| `LedgerType` | income, expense |

`transactionFlowForType()` เป็น source of truth: deposit/unallocated/slip = externalIn, withdraw = externalOut, transfer/allocate/deallocate = internal, adjust = adjustment

## LedgerEntry

รายการรายรับรายจ่ายทั่วไป

| Field | Type | ความหมาย |
|---|---|---|
| id | String | UUID |
| type | LedgerType | income หรือ expense |
| amountSatang | int | ยอดสตางค์ |
| category | String | หมวดที่ผู้ใช้/ระบบเลือก |
| note | String | ข้อความเสริม |
| date | DateTime | เวลารายการ |

## Goal

| Field | Type | ความหมาย |
|---|---|---|
| id, name, description | String | identity และข้อความ |
| targetSatang | int | เป้าหมาย; flexible ใช้ 0 โดยไม่ใช้เป็นตัวหาร |
| currentSatang | int | ยอดสะสม |
| startDate | DateTime | วันเริ่ม |
| targetDate | DateTime? | วันเป้าหมาย |
| category | GoalCategory | หมวด |
| priority | GoalPriority | ความสำคัญ |
| emoji, themeColor | String/int | การแสดงผล |
| status | GoalStatus | active/completed |
| completedDate | DateTime? | วันสำเร็จ |
| flexible | bool | Cloud Pocket ไม่จำกัดยอด |
| locked, lockUntil | bool/DateTime? | lock แบบเตือนใจ |
| shared, members | bool/List<String> | การออมร่วมกันแบบ local simulation |
| highestMilestonePercent | int | milestone สูงสุดที่เคยให้รางวัล |

Derived getters:

- `hasSavingsTarget`: true เมื่อไม่ flexible และ target > 0
- `isCompleted`: flexible เป็น false เสมอ; goal ปกติดู status หรือ current ≥ target
- `progress`: flexible = 0; goal ปกติ clamp 0..1
- `remainingSatang`: flexible = 0; goal ปกติ max(target-current, 0)
- `isLockedNow`: locked และ `lockUntil` ยังไม่ผ่าน

## SavingTransaction

ประวัติการเคลื่อนเงินของระบบกระปุก

| Field | Type | ความหมาย |
|---|---|---|
| id | String | UUID |
| type | TxType | เหตุการณ์เชิงธุรกิจ |
| flow | TransactionFlow | ทิศทางเงิน; constructor ตรวจให้ตรง canonical map |
| amountSatang | int | ยอดสตางค์ |
| date | DateTime | เวลา |
| goalId | String? | ต้นทางตาม compatibility เดิม |
| destinationGoalId | String? | ปลายทางจริง |
| goalNameSnapshot | String? | ชื่อต้นทาง ณ เวลาทำรายการ |
| destinationGoalNameSnapshot | String? | ชื่อปลายทาง ณ เวลาทำรายการ |
| note | String | note สำหรับมนุษย์ ไม่ใช้ซ่อนโครงสร้างใหม่ |
| expAwarded | int | EXP ที่รายการนี้ให้ |
| isPossibleDuplicate | bool | flag จาก flow สลิป |

Snapshot ชื่อทำให้ประวัติยังอ่านได้หลังลบ goal. Transfer เก่าที่ migrate แล้วหา destination ไม่ได้จะมี `destinationGoalId == null` และปิดการแก้ไขที่ต้องรู้ปลายทาง

## Quest

`id`, `title`, `description`, `period`, `target`, `progress`, `expReward`, `claimed`; getter `complete` คือ progress ≥ target

Default set:

- `q-deposit`
- `q-allocate`
- `q-weekly-consistency`
- `q-weekly-review`

## AchievementBadge

`id`, `name`, `description`, `emoji`, `condition`, `unlocked`, `progress`

Default set:

- `b-first-drop`
- `b-rhythm`
- `b-halfway`
- `b-crusher`
- `b-triple`

## AppUser

`name`, `emoji`, `exp`, `consistencyWeeks`, `mode`, `onboarded`; ค่า default ของ `onboarded` สำหรับ JSON เก่าคือ true เพื่อไม่บังคับผู้ใช้เดิมเข้า onboarding ซ้ำ

