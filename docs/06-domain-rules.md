# กฎการเงิน, habit, EXP, quest, badge และรายงาน

## Money invariants

นิยาม `TOTAL = sum(goal.currentSatang) + unallocatedSatang`

- internal operation เช่น transfer/allocate/deallocate ต้องรักษา TOTAL เท่าเดิมเป๊ะ
- external inflow X เพิ่ม TOTAL เท่ากับ X
- external out ลดเงินออกจากระบบจริง
- flexible pocket รับได้ไม่จำกัด ไม่มี overflow, target progress หรือ completed milestone
- goal ปกติรับได้ถึง remaining; ส่วนเกินเข้า unallocated
- invalid input ต้องถูกปฏิเสธก่อนแตะ state รวม EXP/quest/badge

## เงินและ format

- `maxMoneyInputSatang = 10,000,000,000` เท่ากับ 100,000,000 บาทต่อรายการ
- `parseMoneyToSatang()` parse string เป็น integer satang โดยไม่พึ่ง `double`
- `moneyInputError()` คืนข้อความ validation สำหรับ UI
- `formatMoney()` แสดงสตางค์เป็นบาทพร้อมทศนิยมเมื่อจำเป็น
- `formatMoneyInput()` แปลงกลับเป็นข้อความช่องแก้ไข
- การหาร/แปลงที่ต้องปัดใช้ half-up อย่างสม่ำเสมอ

## Transaction type กับ flow

`TxType` บอกเหตุการณ์ ส่วน `TransactionFlow` บอกผลต่อขอบเขตระบบ และต้องตรง mapping กลางเสมอ:

| Type | Flow | ผลต่อ TOTAL |
|---|---|---|
| deposit, unallocated, slip | externalIn | เพิ่ม |
| withdraw | externalOut | ลด |
| transfer, allocate, deallocate | internal | คงเดิม |
| adjust | adjustment | ปรับยอดตาม reconciliation |

กราฟและยอดออมใหม่อ้าง `flow`, ไม่เช็ก type กระจายตามหน้าจอ

## Financial summary pure functions

- `summarizeGoalMoney`: snapshot current/target/remaining/progress ของ goal
- `summarizeGoalTotals`: รวมยอดทุก pocket และแยกยอดที่มี target
- `summarizeLedgerMonth/Period`: รวม income/expense ตามช่วง
- `summarizeSevenDaySavings`: 7 วันรวมเฉพาะ externalIn
- `summarizeDashboardMoney`: รวม summary dashboard ในครั้งเดียว
- `countLedgerExpenseDays`: จำนวนวันซึ่งมี expense
- `summarizeTopExpenseCategory`: หมวดรายจ่ายสูงสุด; tie เรียงชื่อ
- `summarizeExternalGoalSavings`: externalIn ที่มี destination goal
- `countExternalGoalSavingDays`: จำนวนวันที่ออมเข้า goal
- `projectGoalAtWeeklyPace`: คำนวณจำนวนวันด้วย integer/BigInt และ ceil
- `calculateExpenseGoalLink`: ใช้ส่วนต่างรายจ่ายจริงเทียบสัปดาห์ก่อนเพื่อประเมินวันถึงเป้า

## Habit streak

วัน active คือวันที่มี ledger อย่างน้อยหนึ่งรายการ หรือ externalIn เข้า destination goal อย่างน้อยหนึ่งรายการ การโอน/จัดสรรภายในไม่สร้างวัน habit

`calculateHabitStreak()`:

- ตัดวันด้วย `bangkokLocalDay`
- วันที่ต่างกัน 1 หรือ 2 วันยังอยู่ run เดียว; gap ≥3 เริ่ม run ใหม่
- ถ้าวันล่าสุดคือเมื่อวาน: `isGraceActive=true`
- ถ้าห่างวันนี้ ≥2 วัน: current streak = 0 แต่ longest คงอยู่
- การบันทึกย้อนหลังทำให้คำนวณใหม่จาก timestamp ทั้งหมด

ปฏิทินใช้ `buildHabitMonth`; แตะวันเรียก `habitEntriesForDay`

## EXP

- external inflow เข้าระบบให้ base EXP 10
- conversational ledger ที่ parser บันทึกให้ 5 EXP ตาม implementation ปัจจุบัน
- allocate/transfer/deallocate ไม่ให้ base EXP
- milestone goal: 25%=20, 50%=30, 75%=40, 100%=100 EXP
- `highestMilestonePercent` กันเงินไหลออกแล้วกลับเข้าไม่ให้ milestone ซ้ำ
- ห้ามหัก EXP ย้อนหลังและไม่ริบของที่ได้แล้ว

## Level

`levelFromExp`, `levelThreshold`, `levelTitle`, `levelProgress` อยู่ใน `format.dart`; UI อ่าน `LevelInfo` เพื่อแสดง level ปัจจุบัน, EXP ใน level และยอดที่ต้องใช้ถึง level ถัดไป

## Quest และ badge

- q-deposit: progress เมื่อ external deposit เข้า goal
- q-allocate: progress เมื่อจัดสรร unallocated
- q-weekly-consistency: handler จาก longest habit streak
- q-weekly-review: progress เมื่อเปิด/ทำ weekly review
- badge recompute รองรับ first drop, rhythm, halfway, crusher, triple
- unlock เป็น monotonic: เมื่อ true แล้วไม่เปลี่ยนกลับ false

I11 วน default set ทั้งหมดเพื่อป้องกันเพิ่ม definition โดยไม่มี handler

## Weekly review

ช่วง `[start, end)` ใช้วันไทย. ข้อมูลพอสำหรับแนวโน้มเมื่อบันทึกอย่างน้อย 2 วัน. Expense comparison ต้องมี expense อย่างน้อย 2 วันทั้งสัปดาห์ปัจจุบันและก่อนหน้า

Goal projection เลือก goal active ที่ไม่ flexible โดยให้น้ำหนักยอดออมในสัปดาห์, target date และ ID. ตัวเชื่อมจะแสดงเมื่อ:

- มีรายจ่ายทั้งสองสัปดาห์พอเปรียบเทียบ
- มีเป้าที่ยังไม่สำเร็จ
- มีส่วนต่างจริง
- ผลต่อวันถึงเป้าอย่างน้อย 1 วัน

หาก weekly saving เป็นศูนย์ คืนคำชวนเริ่มแทนค่าอนันต์. ทุก report มี disclaimer ว่าคำนวณจากรายการที่ผู้ใช้บันทึก ไม่ใช่ยอดธนาคาร

## Recovery plan

`planStatus(goal)` คำนวณยอดที่ควรถึงตามเวลาที่ผ่านไป, ส่วนต่าง และสถานะตามแผน. Flexible ไม่มี plan. `recoveryOptions()` เสนอออมต่อวัน, เลื่อนวัน หรือปรับเป้าจากข้อมูลจริง. การตอบรับถูกนับใน local metrics แต่ไม่ลงโทษเมื่อไม่รับ

