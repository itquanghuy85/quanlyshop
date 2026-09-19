# FULL TEST PLAN — HULUCA Shop Manager (sinh từ code thật, 2026-09-19)

> Vai trò: QA Lead + Senior Flutter Engineer + DB/Offline-Sync Auditor.
> Nguồn: quét trực tiếp `lib/` (136 file view, 109 service, 45 model), `lib/data/db_helper.dart` (13.807 dòng, SQLite v111),
> `firestore.rules` (1.577 dòng), `functions/index.js` (21 export), `lib/services/sync_*`.
> Không dựa vào lời kể; mọi số liệu dưới đây có lệnh/đường dẫn kiểm chứng.
> Kết quả chạy test: xem `docs/FULL_TEST_REPORT_2026-09-19.md`.

---

## 1. PROJECT OVERVIEW

| Mục | Giá trị (đo từ code) |
|---|---|
| Stack | Flutter 3.41.4 · Firebase (Auth, Firestore, Storage, Functions, FCM, App Check) · SQLite `repair_shop_v22.db` v111 |
| Miền | Cửa hàng sửa điện thoại — 1 loại hình duy nhất |
| Firebase project | `huyaka-1809` (`firebase.json`) |
| Android appId | `com.huluca.shopmanager` — máy test CPH2203 đang cài 3.7.0 |
| Nền tảng có thư mục | android, ios, web, windows, macos, linux (desktop KHÔNG có sqflite FFI trong `main.dart` ⇒ chỉ Android/iOS chạy thật) |
| View files | 136 (127 file có `Scaffold` = màn hình thật; 5 widget có Scaffold: permission_gate, responsive_wrapper, loading_intro_screen, image_picker_widget, app_state_widgets) |
| Service files | 109 (+`history/history_service.dart`) |
| Model files | 45 |
| SQLite table | 45 distinct (`CREATE TABLE` 78 lần vì có lặp trong `onCreate` + `onUpgrade`) |
| Migration | 93 khối `if (oldV < N)` từ v18 → v111 (thiếu khối 38 — nhảy 37→39) |
| Firestore collection dùng trong code | 57 tên (xem §5) |
| Firestore rules `match` | 60 block |
| Cloud Functions | 21 export |
| Storage rules | **`firebase.json` trỏ `storage.rules` nhưng FILE KHÔNG TỒN TẠI** (→ FINDING-INFRA-01) |
| EventBus events | 33 tên (`grep emit('…')`) |
| Test tự động sẵn có | 78 file trong `test/` + 2 file `integration_test/` |

---

## 2. ARCHITECTURE MAP

```
UI (lib/views, lib/finance_v2, lib/widgets)
  │  gọi
  ▼
Services (lib/services)  ──── PaymentIntentService = HUB TIỀN (mọi thu/chi/thu nợ/trả NCC)
  │                       ──── SyncOrchestrator = hàng đợi sync_queue (SQLite) → Firestore
  │                       ──── SyncService = listener/poll cloud → SQLite → EventBus
  │                       ──── AppSession = online | offline | none (gate mọi đường ra Firebase)
  ▼
DBHelper (lib/data/db_helper.dart, singleton, 45 bảng, upsert theo firestoreId)
  ▼
SQLite (nguồn sự thật cho UI) ◄──── Firestore root collections có field shopId (KHÔNG phải /shops/{id}/sub)
```

### 2.1 State management thực tế
- **Không** dùng Provider/Bloc/Riverpod. Kiểm chứng: `pubspec.yaml` không có `provider`/`flutter_bloc`/`riverpod`.
- State = `StatefulWidget` + `setState` + `EventBus` (`lib/services/event_bus.dart`, singleton `Stream`) + một số `ValueNotifier`/`ChangeNotifier` cục bộ (`SyncOrchestrator` status stream, `FinanceV2Cache`).
- `SafeStreamBuilder` (widget) bọc `snapshots()`.

### 2.2 Phiên (AppSession)
| mode | Điều kiện | Firebase |
|---|---|---|
| online | có `FirebaseAuth.currentUser`, không claim | `syncEnabled = true` |
| offline | không user, có `offlineShopId` (chỉ mobile) | mọi write Firestore bị gate; SQLite id client; `isSynced=0` |
| none | Welcome | — |
| claimInProgress | đang nối tài khoản | chỉ `ClaimService` được gọi Firestore |

### 2.3 Luồng ghi (write path) quan trọng — đọc từ code
| Thao tác UI | File | Ghi vào (SQLite) | Ghi cloud | Ghi chú rủi ro |
|---|---|---|---|---|
| Tạo đơn bán | `create_sale_view._processSale` | `sales`, `products`(qty/status), `debts`(nếu nợ), `payment_intents`, `expenses`?(không), `customers`(stats), `financial_activity_log`, `audit_logs` | `FirestoreService.executeSaleTransaction` = **runTransaction** đọc N products → update products → set sales → set debts | Online session + KHÔNG mạng: `ClaimsService.refreshMyClaims()` (callable) + `runTransaction` **không có timeout**, không kiểm connectivity → nghi treo spinner (TC-SALE-30) |
| Trả hàng | `SalesReturnService.processReturn` | `sales_returns`, `sales_return_items`, `products`(+qty), `debts`(giảm total), `financial_activity_log`, `audit_logs` | `debts.update` **trực tiếp** `_firestore.collection('debts').doc().update` (gate syncEnabled) | ghi Firestore trực tiếp từ service, không qua orchestrator; hoàn tiền không đi qua PaymentIntentService? (kiểm TC-SALE-20) |
| Nhập kho nhanh | `fast_stock_in_view` → `StockEntryService.createEntry` | `products`(upsert), `import_orders`+`import_order_items` (`ImportOrderService.createFromStockEntry`), `expenses`(trả ngay) hoặc `debts`(CÔNG NỢ, `createDebtRecord`), `supplier_import_history`, `supplier_product_prices`, `suppliers`(stats), `financial_activity_log` | `stock_entries` doc **bất biến** (runTransaction) rồi products | Offline: `OfflineStockEntryStore` (prefs JSON) vì `stock_entries` không có bảng SQLite |
| Tạo đơn sửa | `create_repair_order_view` | `repairs`, `customers`, `payment_intents`(cọc), `debts`(nếu) | `FirestoreService.addRepair` + guard `applyRepairCloudGuards` | notification "ĐƠN MỚI" căn cứ doc cloud |
| Cập nhật đơn sửa | `repair_detail_view` (7.894 dòng, 11× `upsertRepair`) | `repairs`, `repair_parts`, `products`(trừ linh kiện), `payment_intents`, `debts`, `partner_repair_history`, `repair_partner_payments`, `financial_activity_log`, `audit_logs`, history corrections | `upsertRepairPatchByFirestoreId` (merge) | Race 2 máy cùng sửa — guard `_normalizeRepairStatus` trả 1 khi thiếu |
| Thu nợ khách | `debt_payment_sheet`, `CustomerDebtPaymentService`, `BulkDebtPaymentService`, `collect_customer_debt_view` | `payment_intents`, `debt_payments`, `debts.paidAmount/status`, `expenses`(THU) , `financial_activity_log` | qua orchestrator (`enqueueDebtPayment`) | idempotencyKey = `<debtFid>_<ts>` (đã fix cắt cụt 2026-09-18) |
| Trả NCC | `AdjustmentService.paySupplierDebt`, `supplier_detail_view`, `import_order_detail_view` | `supplier_payments`, `debts`, `payment_intents`, `import_orders.paidAmount` | orchestrator | `SupplierPaymentService` (file) = **MỒ CÔI** ghi vào root `supplier_payments` — dead code |
| Chi phí | `expense_view` | `expenses`, `payment_intents` | orchestrator | 2 đường (934, 1662) đều có key |
| Chốt quỹ | `cash_closing_view` (5.638 dòng) | `cash_closings` | orchestrator | Sổ quỹ cố ý cộng gộp ngày chưa chốt |
| Đối soát tiền về | `MoneyReconcileService.apply` | như thu nợ + `sales.settlement*` | — | sao chép logic 2 luồng gốc — phải giữ đồng bộ |
| Xác máy | `salvage_phone_view` | `salvage_phones`, `expenses` (KHÔNG qua PaymentIntentService, `isSynced: true` cứng) | `FirestoreService.addExpenseCloud` trực tiếp | không idempotent, không qua hub tiền |
| Điều chỉnh dữ liệu | `AdjustmentService` | `adjustment_entries`, `debts`, `payment_intents` | orchestrator | chỉ khi ngày đã chốt quỹ |

