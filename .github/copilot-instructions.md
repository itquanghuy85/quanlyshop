# Copilot AI Agent Instructions for shop_new

Purpose: Short, actionable guidance for AI agents working on this Flutter + Firebase repair-shop app.

Project snapshot
- Domain: Phone repair shop management (Vietnamese UI, English code).
- Stack: Flutter (Dart) frontend, Firebase (Auth/Firestore/Storage/Functions), local SQLite (`sqflite`) for offline caches with real-time sync.
- Entry point: `lib/main.dart` (initializes Firebase, notifications, global error handling with `runZonedGuarded`, AuthGate for role-based routing).

Architecture & key boundaries
- UI layer: `lib/views/` (screens like `home_view.dart`, `login_view.dart`, `create_repair_order_view.dart`).
- Services: `lib/services/` contains all business logic and external integrations (e.g., `firestore_service.dart` for Firestore ops, `user_service.dart` for auth/role, `notification_service.dart` for in-app notifications, `sync_service.dart` for real-time sync).
- Models: `lib/models/` (e.g., `repair_model.dart`) — canonical field names for Firestore docs and local DB rows; use `toMap()`/`fromMap()` for serialization.
- Local DB: `lib/data/db_helper.dart` — SQLite wrapper for offline-first patterns; tables include `repairs`, `products`, `sales`, etc., with `isSynced` flags.
- Reusable UI: `lib/widgets/` and `assets/` for components and media.
- Sync layer: Real-time Firestore subscriptions in `sync_service.dart` update local DB; soft deletes (set `deleted: true`) in Firestore.

Critical patterns to follow (discoverable in code)
- Admin detection: Hardcoded super-admin via `admin@huluca.com` email (see `UserService._isSuperAdmin`); grants global access without shopId filtering.
- Service-first access: All Firestore reads/writes via service classes (never direct Firebase SDK in widgets); e.g., `FirestoreService.addRepair(repairModel)` returns doc ID or null.
- Data isolation: Multi-tenant with `shopId` from `UserService.getCurrentShopId()`; filters queries unless super-admin.
- Sync on auth: `UserService.syncUserInfo()` called in `AuthGate` to ensure user/shop setup; creates shop doc if needed.
- Validation: Input helpers in `user_service.dart` (e.g., `validatePhone` checks cleaned digits 9-12); throw exceptions on invalid data.
- Error handling: Global `runZonedGuarded` in `main.dart`; services use try/catch with rethrow; soft failures return null/false.
- Notifications: `NotificationService.init()` in `main.dart`, `listenToNotifications()` in `AuthGate` for snackbars; rate-limited to 3 per 10s.
- Local persistence: Upsert patterns in `db_helper.dart`; `firestoreId` as unique key; `isSynced` for conflict resolution.
- Soft deletes: Firestore updates with `deleted: true` and `updatedAt: serverTimestamp()`; local DB marks deleted but keeps records.

Developer workflows & commands
- Fetch deps: `flutter pub get`
- Run app: `flutter run` (or IDE run configs)
- Build APK: `flutter build apk --release`
- Run tests: `flutter test`
- Firebase config: `lib/firebase_options.dart` + `android/app/google-services.json` (Android); Cloud Functions in `functions/` (Node.js).
- Localization: ARB files in `lib/l10n/`; generate with `flutter gen-l10n`.
- Sync debugging: Check `sync_service.dart` subscriptions; local DB at `repair_shop_v22.db`.

Integration points and files to inspect first
- `lib/main.dart` — app bootstrap, auth gate, global error handling.
- `lib/services/user_service.dart` — role logic, shopId caching, validation.
- `lib/services/firestore_service.dart` — Firestore CRUD with shopId filtering.
- `lib/services/sync_service.dart` — real-time subscriptions to local DB.
- `lib/data/db_helper.dart` — SQLite schema (version 111), upsert/delete patterns.
- `lib/models/` — data structures (e.g., `Repair` with status enum 1-4).
- `pubspec.yaml` — Firebase packages, `sqflite`, `flutter_local_notifications`, printer libs (`print_bluetooth_thermal`, `esc_pos_printer`).

Examples and quick references
- Get role: `UserService.getUserRole(uid)` (checks admin email first, then Firestore).
- Add repair: `FirestoreService.addRepair(repairModel)` (adds shopId, returns doc ID).
- Sync init: `SyncService.initRealTimeSync(callback)` (subscribes to collections with shop filtering).
- Local upsert: `DBHelper().upsertRepair(repair)` (uses firestoreId for uniqueness).
- Validation: `UserService.validatePhone(phone)` (Vietnamese error messages).

AI agent config (project-specific)
- When merging or running code-generation tools for clients, set the model to `claude-sonnet-4.5` by default.
- Directive: "Enable Claude Sonnet 4.5 for all clients" — add or enforce `model: claude-sonnet-4.5` in agent configuration files or orchestration layer used by your AI clients.

