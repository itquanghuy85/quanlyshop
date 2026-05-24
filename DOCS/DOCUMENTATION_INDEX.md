# Documentation Index - HULUCA Shop Manager

## Mục Lục Toàn Bộ Tài Liệu

---

## 1. CORE DOCUMENTATION (Quan trọng nhất)

| File | Mục đích | Cập nhật khi | Ưu tiên | Đọc trước |
|------|---------|-----------|---------|----------|
| **CLAUDE.md** | Hướng dẫn tổng thể cho AI agents: kiến trúc, module, nguyên tắc | Thay đổi kiến trúc, module, quy tắc | ⭐⭐⭐ | Thứ nhất |
| **.github/copilot-instructions.md** | Hướng dẫn tương tác AI: workflow, coding rules, patterns | Thay đổi ảnh hưởng AI agents, workflow | ⭐⭐⭐ | Thứ hai |
| **README.md** | Giới thiệu dự án, cài đặt, quick start | Thay đổi setup, dependencies | ⭐⭐⭐ | Thứ ba |

---

## 2. PROJECT MANAGEMENT DOCUMENTATION

| File | Mục đích | Cập nhật khi | Ưu tiên |
|------|---------|-----------|---------|
| **docs/CHANGELOG.md** | Lịch sử thay đổi (ngày, summary, files modified/added/removed) | Mỗi task hoàn thành | ⭐⭐⭐ |
| **docs/HANDOVER.md** | Trạng thái hiện tại, tasks hoàn thành, tasks pending, issues, next steps | Mỗi task hoàn thành | ⭐⭐⭐ |
| **docs/KNOWN_ISSUES.md** | Danh sách vấn đề đã biết, workarounds, priority | Phát hiện issues mới | ⭐⭐ |
| **docs/TODO.md** | Danh sách công việc cần làm, priority, assignee | Thêm/xóa/cập nhật tasks | ⭐⭐ |
| **docs/ROADMAP.md** | Lộ trình phát triển, milestones, features planned | Thay đổi strategy | ⭐ |

---

## 3. ARCHITECTURE & STANDARDS DOCUMENTATION

| File | Mục đích | Cập nhật khi | Ưu tiên |
|------|---------|-----------|---------|
| **docs/ARCHITECTURE.md** | Kiến trúc chi tiết: layers, components, interactions | Thay đổi kiến trúc tổng thể | ⭐⭐⭐ |
| **docs/DESIGN_SYSTEM.md** | Design tokens, colors, typography, spacing, components | Thay đổi design tokens, UI components | ⭐⭐ |
| **docs/DESIGN_TOKENS_REFERENCE.md** | Bảng colors, typography sizes, spacings, elevations | Cập nhật design tokens | ⭐⭐ |
| **docs/UI_GUIDELINES.md** | Hướng dẫn UI: layout, colors, patterns, conventions | Thay đổi UI patterns | ⭐⭐ |
| **docs/CODING_STANDARDS.md** | Coding conventions: naming, formatting, patterns, error handling | Thay đổi coding conventions | ⭐⭐ |

---

## 4. SPECIALIZED DOMAIN DOCUMENTATION

### Finance & Payments
| File | Mục đích | Cập nhật khi |
|------|---------|-----------|
| **DOCS/FINANCE_V2_MIGRATION.md** | Chi tiết migration từ v1 sang v2 | Thay đổi finance logic, PaymentIntentService |
| **docs/PAYMENT_AUDIT.md** | Audit thanh toán, transactions, reconciliation | Thay đổi payment flow |

### Integration
| File | Mục đích | Cập nhật khi |
|------|---------|-----------|
| **DOCS/KIOTVIET_INTEGRATION_REPORT.md** | Chi tiết KiotViet API integration | Thay đổi KiotViet sync, API calls |
| **IMAGE_UPLOAD_AUDIT_REPORT.md** | Audit upload ảnh, Firebase Storage | Thay đổi image upload flow |