---

## 3. FEATURE MAP (Module → Màn hình → Chức năng → File → Service → Bảng → Collection → Quan hệ → Mức độ)

Ký hiệu mức độ: **C** = Critical (tiền/kho/nợ/sync), **H** = High, **M** = Medium, **L** = Low.
Ký hiệu trạng thái: ✅ có menu · 🔒 chỉ code (không menu) · 💀 mồ côi (không file nào import).

### M01 — AUTH / SESSION / SHOP
| Màn hình | File | Chức năng | Service | Bảng | Collection | Mức |
|---|---|---|---|---|---|---|
| Splash | `splash_view.dart` | bootstrap, version gate | `main.dart` AuthGate, `version_gate_wrapper` | — | `app_config` | H |
| Welcome | `welcome_view.dart` | chọn Đăng nhập / Dùng ngay không tài khoản | `AppSession` | — | — | H |
| Intro | `intro_view.dart` | onboarding | — | — | — | L |
| Login | `login_view.dart` | email/mật khẩu, Google/Apple (`SocialAuthService`) | `UserService.syncUserInfo` | — | `users`, `shops` | C |
| Register | `register_view.dart` | tạo tài khoản + shop (ghi Firestore trực tiếp 1 chỗ) | `UserService` | — | `users`,`shops` | H |
| Claim account | `claim_account_view.dart` | nối dữ liệu offline lên cloud | `ClaimService` (duy nhất gọi Firestore khi claimInProgress) | tất cả bảng (re-tag shopId khi shop cloud rỗng) | mọi collection | C |
| Sync & Tài khoản | `sync_account_view.dart` | trạng thái đồng bộ, đăng xuất | `SessionLogoutService`, `SyncOrchestrator` | `sync_queue` | — | H |
| Shop selector | `shop_selector_view.dart` | super admin chọn shop | `UserService._adminSelectedShopId`, `CurrentShopService` | — | `shops` | H |
| Shop migration | `shop_migration_view.dart` | chuyển dữ liệu shop | `DataMigrationService` | — | nhiều | H |
| My profile 💀 | `my_profile_view.dart` | — | — | — | — | L |
| Super admin console ✅ / Super admin view 💀 | `super_admin_console_view.dart` (10× Firestore trực tiếp), `super_admin_view.dart` | quản shop/user/broadcast | `SuperAdminSecurityService`, `ShopDeletionService` | — | `shops`,`users`,`admin_security`,`admin_audit_log`,`broadcasts` | C |
Quan hệ: shopId từ `UserService.getShopIdSync()` là khoá lọc của MỌI module.

### M02 — HOME / DASHBOARD
| Màn hình | File | Chức năng | Service | Bảng |
|---|---|---|---|---|
| Home (7 tab động: Trang chủ, Bán hàng, Sửa chữa, Kho, Nhân viên, Tài chính, Cài đặt) | `home_view.dart` (8.815 dòng) | 15 loại thẻ (`DashboardCardType`: greeting, actionRequired, quickActions, todayActivity, financeSummary, financeDetail, activityFeed, chat, alerts, userGuide, financeShortcuts, discovery, tipOfDay, community, dailyReport) + 32 lối tắt (`ShortcutType`) | `DashboardConfigService`, `ReminderService`, `RecentActivityService`, `DiscoveryService`, `FirstTimeGuideService` | đọc hầu hết bảng |
| Dashboard settings | `dashboard_settings_view.dart` | ẩn/hiện/kéo thả thẻ & lối tắt | `DashboardConfigService` (prefs) | — |
| Nhắc nhở | `reminders_view.dart` | CẦN XỬ LÝ: đơn quá hạn, nợ, hàng chờ, BH… | `ReminderService` | repairs, debts, products, … |
| Global search | `global_search_view.dart` | tìm xuyên module | `DBHelper.search*` | repairs, sales, customers, products |
| Recent activity | `recent_activity_view.dart` | | `RecentActivityService` | financial_activity_log, audit_logs |
| Notifications | `notifications_view.dart`, `notification_settings_view.dart` | FCM + local, rate-limit 3/10s | `NotificationService` | — / `shop_notifications`, `notifications` |
| Feature catalog ✅(1 import) | `feature_catalog_view.dart` | danh mục tính năng | `app_knowledge_base` | — |
| Help center / User guide / About / Other apps | `help_center_view`, `user_guide_view`, `about_developer_view`, `other_apps_view` (snapshots trực tiếp) | | `HelpCenterRepository`, `UserGuideRepository` | `other_apps` |

### M03 — SỬA CHỮA (C)
| Màn hình | File | Chức năng |
|---|---|---|
| Danh sách đơn | `order_list_view.dart` | SQLite-only, sort `_compareRepairs`, `_isOverdue` UI-computed, search `DBHelper.searchRepairs` cap 5000 |
| Tạo đơn | `create_repair_order_view.dart` (2.728) | KH (autocomplete + `addCustomer`), model/IMEI, lỗi, giá, cọc (`executePaymentDirect` key), nợ (`createDebtRecord`), KTV, ảnh (`LocalImageStore`/`BackgroundUploadService`), AI nhập giọng nói (`AiRepairInputSheet`, `createRepairOrderAI` CF) |
| Chi tiết đơn | `repair_detail_view.dart` (7.894) | trạng thái 1 Tiếp nhận → 2 Đang sửa → 3 Sửa xong (+`pendingDeliveryApproval` = "Chờ duyệt giao") → 4 Đã giao; đổi KTV; linh kiện (`repair_parts`, trừ `products`); dịch vụ đối tác (`partner_repair_history`, `repair_partner_payments`); giá vốn/lãi; thanh toán khi giao (mặt/CK/nợ/trả góp NH); sửa thông tin KH; xoá đơn (mật khẩu `OwnerReauthService`); in biên nhận/hoá đơn |
| Bảo hành | `warranty_view.dart` | list đơn còn BH, tạo đơn BH (0 đồng? — kiểm `warrantyNote`, test `warranty_note_test`) |
| Biên nhận / hoá đơn / mẫu | `repair_receipt_view.dart` 💀, `repair_invoice_preview_view.dart`, `repair_invoice_template_view.dart`, `invoice_template_view.dart` 💀 | in nhiệt/bluetooth/wifi/PDF |
| Lịch sử sửa tương tự | `similar_repair_history_view.dart` | |
| Xác máy | `salvage_phone_view.dart` | mua xác, ghi chi TIỀN MẶT (không qua hub tiền) |
Bảng: `repairs`, `repair_parts`, `partner_repair_history`, `repair_partners`, `repair_partner_payments`, `salvage_phones`, `customers`, `debts`, `payment_intents`, `products`. Collection: cùng tên. Rules: `status 1..4`, `optNumGte0(price,cost)`, `shopIdLocked`.

