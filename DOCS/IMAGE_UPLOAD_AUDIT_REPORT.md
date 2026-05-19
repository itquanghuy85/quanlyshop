# 📸 IMAGE UPLOAD AUDIT REPORT
**Date:** 2025-04-05  
**Status:** COMPREHENSIVE AUDIT COMPLETE  
**Critical Issues Found:** 5  
**Warnings:** 4  
**App State:** Production (Live on Store) ⚠️

---

## EXECUTIVE SUMMARY

The app uses **local-first upload pattern** where images are stored locally immediately and uploaded to cloud asynchronously in background. While this provides instant feedback, there are **5 critical issues** preventing reliable offline-first behavior and causing potential data loss scenarios.

**Critical Problems:**
1. ❌ **No EventBus subscription** in detail views → Images don't refresh UI when cloud upload completes
2. ❌ **Silent failures** → Failed uploads not retried until next app restart
3. ❌ **Local file deletion risk** → Temp compressed files not reliably cleaned up
4. ❌ **No upload status tracking** → Users unaware of pending uploads, may force-close app
5. ❌ **Missing local cache validation** → App displays broken image icon if local file deleted

---

## ARCHITECTURE OVERVIEW

### Current Flow

```
User picks image
    ↓
_addReceiveImage() [repair_detail_view.dart]
    ├─ Append local path to r.imagePath (immediately)
    ├─ Save repair to SQLite with isSynced=false
    ├─ Enqueue SyncOrchestrator
    └─ Fire-and-forget: BackgroundUploadService.uploadRepairImages()
        ↓
BackgroundUploadService._uploadRepairImages()
    ├─ Read current imagePath from DB
    ├─ Compress via StorageService._compressImage()
    ├─ Upload to Firebase Storage with retry logic (if no network, enqueue pending)
    ├─ Update DB: imagePath = cloud_url (replaces local path)
    ├─ Update Firestore: imagePath = cloud_url
    ├─ Warm NetworkImage cache
    ├─ Emit 'repairs_changed' event
    └─ ❌ BUT repair_detail_view DOES NOT LISTEN to this event!

UI Display [repair_detail_view._buildSmartImage()]
    ├─ If local path exists → Image.file() (displays immediately)
    ├─ If cloud URL → AppCachedImage (with memory cache)
    └─ If neither → broken_image icon
```

### Files Involved

| File | Role | Status |
|------|------|--------|
| `lib/services/background_upload_service.dart` | Background upload orchestration | ⚠️ Has issues |
| `lib/services/storage_service.dart` | Firebase Storage + compression | ⚠️ Retry incomplete |
| `lib/views/repair_detail_view.dart` | Image display + add image | ❌ Missing event listener |
| `lib/views/create_repair_order_view.dart` | Image add during create | ⚠️ No upload tracking |
| `lib/widgets/app_cached_image.dart` | Image display widget | ℹ️ OK |
| `lib/models/repair_model.dart` | receiveImages getter | ✅ OK |

---

## DETAILED ISSUES

### 🔴 ISSUE #1: NO UI REFRESH WHEN CLOUD UPLOAD COMPLETES

**Severity:** CRITICAL (Production Impact)  
**Location:** `lib/views/repair_detail_view.dart` (repair_detail_view)

**Problem:**
```dart
// BackgroundUploadService emits event after upload completes:
EventBus().emit('repairs_changed');

// BUT repair_detail_view DOES NOT subscribe to this event!
// ❌ No listener in initState() or anywhere
// ✅ See: create_repair_order_view.dart for proper pattern
```

**Behavior:**
1. User picks image → sees local thumbnail immediately ✅
2. BackgroundUploadService uploads to cloud (1-5 seconds)
3. DB updated with cloud URL ✅
4. Firestore updated with cloud URL ✅
5. Event emitted ('repairs_changed') ✅
6. ❌ **UI does NOT refresh** - still shows local path
7. User sees local thumbnail until:
   - They leave and re-enter screen
   - They manually trigger refresh
   - App syncs from Firestore on next load

**Impact:**
- Users think image upload failed (no visual feedback)
- Bandwidth waste: local files kept even after cloud upload
- Confusion: can't tell which images are synced

**Test Case:**
1. Open repair detail view
2. Add photo from camera/gallery
3. Observe thumbnail displays locally
4. Open another view, come back after 3-5 seconds
5. ❌ Thumbnail still from local path even though cloud URL exists in DB

**Fix Required:**
Add EventBus subscription in `initState()`:
```dart
void _setupEventListeners() {
  EventBus().listen('repairs_changed', (_) {
    _reloadRepairFromDb();
  });
  // Other event listeners...
}

Future<void> _reloadRepairFromDb() async {
  if (r.id == null) return;
  final updated = await db.getRepairById(r.id!);
  if (mounted && updated != null) {
    setState(() {
      r = updated;
    });
  }
}
```

