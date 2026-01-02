Nếu sau này muốn quay lại chế độ free hoặc quản lý tier thực tế, chỉ cần thay đổi lại code hoặc sử dụng SubscriptionService.setTier('free') trong app.



1. Kiến trúc tổng thể (Architecture Overview)
Mô hình kiến trúc:
Frontend: Flutter (Dart) với Material Design 3
Backend: Firebase (Auth, Firestore, Storage, Functions, Messaging)
Local Storage: SQLite với sqflite package
Sync Strategy: Offline-first với real-time bidirectional sync
Multi-tenancy: Shop-based isolation với shopId
Security: Role-based access control (RBAC) + super admin
Design Patterns:
Service Layer Pattern: Tất cả business logic trong services/
Repository Pattern: DBHelper wrapper cho SQLite
Observer Pattern: EventBus cho cross-component communication
Provider Pattern: State management thông qua setState và streams
Factory Pattern: Model serialization với fromMap()/toMap()
2. Entry Point và Bootstrap (lib/main.dart)
Khởi tạo ứng dụng:
AuthGate Component:
StreamBuilder cho Firebase Auth state changes
FutureBuilder cho role sync từ Firestore
Auto-logout nếu sync thất bại
Route to HomeView với role parameter
Theme Configuration:
Material 3 với custom color scheme
Vietnamese localization với flutter_localizations
Responsive input decorations và button styles
3. Authentication & Authorization System
UserService (lib/services/user_service.dart):
Super Admin Detection: Hardcoded email admin@huluca.com
Role Hierarchy: admin > owner > manager > employee > technician > user
ShopId Caching: _cachedShopId để tối ưu performance
Permission Matrix: 15+ granular permissions (allowViewSales, allowViewRepairs, etc.)
Permission System:
Shop-level Controls:
appLocked: Khóa toàn bộ app cho shop
adminFinanceLocked: Khóa finance views cho admin role
4. Data Models & Serialization (lib/models/)
Core Models:
Repair (repair_model.dart): 25 fields, status enum (1-4), image handling
Product (product_model.dart): 20 fields, inventory tracking, copyWith pattern
SaleOrder (sale_order_model.dart): Complex sale with installment support
PurchaseOrder (purchase_order_model.dart): Supplier import management
Attendance (attendance_model.dart): Time tracking with photos
Debt (debt_model.dart): Debt management với payments
Expense (expense_model.dart): Cost tracking
QuickInputCode (quick_input_code_model.dart): Barcode/product templates
Serialization Pattern:
5. Local Database Layer (lib/data/db_helper.dart)
SQLite Schema (Version 33):
21 Tables với foreign keys và indexes
Upsert Pattern: INSERT OR REPLACE cho sync
Soft Deletes: deleted flag thay vì hard delete
Sync Flags: isSynced cho conflict resolution
Key Tables:
repairs: Core repair orders
products: Inventory management
sales: Sales transactions
attendance: Staff time tracking
debts: Debt management
expenses: Cost tracking
purchase_orders: Supplier imports
quick_input_codes: Product templates
repair_partners: External repair partners
Migration System:
6. Cloud Services & Sync Layer
FirestoreService (lib/services/firestore_service.dart):
ShopId Filtering: Tất cả queries filter theo shopId (trừ super admin)
CRUD Operations: addRepair, upsertRepair, deleteRepair (soft delete)
Notification Integration: Auto-notify trên changes
Validation: Input validation trước save
SyncService (lib/services/sync_service.dart):
Real-time Subscriptions: 10+ Firestore collections
Bidirectional Sync: Cloud → Local updates
Conflict Resolution: Firestore wins, local upsert
Shop Isolation: Dynamic shopId filtering
7. UI Architecture (lib/views/ & lib/widgets/)
Navigation Structure:
Bottom Navigation: 5 tabs (Dashboard, Repairs, Sales, Inventory, Settings)
Role-based Visibility: Permissions control tab access
Deep Linking: Direct routes cho specific views
HomeView (Main Dashboard):
Stats Cards: Pending repairs, today's sales, revenue, expenses
Charts: Revenue trends với fl_chart
Quick Actions: Create repair, sale, inventory check
Real-time Updates: Sync callbacks update UI
Key Views:
create_repair_order_view.dart: Complex form với validation
inventory_view.dart: Product management với search/filter
revenue_view.dart: Financial reports với charts
staff_list_view.dart: User management với permissions
super_admin_view.dart: Multi-shop management
Widgets (lib/widgets/):
notification_badge.dart: Unread count indicators
perpetual_calendar.dart: Date picker component
Custom form fields, dialogs, và reusable components
8. Business Services (lib/services/)
Core Services:
NotificationService: Push notifications + in-app snackbars
StorageService: Firebase Storage cho images
ConnectivityService: Network monitoring
AuditService: Activity logging
EventBus: Cross-component events
Specialized Services:
Printer Services: Bluetooth thermal printing (3 variants)
RepairPartnerService: External repair coordination
SyncControl: Advanced sync management
9. Configuration & Assets
pubspec.yaml Dependencies:
Firebase Ecosystem: core, auth, firestore, storage, messaging, functions
Local Storage: sqflite, shared_preferences
UI/UX: fl_chart, photo_view, qr_flutter
Hardware: mobile_scanner, flutter_blue_plus, print_bluetooth_thermal
Utilities: intl, csv, excel, file_picker
Assets Structure:
images: Icons, logos
fonts: Roboto font family
l10n: Vietnamese/English localization ARBs
Build Configuration:
Android: google-services.json, custom launcher icon
iOS: Firebase config, app icons
Web: Firebase hosting ready
10. Advanced Features
Offline-First Capabilities:
Full CRUD operations offline
Background sync khi online
Conflict resolution strategies
Local cache với TTL
Multi-tenant Architecture:
ShopId isolation ở tất cả layers
Super admin bypass
Invite system cho staff onboarding
Shop-level permissions
Real-time Collaboration:
Live updates across devices
Chat system integrated
Notification broadcasting
Audit trails
Hardware Integration:
QR code scanning
Bluetooth thermal printing
Camera cho photos
GPS cho attendance
Financial Management:
Revenue tracking
Expense categorization
Debt management với payments
Payroll calculation
Cash closing procedures
Inventory Management:
Product catalog với variants
Stock tracking
Supplier management
Purchase order workflow
Inventory audits
Dự án này thể hiện kiến trúc enterprise-grade với focus vào scalability, reliability, và user experience trong context Việt Nam market. Code quality cao với proper error handling, validation, và separation of concerns.