### M04 — BÁN HÀNG (C)
| Màn hình | File | Chức năng |
|---|---|---|
| Tab Bán hàng | `home_view._buildSalesTab()` (KHÔNG phải `sale_list_view`) | list + FAB |
| Sale list (route phụ) | `sale_list_view.dart` (1 import) | |
| Tạo đơn | `create_sale_view.dart` (4.115) | nhiều SP (điện thoại IMEI `status 0/1` + linh kiện `quantity`), tặng/giảm dòng/giảm đơn/sửa giá, giá tham khảo (`PricingEngineService`), thanh toán TIỀN MẶT / CHUYỂN KHOẢN / KẾT HỢP (`ket_hop_cash_split_test`) / CÔNG NỢ (+trả trước) / TRẢ GÓP (NH) (cọc + tất toán), QR VietQR, transaction cloud |
| Chi tiết | `sale_detail_view.dart` (2.740) | sửa, xoá (hoàn kho, xoá debt/intents), tất toán NH (`settlementReceivedAt`), in |
| Trả hàng | `create_sales_return_view.dart`, `sales_return_list_view.dart`, `SalesReturnService` | hoàn kho, giảm nợ, hoàn tiền |
| Tất toán NH | `pending_bank_settlement_view.dart` (list), `bank_installment_report_view.dart` (thống kê) | |
| Hoá đơn | `sale_invoice_preview_view`, `sale_invoice_template_view` | |
Bảng: `sales`, `sales_returns`, `sales_return_items`, `products`, `debts`, `payment_intents`, `customers`, `financial_activity_log`.

### M05 — KHO (C)
| Màn hình | File | Chức năng |
|---|---|---|
| Kho | `inventory_view.dart`, `inventory_detail_view.dart` | list/lọc/sort/tìm, IMEI, vị trí kho, sửa SP, xoá mềm |
| Nhập nhanh | `fast_stock_in_view.dart` (2.348) | NCC (bắt buộc theo setting), nhiều dòng, giá vốn, thanh toán ngay/CÔNG NỢ/một phần, `StockEntryService` |
| Nhập thông minh | `smart_stock_in_view.dart` (2.415) | AI/Excel nhận diện |
| Nhập nhanh tồn kho | `fast_inventory_input_view.dart` + `FastInventoryInputController` | |
| Hàng chờ xác nhận | `pending_stock_list_view.dart` | phiếu nhập chờ (`stock_entries` status) |
| Kiểm kho | `fast_inventory_check_view.dart`, `inventory_check_history_view.dart` | `inventory_checks` |
| Vị trí kho | `storage_location_view.dart` | `storage_locations` |
| Kho phụ tùng | `parts_inventory_view.dart` (1 Firestore trực tiếp) | linh kiện, menu nhập giá từ HĐ NCC |
| Đơn nhập hàng | `purchase_order_list_view`, `create_purchase_order_view` | `purchase_orders` (thanh toán có key) |
| Lịch sử nhập | `import_history_view`, `import_order_detail_view` | `import_orders`, `import_order_items`, trả nợ NCC theo phiếu |
| SP thiếu thông tin | `missing_info_products_view.dart` | |
| In tem/QR | `imei_qr_printer_view`, `label_designer_view`, `label_settings_view`, `pty_print_designer_view` | `LabelSettingsService` |
| QR scan | `qr_scan_view.dart` | `qr_router_test` |
| KiotViet | `kiotviet_settings_view`, `kiotviet_import_view` | `KiotVietService`, `KiotVietExcelImportService`, `KvDuplicateCleanupService` |
Bảng: `products`, `product_categories`, `product_variants`(💀 schema còn, tính năng đã gỡ), `storage_locations`, `inventory_checks`, `import_orders`, `import_order_items`, `purchase_orders`, `supplier_import_history`, `supplier_product_prices`, `price_catalog_items`, `quick_input_codes`. Collection thêm: `stock_entries` (không có bảng SQLite).

### M06 — KHÁCH HÀNG (H)
`customer_management_view`, `customer_profile_view`, `customer_history_view`, `customer_debt_view`, `collect_customer_debt_view` · `CustomerService` (`addCustomer` fallback tên=SĐT do rules `name` ≥1) · bảng `customers` (`customers_new` tạm migration) · stats `totalSpent/repairCount` cập nhật từ sale/repair.

### M07 — NHÀ CUNG CẤP (H)
`supplier_list_view`, `supplier_form_view`, `supplier_detail_view` (trả nợ, lịch sử), `supplier_invoice_price_import_view` (1 import từ parts_inventory: Excel + AI) · `SupplierService`, `SupplierInvoiceService`, `SupplierInvoicePriceBookService`, `PriceCatalogService` · bảng `suppliers`, `supplier_payments`, `supplier_import_history`, `supplier_product_prices`, `price_catalog_items`, `debts`(SHOP_OWES) · 💀 `SupplierPaymentService`.

### M08 — ĐỐI TÁC SỬA CHỮA (H)
`repair_partner_view`, `repair_partner_form_view`, `repair_partner_detail_view`, 💀 `partner_management_view` · `RepairPartnerService`, `RepairPartnerPaymentService` · bảng `repair_partners`, `partner_repair_history`, `repair_partner_payments`, `debts`(debt_partner_/debt_repair_ — sự cố nợ trùng 2026-09-14 CHƯA xử lý).

### M09 — CÔNG NỢ (C)
`debt_view.dart` (2.984), `debt_payment_sheet` (widget), `collect_customer_debt_view`, `customer_debt_view`, `BulkDebtPaymentService`, `CustomerDebtPaymentService`, `DebtSummaryService`, `AdjustmentService` (miễn nợ) · bảng `debts`, `debt_payments`, `payment_intents`, `adjustment_entries` · rules `debts`, `debt_payments`, `adjustment_entries`, `supplier_debts`(collection có rule nhưng code chỉ 1 tham chiếu).

### M10 — TÀI CHÍNH (C)
| Màn hình | File |
|---|---|
| Tài chính 4 tab Tiền/Lãi/Nợ/Chốt quỹ | `finance_v2/finance_v2_view.dart`, `finance_v2_data_service.dart`, `finance_v2_cache.dart`, `finance_v2_reconciliation.dart`, `finance_v2_excel_export.dart` |
| Báo cáo ngày | `finance_v2_daily_report_view.dart` (2 Firestore trực tiếp) |
| Sổ quỹ / Chốt quỹ | `cash_closing_view.dart` (5 Firestore trực tiếp), `CashBalanceCacheService`, `cash_closing_audit_test` |
| Chi phí / Thu chi | `expense_view.dart` |
| Đối soát tiền về | `money_reconcile_view.dart`, `MoneyReconcileService` |
| Lãi theo tháng | `monthly_profit_report_view.dart` |
| Dịch vụ lãi nhất | `top_services_report_view.dart`, `TopServicesReportService` |
| Trả góp NH | `bank_installment_report_view`, `pending_bank_settlement_view` |
| Nhật ký tài chính 💀 | `financial_activity_log_view.dart` (bảng `financial_activity_log` vẫn được ghi & sync) |
| Lịch sử điều chỉnh | `adjustment_history_view.dart` |
| Đối chiếu dữ liệu | `data_reconciliation_view.dart`, `DataReconciliationService` |
| Yêu cầu thanh toán | `payment_request_chat_view`, 💀 `pending_payments_list_view`, `PaymentRequestService` (`payment_requests`) |
| Thông báo NH | `bank_notification_settings_view`, `BankNotificationService`/`Parser` (Android NotificationListener) → `bank_notifications` |
Engine: `DailyFinancialAnalysisService` (dòng tiền) vs `FinanceV2DataService` (dồn tích) — **khác biệt cố ý**, không "sửa".
Phân quyền giá vốn: `canViewCostPrice` 2 tầng (UI + service xoá field), default false.

### M11 — GIÁ (H)
`price_book_view` (`PriceBookService` prefs theo máy + `PricingEngineService`), `PriceCatalogService` (SQLite+cloud), `quick_input_codes_view` (✅), 💀 `quick_input_library_view`, 💀 `quick_input_management_view`, `expansion/pricing/price_selector_sheet`.