---

### 🔴 ISSUE #2: FAILED UPLOADS NOT RETRIED UNTIL APP RESTART

**Severity:** CRITICAL (Data Loss Risk)  
**Location:** `lib/services/storage_service.dart` (StorageService.retryPendingUploads)

**Problem:**
```dart
// Pending uploads stored in SharedPreferences:
static const String _pendingUploadsKey = 'storage_pending_uploads_v1';

// Retry only triggered in 3 places:
// 1. uploadAndGetUrl() - only if no network currently
// 2. uploadXFileAndGetUrl() - only if no network currently
// 3. Manually called (never called in app)

// ❌ MISSING: No scheduled retry on app startup or periodically
// ❌ MISSING: If upload fails with authorization error, NOT retried
// ❌ MISSING: No retry on network reconnect detection
```

**Scenario That Loses Data:**
1. User picks image at 14:50 with good network
2. Upload starts, hits authorization error (Firebase rules issue)
3. Error caught, image added to pending queue in SharedPreferences
4. **NotificationService.showSnackBar** says "đang tải nền" but NOT "lỗi tải, sẽ thử lại"
5. BackgroundUploadService exits, never retries
6. User force-closes app at 14:51
7. ❌ **Image pending in queue indefinitely**
8. If app crashes or reinstalled, pending queue lost (SharedPreferences not backed up)
9. **IMAGE LOST** - local file deleted, cloud file never uploaded

**Current Retry Logic:**
```dart
// Only retries when NEW upload triggered:
if (!_retryingPendingUploads) {
  unawaited(retryPendingUploads());
}
// But if user doesn't upload another image, pending never retried!
```

**Test Case:**
1. Simulate Firebase Storage authorization error (modify storage.rules temporarily)
2. Pick image on device
3. App shows "đang tải nền" but upload fails silently
4. Force close app
5. ❌ Image not in Firestore, pending queue in SharedPreferences not retried
6. Reopen app → image gone (local file deleted if not cleared)

