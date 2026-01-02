# Báo Cáo Chi Tiết Dự Án Quản Lý Cửa Hàng Sửa Chữa Điện Thoại

## Tổng Quan Dự Án

Dự án này là một ứng dụng Flutter quản lý cửa hàng sửa chữa điện thoại, sử dụng Firebase cho backend và SQLite cho local storage. Ứng dụng hỗ trợ đa ngôn ngữ (Việt/Anh), theme sáng/tối, và có tính năng đồng bộ real-time.

**Công nghệ chính:**
- Frontend: Flutter (Dart)
- Backend: Firebase (Firestore, Auth, Messaging, Storage)
- Local DB: SQLite (sqflite)
- State Management: StatefulWidget + EventBus
- Networking: HTTP requests cho Firebase
- UI: Material Design với custom widgets

**Cấu trúc thư mục chính:**
- `lib/main.dart`: Entry point, khởi tạo Firebase, theme, auth gate
- `lib/models/`: Các model data (Repair, Debt, Expense, etc.)
- `lib/services/`: Business logic (FirestoreService, UserService, SyncService, etc.)
- `lib/views/`: UI screens (HomeView, OrderListView, DebtView, etc.)
- `lib/data/db_helper.dart`: SQLite database operations
- `lib/widgets/`: Reusable UI components
- `lib/utils/`: Utilities (ResponsiveLayout, etc.)
- `lib/controllers/`: Business logic controllers
- `lib/l10n/`: Localization files
- `lib/assets/`: Static assets (images, fonts)

## Chi Tiết Models

### Repair Model (`lib/models/repair_model.dart`)
Mô tả đơn sửa chữa điện thoại.

**Thuộc tính chính:**
- `id`: ID local SQLite
- `firestoreId`: ID trên Firestore
- `customerName`, `phone`: Thông tin khách
- `model`, `issue`: Mô tả máy và lỗi
- `status`: 1 (Nhận), 2 (Sửa), 3 (Xong), 4 (Giao)
- `price`, `cost`: Giá bán và chi phí
- `paymentMethod`: Phương thức thanh toán
- `createdAt`, `startedAt`, `finishedAt`, `deliveredAt`: Timestamps
- `createdBy`, `repairedBy`, `deliveredBy`: Người thực hiện
- `imagePath`, `deliveredImage`: Ảnh nhận/giao máy
- `warranty`, `partsUsed`: Bảo hành và linh kiện
- `isSynced`, `deleted`: Trạng thái đồng bộ và xóa mềm

**Hàm chính:**
- `toMap()`: Chuyển sang Map cho DB
- `fromMap(Map)`: Factory từ Map
- `receiveImages`, `deliverImages`: Getter cho list ảnh

### Debt Model (`lib/models/debt_model.dart`)
Mô tả công nợ (khách nợ shop hoặc shop nợ NCC).

**Thuộc tính chính:**
- `personName`, `phone`: Người nợ
- `totalAmount`, `paidAmount`: Tổng nợ và đã trả
- `type`: 'OWE' (shop nợ), 'OWED' (khách nợ)
- `status`: 'ACTIVE', 'PAID', 'CANCELLED'
- `linkedId`: Liên kết đến đơn hàng
- `note`: Ghi chú

**Hàm chính:**
- `toMap()`, `fromMap()`: Serialization
- `toFirestore()`, `fromFirestore()`: Cho Firestore

### Expense Model (`lib/models/expense_model.dart`)
Mô tả chi phí của shop.

**Thuộc tính chính:**
- `title`: Tên chi phí
- `amount`: Số tiền
- `category`: Loại (CỐ ĐỊNH, PHÁT SINH, etc.)
- `date`: Ngày chi
- `paymentMethod`: Thanh toán bằng gì

**Hàm chính:**
- `toMap()`, `fromMap()`: Serialization

## Chi Tiết Services

### FirestoreService (`lib/services/firestore_service.dart`)
Xử lý tất cả operations với Firestore.

**Hàm chính:**
- `addRepair(Repair)`: Thêm đơn sửa
- `updateRepair(Repair)`: Cập nhật đơn sửa
- `addDebtCloud(Map)`: Thêm nợ lên cloud
- `addExpenseCloud(Map)`: Thêm chi phí lên cloud
- `syncAllToCloud()`: Đồng bộ tất cả data lên cloud
- `downloadAllFromCloud()`: Tải data từ cloud

**Logic:**
- Mỗi operation thêm `shopId` từ `UserService.getCurrentShopId()`
- Sử dụng `SetOptions(merge: true)` để upsert
- Gửi notification khi có thay đổi

### UserService (`lib/services/user_service.dart`)
Quản lý user và permissions.

**Hàm chính:**
- `getCurrentUserPermissions()`: Lấy quyền của user hiện tại
- `getCurrentShopId()`: Lấy shop ID
- `syncUserInfo(uid, email)`: Đồng bộ info user từ Firestore
- `getUserRole(uid)`: Lấy role (admin, user, etc.)