### M12 — NHÂN SỰ (H)
`staff_list_view`, `staff_directory_view`, 💀 `staff_permissions_view` (phân quyền hiện nằm trong `staff_list_view` section "Phân quyền" dòng 459), `staff_performance_view`, `staff_self_profile_view`, `staff_public_profile_view`, `attendance_view`, `attendance_management_view`, `work_schedule_settings_view` (5 Firestore trực tiếp), `shift_swap_view`, `hr_salary_settings_view` (=`SalarySettingsView`), `hr/shop_deduction_settings_view`, `hr/add_custom_adjustment_dialog` (💀 class không được gọi), 💀 `payroll_view.dart` (knowledge base ghi "Nhân viên → Bảng lương" nhưng không điều hướng tới — FINDING-DOC-01). Services: `AttendanceApprovalService`, `AttendanceSummaryService`, `SalaryCalculationService`, `SalarySlipPdfService`, `ShiftSwapService`. Bảng: `attendance`, `work_schedules`, `leave_requests`, `employee_salary_settings`, `payroll_settings`, `payroll_locks`. Collection thêm: `custom_salary_adjustments`, `shop_salary_defaults`, `shop_deduction_settings`, `attendance/{id}/leave_requests`, `attendance/{id}/shift_swap_requests`. Cloud Functions: `createStaffAccount`, `addUserToShop`, `removeUserFromShop`, `updateUserRole`, `syncUserClaims`.

### M13 — CHAT / CỘNG ĐỒNG (M)
`advanced_chat_view` (4 Firestore trực tiếp, `snapshots()` thật), `payment_request_chat_view`, `community_view` · `ChatService`, `CommunityService` · `chats`, `chat_messages`, `chat_online`, `chat_typing`, `shop_chats`, `community_posts/{id}/comments`. CF `chatAssistant`, `sendShopNotification`, `sendBroadcastNotification`.

### M14 — CÀI ĐẶT / HỆ THỐNG (M)
Menu thực tế tab Cài đặt (đọc `_buildSettingsTab`): Đồng bộ & Tài khoản · QR chuyển khoản (`bank_qr_settings_view`) · Đọc thông báo ngân hàng · Tuỳ chỉnh dashboard · Cho phép nhập giá vốn sau · Hiển thị NCC · Bắt buộc chọn NCC · Ngôn ngữ · Cài đặt tem nhãn · Cài đặt lương · Lịch làm việc · Hướng dẫn · Ứng dụng khác · Nhật ký kiểm toán (`audit_log_view`) · Sao lưu & Khôi phục (`backup_restore_view`, `BackupService`) · Nhập/Xuất (`import_export_view`, `ExcelImportService`) · Kết nối KiotViet · Công cụ điều chỉnh dữ liệu · Kiểm tra kết nối (`firestore_connectivity_test_view`) · Thống kê đọc/ghi (`firebase_rw_stats_view`) · Giám sát Firestore Read (`developer/firestore_audit`) · Huỷ liên kết. Thêm: `shop_settings_view` (6 Firestore trực tiếp), `printer_settings_view`, `invoice template`. Bảng `shop_settings` (bug phụ INSERT thay vì upsert — ghi nhận 2026-08-29), `bank_notifications`, `audit_logs`.

### M15 — AI (M)
`AiChatService`, `AiCommandRouter`, `AiNavBridge`, `AiKnowledgeService`, `AiService`, `AiUsageLogger`, `NaturalOrderParserService`, `VoiceCorrectionService`, `RepairVocabularyService` · 💀 `ai_usage_dashboard_view` · CF `parseOrderAI`, `createRepairOrderAI`, `chatAssistant` · quyền `allowCloudAI`.

### M16 — SYNC / INFRA (C)
`SyncService` (6.011 dòng: listener cửa sổ 3 ngày cho `repairs`,`sales`; poll con trỏ `updatedAt` cho 30 bảng `_incrementalRealtimeCollections`; quét trọn 1 lần/24h `_launchFullSweepCollections`; lưới an toàn 10 phút; `_cloudReadTimeout` 20s), `SyncOrchestrator` (bảng `sync_queue`: enqueue/create/update/delete, retry, failed), `SyncHealthCheck` (gate 24h), `SyncAuditService`, `SyncDomainReportService`, `FirebaseRwStatsService`, `FirebaseUsageStatsService`, `ConnectivityService`, `FirestoreConnectivityService`, `BackgroundUploadService`, `ProductImageService`, `LocalImageStore`, `EncryptionService` (mã hoá field sales/debts trước khi set), `OfflineStockEntryStore`. 💀 `sync_control.dart`, 💀 `logging_service.dart`, 💀 `test_data_service.dart`, 💀 `thermal_printer_service.dart` (đã thay bằng `UnifiedPrinterService`), 💀 `repair_stock_service.dart`. `lib/data/db_migration_service.dart` = dead code (đã ghi nhận trước).

### M17 — EXPANSION (safe mode) (L)
`expansion/branch/*` (3), `expansion/crm/*` (3: loyalty, history, redeem), `expansion/vat/create_invoice_view`, 💀 `expansion_modules_hub_view` · `lib/expansion/safe_mode` (`expansion_safe_mode_test`, `crm_loyalty_persistence_test`). Không có bảng SQLite riêng ⇒ kiểm xem lưu ở đâu (prefs?) — TC-EXP.

**Tổng kết đếm:** 17 module · 127 màn hình có Scaffold (13 file view 💀 mồ côi + 1 dialog 💀) · 6 service 💀 · 1 bảng schema chết (`product_variants`) + 3 bảng tạm migration (`*_new`).

---

## 4. DATABASE MAP (SQLite v111 — 45 bảng)

| Bảng | Nhóm | Khoá cloud | isSynced | deleted | shopId | Ghi bởi |
|---|---|---|---|---|---|---|
| repairs | Sửa | firestoreId UNIQUE | ✓ | ✓ | ✓ | create/detail view, sync |
| repair_parts | Sửa | firestoreId | ✓ | ✓ | ✓ | detail, StockEntryService (`upsertRepairPart`) |
| repair_partners / partner_repair_history / repair_partner_payments | Đối tác | firestoreId | ✓ | ✓ | ✓ | partner services |
| salvage_phones | Sửa | firestoreId | ✓ | ✓ | ✓ | salvage view |
| sales / sales_returns / sales_return_items | Bán | firestoreId | ✓ | ✓ | ✓ | create_sale, SalesReturnService |
| products / product_categories / product_variants(💀) | Kho | firestoreId | ✓ | ✓ | ✓ | nhiều |
| import_orders / import_order_items / purchase_orders | Kho | firestoreId | ✓ | ✓ | ✓ | StockEntry/ImportOrder/PO |
| supplier_import_history / supplier_product_prices / price_catalog_items | NCC | firestoreId | ✓ | ✓ | ✓ | stock in, PriceCatalog |
| storage_locations / inventory_checks / quick_input_codes | Kho | firestoreId | ✓ | ✓ | ✓ | |
| customers / suppliers | Danh bạ | firestoreId | ✓ | ✓ | ✓ | |
| supplier_payments | NCC | firestoreId | ✓ | ✓ | ✓ | Adjustment/supplier_detail |
| debts / debt_payments | Nợ | firestoreId | ✓ | ✓ | ✓ | PaymentIntentService |
| payment_intents | Tiền | intentId/firestoreId | ✓ | — | ✓ | PaymentIntentService |
| payment_requests | Tiền | firestoreId | ✓ | ✓ | ✓ | PaymentRequestService |
| expenses | Tiền | firestoreId | ✓ | ✓ | ✓ | PaymentIntentService, salvage, stock in |
| cash_closings / adjustment_entries / financial_activity_log / bank_notifications | Tài chính | firestoreId | ✓ | ✓ | ✓ | |
| attendance / work_schedules / leave_requests / employee_salary_settings / payroll_settings / payroll_locks | HR | firestoreId (work_schedules: userId UNIQUE) | ✓ | | ✓ | |
| audit_logs | Hệ thống | firestoreId | ✓ | | ✓ | AuditService |
| shop_settings | Hệ thống | — | | | ✓ | CategoryService (INSERT không upsert) |
| sync_queue | Sync | — | — | — | — | SyncOrchestrator |
| customers_new / products_new / quick_input_codes_new | Tạm migration | | | | | onUpgrade (rename) |