Editing & PR guidance for agents
- Preserve service interfaces; extend rather than rewrite (e.g., add methods to `FirestoreService`).
- Keep UI text in Vietnamese; code/comments in English.
- Update `pubspec.yaml` only for runtime deps; run `flutter pub get` after.
- Use `SetOptions(merge: true)` for Firestore upserts to avoid overwriting.
- Test sync: Ensure local DB updates on Firestore changes; handle offline scenarios.

Multi-industry expansion (important)
- When working on multi-industry features (categories, variants, expiry tracking), read `DOCS/MULTI_INDUSTRY_EXPANSION_GUIDE.md` first.
- Do NOT modify PaymentIntentService or SalaryCalculationService during expansion.
- Keep backward compatibility: existing shops must continue working without changes.
- Use feature flags to enable/disable modules per businessType.

MANDATORY DOCUMENTATION PROCESS (REQUIRED FOR ALL TASKS)
========================================================

TASK COMPLETION REQUIREMENTS:
Every task is ONLY considered COMPLETE when ALL of these are satisfied:
1. Code changes implemented and tested
2. flutter analyze → zero errors
3. flutter build → success
4. All documentation updated
5. Changed files reported
6. HANDOVER updated with status

AUTOMATIC DOCUMENTATION UPDATES:
After EVERY code change, automatically update:

1. CLAUDE.md (if: architecture/module/rules change)
   - Kiến trúc, module mới, quy tắc phát triển

2. .github/copilot-instructions.md (if: AI/workflow change)
   - Hướng dẫn AI agents, workflow, coding rules

3. docs/CHANGELOG.md (every task)
   - Add new entry: date, summary, files modified/added/removed, validation results

4. docs/HANDOVER.md (every task)
   - Update: Current Status, Completed Tasks, Pending Tasks, Known Issues, Next Steps

5. docs/DOCUMENTATION_INDEX.md (if: new/removed doc files)
   - Add/remove entries from documentation index

6. (DOCS/FULL_DOCUMENTATION.md đã xoá ở [2026-08-30o] — bỏ qua mục này)
   - Chi tiết services, database schema, core logic

7. Specialized Reports (if: relevant to change):
   - PERMISSION_AUDIT_REPORT.md → permission logic
   - FINANCE_V2_MIGRATION.md → finance/payments
   - KIOTVIET_INTEGRATION_REPORT.md → KiotViet sync
   - IMAGE_UPLOAD_AUDIT_REPORT.md → image upload
   - UI_STANDARDIZATION_REPORT.md → UI components

VALIDATION CHECKLIST (before ending task):
☐ Code implemented
☐ flutter analyze: no errors
☐ flutter test: passing (if applicable)
☐ flutter build: success
☐ CLAUDE.md updated (if needed)
☐ .github/copilot-instructions.md updated (if needed)
☐ docs/CHANGELOG.md entry added
☐ docs/HANDOVER.md status updated
☐ docs/DOCUMENTATION_INDEX.md updated (if needed)
☐ Specialized reports updated (if needed)
☐ Changed files reported to user

DO NOT SKIP DOCUMENTATION:
- Documentation updates are MANDATORY, not optional
- No need to ask user: "Should I update docs?" → Just do it
- No need to ask user: "Update CHANGELOG?" → Just update it
- This is default workflow for ALL tasks

DOCUMENTATION FILES STRUCTURE:
Core Documents:
- CLAUDE.md (tổng thể cho AI agents)
- .github/copilot-instructions.md (hướng dẫn)
- docs/DOCUMENTATION_INDEX.md (chỉ mục)
- docs/CHANGELOG.md (lịch sử)
- docs/HANDOVER.md (trạng thái)

Architecture & Standards:
- docs/ARCHITECTURE.md (chi tiết kiến trúc)
- docs/DESIGN_SYSTEM.md (design tokens)
- docs/UI_GUIDELINES.md (hướng dẫn UI)
- docs/CODING_STANDARDS.md (quy tắc coding)

Project Management:
- docs/KNOWN_ISSUES.md (vấn đề)
- docs/TODO.md (công việc)
- docs/ROADMAP.md (lộ trình)

Implementation:
- docs/IMPLEMENTATION_REPORT.md (chi tiết)
- (DOCS/FULL_DOCUMENTATION.md đã xoá ở [2026-08-30o])

References:
- Read CLAUDE.md first (kiến trúc + quy tắc)
- Read docs/DOCUMENTATION_INDEX.md for overview
- Read docs/HANDOVER.md for current status
- Check docs/KNOWN_ISSUES.md before starting task

Key Principle:
When task ends, someone should understand:
- What was changed and why
- Current system state
- What's coming next
Just by reading CLAUDE.md + HANDOVER.md + CHANGELOG.md

NO EXCEPTIONS. Documentation is part of every task.
