# Documentation Index — HULUCA Shop Manager

Chỉ mục **các tài liệu thực sự tồn tại** trong repo (đã dọn các file lỗi thời / auto-gen / một lần — xem `DOCS/CHANGELOG.md` mục `[2026-08-30o]`).

---

## 1. Đọc trước (cho AI agent & người mới)

| File | Mục đích |
|------|----------|
| **CLAUDE.md** (gốc repo) | Hướng dẫn tổng thể cho AI: kiến trúc, module, nguyên tắc, quy trình tài liệu hoá. **Đọc đầu tiên.** |
| **.github/copilot-instructions.md** | Hướng dẫn tương tác AI, workflow, coding rules. |
| **DOCS/HANDOVER.md** | Trạng thái hiện tại: version, việc vừa xong, việc pending, known issues, next steps. |
| **DOCS/CHANGELOG.md** | Lịch sử mọi thay đổi (ngày, tóm tắt, files, kết quả test). |

---

## 2. Tài liệu chuyên biệt

| File | Nội dung | Cập nhật khi |
|------|----------|--------------|
| **DOCS/AI_SECURITY_RISK_AUDIT.md** | Rủi ro AI context, dữ liệu nhạy cảm, token/key exposure | Đổi luồng AI cloud, prompt context, logging |
| **DOCS/DEEPSEEK_AI_SETUP.md** | Cấu hình AI (chat assistant / repair AI) | Đổi provider / endpoint AI |
| **DOCS/store_metadata.md** | Metadata store (What's New, mô tả) | Trước mỗi lần lên store |
| **DOCS/release_notes_YYYY-MM-DD.md** | Ghi chú phát hành từng đợt | Mỗi đợt build lên store |

### Từ điển NLP (dữ liệu, dùng bởi `repair_vocabulary_service.dart` khi build từ điển)

`DOCS/vocabulary/` — `vocabulary.json` (từ điển ngành), `alias_mapping.json` (viết tắt/slang → chuẩn), `typo_mapping.json` (lỗi chính tả → chuẩn), `phonetic_mapping.json` (nhầm âm STT → chuẩn), `intent_mapping.json` (từ khoá → intent + disambiguation).

---

## 3. Test

| File | Nội dung |
|------|----------|
| **test/TEST_SCENARIOS.md** | Kịch bản test chức năng tổng hợp |
| **test/cash_flow_test_scenario.md** | Kịch bản test dòng tiền / tài chính |

Test tự động: `test/*_test.dart` (chạy `flutter test`).

---

## 4. Quy trình cập nhật tài liệu (bắt buộc mỗi task — xem CLAUDE.md mục VII)

1. **DOCS/CHANGELOG.md** — thêm mục mới: ngày, tóm tắt, files, kết quả `flutter analyze` / `flutter test`.
2. **DOCS/HANDOVER.md** — cập nhật version, trạng thái, việc còn lại.
3. **CLAUDE.md** — chỉ khi đổi kiến trúc / module / quy tắc.
4. **.github/copilot-instructions.md** — chỉ khi đổi workflow / coding rules.
5. **DOCS/DOCUMENTATION_INDEX.md** (file này) — khi thêm/xoá tài liệu.
6. **`lib/data/app_knowledge_base.dart`** — khi THÊM / ĐỔI / BỎ tính năng hoặc màn hình, hoặc đổi đường dẫn menu. Nguồn sự thật DUY NHẤT cho AI Trợ Lý *và* Trung tâm trợ giúp (`HelpCenterRepository`). Xem CLAUDE.md mục VII.

---

## 5. Checklist trước khi kết thúc task

```
☐ flutter analyze — 0 error, 0 warning mới
☐ flutter test — không hồi quy (baseline +435 −8, 8 lỗi môi trường có sẵn)
☐ DOCS/CHANGELOG.md — thêm mục
☐ DOCS/HANDOVER.md — cập nhật
☐ commit + push (theo feedback "docs + commit + push bắt buộc")
☐ KHÔNG tự tăng version / build AAB — user báo khi cần
```

---

**Cập nhật lần cuối:** 2026-08-30