Kiểm tra DB (Bước 3) thực hiện bằng **sqflite FFI** (test `test/full_audit_db_schema_test.dart` tạo trong đợt này) + kéo file DB thật từ máy (`adb pull … -wal`).

---

## 5. FIRESTORE MAP

**Mô hình:** root collections + field `shopId` (rules `docInMyShop()`), KHÔNG dùng `/shops/{id}/{sub}` trừ `shops/{id}/custom_salary_adjustments|settings|product_categories|meta`, `attendance/{id}/leave_requests|shift_swap_requests`, `community_posts/{id}/comments`.

| Collection | Có rule | Sync 2 chiều (`SyncCollections.all`) | Ghi từ đâu |
|---|---|---|---|
| repairs, repair_parts, repair_partners, repair_partner_payments, partner_repair_history, salvage_phones | ✓ | ✓ | orchestrator + FirestoreService |
| sales, sales_returns, sales_return_items | ✓ | ✓ | transaction + orchestrator |
| products, import_orders, import_order_items, purchase_orders, supplier_import_history, price_catalog_items, storage_locations, quick_input_codes | ✓ | ✓ | |
| stock_entries | ✓ (immutable) | ✗ (chỉ cloud) | StockEntryService |
| customers, suppliers, supplier_payments | ✓ | ✓ | |
| expenses, debts, debt_payments, payment_intents, payment_requests, cash_closings, financial_activity_log | ✓ | ✓ | |
| attendance, work_schedules, audit_logs | ✓ | ✓ | |
| adjustment_entries, inventory_checks, payroll_settings, employee_salary_settings, shop_deduction_settings, shop_salary_defaults, custom_salary_adjustments | ✓ | ✗ (ghi trực tiếp) | views/services |
| users, shops, invites, settings, meta, app_config, admin_security, admin_audit_log, broadcasts, other_apps, notifications, shop_notifications | ✓ | ✗ | auth/admin |
| chats, chat_messages, chat_online, chat_typing, community_posts, comments | ✓ | ✗ (snapshots thật) | ChatService |
| product_variants, supplier_debts, financial_activities | ✓ rule | ✗ | **legacy** — code không còn ghi (`financial_activities` 1 tham chiếu, `supplier_debts` 1) |
| shop_chats, bank_notifications | ✗ rule / ✓ | — | `shop_chats` có trong code (1) nhưng KHÔNG có rule → rơi vào `match /{document=**}` (kiểm TC-PERM-20) |
| Tổng | 60 rule | 30 sync | 57 tên trong code |

Cloud Functions (21): claims (`syncUserClaims`, `syncUserClaimsV`, `refreshMyClaims(V)`, `getMyClaimsV`, `getUserClaims`, `batchSyncAllClaims`), staff (`createStaffAccount`, `addUserToShop`, `removeUserFromShop`, `updateUserRole`, `updateUserProfileSecure`, `updateShopProfileSecure`, `deleteUserData`), notify (`sendShopNotification`, `sendBroadcastNotification`, `cleanupFCMTokens`), AI (`chatAssistant`, `createRepairOrderAI`, `parseOrderAI`), dọn (`cleanupDeletedRepairs`).

---

## 6. SYNC MAP

```
UI save ──► DBHelper.insert/upsert (isSynced=0) ──► SyncOrchestrator.enqueueX(sync_queue) ──► syncAll()
                                                        │ _handleCreate/_handleUpdate/_handleDelete
                                                        │ applyRepairCloudGuards (repairs)
                                                        ▼
                                              Firestore set(merge)/update ──► _markLocalAsSynced (isSynced=1)
Cloud ──► SyncService listener (repairs/sales cửa sổ 3 ngày) / poll con trỏ updatedAt / sweep 24h
       ──► DBHelper.upsertX (theo firestoreId) ──► EventBus.emit('<table>_changed') ──► view setState
```
Điểm rủi ro cần test: (a) `isSynced=1` nhưng cloud chưa có (đường ghi thẳng `rawUpdate … isSynced = 1` ở create_sale sau transaction); (b) local ghi đè cloud mới hơn (`_handleUpdate` không so `updatedAt`?); (c) cloud ghi đè local `isSynced=0` (poll upsert khi local có thay đổi chưa đẩy); (d) retry tạo trùng (create với docId cố định → an toàn, create không docId → trùng); (e) queue mất khi clear DB (`_checkAndClearLocalDataIfShopChanged`).

---

## 7. PERMISSION MAP

| Role (Firestore `users.role`) | App role (`getUserRole`) | Quyền mặc định |
|---|---|---|
| super_admin | 'admin' (bẫy đặt tên) | tất cả, chọn shop; rules `isSuperAdmin()` đọc token |
| owner | 'admin' | full |
| manager | 'manager' | full trừ quản lý shop |
| employee / technician / user | 'staff' | theo 25 cờ `allow*` |

25 cờ: allowView, allowCreate, allowManage, allowManageStaff, allowViewCostPrice, allowViewRevenue, allowViewDebts, allowViewExpenses, allowViewInventory, allowViewParts, allowViewSales, allowViewRepairs, allowViewCustomers, allowViewSuppliers, allowViewWarranty, allowViewAttendance, allowViewSettings, allowViewPrinter, allowViewPurchaseOrders, allowCreatePurchaseOrders, allowViewChat, allowSendChat, allowPinChat, allowDeleteOtherChat, allowCloudAI.
Server: `firestore.rules` `canCreateSales()`, `isOwner()`, `isStaff()`, `shopIdLocked()`, `docInMyShop()`; delete chỉ owner/super admin.

---

## 8. BUSINESS WORKFLOW MAP (xuyên module)

| WF | Chuỗi | Module chạm |
|---|---|---|
| WF-01 Bán máy công nợ + trả trước | Kho(SP) → Bán → Nợ(CUSTOMER_OWES) → Tiền(thu trước) → Tài chính → Sync | M05,M04,M09,M10,M16 |
| WF-02 Bán trả góp NH | Bán(cọc) → Tất toán NH (sale_detail/pending_bank_settlement) → Đối soát tiền về → Tài chính | M04,M10 |
| WF-03 Trả hàng | Bán → Trả hàng → Kho(+) → Nợ(−) → Tiền(hoàn) → Tài chính | M04,M05,M09,M10 |
| WF-04 Nhập kho nợ NCC → trả NCC theo phiếu | Kho → NCC → Nợ(SHOP_OWES) → import_orders.paidAmount → Tài chính | M05,M07,M09,M10 |
| WF-05 Sửa chữa đầy đủ | Nhận(cọc) → linh kiện(trừ kho) → đối tác(nợ đối tác) → Sửa xong → duyệt giao → giao (thu/nợ) → BH | M03,M05,M08,M09,M10 |
| WF-06 Thu nợ nhiều khoản | Nợ → BulkDebtPayment → payment_intents/debt_payments → Sổ quỹ | M09,M10 |
| WF-07 Chốt quỹ → điều chỉnh sau chốt | Tài chính → Adjustment (chặn sửa trực tiếp `canEditDirectly`) | M10,M09,M04 |
| WF-08 Offline → claim | Welcome offline → tạo dữ liệu → Đăng ký → Claim → sync | M01,M16, mọi |
| WF-09 Nhân viên mới | createStaffAccount → claims → phân quyền → đăng nhập máy 2 | M12,M01,M16 |
| WF-10 Xác máy | mua xác (chi) → linh kiện từ xác → dùng vào đơn sửa | M03,M05,M10 |

---

## 9–18. TEST CASES

Định dạng mỗi dòng: **ID** · Precondition · Test data · Action · Expected · DB check · Cloud check · Sync check · UI check. Cột PASS/FAIL ghi ở REPORT.
Mức thực thi: **[A]** tự động (flutter test/FFI) · **[D]** máy thật CPH2203 (m@m.com shop M) · **[E]** emulator máy 2 · **[R]** đọc code (static) · **[B]** blocked.

