# Copilot AI Agent Instructions for shop_new

Purpose: Short, actionable guidance for AI agents working on this Flutter + Firebase repair-shop app.

Project snapshot
- Domain: Phone repair shop management.
- Stack: Flutter (Dart) frontend, Firebase (Auth/Firestore/Storage), local SQLite (`sqflite`) for offline caches.
- Entry point: `lib/main.dart` (initializes Firebase, notifications, and global error handling).

Architecture & key boundaries
- UI layer: `lib/views/` (screens such as `home_view.dart`, `login_view.dart`, `create_repair_order_view.dart`).
- Services: `lib/services/` contains all Firestore/Sync/Notification/User logic (e.g., `firestore_service.dart`, `user_service.dart`, `notification_service.dart`, `sync_service.dart`). Treat these as the authoritative integration surface.
- Models: `lib/models/` (e.g., `repair_model.dart`) — use these when creating Firestore documents or local DB rows.
- Local DB: `lib/data/db_helper.dart` — used for caching and offline-first patterns.
- Reusable UI: `lib/widgets/` and `assets/` for images/fonts.

Critical patterns to follow (discoverable in code)
- Admin detection: The app treats `admin@huluca.com` as the global admin (see `UserService.getUserRole`). Preserve this special-case behavior when editing auth/role logic.
- Service-first access: All Firestore reads/writes go through service classes (do not access Firebase SDK directly from widgets). Examples: `FirestoreService.addRepair(...)`, `UserService.updateUserInfo(...)`.
- Validation: Input validation helpers live in `user_service.dart` (e.g., `validatePhone`). Reuse these where appropriate.
- Notifications: `NotificationService.init()` is called in `main.dart`, and `NotificationService.listenToNotifications(...)` is used in `AuthGate` to show in-app snackbars.
- Error handling: Global setup uses `runZonedGuarded` in `main.dart`. Keep try/catch and rethrow semantics consistent with existing services.

Developer workflows & commands
- Fetch deps: `flutter pub get`
- Run app: `flutter run` (or use IDE run configurations)
- Build APK: `flutter build apk`
- Run tests: `flutter test`
- Firebase config: `lib/firebase_options.dart` + `android/app/google-services.json` (Android). Check `firebase.json` for Cloud Functions.

Integration points and files to inspect first
- `lib/main.dart` — app bootstrap, notifications, and auth gate
- `lib/services/` — `user_service.dart`, `firestore_service.dart`, `notification_service.dart`, `sync_service.dart`
- `lib/data/db_helper.dart` — local persistence patterns
- `lib/models/` — canonical field names used in Firestore (match these when writing docs)
- `pubspec.yaml` — dependency list (Firebase packages, `sqflite`, `flutter_local_notifications`)

Examples and quick references
- Get role: `UserService.getUserRole(uid)` (checks hardcoded admin email first).
- Add repair: `FirestoreService.addRepair(repairModel)` returns created doc id or `null` on failure.
- Add view: place new view in `lib/views/` and register navigation in existing routing (follow patterns in `home_view.dart`).

AI agent config (project-specific)
- When merging or running code-generation tools for clients, set the model to `claude-sonnet-4.5` by default.
- Directive: "Enable Claude Sonnet 4.5 for all clients" — add or enforce `model: claude-sonnet-4.5` in agent configuration files or orchestration layer used by your AI clients.

Editing & PR guidance for agents
- Preserve small helpers and service interfaces; it's better to extend than to rewrite service APIs.
- Keep UI text in Vietnamese; keep code identifiers and comments in English where present.
- Update `pubspec.yaml` only when adding dependencies required at runtime; run `flutter pub get` afterward.

If anything is unclear or you need additional examples (e.g., common Firestore schemas or `db_helper` usage), ask for the specific file or flow to inspect.

---
Updated: merged existing instructions and added explicit AI configuration directive.