### Permissions & Security
| File | Mục đích | Cập nhật khi |
|------|---------|-----------|
| **DOCS/PERMISSION_AUDIT_REPORT.md** | Audit quyền user, roles, data isolation | Thay đổi permission logic, role definitions |

### UI & Design
| File | Mục đích | Cập nhật khi |
|------|---------|-----------|
| **UI_STANDARDIZATION_REPORT.md** | Báo cáo chuẩn hóa UI, components | Thay đổi UI components, styling |
| **DESIGN_SYSTEM_AUDIT.md** | Audit design system | Thay đổi design system |
| **FINAL_UI_CONSISTENCY_REPORT.md** | Báo cáo consistency UI | Kiểm tra UI consistency |

---

## 5. IMPLEMENTATION & REPORTS

| File | Mục đích | Cập nhật khi | Format |
|------|---------|-----------|--------|
| **docs/IMPLEMENTATION_REPORT.md** | Chi tiết implementation (technical deep-dive) | Thay đổi lớn, phức tạp | MD |
| **DOCS/IMPLEMENTATION_GUIDE.md** | Hướng dẫn implementation chi tiết | Thay đổi implementation | MD |
| **docs/IMPLEMENTATION_REPORT.docx** | Report formal (optional, archived) | Thay đổi lớn | DOCX |
| **Finance_V2_Migration_and_UI_Standardization_Report.docx** | Report formal migration (archived) | Archive | DOCX |

---

## 5.1 BLUEPRINT DOCUMENTATION (Rebuild DNA)

| File | Mục đích | Cập nhật khi | Ưu tiên |
|------|---------|-----------|---------|
| **DOCS/BLUEPRINT/index.md** | Chỉ mục toàn bộ blueprint và liên kết từng phần | Có thêm/sửa module blueprint | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/CORE_ARCHITECTURE.md** | Kiến trúc lõi, startup/async/data flow/sync | Kiến trúc thay đổi | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/BUSINESS_LOGIC.md** | DNA nghiệp vụ thực tế theo flow | Logic nghiệp vụ thay đổi | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/DESIGN_SYSTEM.md** | Màu sắc, typography, spacing, visual hierarchy | Design system thay đổi | ⭐⭐ |
| **DOCS/BLUEPRINT/COMPONENT_LIBRARY.md** | Component tái sử dụng và hành vi | Component mới/sửa | ⭐⭐ |
| **DOCS/BLUEPRINT/USER_FLOW_MAP.md** | Bản đồ flow người dùng, sync flow, admin flow | Navigation/flow thay đổi | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/DATABASE_SCHEMA.md** | SQLite + Firestore schema, index, migration/sync | Schema/sync thay đổi | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/API_AND_SERVICES.md** | Trách nhiệm service, async/retry/failure | Service layer thay đổi | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/OFFLINE_BEHAVIOR.md** | Hành vi offline/online và conflict handling | Offline logic thay đổi | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/APP_REBUILD_GUIDE.md** | Thứ tự dựng lại app từ đầu | Đổi chiến lược rebuild | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/README_FINAL.md** | Tổng kết chất lượng blueprint + rủi ro | Mỗi lần tái tạo blueprint | ⭐⭐⭐ |
| **DOCS/BLUEPRINT/TODO_GAPS.md** | Gaps cần test runtime/thực địa | Phát hiện điểm chưa rõ | ⭐⭐ |

---

## 5.2 UX AUDIT DOCUMENTATION