### 9.1 AUTH / SESSION (M01)
| ID | Pre | Data | Action | Expected | DB | Cloud | Sync | UI | Mức |
|---|---|---|---|---|---|---|---|---|---|
| TC-AUTH-01 | app fresh | m@m.com/123123 | đăng nhập | vào Home shop M | shopId lưu prefs | users/{uid} shopId | listener khởi động | tab đúng quyền | D |
| TC-AUTH-02 | — | sai mật khẩu | đăng nhập | báo lỗi VN, không treo | — | — | — | — | D |
| TC-AUTH-03 | offline (wifi off) | đúng TK | đăng nhập | lỗi mạng rõ ràng ≤20s | — | — | — | — | D |
| TC-AUTH-04 | fresh | — | "Dùng ngay không tài khoản" | AppSession.offline, offlineShopId | shop_settings có shopId cục bộ | không có write | syncEnabled=false | Home | D |
| TC-AUTH-05 | offline session có data | — | Đăng xuất | SQLite giữ (ownsShop) | rows còn | — | — | Welcome | D/A(`app_session_test`) |
| TC-AUTH-06 | online | — | đăng xuất | `SessionLogoutService`; clearCache; SQLite xoá khi không ownsShop | | | queue? (TC-SYNC-12) | | D |
| TC-AUTH-07 | super admin | huy@ | chọn shop khác | mọi query lọc shopId đã chọn | | | reinit listener | | R |
| TC-AUTH-08 | 2 role | employee không allowViewRevenue | vào Tài chính | bị chặn UI + service xoá cost | | rules cho đọc? (TC-PERM) | | | D/R |
| TC-AUTH-09 | claim | offline data 3 bảng | Đăng ký → Kết nối | shopId cục bộ = cloud id, không merge tự động | re-tag chỉ khi cloud rỗng | docs xuất hiện | queue đẩy hết | | A(`claim_retag_test`) |
| TC-AUTH-10 | — | — | kill app lúc claim | không xoá SQLite (`claimInProgress`) | | | | | R |

### 9.2 SỬA CHỮA (M03)
| ID | Pre | Data | Action | Expected | DB | Cloud | Sync | UI |
|---|---|---|---|---|---|---|---|---|
| TC-REP-01 [D] | online | KH mới "QA KH1" 0901, iPhone 12, lỗi màn, giá 1.500k | tạo đơn | đơn status 1, KH tạo | repairs+customers isSynced=1 | repairs doc có shopId,status=1 | không hàng đợi | list hiện ngay |
| TC-REP-02 [D] | online | cọc 500k TIỀN MẶT | tạo đơn có cọc | intent completed, tiền mặt +500k | payment_intents 1 row | payment_intents doc | | Sổ quỹ +500k |
| TC-REP-03 [D] | — | model rỗng | lưu | chặn validate | không row | không doc | | thông báo |
| TC-REP-04 [D] | — | giá âm / chữ | lưu | chặn (rules `optNumGte0`) | | | | |
| TC-REP-05 [D] | — | double tap Lưu | 1 đơn | 1 row | 1 doc | | |
| TC-REP-06 [D] | — | Back khi đang lưu | không đơn dở / hoặc 1 đơn đầy đủ | | | | |
| TC-REP-07 [D] | wifi OFF, online session | tạo đơn | lưu local `isSynced=0`, không treo | queue có create | chưa có doc | bật wifi → doc xuất hiện, `isSynced=1` | badge sync |
| TC-REP-08 [D] | offline session | tạo đơn | id client, không chạm Firebase | | | | |
| TC-REP-09 [D] | TC-REP-07 | kill app trước khi online | mở lại → queue còn → sync | sync_queue row | | | |
| TC-REP-10 [D] | đơn status 1 | đổi 1→2→3 | status đúng, `repairedBy` giữ | | doc status; không mất `repairedBy` | guard | detail |
| TC-REP-11 [D] | status 3 | Y/c duyệt giao | `pendingDeliveryApproval=1` | | doc field | | list nhóm "Y/c duyệt giao" |
| TC-REP-12 [D] | có SP linh kiện tồn 5 | thêm linh kiện x2 | repair_parts +1, products qty 3, cost đơn +vốn | | products doc qty 3 | | Kho cập nhật ngay |
| TC-REP-13 [D] | TC-12 | xoá linh kiện | hoàn kho 5 | | | | |
| TC-REP-14 [D] | TC-12 | đổi linh kiện A→B | A hoàn, B trừ, không trùng | | | | |
| TC-REP-15 [D] | đối tác "QA ĐT" | thêm dịch vụ đối tác 200k | partner_repair_history +1, debts debt_partner_ 1 row (KHÔNG thêm debt_repair_ trùng) | 1 debt | | | Nợ NCC +200k |
| TC-REP-16 [D] | TC-15 | trả đối tác 200k | repair_partner_payments 1, debt paid, intent completed 1 lần | | | | Sổ quỹ −200k |
| TC-REP-17 [D] | TC-16 | trả lần 2 (thử vượt) | chặn vượt hoặc = 0 còn lại | | | | |
| TC-REP-18 [D] | status 3 | giao máy thu TIỀN MẶT | status 4, intent salePayment? (repair) 1 row, cọc trừ đúng | | | | Tài chính doanh thu |
| TC-REP-19 [D] | status 3 | giao máy CÔNG NỢ | debts CUSTOMER_OWES 1 row | | | | |
| TC-REP-20 [D] | status 4 | sửa giá sau giao | history correction, tiền không double | | | | |
| TC-REP-21 [D] | status 4 | xoá đơn (mật khẩu) | soft delete, hoàn kho linh kiện, xoá intents/debts liên quan | deleted=1 | deleted:true | | biến khỏi list |
| TC-REP-22 [D] | — | sai mật khẩu xoá | chặn | | | | |
| TC-REP-23 [D] | đơn có ảnh, offline | chọn ảnh | `LocalImageStore` documents dir; online → upload | | Storage | `uploadPendingLocalRepairImages` | |
| TC-REP-24 [D] | đơn 4 | tạo BH | 0 đồng, không tăng doanh thu, không trừ kho lần 2 | | | | Bảo hành list |
| TC-REP-25 [D] | 200 đơn | search/scroll | ≤1s, không crash | `searchRepairs` cap 5000 | | | |
| TC-REP-26 [E] | 2 máy | A tạo → B | B thấy ≤ 10s (listener cửa sổ 3 ngày) | | | | |
| TC-REP-27 [E] | 2 máy cùng mở đơn | A đổi status, B đổi KTV cùng lúc | không mất field nào (merge) | | | | |
| TC-REP-28 [E] | A offline sửa giá, B online sửa giá | A online | last-write? phải không tụt status | | | applyRepairCloudGuards | |
| TC-REP-29 [D] | — | xác máy 300k | expenses 1 row, `isSynced` cứng 1 nhưng cloud có? | | expenses doc | ⚠ không qua orchestrator | Sổ quỹ −300k |
| TC-REP-30 [D] | — | AI giọng nói tạo đơn | `createRepairOrderAI` | | | | |

