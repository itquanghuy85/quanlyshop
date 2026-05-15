# Coding Standards - HULUCA Shop Manager

Quy tắc coding, naming conventions, formatting, patterns, best practices.

---

## Language & Style

### Primary Language
- **Code/Comments:** English (MUST)
- **UI Text:** Vietnamese with diacritics (MUST)
- **Commit Messages:** Vietnamese with diacritics
- **Documentation:** Vietnamese with diacritics

### Code Style
- **Language:** Dart (following Dart style guide)
- **Formatter:** `dart format` (automatic)
- **Analyzer:** `flutter analyze` (zero tolerance for errors)
- **Linter:** Enable all recommended rules in `analysis_options.yaml`

---

## Naming Conventions

### Classes & Types
```dart
// ✓ PascalCase for classes
class RepairModel {}
class FirestoreService {}

// ✓ PascalCase for enums
enum RepairStatus { pending, inProgress, done, cancelled }

// ✓ PascalCase for typedefs
typedef OnRepairChanged = void Function(RepairModel);
```

### Variables & Constants
```dart
// ✓ camelCase for variables, parameters
String customerName;
int totalAmount;
void processRepair(String repairId) {}

// ✓ UPPER_SNAKE_CASE for constants
const String SUPER_ADMIN_EMAIL = 'admin@huluca.com';
const int MAX_RETRY_COUNT = 3;
const Duration SYNC_INTERVAL = Duration(seconds: 30);
```

### Methods & Functions
```dart
// ✓ camelCase for methods/functions
void addRepair(RepairModel repair) {}
Future<String?> uploadImage(File file) async {}
String formatCurrency(double amount) {}

// ✓ Prefix with `get` for getters that do work
Future<String> getShopId() async => await UserService.getCurrentShopId();

// ✓ Prefix with `set` for setters
void setUserRole(String uid, String role) {}

// ✓ Prefix with `_` for private methods
void _validateInput(String input) {}

// ✓ Boolean methods can start with `is`, `has`, `can`
bool isAdmin() => role == 'admin';
bool hasPermission(String permission) => permissions.contains(permission);
bool canDelete(RepairModel repair) => repair.createdBy == currentUser;
```

### Files & Directories
```dart
// ✓ snake_case for files
repair_model.dart
firestore_service.dart
create_repair_order_view.dart
user_service.dart

// ✓ Organize by feature/layer
lib/
├── services/          // Business logic
├── views/             // UI screens
├── widgets/           // Reusable components
├── models/            // Data models
├── data/              // Database, storage
└── utils/             // Utilities, helpers
```

---

## Code Organization

### File Structure
```dart
// 1. Imports (organized)
import 'package:flutter/material.dart';
import 'package:firebase_firestore/firebase_firestore.dart';

import '../models/repair_model.dart';
import '../services/user_service.dart';

// 2. Constants
const String COLLECTION_REPAIRS = 'repairs';
const int DEFAULT_PAGE_SIZE = 20;

// 3. Main class/function
class FirestoreService {
  // Static properties
  static final FirestoreService _instance = FirestoreService._();
  
  // Instance properties
  late final FirebaseFirestore _firestore;
  
  // Constructor
  FirestoreService._();
  
  // Factory/Getters
  factory FirestoreService.instance => _instance;
  
  // Lifecycle
  Future<void> initialize() async {}
  
  // Public methods (organized by feature)
  Future<String?> addRepair(RepairModel repair) async {}
  Future<bool> updateRepair(String repairId, RepairModel repair) async {}
  Future<bool> deleteRepair(String repairId) async {}
  
  // Private methods
  void _validateInput(RepairModel repair) {}
  Query _buildQuery(String shopId) {}
}
```

---

## Pattern Requirements

### 1. Service-First Access
```dart
// ✓ GOOD - All Firestore access via service
class RepairListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FirebaseStreamBuilder<List<RepairModel>>(
      stream: FirestoreService.getRepairs(),
      builder: (context, repairs) => ...
    );
  }
}

// ✗ BAD - Direct Firebase SDK in widget
class RepairListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('repairs').snapshots(),
      builder: (context, snapshot) => ...
    );
  }
}
```