| File | Mục đích | Cập nhật khi | Ưu tiên |
|------|---------|-----------|---------|
| **DOCS/UX_AUDIT/UX_SCORE_REPORT.md** | Bảng điểm UX/UI tổng thể, severity, priority | Mỗi lần audit UX lớn | ⭐⭐⭐ |
| **DOCS/UX_AUDIT/UX_PROBLEMS.md** | Danh sách vấn đề UX/UI, anti-pattern, root causes | Phát hiện vấn đề UX mới | ⭐⭐⭐ |
| **DOCS/UX_AUDIT/UX_IMPROVEMENTS.md** | Hướng cải thiện theo hệ thống và workflow | Chốt action plan UX | ⭐⭐⭐ |
| **DOCS/UX_AUDIT/DESIGN_SYSTEM_PROBLEMS.md** | Nợ design system, fragmentation, visual debt | Refactor design system/UI foundation | ⭐⭐⭐ |
| **DOCS/UX_AUDIT/WORKFLOW_OPTIMIZATION.md** | Tối ưu luồng repair/kho/nợ/settings/thanh toán | Flow vận hành thay đổi | ⭐⭐⭐ |
| **DOCS/UX_AUDIT/LOADING_AND_ASYNC_UX.md** | Audit loading, sync, save feedback, async communication | Async/offline UX thay đổi | ⭐⭐⭐ |
| **DOCS/UX_AUDIT/MODERNIZATION_PLAN.md** | Lộ trình hiện đại hóa UX/UI theo phase | Điều chỉnh roadmap UX | ⭐⭐⭐ |

---

## 6. MISC DOCUMENTATION

| File | Mục đích | Cập nhật khi |
|------|---------|-----------|
| **AI_REPAIR_GUIDE.md** | Hướng dẫn sửa chữa AI | Thay đổi error handling, AI integration |
| **DEEP_LINK_NAVIGATION_IMPLEMENTATION.md** | Chi tiết deep linking | Thay đổi deep link logic |
| **ui_guidelines.md** | Hướng dẫn UI legacy | Legacy (không dùng, dùng docs/UI_GUIDELINES.md) |

---

## 7. QUY TẮC CẬP NHẬT

### Khi Nào Cập Nhật Từng File?

#### 1. **CLAUDE.md**
```
Cập nhật khi:
- Thay đổi kiến trúc (layers, modules, components)
- Thay đổi quy tắc phát triển (patterns, conventions)
- Thay đổi design system (tokens, colors, typography)
- Thêm/xóa module chính
```

#### 2. **.github/copilot-instructions.md**
```
Cập nhật khi:
- Thay đổi hướng dẫn cho AI agents
- Thay đổi workflow
- Thay đổi coding rules
- Thêm/xóa integration points
```

#### 3. **docs/CHANGELOG.md**
```
Cập nhật với mỗi task hoàn thành:
- Ngày giờ
- Summary (1-2 dòng)
- Files Modified
- Files Added
- Files Removed
- Validation Results (analyze, tests, build)
```

#### 4. **docs/HANDOVER.md**
```
Cập nhật sau mỗi task:
- Current Status (1-2 dòng)
- Completed Tasks (list)
- Pending Tasks (list)
- Known Issues (list)
- Recommended Next Steps
```

#### 5. **docs/ARCHITECTURE.md**
```
Cập nhật khi:
- Thay đổi layers architecture
- Thay đổi data flow
- Thay đổi components interactions
- Thay đổi services
```

#### 6. **docs/KNOWN_ISSUES.md**
```
Cập nhật khi:
- Phát hiện issue mới
- Giải quyết issue (move to DONE)
- Workaround tìm được
```

#### 7. **Tài liệu chuyên biệt** (Permission, Finance, KiotViet, etc.)
```
Cập nhật khi thay đổi lĩnh vực tương ứng:
- PERMISSION_AUDIT_REPORT.md → permission logic
- FINANCE_V2_MIGRATION.md → finance/payments
- KIOTVIET_INTEGRATION_REPORT.md → KiotViet sync
- IMAGE_UPLOAD_AUDIT_REPORT.md → image upload
- UI_STANDARDIZATION_REPORT.md → UI components
```

---

## 8. VALIDATION CHECKLIST

Trước khi kết thúc task, kiểm tra:

```
☐ Code đã chỉnh sửa xong
☐ flutter analyze: no errors
☐ flutter test: passing (nếu có)
☐ flutter build: success
☐ CLAUDE.md cập nhật (nếu cần)
☐ .github/copilot-instructions.md cập nhật (nếu cần)
☐ docs/CHANGELOG.md thêm mục mới
☐ docs/HANDOVER.md cập nhật status
☐ docs/DOCUMENTATION_INDEX.md cập nhật (nếu thêm file)
☐ Tài liệu chuyên biệt cập nhật (nếu cần)
☐ Report changed files
```