### 9.3 BÁN HÀNG (M04)
| ID | Pre | Data | Action | Expected | DB | Cloud | Sync | UI |
|---|---|---|---|---|---|---|---|---|
| TC-SALE-01 [D] | online, SP điện thoại IMEI tồn 1 | bán 1 máy 5.000k TIỀN MẶT | 1 sale, product status 0, intent 1 | sales, products, payment_intents | transaction atomic | | Kho: máy đã bán |
| TC-SALE-02 [D] | linh kiện qty 10 | bán x3 | qty 7 | | doc qty 7 | | |
| TC-SALE-03 [D] | nhiều SP | giảm dòng + giảm đơn | totalPrice = Σ − giảm | | | | |
| TC-SALE-04 [D] | — | KẾT HỢP mặt 3.000k + CK 2.000k | 2 intents / split đúng (`ket_hop_cash_split_test`) | | | | Sổ quỹ 2 dòng |
| TC-SALE-05 [D] | — | CÔNG NỢ, trả trước 1.000k | debt total 5.000k paid 1.000k, 1 intent thu trước, debt_payments 1 | | debts doc | | Nợ 4.000k |
| TC-SALE-06 [D] | — | TRẢ GÓP (NH) cọc 1.000k | sale settlement pending, cọc ghi nhận | | | | Chờ tất toán |
| TC-SALE-07 [D] | TC-06 | tất toán NH 4.000k | `settlementReceivedAt`, tiền NH +4.000k | | | | Đối soát |
| TC-SALE-08 [D] | — | double tap Thanh toán | 1 sale (`_isSaving`) | 1 row | 1 doc | | |
| TC-SALE-09 [D] | — | qty > tồn | chặn OUT_OF_STOCK | | | | |
| TC-SALE-10 [E] | 2 máy cùng 1 máy IMEI | bán đồng thời | 1 thành công, 1 "Hàng đã được bán" | | transaction | | |
| TC-SALE-11 [D] | wifi OFF, online session | bán | **kỳ vọng**: lưu local không treo | | | | ⚠ nghi treo (không timeout) |
| TC-SALE-12 [D] | SP chưa có firestoreId | bán | dialog "Bán offline" | | | | |
| TC-SALE-13 [D] | offline session | bán | local, không dialog | | | | |
| TC-SALE-14 [D] | TC-13 | kill app → mở lại | sale còn | | | | |
| TC-SALE-15 [D] | TC-13 ×3 | online | 3 doc, kho trừ 1 lần | | | | |
| TC-SALE-16 [D] | sale TIỀN MẶT | xoá đơn | hoàn kho, xoá intents, deleted | | | | Sổ quỹ −5.000k |
| TC-SALE-17 [D] | sale CÔNG NỢ | xoá đơn | xoá debt (`deleteDebtByFirestoreId`) | | | | |
| TC-SALE-18 [D] | sale 3 linh kiện | trả 1 dòng, hoàn TIỀN MẶT | sales_returns, +qty 1, tiền −, debt − nếu có | | | | |
| TC-SALE-19 [D] | sale CÔNG NỢ | trả hàng | debts.totalAmount giảm; cloud `debts.update` trực tiếp | | | ⚠ không qua orchestrator | |
| TC-SALE-20 [R] | — | hoàn tiền trả hàng | có đi qua PaymentIntentService? (đọc `SalesReturnService`) | | | | |
| TC-SALE-21 [D] | 500 sale | list/scroll/search | | | | | |
| TC-SALE-22 [D] | — | in hoá đơn/QR | QR VietQR đúng số | | | | |
| TC-SALE-23 [D] | ngày đã chốt quỹ | bán | chặn `canEditDirectly` → qua Adjustment | | | | |
| TC-SALE-24 [D] | staff không canCreateSales | bán | rules deny → fallback dialog "bán offline"? ⚠ (permission-denied → local-first) | | | | |

### 9.4 KHO (M05)
| ID | Pre | Data | Action | Expected |
|---|---|---|---|---|
| TC-INV-01 [D] | online | NCC "QA NCC", 1 SP linh kiện x10 giá 50k, trả ngay TIỀN MẶT | nhập | products +10, stock_entries doc, import_orders 1, expenses 1 (500k), supplier_import_history 1, supplier_product_prices 1 |
| TC-INV-02 [D] | — | 3 SP, 1 lần | import_order_items 3, expense 1 tổng (không 3) |
| TC-INV-03 [D] | — | cùng SP nhập 2 lần | qty cộng dồn, giá vốn cập nhật (bình quân hay cuối? đọc `upsertProduct`) |
| TC-INV-04 [D] | — | qty 0 / âm / giá 0 | chặn |
| TC-INV-05 [D] | — | IMEI trùng | chặn |
| TC-INV-06 [D] | — | CÔNG NỢ | debts SHOP_OWES 1, không expense |
| TC-INV-07 [D] | — | trả 1 phần 200k/500k | expense 200k + debt 300k |
| TC-INV-08 [D] | TC-06 | trả NCC theo phiếu | import_orders.paidAmount, supplier_payments, debt paid |
| TC-INV-09 [D] | wifi OFF, online session | nhập | ⚠ `runTransaction stock_entries` không timeout |
| TC-INV-10 [D] | offline session | nhập | OfflineStockEntryStore + SQLite; online → stock_entries doc tạo 1 lần |
| TC-INV-11 [D] | TC-10 | kill app | prefs còn |
| TC-INV-12 [D] | — | double tap Nhập | 1 phiếu |
| TC-INV-13 [D] | — | sửa SP (tên/giá) | products updatedAt, sync |
| TC-INV-14 [D] | — | xoá SP có tồn | soft delete, không mất lịch sử |
| TC-INV-15 [D] | — | kiểm kho lệch −2 | inventory_checks, products qty điều chỉnh, cost? |
| TC-INV-16 [D] | — | vị trí kho gán/bỏ | storage_locations |
| TC-INV-17 [D] | — | hàng chờ xác nhận → xác nhận | stock_entries status, products |
| TC-INV-18 [D] | — | PO tạo → nhận | purchase_orders |
| TC-INV-19 [D] | 500 SP | search/filter/sort | |
| TC-INV-20 [D] | staff không allowViewCostPrice | Kho/Excel/in tem | không cột vốn |
| TC-INV-21 [E] | A nhập, B xem | B qty đúng ≤ 2 phút (poll) hoặc ngay (products listener?) |

### 9.5 CÔNG NỢ (M09)
| ID | Action | Expected |
|---|---|---|
| TC-DEBT-01 [D] | thu 1 phần 1.000k/4.000k TIỀN MẶT | debt paid 1.000k ACTIVE, debt_payments 1, intent 1, Sổ quỹ +1.000k |
| TC-DEBT-02 [D] | thu hết | status PAID |
| TC-DEBT-03 [D] | thu vượt | chặn |
| TC-DEBT-04 [D] | thu 2 lần nhanh (double tap) | 1 phiếu (idempotency `<fid>_<ts>` ⚠ ts khác nhau ⇒ dựa `_isProcessing` UI) |
| TC-DEBT-05 [D] | thu gộp 3 khoản (Bulk) | 3 debt_payments, 1 hay 3 intent? Sổ quỹ tổng đúng |
| TC-DEBT-06 [D] | miễn nợ | adjustment_entries, debt CLOSED không tăng tiền |
| TC-DEBT-07 [D] | offline thu nợ → online | không trùng |
| TC-DEBT-08 [D] | trả NCC 1 phần / hết / nhiều lần | supplier_payments, import_orders.paidAmount |
| TC-DEBT-09 [R+D] | nợ đối tác trùng (debt_partner_ vs debt_repair_) | ghi nhận nếu tái diễn |
| TC-DEBT-10 [D] | tổng nợ tab Nợ = Σ debts ACTIVE (SQLite) | đối chiếu SQL |
| TC-DEBT-11 [D] | xoá/sửa phiếu thu | có cho phép? nếu có → hoàn paidAmount, tiền |

### 9.6 TÀI CHÍNH (M10)
| ID | Action | Expected / Đối chiếu |
|---|---|---|
| TC-FIN-01 [D] | sau chuỗi TC-SALE-01,05, TC-REP-18, TC-DEBT-01, TC-INV-01, chi 100k | tab Tiền: thu = Σ intent thu; chi = Σ intent chi; SQL: `SELECT SUM(amount) FROM payment_intents WHERE status='COMPLETED' AND date…` |
| TC-FIN-02 [D] | tab Lãi | doanh thu = Σ sales.totalPrice + repairs.price (đã giao) ; vốn = Σ totalCost + repairs.cost; lãi = hiệu; so SQL |
| TC-FIN-03 [D] | tab Nợ | = TC-DEBT-10 |
| TC-FIN-04 [D] | Chốt quỹ ngày | opening + in − out = closing; sau chốt sửa bị chặn |
| TC-FIN-05 [D] | staff không cost | tab Lãi ẩn vốn & lãi; Excel không cột |
| TC-FIN-06 [A] | `finance_full_scenario_test`, `comprehensive_financial_test`, `cash_closing_audit_test`, `installment_*` | PASS |
| TC-FIN-07 [D] | trả hàng/hoàn tiền | doanh thu giảm, tiền giảm |
| TC-FIN-08 [D] | trả góp: cọc ngày 1, tất toán ngày 2 | ngày 1 chỉ cọc, ngày 2 phần tất toán (memory: settlementSales query riêng) |
| TC-FIN-09 [D] | Excel export | nhãn VN, số đúng |
| TC-FIN-10 [D] | Báo cáo ngày = tab Tiền cùng ngày | khớp |
| TC-FIN-11 [D] | mở tab Tài chính 3 lần | read Firestore ≤ 1 lần/10 phút (Chốt quỹ keep-alive) — đo `FirebaseRwStats` |