**Fix Required:**
1. Retry pending uploads on app startup (in `main.dart`)
2. Retry on network reconnect (connectivity_plus package)
3. Show explicit error UI if upload fails, not just "đang tải nền"
4. Keep local files until cloud confirmed (don't delete temp files)

---

### 🔴 ISSUE #3: TEMP COMPRESSED FILES NOT RELIABLY CLEANED UP

**Severity:** HIGH (Disk Space + Permission Issues)  
**Location:** `lib/services/storage_service.dart` (StorageService.uploadAndGetUrl, _compressImage)

**Problem:**
```dart
// Compress image creates temp file:
final tempDir = await getTemporaryDirectory();
final timestamp = DateTime.now().millisecondsSinceEpoch;
final targetPath = '${tempDir.path}/compressed_$timestamp.jpg';

// Upload succeeds, try to delete:
if (fileToUpload.path != file.path && fileToUpload.existsSync()) {
  try {
    await fileToUpload.delete();
  } catch (_) {} // ❌ Silently ignore errors!
}

// Problems:
// 1. Temp directory auto-clears on some Android versions (could lose original if compress deleted)
// 2. If upload fails partway, temp file stranded
// 3. Repeated uploads = temp dir fills up with orphaned .jpg files
// 4. No tracking of temp files (can't clean up stale ones)
```

**Reproduction:**
1. On low-disk device, pick large image (2MB+)
2. Upload repeatedly (10x)
3. `getTemporaryDirectory()` fills with `compressed_*.jpg` files
4. Eventually app fails to compress due to disk space

**Impact:**
- Temp directory pollution: `/data/local/tmp/` fills with orphaned files
- On some devices (MIUI, OneUI), temp dir auto-cleaned but at unpredictable times
- If app crashes during upload, temp files never deleted

**Fix Required:**
```dart
// Better cleanup strategy:
static Future<void> _cleanupTempFiles() async {
  try {
    final tempDir = await getTemporaryDirectory();
    final files = tempDir.listSync();
    for (final f in files) {
      if (f is File && f.path.contains('compressed_')) {
        try {
          if (await f.lastModified().difference(DateTime.now()).inHours > 24) {
            await f.delete();
          }
        } catch (_) {}
      }
    }
  } catch (_) {}
}

// Call on app startup and periodically
```

---

### 🔴 ISSUE #4: NO UPLOAD PROGRESS/STATUS TRACKING FOR USER

**Severity:** CRITICAL (UX + Data Awareness)  
**Location:** `lib/views/repair_detail_view.dart`, `lib/views/create_repair_order_view.dart`

**Problem:**
```dart
// Current flow in _addReceiveImage():
final imagesToUpload = List<XFile>.from(_images);
final r = await _saveOrderProcess();

if (imagesToUpload.isNotEmpty && r.id != null && r.firestoreId != null) {
  NotificationService.showSnackBar(
    'Đơn đã lưu. Đang tải ảnh lên hệ thống, vui lòng không thoát ứng dụng.',
    color: Colors.blue,
    duration: const Duration(seconds: 7), // ⚠️ Only 7 seconds!
  );
  BackgroundUploadService.uploadRepairImages(
    localRepairId: r.id!,
    firestoreId: r.firestoreId!,
    images: imagesToUpload,
  );
}

// Issues:
// 1. Snackbar disappears after 7 seconds, but upload may take 30+ seconds
// 2. No indication when upload completes (success/fail)
// 3. User doesn't know if they can safely exit app
// 4. App crash/force close likely if user impatient
```

**Scenario:**
1. User creates repair with 5 photos
2. Snackbar says "Đang tải ảnh..." for 7 seconds then disappears
3. Upload actually still running (network slow)
4. User thinks upload done, force-closes app
5. ❌ Upload interrupted, images stuck in pending queue
6. Next app startup: retry, but old local files may be deleted

**Fix Required:**
1. Use persistent notification (not snackbar) while uploading
2. Update notification with progress: "Uploading 3/5 images..."
3. Show success/fail notification when complete
4. Prevent app exit while uploads pending (show warning dialog)
5. Use foreground service on Android (if long upload)

---

### 🟡 ISSUE #5: MISSING LOCAL CACHE VALIDATION

**Severity:** MEDIUM-HIGH (Silent Failures)  
**Location:** `lib/views/repair_detail_view.dart` (_buildSmartImage)

**Problem:**
```dart
// Current logic:
Widget _buildSmartImage(String path) {
  final normalized = path.trim();
  
  // ... handle cloud paths ...
  
  // Local file display:
  File file = File(normalized);
  if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
  
  // ❌ If file DOESN'T exist but path is stored, show broken icon:
  return const Icon(Icons.cloud_download, color: AppColors.primary);
}

// Issues:
// 1. If local file deleted (by OS, user, or accident), shows broken icon
// 2. But imagePath STILL contains local path reference
// 3. Should check if image is also available in cloud before showing broken
// 4. No attempt to recover cloud version if local missing
```

**Scenario:**
1. User picks photo → stored as `/data/user/cache/img_12345.jpg`
2. System cleanup deletes cache (low disk space)
3. User reopens repair → local path still in imagePath
4. ❌ Shows broken image icon even though cloud version exists
5. User thinks image lost

**Fix Required:**
```dart
// Enhanced logic:
Widget _buildSmartImage(String path) {
  final normalized = path.trim();
  
  // Check cloud paths first
  if (_isGsStoragePath(normalized) || _isStorageRelativePath(normalized)) {
    return FutureBuilder<String?>(
      future: _resolveDisplayImagePath(normalized),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return AppCachedImage(imageUrl: snapshot.data!, ...);
        }
        return const Icon(Icons.broken_image, ...);
      },
    );
  }
  
  // For local paths: if file missing, try to resolve to cloud
  File file = File(normalized);
  if (!file.existsSync()) {
    // ✅ Try to get cloud version from Firestore
    return FutureBuilder<String?>(
      future: _resolveCloudImageForLocalPath(normalized),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return AppCachedImage(imageUrl: snapshot.data!, ...);
        }
        return const Icon(Icons.image_not_supported, ...);
      },
    );
  }
  
  return Image.file(file, fit: BoxFit.cover);
}
```

---

## WARNINGS

### ⚠️ WARNING #1: COMPRESSION TIME BLOCKS UPLOAD

**Location:** `lib/services/storage_service.dart` (_compressImage)  
**Severity:** MEDIUM

Compression runs on UI thread (FlutterImageCompress), not in isolate:
```dart
final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
  filePath,
  targetPath,
  quality: quality,
  minWidth: targetSize,
  minHeight: targetSize,
  format: format,
  keepExif: false,
).timeout(const Duration(seconds: 12)); // ⚠️ 12 second timeout!
```

On slow devices or large images (5MB+), compression can block UI for 2-5 seconds.

**Mitigation:** Use compute() to run in background isolate:
```dart
final compressedFile = await compute(
  _compressImageInBackground,
  CompressParams(filePath, targetPath, quality, targetSize),
);
```

---

### ⚠️ WARNING #2: NETWORK IMAGE WARMING UNRELIABLE

**Location:** `lib/services/background_upload_service.dart` (_warmNetworkImageCache)  
**Severity:** LOW-MEDIUM

Network image cache warming is best-effort, ignores all errors:
```dart
static Future<void> _warmSingleNetworkImage(String url) async {
  try {
    final provider = NetworkImage(url);
    // ... setup listener ...
    await completer.future.timeout(const Duration(seconds: 4), onTimeout: () {
      stream.removeListener(listener);
    });
  } catch (_) {
    // ❌ Best-effort cache warmup, ignore failures.
  }
}
```

If network slow, warming may not complete before user scrolls to image → image reloads from network again.

---

### ⚠️ WARNING #3: SYNC QUEUE RACE CONDITION

**Location:** `lib/services/background_upload_service.dart` (_uploadRepairImages)  
**Severity:** LOW

```dart
final hasPendingQueue = await _hasPendingRepairQueue(dbConn, localRepairId);
await dbConn.update(
  'repairs',
  {
    'isSynced': cloudUpdated && !hasPendingQueue ? 1 : 0, // ❌ Race condition
  },
  where: 'id = ?',
  whereArgs: [localRepairId],
);
```

Between checking `hasPendingQueue` and updating `isSynced`, sync queue could change. Should use atomic update or lock.

---

### ⚠️ WARNING #4: ENCRYPTION OVERHEAD ON FIRESTORE UPDATE

**Location:** `lib/services/background_upload_service.dart` (_uploadRepairImages)  
**Severity:** LOW

```dart
final encData = EncryptionService.encryptMap({
  'imagePath': cloudPaths,
  'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
});
await _db.collection('repairs').doc(firestoreId).update(encData);
```

Image URLs encrypted on every upload. If image has 10+ paths, encryption overhead grows. Consider whitelisting fields to NOT encrypt.

---

## ROOT CAUSE ANALYSIS

| Issue | Root Cause | Why It Happened |
|-------|-----------|-----------------|
| #1: No UI Refresh | EventBus not subscribed in detail view | Async background upload not integrated with UI layer |
| #2: Failed uploads not retried | No retry trigger on app startup/network reconnect | Development assumed good network, didn't handle real-world scenarios |
| #3: Temp files not cleaned | Exception ignored silently | Defensive coding without recovery strategy |
| #4: No upload tracking | Fire-and-forget pattern without status monitoring | UX design didn't account for background operations |
| #5: Missing local cache validation | Assumed local files always exist if path stored | No fallback to cloud version if local deleted |

---

## PRIORITY RECOMMENDATIONS

### Phase 2A: CRITICAL FIXES (Do First - App on Store)
1. **Add EventBus subscription** to repair_detail_view + create_repair_order_view
2. **Show persistent upload status** (notification, not snackbar)
3. **Prevent app exit during upload** (warn user if trying to close)

### Phase 2B: URGENT FIXES (Do Soon)
4. **Retry pending uploads** on app startup + network reconnect
5. **Validate local cache** before display (fallback to cloud)
6. **Explicit error handling** (distinguish auth errors from network errors)

### Phase 2C: IMPROVEMENTS (Do Later)
7. Clean up temp files on startup
8. Move compression to background isolate
9. Add upload progress tracking
10. Improve pending upload persistence

---

## TESTING CHECKLIST

- [ ] Add image → observe local thumbnail immediately
- [ ] Wait 5 seconds → verify thumbnail updates to cloud URL without navigating away
- [ ] Slow network (throttle to 2G) → verify upload progresses, doesn't timeout
- [ ] Network disconnect mid-upload → verify retry on reconnect
- [ ] Low disk space → verify temp files cleaned properly
- [ ] App force-close during upload → reopen and verify recovery
- [ ] Multiple images rapid-fire → verify all queued and uploaded sequentially
- [ ] Camera roll image → verify works (different file path format)
- [ ] Very large image (5MB+) → verify doesn't freeze UI, compresses properly
- [ ] Storage authorization error → verify explicit error message (not silent fail)

---

## ESTIMATED FIX TIME

| Priority | Issue | Estimated Hours | Complexity |
|----------|-------|-----------------|-----------|
| P0 | #1 + #2 + #4 | 4-6 | Medium |
| P1 | #3 + #5 | 3-4 | Medium |
| P2 | Warnings | 2-3 | Low-Medium |
| **Total** | **All Fixes** | **10-14** | **Medium** |

---

## CONCLUSION

The app's **local-first upload pattern** is good for UX (instant feedback), but lacks proper status tracking and error recovery. Current implementation allows **silent failures** and **data loss** in edge cases. 

**Recommended:** Fix critical issues #1-4 before next store submission to ensure production reliability.

