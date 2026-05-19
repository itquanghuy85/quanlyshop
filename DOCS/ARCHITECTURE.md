# Architecture - HULUCA Shop Manager

Chi tiết kiến trúc, layers, data flow, components, interactions.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     UI LAYER                            │
│            (Views, Widgets, Screens)                    │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│              BUSINESS LOGIC LAYER                       │
│         (Services, State Management)                    │
├────────────────────────┬────────────────────────────────┤
│   Firestore Service    │    User Service                │
│   Sync Service         │    Notification Service        │
│   Payment Service      │    Connectivity Service        │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│              DATA LAYER                                │
│      (Models, Local Database)                           │
├────────────────────────┬────────────────────────────────┤
│   Models               │    Database Helper             │
│   (Serializable)       │    (SQLite v17)                │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│         EXTERNAL INTEGRATIONS LAYER                     │
├──────────────────────────────────────────────────────────┤
│   Firebase            │  KiotViet         │ Printer API │
│   (Auth/Firestore)    │  (Sync API)       │ (ESC/POS)   │
└───────────────────────────────────────────────────────────┘
```

---

## Detailed Layer Architecture

### 1. UI Layer (`lib/views/` & `lib/widgets/`)

**Responsibility:** User interface, user interactions, visual presentation

**Components:**
- Screens (Views): `*_view.dart`
  - `login_view.dart` - Authentication
  - `home_view.dart` - Dashboard
  - `create_repair_order_view.dart` - Repair creation
  - `inventory_view.dart` - Inventory management
  - `sales_view.dart` - Sales management
  - `customer_view.dart` - Customer management
  - `report_view.dart` - Reports & analytics

- Reusable Widgets: `lib/widgets/*.dart`
  - Buttons, cards, dialogs, forms
  - Input fields with validation
  - Lists, tables, charts

**Key Rules:**
- Never access Firebase directly
- Always use Services for data access
- Use StreamBuilder/FutureBuilder for async data
- Implement proper error handling UI
- Follow design system tokens

---

### 2. Business Logic Layer (`lib/services/`)

**Responsibility:** Core business rules, data processing, API orchestration

#### 2.1 FirestoreService (`lib/services/firestore_service.dart`)
```
Responsibilities:
- All Firestore CRUD operations
- Query building with shopId filtering
- Transaction management
- Error handling & logging
- Subscription management

Key Methods:
- addRepair(RepairModel) → Future<String?>
- updateRepair(String, RepairModel) → Future<bool>
- deleteRepair(String) → Future<bool>
- getRepairs(String shopId) → Stream<List<RepairModel>>
- getRepairById(String id) → Future<RepairModel?>
```

#### 2.2 UserService (`lib/services/user_service.dart`)
```
Responsibilities:
- User authentication (Firebase Auth)
- Role & permission management
- ShopId caching & management
- Data validation (phone, email, etc.)
- Admin detection (super-admin logic)

Key Methods:
- getCurrentUser() → User?
- getUserRole(String uid) → Future<String?>
- getCurrentShopId() → Future<String?>
- syncUserInfo() → Future<void>
- validatePhone(String) → void (throws on invalid)
- isSuperAdmin() → Future<bool>
```

#### 2.3 SyncService (`lib/services/sync_service.dart`)
```
Responsibilities:
- Real-time Firestore subscriptions
- Offline-first synchronization
- Local database updates
- Conflict resolution (isSynced flag)
- Subscription lifecycle management

Key Methods:
- initRealTimeSync(callback) → Future<void>
- subscribeToRepairs() → StreamSubscription
- subscribeToProducts() → StreamSubscription
- syncOfflineChanges() → Future<void>
- handleConflicts() → void
```

#### 2.4 NotificationService (`lib/services/notification_service.dart`)
```
Responsibilities:
- FCM initialization & token management
- Local notification handling
- Notification routing & display
- Rate limiting (3 per 10s)

Key Methods:
- init() → Future<void>
- getFCMToken() → Future<String?>
- listenToNotifications() → void
- showNotification(title, body) → Future<void>
- scheduleNotification() → Future<void>
```

#### 2.5 PaymentIntentService (`lib/services/payment_intent_service.dart`)
```
Responsibilities:
- Payment processing
- Transaction recording
- Payment status tracking
- Reconciliation

Key Methods:
- processPayment(amount, method) → Future<bool>
- recordTransaction() → Future<void>
- getPaymentHistory() → Stream<List<Transaction>>
```

#### 2.6 ConnectivityService (`lib/services/connectivity_service.dart`)
```
Responsibilities:
- Network status monitoring
- Offline/online detection
- Connection quality tracking

Key Methods:
- isOnline() → bool
- listenToConnectivityChanges() → Stream<bool>
```

---

### 3. Data Layer (`lib/models/` & `lib/data/`)

**Responsibility:** Data structures, serialization, persistence

#### 3.1 Models (`lib/models/*.dart`)
```
Purpose: Canonical data structures for Firestore & local DB

Requirements:
- Implement toMap() & fromMap()
- Support null safety
- Immutable where possible
- Include validation in constructors

Example:
class RepairModel {
  final String id;
  final String shopId;
  final String customerName;
  final String customerPhone;
  final String description;
  final int status; // 1=pending, 2=inProgress, 3=done, 4=cancelled
  final double estimatedCost;
  final Timestamp createdAt;
  
  Map<String, dynamic> toMap() => {
    'id': id,
    'shopId': shopId,
    'customerName': customerName,
    ...
  };
  
  factory RepairModel.fromMap(Map<String, dynamic> map) => RepairModel(
    id: map['id'] as String,
    shopId: map['shopId'] as String,
    ...
  );
}
```

#### 3.2 Database Helper (`lib/data/db_helper.dart`)
```
Purpose: SQLite wrapper for offline-first pattern

Schema Version: 17

Tables:
- repairs (id, shopId, data JSON, isSynced, deleted, updatedAt)
- products (id, shopId, data JSON, isSynced, deleted, updatedAt)
- sales (id, shopId, data JSON, isSynced, deleted, updatedAt)
- customers (id, shopId, data JSON, isSynced, deleted, updatedAt)
- payments (id, shopId, data JSON, isSynced, deleted, updatedAt)
- settings (key, value)

Key Methods:
- upsertRepair(RepairModel) → Future<int> (uses firestoreId as unique key)
- deleteRepair(String id, soft=true) → Future<bool>
- getRepairs(String shopId) → Future<List<RepairModel>>
- markSynced(String collectionId, String docId) → Future<bool>
- getUnsyncedChanges(String collection) → Future<List<Map>>
```

---

### 4. External Integrations Layer

#### 4.1 Firebase Integration
```
Components:
- Firebase Auth (user authentication)
- Firestore (cloud database)
- Cloud Storage (image upload)
- Cloud Functions (server-side logic)
- Cloud Messaging (FCM notifications)
- Crashlytics (error reporting)

Access Pattern:
✓ All access through Services (FirestoreService, etc.)
✗ Never direct Firebase SDK calls from widgets
```

#### 4.2 KiotViet Integration
```
Purpose: Sync data with KiotViet POS system

Responsibility:
- Products, inventory, sales sync
- Real-time inventory updates
- Sales order synchronization

Key Methods (in services):
- syncProductsFromKiotViet() → Future<void>
- syncInventoryFromKiotViet() → Future<void>
- pushSalesToKiotViet(List<Sale>) → Future<bool>
```

#### 4.3 Thermal Printer Integration
```
Purpose: Print receipts, reports

Libraries:
- `print_bluetooth_thermal` - Connect to printer
- `esc_pos_printer` - Generate ESC/POS format

Key Methods:
- connectPrinter(String deviceId) → Future<bool>
- printReceipt(RepairModel) → Future<void>
- printReport(Report) → Future<void>
```

---

## Data Flow

### Typical Read Flow
```
User (Views)
    ↓
Views calls Service method
    ↓
Service queries Firestore (via StreamBuilder/FutureBuilder)
    ↓
Firestore returns data
    ↓
Service filters by shopId (or super-admin bypass)
    ↓
Service converts to Model
    ↓
Views renders data
    ↓
Meanwhile: SyncService subscribes to updates → Local DB updated
```

### Typical Write Flow
```
User (Views) submits form
    ↓
Views validates input locally
    ↓
Views calls Service method with data
    ↓
Service validates input again
    ↓
Service adds shopId automatically
    ↓
Service writes to Firestore
    ↓
Firestore returns doc ID
    ↓
Service also saves to Local DB (with isSynced=false initially)
    ↓
SyncService marks as isSynced=true when confirmed
    ↓
Views shows success notification
```

### Offline Flow
```
User (offline) fills form & submits
    ↓
Views calls Service method
    ↓
Service detects offline (ConnectivityService.isOnline() = false)
    ↓
Service saves to Local DB with isSynced=false
    ↓
Views shows "saved offline" message
    ↓
When online: SyncService detects reconnect
    ↓
SyncService uploads all isSynced=false records to Firestore
    ↓
Sets isSynced=true on successful upload
```

---

## Multi-Tenant Architecture

### ShopId Isolation
```
Firestore Structure:
/shops/{shopId}/repairs/{repairId}
/shops/{shopId}/products/{productId}
/shops/{shopId}/customers/{customerId}
/shops/{shopId}/sales/{saleId}
/shops/{shopId}/payments/{paymentId}

Every query MUST filter by shopId:
  query.where('shopId', isEqualTo: currentShopId)

Exception: Super-admin (admin@huluca.com) bypasses shopId filtering
```

### Role-Based Access
```
Admin
├─ Global access (all shops)
├─ Can create/delete shops
└─ Can manage users & roles

Manager
├─ Access to their shop only
├─ Can create/edit repairs, products, sales
└─ Can view reports

Staff
├─ Access to their shop only
├─ Can create repairs, view products
└─ Limited reporting access
```

---

## Error Handling Strategy

### Global Error Handler
```dart
// main.dart
runZonedGuarded(
  () => runApp(const MyApp()),
  (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
    debugPrint('Fatal error: $error\n$stackTrace');
  },
);
```

### Service-Level Error Handling
```dart
// services
try {
  // Do something
} catch (e, stackTrace) {
  debugPrint('Service error: $e\n$stackTrace');
  rethrow; // Let caller handle
}
```

### Widget-Level Error Handling
```dart
// views
try {
  await FirestoreService.addRepair(repair);
  showSnackBar('Đơn sửa đã được tạo');
} catch (e) {
  showErrorSnackBar(e.toString());
}
```

---

## Performance Optimization Points

### Database
- Firestore indexes for common queries
- Pagination (20 items per page)
- Query caching in SyncService

### UI
- Lazy loading for large lists
- Image optimization & caching
- Debounced search/filters

### Network
- Offline-first with local DB
- Batch operations where possible
- Connection-aware retries

---

## Deployment Architecture

### Development
```
Local Dev → Firebase Emulator (testing)
         → Firebase Dev Project (staging)
```

### Production
```
User App (APK/PlayStore) → Firebase Production
                        ↓
                    Firestore
                    Storage
                    Functions
                    Auth
                    Messaging
```

---

## Product Image & Storage Location System (v98)

### Overview
Hệ thống quản lý ảnh sản phẩm và vị trí lưu kho được thêm vào phiên bản DB schema v98.

### Data Model

#### StorageLocation (`lib/models/storage_location_model.dart`)
```
Fields: id, firestoreId, shopId, code, name, warehouse, floor, shelf, bin, note, isActive, createdAt, updatedAt
Table:  storage_locations (SQLite v98)
Index:  idx_storage_locations_shopId
```

#### Product additions
```
New fields: locationId, locationCode, locationName (TEXT)
            localImagePath (TEXT), imageUpdatedAt (INTEGER)
Table: products (ALTER TABLE via onOpen + v98 migration)
```

#### Repair additions
```
New fields: storageLocationId, storageLocationCode, storageLocationName (TEXT)
Table: repairs (ALTER TABLE via onOpen + v98 migration)
DB safety: Added to onOpen() defensive migration — guaranteed to exist on all installs
```

### Components

| Component | Path | Role |
|-----------|------|------|
| `ImagePickerWidget` | `lib/widgets/image_picker_widget.dart` | Camera/gallery pick, auto-compress (<300KB), full-screen view |
| `_FullScreenImageViewer` | Inside image_picker_widget.dart | Full-screen zoom viewer (PhotoView) |
| `StorageLocationSelector` | `lib/widgets/storage_location_selector.dart` | Bottom sheet picker for location |
| `StorageLocationView` | `lib/views/storage_location_view.dart` | CRUD management screen |
| `ProductImageService` | `lib/services/product_image_service.dart` | Background upload to Firebase Storage |
| `AppCachedImage` | `lib/widgets/app_cached_image.dart` | Cached network image with placeholder |

### Image Storage Path
```
Firebase Storage: uploads/products/{shopId}/{productId}/main.jpg
                  uploads/products/{shopId}/{productId}/{timestamp}.jpg (multiple)
```

### Background Upload Pattern
```
1. User picks image → compressed local file saved immediately
2. DB record saved with localImagePath (not imageUrl yet)
3. Background: ProductImageService.uploadAndSaveToProduct() runs
4. On success: product.images = downloadUrl, localImagePath cleared
5. On network error: upload retried on next app session
```

### Location Filter in Inventory
```
Filter chip "Vị trí" in _buildCategoryChips():
- Taps → _showLocationFilterSheet() → loads locations from SQLite → user picks
- Active: chip shows code + X button → tap X to clear
- Filter logic: products.where(p.locationCode == _filterLocationCode)
- Requires _needsFullData = true → loads all products (disables pagination)
```

### Integration Points
- **Inventory**: thumbnail in product cards + image+location in add/edit dialogs + location filter chip
- **Sales picker**: 40×40 thumbnail leading in product ListTile
- **Repair detail**: optional location picker dialog when marking XONG (status=3)
- **Order list**: location chip badge on repair cards

---

**Last Updated:** 2026-05-19  
**Version:** 1.0
