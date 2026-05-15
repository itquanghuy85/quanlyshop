# Known Issues - HULUCA Shop Manager

Danh sách vấn đề đã phát hiện, workarounds, và priority levels.

---

## Active Issues

### BUILD & COMPILATION

#### [1] Android NDK Version Mismatch
- **Severity:** ⚠ Medium
- **Status:** Pending Fix
- **Description:** integration_test requires Android NDK 28.2.13676358 nhưng project configured NDK 27.0.12077973
- **Affected:** Android build
- **Error Message:**
  ```
  integration_test requires Android NDK 28.2.13676358
  ```
- **Workaround:** Add to `android/app/build.gradle.kts`:
  ```gradle
  android {
      ndkVersion = "28.2.13676358"
  }
  ```
- **Fix Location:** `android/app/build.gradle.kts`
- **Priority:** High (blocks release builds)

#### [2] Impeller Opt-out Deprecated
- **Severity:** ⚠ Medium
- **Status:** Pending Removal
- **Description:** Flutter warning về opt-out Impeller deprecated
- **Affected:** Android build warnings
- **Error Message:**
  ```
  [Action Required]: Impeller opt-out deprecated.
  ```
- **Workaround:** Remove from `android/app/src/main/AndroidManifest.xml`:
  ```xml
  android:io.flutter.embedding.android.EnableImpeller=false
  ```
- **Fix Location:** `android/app/src/main/AndroidManifest.xml`
- **Priority:** Medium (deprecation warning)

---

### RUNTIME

#### [3] Image Decoder Failures
- **Severity:** ⚠ Medium
- **Status:** Device-Specific
- **Description:** Some images fail to decode with "Failed to create image decoder with message 'unimplemented'"
- **Affected:** Image display (especially on Android 12+)
- **Error:** 
  ```
  android.graphics.ImageDecoder$DecodeException: Failed to create image decoder
  ```
- **Root Cause:** Device-specific image format support
- **Workaround:** Validate image format + size before upload
- **Fix Location:** `lib/services/image_upload_service.dart` (if exists)
- **Priority:** Medium (affects UX but not critical)

#### [4] FCM Token Cannot Save at Login
- **Severity:** ℹ Informational
- **Status:** Expected Behavior
- **Description:** "Cannot save FCM token: no authenticated user" appears at login screen
- **Affected:** Notifications (only at login state)
- **Error:**
  ```
  I/flutter: Cannot save FCM token: no authenticated user
  ```
- **Root Cause:** Expected - no user authenticated yet
- **Workaround:** None needed, automatic retry after auth success
- **Priority:** Low (not a bug)

#### [5] ANR (Application Not Responding) Warnings
- **Severity:** ⚠ Medium
- **Status:** Performance Investigation Needed
- **Description:** Occasional ANR warnings (~1900ms delays detected)
- **Affected:** App startup, performance
- **Error:**
  ```
  E/ANR_LOG: >>> msg's executing time is too long
  ```
- **Root Cause:** Heavy operations on main thread (Firebase init, sync, etc.)
- **Workaround:** Monitor in debugger, optimize offending code
- **Priority:** Medium (affects user experience)

#### [6] Frame Skipping
- **Severity:** ℹ Informational
- **Status:** Performance Optimization Needed
- **Description:** "Skipped XXX frames" warnings during startup
- **Affected:** UI responsiveness
- **Error:**
  ```
  I/Choreographer: Skipped 471 frames!
  ```
- **Root Cause:** Heavy rendering/initialization on main thread
- **Workaround:** Use profiler to identify bottleneck
- **Priority:** Low (startup only)

---

### DEVICE/ENVIRONMENT

#### [7] Device Connection Loss
- **Severity:** ⚠ Medium
- **Status:** Hardware-Related
- **Description:** "Lost connection to device" during development
- **Affected:** flutter run, debugging
- **Error:**
  ```
  Lost connection to device.
  ```
- **Root Cause:** USB connection instability or ADB timeout
- **Workaround:**
  - Reconnect USB cable
  - Kill and restart adb: `adb kill-server && adb devices`
  - Restart flutter run
- **Priority:** Low (development only)

#### [8] Parcel NULL String Reading Errors
- **Severity:** ℹ Minor
- **Status:** Known Platform Issue
- **Description:** "Reading a NULL string not supported here" Parcel errors
- **Affected:** Android framework communication (non-critical)
- **Error:**
  ```
  E/Parcel: Reading a NULL string not supported here.
  ```
- **Root Cause:** Android framework quirk
- **Workaround:** None needed, non-blocking
- **Priority:** Low (informational only)

---

## Resolved Issues

### PAST (Archived)

*Ví dụ (xóa khi có issues thực tế):*
- ~~[RESOLVED] Firebase initialization timeout~~ ✓ Fixed by updating Firebase packages
- ~~[RESOLVED] Firestore query performance~~ ✓ Fixed by adding indexes

---

## Issues by Priority

### Critical (🔴)
- None at this time

### High (🟠)
1. Android NDK Version Mismatch

### Medium (🟡)
1. Impeller Opt-out Deprecated
2. Image Decoder Failures
3. ANR Warnings
4. Device Connection Loss

### Low (🟢)
1. FCM Token at Login (not a bug)
2. Frame Skipping (startup only)
3. Parcel NULL String Errors (non-critical)

---

## Issues by Category

### Build & Compilation (2)
- Android NDK Version Mismatch
- Impeller Opt-out Deprecated

### Runtime (4)
- Image Decoder Failures
- FCM Token Cannot Save
- ANR Warnings
- Frame Skipping

### Device/Environment (2)
- Device Connection Loss
- Parcel NULL String Errors

---

## How to Report New Issues

1. **Title:** Concise description
2. **Severity:** Critical/High/Medium/Low
3. **Status:** Pending/In Progress/Fixed
4. **Description:** What happens?
5. **Affected:** Which feature/component?
6. **Error Message:** Full error if applicable
7. **Root Cause:** Why does it happen?
8. **Workaround:** How to work around it?
9. **Fix Location:** Which file(s)?
10. **Priority:** For scheduling

---

## Issue Template

```markdown
#### [N] Issue Title
- **Severity:** (Critical/High/Medium/Low)
- **Status:** (Pending Fix/In Progress/Fixed/Workaround Only)
- **Description:** What happens?
- **Affected:** Which feature/component?
- **Error Message:**
  ```
  Full error message
  ```
- **Root Cause:** Why?
- **Workaround:** How to work around?
- **Fix Location:** Which file(s)?
- **Priority:** (For scheduling)
```

---

**Last Updated:** 2026-05-15  
**Maintained By:** GitHub Copilot  
**Review Frequency:** After each major task
