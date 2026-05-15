# TODO - HULUCA Shop Manager

Danh sách công việc cần làm, priority, assignee, due dates.

---

## Current Sprint

### Documentation (High Priority)

- [ ] **Complete ARCHITECTURE.md**
  - Priority: High
  - Size: Medium
  - Description: Chi tiết kiến trúc, layers, data flow, components
  - Due: 2026-05-20
  - Assignee: Claude Copilot

- [ ] **Complete DESIGN_SYSTEM.md**
  - Priority: High
  - Size: Small
  - Description: Design tokens, colors, typography, spacing
  - Due: 2026-05-20
  - Assignee: Claude Copilot

- [ ] **Complete ROADMAP.md**
  - Priority: High
  - Size: Small
  - Description: Milestones, features planned, timeline
  - Due: 2026-05-20
  - Assignee: Claude Copilot

- [ ] **Complete CODING_STANDARDS.md**
  - Priority: Medium
  - Size: Medium
  - Description: Naming conventions, formatting, patterns
  - Due: 2026-05-22
  - Assignee: Claude Copilot

### Build & Compilation (High Priority)

- [ ] **Fix Android NDK Version Mismatch**
  - Priority: High
  - Size: Small
  - Description: Update to NDK 28.2.13676358
  - Location: `android/app/build.gradle.kts`
  - Due: 2026-05-18
  - Assignee: Claude Copilot
  - Related: KNOWN_ISSUES.md #1

- [ ] **Remove Impeller Opt-out Deprecated**
  - Priority: Medium
  - Size: Small
  - Description: Remove opt-out flag from AndroidManifest.xml
  - Location: `android/app/src/main/AndroidManifest.xml`
  - Due: 2026-05-18
  - Assignee: Claude Copilot
  - Related: KNOWN_ISSUES.md #2

---

## Backlog

### Documentation (Medium Priority)

- [ ] **Update DOCS/FULL_DOCUMENTATION.md**
  - Priority: Medium
  - Size: Large
  - Description: Review, add missing details, update all links
  - Due: 2026-05-25
  - Assignee: Claude Copilot

- [ ] **Create DESIGN_TOKENS_REFERENCE.md**
  - Priority: Medium
  - Size: Small
  - Description: Bảng colors, typography sizes, spacings
  - Due: 2026-05-22
  - Assignee: Claude Copilot

- [ ] **Create UI_GUIDELINES.md**
  - Priority: Medium
  - Size: Medium
  - Description: Layout patterns, color usage, conventions
  - Due: 2026-05-22
  - Assignee: Claude Copilot

- [ ] **Create IMPLEMENTATION_REPORT.md**
  - Priority: Low
  - Size: Large
  - Description: Technical deep-dive, architecture details
  - Due: 2026-06-01
  - Assignee: Claude Copilot

- [ ] **Create PAYMENT_AUDIT.md**
  - Priority: Medium
  - Size: Medium
  - Description: Audit thanh toán, transactions, reconciliation
  - Due: 2026-05-25
  - Assignee: Claude Copilot

### Code Review & Verification (Medium Priority)

- [ ] **Verify All Services Implementation**
  - Priority: Medium
  - Size: Large
  - Description: Review firestore_service, user_service, sync_service, etc.
  - Due: 2026-05-28
  - Assignee: Code Review

- [ ] **Test All Firestore Operations**
  - Priority: Medium
  - Size: Large
  - Description: Comprehensive testing of CRUD operations
  - Due: 2026-05-28
  - Assignee: QA

- [ ] **Validate Real-time Sync Reliability**
  - Priority: Medium
  - Size: Large
  - Description: Test offline/online transitions
  - Due: 2026-05-28
  - Assignee: QA

### Performance Optimization (Low Priority)

- [ ] **Analyze App Startup Time**
  - Priority: Low
  - Size: Medium
  - Description: Profile Firebase init, sync, etc.
  - Due: 2026-06-10
  - Assignee: Performance Team

- [ ] **Optimize Firestore Queries**
  - Priority: Low
  - Size: Large
  - Description: Add indexes, optimize pagination, caching
  - Due: 2026-06-15
  - Assignee: Performance Team

- [ ] **Reduce App Bundle Size**
  - Priority: Low
  - Size: Medium
  - Description: Analyze and optimize package sizes
  - Due: 2026-06-15
  - Assignee: Performance Team

### Feature Expansion (Low Priority)

- [ ] **Multi-Language Support**
  - Priority: Low
  - Size: Large
  - Description: Add English, Chinese, Thai support
  - Due: 2026-07-01
  - Assignee: TBD

- [ ] **Advanced Reporting**
  - Priority: Low
  - Size: Large
  - Description: Custom reports, analytics, charts
  - Due: 2026-07-15
  - Assignee: TBD

- [ ] **Mobile Payment Integration**
  - Priority: Low
  - Size: Large
  - Description: Integrate additional payment providers
  - Due: 2026-08-01
  - Assignee: TBD

---

## Completed Tasks

### Recent (2026-05-15)

- [x] **Setup Documentation Process**
  - Created CLAUDE.md
  - Created docs/ structure
  - Updated copilot-instructions.md

---

## Prioritization Matrix

```
                    Small      Medium     Large
High Priority       ✓ ✓ ✓      ✓ ✓        ✓
Medium Priority     ✓          ✓ ✓        ✓
Low Priority        ✓          ✓          ⏳
```

---

## Status Legend

- `[ ]` - Not started
- `[~]` - In progress
- `[x]` - Completed
- `[⏳]` - Blocked/Waiting

---

## How to Update

When you complete a task:
1. Mark with `[x]`
2. Move to "Completed Tasks" section
3. Add date and any notes
4. Update HANDOVER.md "Completed Tasks"

---

**Last Updated:** 2026-05-15  
**Maintained By:** GitHub Copilot  
**Next Review:** Before sprint planning