**Logic:**
- Super admin hardcoded bằng email `admin@huluca.com`
- Permissions: allowViewExpenses, allowEditInventory, etc.

### SyncService (`lib/services/sync_service.dart`)
Đồng bộ real-time giữa local và cloud.

**Hàm chính:**
- `initRealTimeSync(callback)`: Khởi tạo sync với callback khi có thay đổi
- `syncAllToCloud()`: Push local changes lên cloud
- `downloadAllFromCloud()`: Pull cloud changes về local

**Logic:**
- Sử dụng Firestore listeners cho real-time
- Conflict resolution: Cloud wins
- Soft deletes: Set `deleted: true` trên Firestore

### NotificationService (`lib/services/notification_service.dart`)
Xử lý push notifications và in-app notifications.

**Hàm chính:**
- `init()`: Khởi tạo Firebase Messaging
- `showSnackBar(message)`: Hiển thị snackbar
- `sendCloudNotification(title, body)`: Gửi notification lên cloud

## Chi Tiết Views

### HomeView (`lib/views/home_view.dart`)
Màn hình chính với bottom navigation tabs.

**Tabs chính:**
- Sửa chữa: OrderListView
- Bán hàng: SaleListView
- Kho: InventoryView
- Báo cáo: RevenueView
- Chi phí: ExpenseView
- Công nợ: DebtView
- Cài đặt: SettingsView

**Logic:**
- Load stats: totalPendingRepair, revenueToday, totalDebtRemain, etc.
- Auto sync mỗi 60s
- Permissions-based tabs

### OrderListView (`lib/views/order_list_view.dart`)
Danh sách đơn sửa chữa.

**Components:**
- `RepairListItem`: Item cho mỗi đơn
  - Ảnh máy bên trái
  - Info bên phải: model, issue, status, price
  - Swipe delete (admin only)

**Logic:**
- Load từ DB: `db.getAllRepairs()`
- Filter theo status, search phone
- Delete: Confirm dialog, set `deleted: true`, sync cloud

### DebtView (`lib/views/debt_view.dart`)
Quản lý công nợ với 3 tabs: Khách nợ, Shop nợ NCC, Công nợ khác.

**Logic:**
- Load debts: `db.getAllDebts()`
- Totals: Fold để tính tổng nợ còn lại
- Payment: Dialog nhập số tiền, tạo `debt_payments` record, update `paidAmount`
- Status: ACTIVE/PAID dựa trên remain > 0

### ExpenseView (`lib/views/expense_view.dart`)
Quản lý chi phí với filter ngày/tuần/tháng.

**Logic:**
- Load expenses: `db.getAllExpenses()`
- Load purchase debts: `db.getPurchaseDebts()` (convert to expense-like)
- Totals: Fold `amount`
- Add: Parse amount từ text (remove dots, *1000 if <100000)
- Delete: Require password reauth

## Chi Tiết Database (DBHelper)

### Tables Chính
- `repairs`: Đơn sửa chữa
- `products`: Sản phẩm trong kho
- `sales`: Đơn bán hàng
- `expenses`: Chi phí
- `debts`: Công nợ
- `debt_payments`: Lịch sử trả nợ
- `purchase_orders`: Đơn nhập hàng
- `attendance`: Chấm công
- `audit_logs`: Nhật ký hoạt động

### Hàm Chính
- `insertRepair(Repair)`: Thêm đơn sửa
- `getAllRepairs()`: Lấy tất cả đơn sửa
- `updateDebtPaid(id, pay)`: Cập nhật paidAmount cho debt
- `getAllDebts()`: Lấy tất cả debts
- `getAllExpenses()`: Lấy tất cả expenses
- `getPurchaseDebts()`: Lấy debts từ purchase orders

**Logic:**
- Upsert patterns: Insert if not exists, update if exists
- Soft deletes: Set `deleted = 1`
- Sync flags: `isSynced` để track cloud sync

## Chi Tiết Widgets

### ThousandCurrencyTextField (`lib/widgets/thousand_currency_text_field.dart`)
TextField cho nhập tiền VND với format 1.000.000.

**Logic:**
- Format on change: Add dots every 3 digits
- Parse: Remove dots, convert to int
- Validation: Required, min/max

### NotificationBadge (`lib/widgets/notification_badge.dart`)
Badge cho unread notifications.

**Logic:**
- Show count nếu >0
- Positioned trên icon

## Chi Tiết Utils

### ResponsiveLayout (`lib/utils/responsive_layout.dart`)
Layout responsive cho mobile/tablet.

**Logic:**
- Detect screen size
- Adjust padding, font sizes

## Kết Luận

Dự án này là một hệ thống quản lý cửa hàng sửa chữa điện thoại toàn diện với:
- CRUD cho repairs, sales, inventory, expenses, debts
- Real-time sync với Firebase
- Offline-first với SQLite
- Multi-tenant với shopId
- Permissions và roles
- Notifications và audit logs

Code được tổ chức tốt với separation of concerns: Models cho data, Services cho logic, Views cho UI, DBHelper cho persistence.