### 2. Error Handling
```dart
// ✓ GOOD - Try/catch with logging
try {
  final repair = await FirestoreService.addRepair(repairModel);
  if (repair == null) throw Exception('Failed to create repair');
  return repair;
} catch (e, stackTrace) {
  debugPrint('Error adding repair: $e\n$stackTrace');
  rethrow;
}

// ✗ BAD - Silent failures
try {
  return await FirestoreService.addRepair(repairModel);
} catch (e) {
  return null; // No logging, hard to debug
}
```

### 3. Null Safety
```dart
// ✓ GOOD - Explicit nullability
String? getShopId() => _shopId;
Future<RepairModel?> getRepair(String id) async => ...

String getCurrentShopId() {
  final shopId = getShopId();
  if (shopId == null) throw Exception('No shop selected');
  return shopId;
}

// ✗ BAD - Implicit nullability
String getShopId() => _shopId; // Can return null!
```

### 4. Data Validation
```dart
// ✓ GOOD - Validate early
void addRepair(RepairModel repair) {
  if (!validatePhone(repair.customerPhone)) {
    throw Exception('Số điện thoại không hợp lệ');
  }
  if (repair.description.isEmpty) {
    throw Exception('Mô tả không được trống');
  }
  // Process...
}

// ✗ BAD - Process first, validate later
void addRepair(RepairModel repair) {
  // Process...
  if (!validatePhone(repair.customerPhone)) {
    throw Exception('Số điện thoại không hợp lệ');
  }
}
```

### 5. Async Operations
```dart
// ✓ GOOD - Proper async/await
Future<void> syncData() async {
  try {
    final repairs = await FirestoreService.getRepairs();
    await DBHelper().upsertRepairs(repairs);
  } catch (e) {
    debugPrint('Sync error: $e');
  }
}

// ✗ BAD - Mixing callbacks
void syncData() {
  FirestoreService.getRepairs().then((repairs) {
    DBHelper().upsertRepairs(repairs).then((_) {
      // Nested callbacks are hard to read
    });
  }).catchError((e) {
    // Error handling is scattered
  });
}
```

### 6. Constants & Configuration
```dart
// ✓ GOOD - Centralized constants
class Config {
  static const String SUPER_ADMIN_EMAIL = 'admin@huluca.com';
  static const int MAX_RETRIES = 3;
  static const Duration SYNC_INTERVAL = Duration(seconds: 30);
  
  static const Map<String, String> ROLE_PERMISSIONS = {
    'admin': 'all',
    'manager': 'shop',
    'staff': 'limited',
  };
}

// ✗ BAD - Magic numbers/strings scattered in code
if (userEmail == 'admin@huluca.com') { } // Magic string
const int timeout = 3; // Unclear what this means
```

---

## Widget Guidelines

### State Management
```dart
// ✓ Use proper state management
class RepairListView extends StatefulWidget {
  @override
  State<RepairListView> createState() => _RepairListViewState();
}

class _RepairListViewState extends State<RepairListView> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RepairModel>>(
      stream: FirestoreService.getRepairs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorWidget(error: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return LoadingWidget();
        }
        return RepairList(repairs: snapshot.data!);
      },
    );
  }
}
```

### Widget Decomposition
```dart
// ✓ GOOD - Break into smaller widgets
class RepairListView extends StatefulWidget {
  @override
  State<RepairListView> createState() => _RepairListViewState();
}

class _RepairListViewState extends State<RepairListView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(),
        _SearchBar(),
        _RepairList(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('Repairs');
  }
}

// ✗ BAD - One huge widget
class RepairListView extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 200 lines of code...
      ],
    );
  }
}
```

---

## Documentation Requirements

### Comments
```dart
// ✓ Document why, not what
/// Lấy shopId từ cache hoặc Firestore.
/// 
/// Nếu không có cache, gọi [UserService.syncUserInfo] để tải.
/// 
/// Returns: shopId hoặc null nếu chưa auth
Future<String?> getCurrentShopId() async {
  return _shopId ?? await syncUserInfo();
}

// ✗ BAD - State the obvious
String? shopId; // This is the shopId
void setShopId(String id) { // Set the shopId
  shopId = id;
}
```