---

## 9. HOW TO READ DOCUMENTATION

### Nếu bạn là lập trình viên mới
1. Đọc **CLAUDE.md**
2. Đọc **docs/ARCHITECTURE.md**
3. Đọc **.github/copilot-instructions.md**
4. Đọc **docs/HANDOVER.md**
5. Đọc code từng phần

### Nếu bạn là AI agent
1. Đọc **CLAUDE.md** (nguyên tắc, kiến trúc)
2. Đọc **.github/copilot-instructions.md** (hướng dẫn)
3. Kiểm tra **docs/KNOWN_ISSUES.md** (vấn đề)
4. Kiểm tra **docs/HANDOVER.md** (trạng thái)
5. Thực hiện task
6. Cập nhật tài liệu theo quy tắc

### Nếu bạn cần hiểu chi tiết
1. Đọc **DOCS/FULL_DOCUMENTATION.md**
2. Đọc **docs/ARCHITECTURE.md**
3. Đọc tài liệu chuyên biệt tương ứng
4. Đọc code

---

## 10. FILE HIERARCHY

```
project-root/
├── CLAUDE.md (📍 START HERE - tổng thể)
├── .github/
│   └── copilot-instructions.md (hướng dẫn AI)
├── docs/ (tài liệu chính)
│   ├── DOCUMENTATION_INDEX.md (file này)
│   ├── CHANGELOG.md (lịch sử thay đổi)
│   ├── HANDOVER.md (trạng thái hiện tại)
│   ├── KNOWN_ISSUES.md (vấn đề đã biết)
│   ├── TODO.md (công việc cần làm)
│   ├── ROADMAP.md (lộ trình)
│   ├── ARCHITECTURE.md (kiến trúc chi tiết)
│   ├── DESIGN_SYSTEM.md (design tokens)
│   ├── DESIGN_TOKENS_REFERENCE.md (bảng colors, etc.)
│   ├── UI_GUIDELINES.md (hướng dẫn UI)
│   ├── CODING_STANDARDS.md (quy tắc coding)
│   ├── IMPLEMENTATION_REPORT.md (chi tiết implementation)
│   └── PAYMENT_AUDIT.md (audit thanh toán)
├── DOCS/ (tài liệu chuyên biệt)
│   ├── FULL_DOCUMENTATION.md (tài liệu toàn bộ)
│   ├── PERMISSION_AUDIT_REPORT.md (quyền)
│   ├── FINANCE_V2_MIGRATION.md (finance)
│   ├── KIOTVIET_INTEGRATION_REPORT.md (KiotViet)
│   ├── IMPLEMENTATION_GUIDE.md (hướng dẫn)
│   └── ...
├── IMAGE_UPLOAD_AUDIT_REPORT.md (legacy location)
├── UI_STANDARDIZATION_REPORT.md (legacy location)
├── DEEP_LINK_NAVIGATION_IMPLEMENTATION.md (legacy)
├── AI_REPAIR_GUIDE.md (legacy)
├── ui_guidelines.md (legacy - dùng docs/UI_GUIDELINES.md)
├── DESIGN_SYSTEM_AUDIT.md (legacy)
├── FINAL_UI_CONSISTENCY_REPORT.md (legacy)
├── CUSTOMER_PRODUCT_NAVIGATION_TEST_REPORT.md (legacy)
├── LEGACY_UI_CLEANUP_REPORT.md (legacy)
└── ...
```

---

## 11. PRIORITY LEVELS

| ⭐⭐⭐ (Critical) | Phải cập nhật với mỗi thay đổi code lớn |
| ⭐⭐ (High) | Phải cập nhật với thay đổi liên quan |
| ⭐ (Medium) | Cập nhật theo yêu cầu hoặc định kỳ |

---

**Cập nhật lần cuối:** 2026-05-22  
**Phiên bản:** 1.0