### 9.7 PHÂN QUYỀN (M11 mục 11)
| ID | Action | Expected |
|---|---|---|
| TC-PERM-01 [D] | employee tắt allowViewRevenue | tab Tài chính ẩn; nếu vào deep-link → chặn |
| TC-PERM-02 [D] | tắt allowViewCostPrice | Kho/Bảng giá/đơn sửa/Excel/in không vốn, không lãi |
| TC-PERM-03 [R] | rules: user shop A đọc `repairs` shop B | `docInMyShop()` deny — harness `tools/firestore_rules_test` (emulator) |
| TC-PERM-04 [R] | rules: create repairs với shopId B | `newDocInMyShop()` deny |
| TC-PERM-05 [R] | rules: update shopId | `shopIdLocked()` deny |
| TC-PERM-06 [R] | rules: staff delete sales | deny (owner only) |
| TC-PERM-07 [R] | rules `deleted` thiếu field | đã có test js |
| TC-PERM-08 [R] | `shop_chats` không rule | rơi `{document=**}` → xem dòng 1573 |
| TC-PERM-09 [R] | `SupplierPaymentService` root collection | dead — không rủi ro runtime |
| TC-PERM-10 [R] | ghi `role:'admin'` xuống users | mất super admin (SA-01 đã audit) |
| TC-PERM-11 [D] | staff không canCreateSales bán | rules deny → app rơi "bán offline" local-first ⇒ đơn kẹt queue mãi? |

### 9.8 MULTI-DEVICE (Bước 12) — [E] emulator `Medium_Phone` + CPH2203, cùng m@m.com
TC-MD-01 A tạo đơn sửa → B · TC-MD-02 A sửa → B · TC-MD-03 B sửa → A · TC-MD-04 A,B sửa cùng lúc 2 field khác · TC-MD-05 A offline tạo, B online tạo, A online (2 doc, không trùng) · TC-MD-06 A xoá, B đang sửa → B lưu (đơn "sống lại"?) · TC-MD-07 A,B cùng tạo KH cùng SĐT (trùng?) · TC-MD-08 A bán máy IMEI, B bán cùng máy (transaction) · TC-MD-09 A thu nợ, B thu cùng khoản (vượt?) · TC-MD-10 A nhập kho, B thấy qty.

### 9.9 FIRESTORE READ AUDIT (Bước 13) — [R]+[D] đo bằng `FirebaseRwStatsService` / Giám sát Firestore Read
| Màn hình | Caller → Service → Function → Collection → Query | Kỳ vọng |
|---|---|---|
| Mở app (AuthGate) | `main.AuthGate` → `SyncService.initRealTimeSync` → listener `repairs`,`sales` where shopId & updatedAt>now−3d; poll 30 bảng con trỏ; sweep 24h; `SyncHealthCheck` gate 24h; `users/{uid}`, `shops/{id}` snapshots | ≤ (docs thay đổi) + 30 query tối thiểu |
| Home | SQLite only; `RecentActivityService`? ; `other_apps` snapshots | 0–1 |
| Danh sách đơn | SQLite only (2026-09-17) | 0 |
| Chi tiết đơn | `FirestoreService.getRepairDoc` (3 chỗ create, 1 detail) | ≤1/get |
| Tạo đơn bán | `refreshMyClaims` CF + transaction N reads | N+1 |
| Tài chính | `FinanceV2Cache`; Chốt quỹ cloud ≤1/10ph; `finance_v2_daily_report_view` 2 Firestore trực tiếp | ≤ 1 quét |
| Chat | `snapshots()` thật `chats`,`chat_messages`,`chat_online`,`chat_typing` | theo tin |
| Super admin console | 10 Firestore trực tiếp, snapshots | quét shops/users |
| Cài đặt → Kiểm tra kết nối | `FirestoreConnectivityService` 1 doc | 1 |
Tìm: listener không dispose (`_subscriptions` clear khi logout?), duplicate listener sau `shopChanged`, `_safetyNetRefreshInterval` chồng với resume poll.

### 9.10 CRASH / RECOVERY (Bước 16)
TC-CR-01 kill app giữa `_processSale` sau transaction cloud trước rawUpdate SQLite → mở lại: sale doc cloud có, SQLite thiếu → listener kéo về? kho lệch? · TC-CR-02 kill giữa stock entry (cloud doc tạo, products chưa) → `_reconcile`? · TC-CR-03 kill giữa syncAll → item `processing` kẹt? retry · TC-CR-04 back khi dialog "Bán offline" · TC-CR-05 đổi wifi→4G giữa listener → listener re-attach (`_safetyNet`) · TC-CR-06 khoá màn hình 5 phút → resume poll không trùng · TC-CR-07 app background 30 phút → `app_resumed` event.

### 9.11 REGRESSION
Mỗi bug FAIL → chạy lại: case gốc + WF liên quan (§8) + `flutter test` + offline (TC-*-offline) + sync + finance/inventory/debt đối chiếu + multi-device.

### 9.12 STRESS (Bước 15)
Sinh bằng SQL trực tiếp vào SQLite máy test (adb + sqlite3) hoặc `TestDataService` (💀 nhưng gọi được?): 100 KH, 500 SP, 1000 sale, 100 đơn sửa, 100 payment → đo list/search/scroll/tab/refresh/sync; theo dõi `adb logcat` crash, `dumpsys meminfo`.

### 9.13 TEST DATA (Bước 18) — shop M (m@m.com)
- Customer QA-KH1 (0901000001), QA-KH2 (0901000002)
- Supplier QA-NCC (0902000001); Repair partner QA-ĐT
- Products: QA-IP12 (DIEN_THOAI, IMEI 3512345QA0001, vốn 3.000k, bán 5.000k), QA-MAN (linh kiện màn, qty 10, vốn 500k, bán 800k), QA-PIN (qty 20, vốn 100k, bán 250k)
- Sales: S1 tiền mặt IP12; S2 công nợ 3×PIN trả trước 200k; S3 trả góp NH
- Repairs: R1 (KH1, cọc 200k, linh kiện MAN, đối tác 100k, giao thu mặt); R2 (KH2, giao công nợ); R3 bảo hành từ R1
- Payments: thu nợ S2 1 phần; trả NCC 1 phần; trả đối tác
- Expense: chi 100k; Cash closing ngày test

---

## 19. BUG REPORT TEMPLATE
```
BUG ID | MODULE | SCREEN | WORKFLOW | FILE:LINE | SERVICE | DB TABLE | FIRESTORE COLLECTION
CONDITION | STEPS | EXPECTED | ACTUAL
SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | DATA IMPACT | FINANCIAL IMPACT | SYNC IMPACT
REPRODUCIBILITY (n/n) | OFFLINE TEST | MULTI-DEVICE TEST | ROOT CAUSE DỰ KIẾN
```

## 20. FINAL TEST REPORT TEMPLATE
Tổng module / màn hình / workflow / test case · PASS / FAIL / BLOCKED · CRITICAL / HIGH / MEDIUM / LOW · Top 10 bug · Phần chưa test + lý do · Bằng chứng (SQL, doc id, screenshot path, log).