### Class Documentation
```dart
/// Service quản lý tất cả tương tác Firestore.
/// 
/// Đảm bảo:
/// - Tất cả queries được filter theo shopId (trừ super-admin)
/// - Soft deletes luôn được kiểm tra
/// - Real-time subscriptions được cleanup
/// 
/// Ví dụ:
/// ```dart
/// final repairs = await FirestoreService.getRepairs();
/// ```
class FirestoreService {
  // ...
}
```

---

## Testing Requirements

### Unit Tests
```dart
void main() {
  group('RepairModel', () {
    test('fromMap creates correct instance', () {
      final data = {
        'id': 'repair-1',
        'customerName': 'John',
        'status': 1,
      };
      
      final repair = RepairModel.fromMap(data);
      
      expect(repair.id, 'repair-1');
      expect(repair.customerName, 'John');
      expect(repair.status, RepairStatus.pending);
    });
  });
}
```

### Widget Tests
```dart
void main() {
  testWidgets('RepairListView displays repairs', (tester) async {
    await tester.pumpWidget(TestApp());
    
    expect(find.text('Repairs'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}
```

---

## Performance Guidelines

### Optimization Rules
1. **Lazy loading** - Load data only when needed
2. **Pagination** - Use page sizes (e.g., 20 items)
3. **Caching** - Cache frequently accessed data
4. **Debouncing** - Debounce user input (search, filters)
5. **Throttling** - Throttle frequent operations
6. **Assets** - Optimize images, use SVG where possible
7. **Queries** - Add Firestore indexes, avoid N+1

### Example: Lazy Loading
```dart
class RepairListView extends StatefulWidget {
  @override
  State<RepairListView> createState() => _RepairListViewState();
}

class _RepairListViewState extends State<RepairListView> {
  final _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Load more when at bottom
      context.read<RepairProvider>().loadMore();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemBuilder: (context, index) => RepairTile(index: index),
    );
  }
}
```

---

## Security Guidelines

### Data Protection
```dart
// ✓ GOOD - Always check shopId
Future<List<RepairModel>> getRepairs(String shopId) async {
  // Validate shopId belongs to current user
  final currentShopId = await UserService.getCurrentShopId();
  if (shopId != currentShopId && !await UserService.isSuperAdmin()) {
    throw Exception('Unauthorized access');
  }
  
  return await _firestore
      .collection('shops')
      .doc(shopId)
      .collection('repairs')
      .where('deleted', isNotEqualTo: true)
      .get();
}

// ✗ BAD - No shopId validation
Future<List<RepairModel>> getRepairs(String shopId) async {
  return await _firestore
      .collection('shops')
      .doc(shopId)
      .collection('repairs')
      .get();
}
```

---

## Formatting & Spacing

### Line Length
- Maximum 100 characters per line
- Break long lines into multiple lines

### Spacing
```dart
// ✓ GOOD
class MyClass {
  String name;
  int age;
  
  MyClass(this.name, this.age);
  
  void doSomething() {
    // Implementation
  }
  
  void doAnotherThing() {
    // Implementation
  }
}

// ✗ BAD - No spacing between methods
class MyClass {
  String name;
  int age;
  MyClass(this.name, this.age);
  void doSomething() {
    // Implementation
  }
  void doAnotherThing() {
    // Implementation
  }
}
```

---

## Tools & Validation

### Before Committing
```bash
# Format code
dart format lib/

# Run analyzer
flutter analyze

# Run tests
flutter test

# Check build
flutter build apk --release
```

### Pre-commit Hooks (Recommended)
```bash
# .git/hooks/pre-commit
#!/bin/bash
flutter analyze
flutter test
```

---

## References

- **Dart Style Guide:** https://dart.dev/guides/language/effective-dart/style
- **Flutter Best Practices:** https://flutter.dev/docs/testing/best-practices
- **Effective Dart:** https://dart.dev/guides/language/effective-dart

---

**Last Updated:** 2026-05-15  
**Version:** 1.0
