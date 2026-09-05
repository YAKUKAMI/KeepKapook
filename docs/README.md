# เอกสารระบบ KeepKapook

เอกสารชุดนี้อธิบายสถานะจริงของแอปจาก source code บน branch `main` ณ วันที่ 5 กันยายน 2026 ไม่ใช่เอกสารแนวคิดล่วงหน้า หากข้อความในเอกสารแนวคิดขัดกับโค้ด ให้ตรวจ `AGENTS.md` และโค้ดเป็นหลัก

## แผนที่เอกสาร

1. [ภาพรวมผลิตภัณฑ์และฟีเจอร์](01-product-features.md)
2. [สถาปัตยกรรมและวงจรการทำงาน](02-architecture-runtime.md)
3. [โมเดลข้อมูลและกฎ JSON](03-data-models.md)
4. [AppState และคำสั่งที่เปลี่ยนข้อมูล](04-app-state-actions.md)
5. [Persistence, migration, backup และ recovery](05-persistence-migrations.md)
6. [กฎการเงิน, habit, EXP, quest, badge และรายงาน](06-domain-rules.md)
7. [Thai parser และ conversational entry](07-parser-conversational-entry.md)
8. [Service, notification และความต่างระหว่าง platform](08-services-platforms.md)
9. [หน้าจอ, widget และ navigation](09-ui-reference.md)
10. [การทดสอบ, invariant และ CI](10-testing-ci.md)
11. [Build, signing, release และ security](11-build-release.md)
12. [ดัชนีฟังก์ชันแยกตามไฟล์](12-function-index.md)
13. [Data flow แบบ end-to-end](13-data-flows.md)
14. [ข้อจำกัดและ backlog ที่ยืนยันจากโค้ด](14-limitations-backlog.md)
15. [Local metrics, W4 retention และ parser corpus](15-local-metrics.md)

## ข้อเท็จจริงสำคัญฉบับย่อ

- Flutter app ใช้ `provider` และ `ChangeNotifier`; state หลักอยู่ใน `AppState`.
- จำนวนเงินทุกก้อนใช้ `int` หน่วยสตางค์ และแปลงเป็นบาทเฉพาะตอนแสดงผล.
- state หลัก persist เป็น JSON ใน `shared_preferences` key `keepkapook_state_v1`.
- schema ปัจจุบันคือ v6 และมี migration ต่อขั้น v1 → v2 → v3 → v4 → v5 → v6.
- แอปไม่เชื่อมธนาคารและไม่ถือเงินจริง ทุกยอดมาจากสิ่งที่ผู้ใช้บันทึกเอง.
- analytics เป็นตัวนับ local-only ไม่มี third-party analytics SDK และไม่ส่งข้อมูลอัตโนมัติ.
- Android/iOS ใช้ bundle ID `com.keepkapook`; เวอร์ชันใน `pubspec.yaml` คือ `1.0.0+1`.
- Definition of Done บังคับ analyze แบบ fatal, test และ web build ทั้งในเครื่องและ GitHub Actions.
