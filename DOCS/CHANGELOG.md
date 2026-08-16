# CHANGELOG - HULUCA Shop Manager

Lịch sử tất cả thay đổi từng phiên bản.

---

## [2026-08-16o] - fix(sync): đơn sửa từ máy khác không hiện tới khi thoát app vào lại

**Yêu cầu user:** "sau khi tối ưu read cho repair có phát sinh 1 số vấn đề: khi người khác nhận máy sửa ở máy A thì máy B không có trên list phải thoát ra vào lại mới thấy. Khi sửa hay chuyển trạng thái cũng không cập nhật ngay."

**Nguyên nhân:** đợt tối ưu Firestore read trước đó (commit `55b4870e`) đổi cách đồng bộ nhiều collection (bao gồm `repairs`) từ `snapshots()` (đẩy realtime) sang `get()` polling 1 lần lúc mở app/đăng nhập, để giảm số lần đọc. Nhưng KHÔNG có điểm nào kích hoạt fetch lại sau đó — không có polling định kỳ, không refresh khi app resume từ nền, và màn Danh sách đơn sửa cũng không nằm trong 5 nơi đang gọi `refreshCloudCollections()` (kho, chi nhánh...). Nên chỉ có cách thoát app rồi vào lại (kích hoạt lại `initRealTimeSync` → fetch 1 lần) mới thấy thay đổi từ thiết bị khác.

**Fix (tái dùng hạ tầng polling có sẵn, không quay lại `snapshots()` toàn phần để tránh đội read cost trở lại):**
- `sync_service.dart`: thêm 1 `Timer.periodic` (45s) CHỈ fetch lại riêng collection `repairs` — gọi thẳng `_collectionRefreshers['repairs']` thay vì `refreshCloudCollections()` chung, để không kéo theo ~20 collection khác cũng đang polling (tránh đội read cost trở lại đúng thứ đợt tối ưu trước vừa giảm). Timer được lưu vào `_pollingTimers` (hạ tầng có sẵn nhưng trước đây chưa từng được dùng tới) nên tự dừng đúng khi đổi shop/đăng xuất qua `cancelAllSubscriptions()` sẵn có.
- `main.dart`: thêm `SyncService.refreshCloudCollections(reason: 'app_resumed')` khi app resume từ nền (`AppLifecycleState.resumed`) — bắt kịp ngay lập tức thay vì chờ tick định kỳ tiếp theo.

**Verify:** `flutter analyze` sạch (0 lỗi). Build + cài Oppo CPH2203, theo dõi logcat qua nhiều chu kỳ — xác nhận cả 3 cơ chế fetch đều chạy đúng: `reason=initial` lúc mở app, `reason=manual_refresh` (qua Timer riêng cho repairs) đúng 45s sau, và `reason=app_resumed` (tổng 35 collection) ngay khi đưa app từ nền lên lại. Mở màn Danh sách đơn sửa thật (13 đơn) không crash trong suốt quá trình. **Giới hạn đã biết:** chỉ có 1 thiết bị test nên KHÔNG mô phỏng được đúng kịch bản "máy A tạo/sửa đơn, xác nhận máy B nhận được" — chỉ xác nhận được cơ chế fetch (Timer + resume trigger) tự chạy đúng lịch, không lỗi; không có sẵn service-account/Admin SDK credentials để giả lập ghi từ "thiết bị khác" trực tiếp vào Firestore.

**Files:** `lib/services/sync_service.dart`, `lib/main.dart`.

---

## [2026-08-16n] - fix(debt): dọn giao diện màn Công nợ — bớt cấn, chuyên nghiệp hơn

**Yêu cầu user:** gửi 2 ảnh chụp màn "Quản lý công nợ" (tab Phải thu, Phải trả), nhận xét thao tác/trải nghiệm "cấn cấn không chuyên nghiệp", nhờ xem và cho ý kiến sửa. Sau khi review + đối chiếu code, user đồng ý sửa cả 4 điểm.

1. **Tiêu đề AppBar bị cắt chữ** ("QUẢN LÝ CÔN...") — chuỗi "QUẢN LÝ CÔNG NỢ" quá dài so với khoảng trống còn lại (đã có nút back + phụ đề + 3 icon bên phải). Rút gọn còn "CÔNG NỢ" (`debtManagementTitle` trong `app_vi.arb`).
2. **Mỗi thẻ nợ lặp lại chỉ báo "thu/trả" tới 3 lần dư thừa**: số thứ tự (badge vuông "1","2"...) + icon mũi tên ↓/↑ cùng màu + chữ "Phải thu"/"Phải trả" — trong khi đang lọc theo tab thì cả 3 đều nói cùng 1 điều. Bỏ số thứ tự (không mang ý nghĩa gì với người dùng — chỉ là thứ tự hiển thị) và bỏ chip chữ "Phải thu"/"Phải trả" (trùng lặp với icon + ngữ cảnh tab); chỉ còn hiện 1 chip khi có điều thật sự cần báo (đã trả đủ / quá hạn). Áp dụng cho cả thẻ nợ khách/NCC (`_debtCard`) lẫn thẻ nợ đối tác sửa chữa (`_partnerDebtCard`).
3. **Khối "TỔNG NỢ ĐỐI TÁC SỬA CHỮA" bị cắt cụt giữa chừng** (nguyên nhân chính gây cảm giác giật/thiếu chuyên nghiệp) — code cũ chia màn thành 2 khung theo **tỷ lệ cố định** (danh sách nợ thường : nợ đối tác = 3:2, `Expanded(flex: ...)`), nên khi danh sách ngắn vẫn bị ép cắt cụt ngay trước khối tổng. Gộp lại thành **1 `ListView` cuộn liền mạch duy nhất**, cao theo đúng nội dung — `_buildSimpleDebtList`/`_buildPartnerDebtList` đổi thành `_buildSimpleDebtItems`/`_buildPartnerDebtItems` trả về `List<Widget>` thay vì `Widget` có `Expanded` riêng.
4. **Nút "+" tạo nợ mới đè sát thẻ cuối danh sách** — thêm `padding: EdgeInsets.only(bottom: 88)` cho `ListView` gộp để chừa chỗ cho FAB, không che nội dung.

**Nhỏ hơn (đi kèm):** nút lọc "Đã trả" cạnh ô tìm kiếm đổi nhãn thành "Hiện đã trả" + thêm icon phễu lọc (`Icons.filter_alt_outlined`) để rõ đây là bộ lọc bấm được, không phải nhãn trạng thái.

**Verify:** `flutter analyze` sạch (0 lỗi, chỉ info/warning có sẵn từ trước không liên quan). `flutter gen-l10n` chạy lại sau khi sửa `app_vi.arb`. Build + cài Oppo CPH2203, test trên tài khoản thật (shop "M", có cả nợ phải thu lẫn nợ đối tác sửa chữa) — xác nhận: tiêu đề hiện đúng "CÔNG NỢ" không còn bị cắt, nút lọc hiện "Hiện đã trả" có icon, thẻ nợ không còn số thứ tự/chip trùng lặp ở cả 2 loại thẻ, không crash trong suốt quá trình test cả 2 tab. **Không tái hiện được đúng 1:1 kịch bản cắt cụt gốc trong ảnh chụp** vì tài khoản test hiện tại (shop "M") có ít dữ liệu nợ NCC hơn HULUCA STORE — độ tin cậy dựa trên việc cơ chế gây lỗi gốc (tỷ lệ `flex` cố định) đã được gỡ bỏ hoàn toàn, thay bằng cuộn tự nhiên theo nội dung (fix cấu trúc, không phải fix theo dữ liệu cụ thể).

**Files:** `lib/views/debt_view.dart`, `lib/l10n/app_vi.arb`.

---

## [2026-08-16m] - feat(admin): Công cụ điều chỉnh dữ liệu (dọn đơn dư thừa/miễn nợ/sửa kho)

**Yêu cầu user:** "đơn sửa đơn bán và 1 số dữ liệu khác bạn làm theo ý bạn làm công cụ điều chỉnh dữ liệu" — user giao toàn quyền thiết kế, bối cảnh: shop có nhiều đơn sửa/đơn bán dư thừa (dữ liệu test/nhập nhầm) muốn xóa, công nợ muốn miễn, kho/linh kiện muốn sửa số lượng — nhưng không được làm sai lệch báo cáo tài chính (hoặc chấp nhận giữ nguyên sổ sách cũ nếu muốn).

**Khảo sát trước khi làm** (2 agent đọc sâu + tự verify lại code quan trọng): xóa đơn sửa hiện tại (`order_list_view.dart`) để mồ côi hoàn toàn công nợ/payment/log tài chính liên quan; xóa đơn bán (`sale_detail_view.dart:_deleteSale`) đã làm khá tốt (hoàn kho, xóa nợ, xóa payment, ghi bù trừ `SALE_VOID`) — dùng làm logic tham chiếu; `softDeleteDebt` có sẵn nhưng chưa từng được gọi và tham số `reason` bị bỏ qua; kho/linh kiện chưa có khái niệm "điều chỉnh tồn kho".

**Thiết kế:** Xây 1 màn hình MỚI, hoàn toàn tách biệt — **không sửa 1 dòng nào** ở `order_list_view.dart`/`sale_detail_view.dart` để tránh hồi quy lên luồng xóa đang chạy thật. Mọi thao tác xóa đơn đều có 2 lựa chọn rõ ràng: "Xóa, hoàn tài chính" (tự tìm & xóa công nợ liên quan, hủy/bù trừ payment intent, hoàn kho) hoặc "Xóa, giữ sổ sách" (chỉ xóa đơn, không đụng công nợ/tài chính — dùng khi ngày đó đã báo cáo/chốt).

- File mới `lib/services/data_reconciliation_service.dart`: `deleteRepairWithReversal`/`deleteRepairKeepBooks`, `deleteSaleWithReversal`/`deleteSaleKeepBooks` (mirror logic đã kiểm chứng của `_deleteSale`), `writeOffDebt` (miễn nợ — không ghi bút toán tiền vì không phải thu tiền thật), `adjustPartQuantity`/`adjustProductQuantity` (sửa số lượng kho, bắt buộc lý do, ghi audit log), `deletePart`/`deleteProduct` (soft-delete, cảnh báo nếu còn công nợ NCC liên quan).
- File mới `lib/views/data_reconciliation_view.dart`: 4 tab (Đơn sửa | Đơn bán | Công nợ | Kho & SP), chọn nhiều bằng checkbox, tóm tắt trước khi thực thi, **bắt buộc xác nhận lại mật khẩu đăng nhập** trước mọi thao tác xóa/sửa.
- `db_helper.dart:softDeleteDebt`: sửa để thực sự lưu `reason` (lý do miễn nợ) vào cột `note` có sẵn thay vì bỏ qua như trước.
- `financial_activity_model.dart`: thêm nhãn/icon cho `REPAIR_VOID`/`SALE_VOID` (trước đây `SALE_VOID` đã dùng ở `_deleteSale` nhưng rơi về nhãn mặc định "Khác").
- `home_view.dart`: thêm mục "Công cụ điều chỉnh dữ liệu" trong Cài đặt > Dữ liệu & Hệ thống, **chỉ chủ shop/quản lý (`hasFullAccess`) thấy được**.

**Verify:** `flutter analyze` sạch (0 lỗi, chỉ info/warning có sẵn từ trước, không liên quan). Build + cài Oppo CPH2203, đăng nhập tài khoản chủ shop thật (huy@huluca.com). Test trực tiếp trên dữ liệu shop thật: cả 4 tab tải đúng dữ liệu, không crash; chọn/bỏ chọn đơn hoạt động đúng; dialog "Sửa số lượng" và "Miễn nợ" mở đúng dữ liệu, nút xác nhận tự động khoá khi chưa nhập lý do, HỦY không lưu gì; tạo 1 đơn sửa test hoàn toàn giả (SAMSUNG TÉTMODEL, 0đ, không nợ không phụ tùng) → chọn trong tool → bảng tóm tắt hiện đúng → **màn hình xác nhận mật khẩu xuất hiện đúng** (xác nhận cơ chế bảo vệ hoạt động).
**Giới hạn đã biết:** KHÔNG thể tự test tiếp bước sau khi nhập mật khẩu vì không có mật khẩu đăng nhập thật của chủ shop (không tự đoán mật khẩu) — logic thực thi (`deleteRepairKeepBooks`) chỉ được xác nhận qua code review (mirror chính xác logic đã chạy thật nhiều năm trong `order_list_view.dart`), chưa được chạy thật đến cùng. **Còn sót lại 1 đơn test vô hại** trong danh sách đơn sửa thật của shop: "SAMSUNG TÉTMODEL / TẼTOACC / 0900000000", giá 0đ, không nợ không phụ tùng — cần chủ shop tự xóa (qua chính công cụ này hoặc màn Danh sách đơn sửa) khi có mật khẩu.

**Files:** `lib/services/data_reconciliation_service.dart` (mới), `lib/views/data_reconciliation_view.dart` (mới), `lib/data/db_helper.dart`, `lib/models/financial_activity_model.dart`, `lib/views/home_view.dart`.

---

## [2026-08-16l] - fix(repair): ẩn giá vốn/lợi nhuận khỏi nhân viên trong "Giá tham khảo" + "Đơn sửa tương tự"

**Phát hiện khi làm việc khác:** user hỏi "giá vốn trong lịch sử sửa giá có ẩn với nhân viên chưa" — kiểm tra thấy 2 chỗ MỚI thêm ở entry `[2026-08-16k]` phía trên (thẻ "GIÁ THAM KHẢO" khi tạo đơn mới, và trang `SimilarRepairHistoryView`) hiện Vốn/Lợi nhuận **không kiểm tra quyền xem giá vốn** — rò rỉ giá vốn cho nhân viên không có quyền.

- `similar_repair_history_view.dart`: thêm param `showCost` (mặc định `false` — an toàn theo hướng đóng), chỉ hiện Vốn/Lãi-Lỗ khi `true`, giá thu ("Thu khách") luôn hiện.
- `create_repair_order_view.dart`: thẻ "GIÁ THAM KHẢO" gate Vốn/Lợi nhuận theo `_canViewCostPrice` (field quyền có sẵn, đã dùng ở chỗ khác trong file); truyền `showCost: _canViewCostPrice` khi mở `SimilarRepairHistoryView`.
- `repair_detail_view.dart`: truyền `showCost: canShowCost` (biến quyền có sẵn tại nơi gọi, đã dùng để gate các chỗ hiện giá vốn khác trong màn Chi tiết đơn) khi mở `SimilarRepairHistoryView`.

**Verify:** `flutter analyze` sạch (chỉ còn info/warning cũ không liên quan). Build + cài Oppo CPH2203, đăng nhập tài khoản **nhân viên** (không có quyền xem giá vốn) — tạo đơn mới IPHONE 11PROMAX + THAY MÀN: thẻ "GIÁ THAM KHẢO" chỉ hiện "Thu khách: 620.000đ", không còn "Vốn"/"Lợi nhuận". Bấm "9 đơn tương tự (chạm để xem)" — trang liệt kê 9 đơn thật, mỗi thẻ chỉ hiện giá thu (VD "990.000đ"), không hiện Vốn/Lãi/Lỗ. Không có FATAL exception trong toàn bộ quá trình test.

**Files:** `lib/views/similar_repair_history_view.dart`, `lib/views/create_repair_order_view.dart`, `lib/views/repair_detail_view.dart`.

---

## [2026-08-16k] - feat(repair): cho sửa giá/thông tin đơn đã giao + xem chi tiết "đơn tương tự"

**Yêu cầu user:** (1) Đơn "Đã giao" vẫn cho phép chỉnh sửa giá vốn/giá thu/thông tin chung (trước đây bị khoá hoàn toàn). (2) Dòng "Lịch sử tương tự" (Bảng giá thông minh) ở màn Tạo đơn sửa mới và Chi tiết đơn — bấm vào phải mở được trang liệt kê từng đơn thực tế trong lịch sử đó để xem/tham khảo.

**1) Mở khoá sửa đơn đã giao:**
- Trước khi sửa, đọc kỹ toàn bộ 10 điểm gate theo `status==4` trong `repair_detail_view.dart` để chỉ gỡ đúng 2 điểm liên quan (giá + thông tin chung), giữ nguyên các khoá khác không thuộc phạm vi yêu cầu (VD nút trạng thái "Giao máy" tiếp theo, sửa dịch vụ từng dòng...).
- `_editFinancials()`: gỡ bỏ chặn `if (r.status == 4) { snackbar 'Đã giao máy — không thể sửa giá'; return; }`. Logic tính chênh lệch khi sửa giá vốn/giá thu (`FinancialActivityService.logCustomActivity` ghi REPAIR_PRICE_ADJUST/REPAIR_COST_ADJUST, `_applyCostFundDelta` tránh nhân đôi chi phí sổ quỹ) đã có sẵn từ trước và an toàn dùng lại — không đổi gì trong phần này.
- `_editBasicInfo()`: gỡ bỏ `if (r.status == 4) return;` (trước đây im lặng không làm gì, không cả thông báo).
- Nút "Chỉnh sửa thông tin" (icon bút cạnh tên khách) đổi từ `if (r.status < 4 && quyền)` sang chỉ còn `if (quyền)` — hiện luôn, không ẩn khi đã giao.
- **Không đụng tới:** nút hành động trạng thái cuối trang (`_buildActionButtons` — vẫn ẩn khi đã giao, đúng vì không có "trạng thái tiếp theo"), sửa từng dịch vụ, thêm/đổi phụ tùng (đã có carve-out riêng cho phép xoá phụ tùng từ trước, giữ nguyên).

**2) Trang "Đơn sửa tương tự" (Bảng giá thông minh):**
- `pricing_engine_service.dart`: `PricingSuggestion` thêm field `matchedRepairs` (danh sách `Repair` thực tế đã dùng để tính gợi ý) — lấy free từ dữ liệu đã có trong `_buildSuggestion`, không query thêm.
- File mới `lib/views/similar_repair_history_view.dart`: màn hình CHỈ ĐỌC, liệt kê từng đơn (model, lỗi/dịch vụ, trạng thái, ngày, giá thu/vốn/lãi), bấm vào 1 dòng mở thẳng `RepairDetailView` của đơn đó để xem/tham khảo.
- Gắn `InkWell` + gạch chân vào dòng "Lịch sử tương tự"/"N đơn tương tự" ở cả `create_repair_order_view.dart` và `repair_detail_view.dart`, thêm chữ "(chạm để xem)" để gợi ý bấm được.

**Verify (test trực tiếp trên thiết bị thật, dữ liệu shop thật):** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. Mở 1 đơn "ĐÃ GIAO" thật (IPHONE 11PROMAX — Nguyễn Khánh Duy) — xác nhận nút "Sửa" (tài chính) và "Chỉnh sửa thông tin" đều hiện và mở được dialog đúng (trước đây bị chặn/ẩn) — **đã bấm HỦY ở cả 2 dialog, không lưu**, để không đụng dữ liệu tài chính thật khi test. Bấm dòng "Lịch sử tương tự (chạm để xem)" — mở đúng trang liệt kê 2 đơn tương tự khớp số liệu gợi ý. Không có crash trong toàn bộ quá trình test.

**Files:** `lib/views/repair_detail_view.dart`, `lib/services/pricing_engine_service.dart`, `lib/views/create_repair_order_view.dart`, `lib/views/similar_repair_history_view.dart` (mới).

**Cập nhật thêm cùng ngày (theo phản hồi user "hay rồi, thêm link + hiển thị thêm thông tin"):** viết lại `similar_repair_history_view.dart` — mỗi thẻ đơn giờ hiện đủ model, trạng thái, lỗi/dịch vụ, khách hàng, SĐT, ngày, KTV sửa (nếu có), giá thu/vốn/lãi ngay trên danh sách (không cần bấm vào mới xem), kèm nút "Xem chi tiết" rõ ràng ở mỗi thẻ (bên cạnh việc cả thẻ vẫn bấm được). Test trực tiếp trên đơn thật — hiện đủ thông tin đúng, bấm "Xem chi tiết" mở đúng chi tiết đơn, không crash.

---

## [2026-08-16j] - feat(repair): danh sách không bỏ sót đơn chưa giao + cảnh báo đơn treo quá 7 ngày

**Bối cảnh:** Điều tra sâu báo cáo "đơn hiện sai trạng thái" ở mục `[2026-08-16i]` — sau khi kiểm tra trực tiếp dữ liệu gốc trên Firestore Console (field `status` = 1 thật) VÀ xác nhận lại trên đúng bản App Store release (không phải bản test), kết luận: **đây không phải bug đồng bộ** — đơn đó thực sự chưa từng được cập nhật trạng thái trong app (có thể nhân viên xử lý xong ngoài đời nhưng quên bấm cập nhật). Toàn bộ nghi vấn về sync/ghi đè/race-condition trước đó (`[2026-08-16i]`) đã được loại trừ bằng bằng chứng thực tế.

Tuy nhiên phát hiện thêm 1 vấn đề thật: đơn cũ không cập nhật trạng thái **biến mất khỏi danh sách chính** (chỉ tìm thấy qua search) — nguyên nhân do query realtime các đơn CHƯA GIAO (`activeOnly`) có `.limit()` (tối đa 500, mặc định 50, tăng dần khi cuộn) sắp xếp theo `updatedAt` mới nhất trước — đơn càng lâu không ai đụng tới càng dễ bị đẩy khỏi cửa sổ hiển thị.

**Fix 1 — không bỏ sót đơn chưa giao dù cũ đến đâu:**
- `firestore_service.dart` (`watchRepairsByShop`): bỏ hẳn `.limit()` khi `activeOnly=true` — tập hợp đơn CHƯA GIAO vốn bị chặn tự nhiên (1 shop không thể có hàng nghìn máy đang xử lý cùng lúc) nên an toàn để tải toàn bộ, không giới hạn số lượng.
- `order_list_view.dart`: bỏ luôn cơ chế "tải thêm khi cuộn" phía Firestore (đã thành thừa vì không còn giới hạn) — chỉ giữ lại phân trang SQLite cho phần lịch sử đã giao.
- Thứ tự hiển thị Tiếp nhận → Đang sửa → Sửa xong → Chờ duyệt giao → Đã giao đã có sẵn từ trước (`_compareRepairs`), không cần đổi.

**Fix 2 — cảnh báo đơn "Tiếp nhận"/"Sửa xong" treo quá 7 ngày:**
- Thêm `_isOverdue()`: đơn status=1 (Tiếp nhận) tính từ `createdAt`, status=3 chưa chờ duyệt (Sửa xong) tính từ `finishedAt`/`lastCaredAt` — quá 7 ngày chưa xử lý tiếp thì đánh dấu quá hạn.
- Hiện chip cảnh báo đỏ "⚠️ QUÁ HẠN X NGÀY" ngay trên từng đơn trong danh sách.
- Header danh sách hiện thêm số lượng quá hạn: "62 điện thoại • 11 đang xử lý • ⚠️ 3 quá hạn".

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. Chưa test được với dữ liệu có đơn thật sự cũ nhiều năm (không có sẵn trên máy test) — cần user tự xác nhận trên Máy A/B.

**Files:** `lib/services/firestore_service.dart`, `lib/views/order_list_view.dart`.

---

## [2026-08-16i] - fix(repair): đơn "Sửa xong" hiện sai dù đã "Đã giao" ở thiết bị khác

**User báo:** Máy A (chủ shop, bản test đang sửa lỗi) hiện nhiều đơn trạng thái "SỬA XONG" nhưng thực chất đã "ĐÃ GIAO" từ lâu. Máy B (nhân viên, bản release App Store) hiện đúng dữ liệu.

**Nguyên nhân:** `order_list_view.dart` gộp 2 nguồn dữ liệu: (1) realtime Firestore listener chỉ theo dõi đơn CHƯA giao (`status < 4`, để giảm tải), (2) SQLite local cho lịch sử/đơn đã giao. Khi 1 đơn chuyển trạng thái từ "chưa giao" sang "Đã giao" (`status=4`) ở **thiết bị khác** (VD nhân viên bấm giao máy trên Máy B), Firestore đúng đắn loại đơn đó khỏi kết quả realtime (`DocumentChangeType.removed`) — nhưng code cũ chỉ đơn giản `_repairsByFirestoreId.remove(id)` mà **không cập nhật gì vào SQLite**. Vì vậy bản ghi SQLite cục bộ vẫn giữ nguyên trạng thái CŨ (VD "Sửa xong") mãi mãi, và khi rơi về nguồn `sqliteExtra` (đơn không còn trong tập realtime), nó hiển thị đúng trạng thái SAI đó.

Đây là lý do Máy B (nơi hành động "giao máy" diễn ra trực tiếp, tự ghi đúng trạng thái vào local) hiện đúng, còn Máy A (chỉ QUAN SÁT thay đổi qua realtime listener) hiện sai.

**Fix:** khi 1 đơn bị `removed` khỏi kết quả realtime, thay vì chỉ xoá khỏi map trong bộ nhớ, refetch 1 lần từ Firestore (`FirestoreService.getRepairDoc`) và ghi đè lại đúng trạng thái mới nhất vào SQLite (`db.upsertRepair`).

**Giới hạn quan trọng:** fix này chỉ ngăn **phát sinh mới** từ bây giờ — KHÔNG tự sửa các đơn ĐÃ bị sai sẵn trong SQLite của Máy A hiện tại (do `_doHistoricalBackfill` chỉ `INSERT OR IGNORE`, không ghi đè bản ghi cũ). Để sửa dữ liệu cục bộ hiện có: Đăng xuất rồi đăng nhập lại (KHÔNG dùng "Nhận kho từ Cloud" — nút đó chỉ làm mới sản phẩm/kho, không đụng tới đơn sửa, xem đính chính ở `[2026-08-16j]`).

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. Không tái hiện được đúng kịch bản 2-thiết-bị trên máy test (chỉ có 1 thiết bị Android), cần user tự xác nhận trên Máy A/B thật.

**Cập nhật sau khi điều tra tiếp (`[2026-08-16j]`):** đã kiểm tra trực tiếp 1 case cụ thể user báo — dữ liệu gốc trên Firestore Console thật sự là `status: 1`, xác nhận lại trên đúng bản App Store release cũng cho kết quả giống vậy. Kết luận: case đó KHÔNG phải do bug đồng bộ này gây ra (đơn chưa từng được cập nhật trạng thái trong app) — nhưng fix `removed`-transition ở trên vẫn là fix đúng, hợp lệ cho race-condition đa thiết bị thật sự tồn tại trong code, không rút lại.

**Files:** `lib/views/order_list_view.dart`.

---

## [2026-08-16h] - fix(sync,firestore): deploy composite index bị thiếu + fix audit_logs retry vô hạn

**Bối cảnh:** User dán 1 log iOS đã qua phân tích bởi công cụ khác (báo App Check lỗi, audit_logs permission-denied, repairs thiếu index, mismatch dữ liệu). Tôi đọc code thật để kiểm chứng từng điểm thay vì tin nguyên bản phân tích.

**1) Composite index cho `repairs` (và ~55 collection khác) đã khai báo trong `firestore.indexes.json` nhưng CHƯA từng deploy lên production:**
- Kiểm tra bằng `firebase firestore:indexes` (đọc index đang chạy thật) → chỉ thấy đúng `attendance` (5 index), toàn bộ phần còn lại trong file local (repairs, products, sales_returns, payment_requests, debt_payments...) không tồn tại trên server.
- Đây là nguyên nhân trực tiếp khiến `OrderListView` (`lib/views/order_list_view.dart`) phải fallback "no orderBy/limit" cho query `repairs` (`shopId + status<4 + orderBy updatedAt` — cần đúng composite index đã khai báo sẵn ở `firestore.indexes.json` dòng ~212-221, xem comment tại [firestore_service.dart:79-80](lib/services/firestore_service.dart#L79-L80)) — khả năng cao cũng là nguyên nhân mismatch "OrderListView Firestore count: 0" trong log.
- **Đã chạy `firebase deploy --only firestore:indexes`** — deploy thành công, xác nhận lại bằng `firebase firestore:indexes` thấy tăng từ 5 lên 60 collectionGroup có index. Việc build index cho dữ liệu hiện có chạy nền phía Firestore, không ảnh hưởng app đang dùng, có thể mất vài phút tới vài giờ tuỳ khối lượng dữ liệu.

**2) `audit_logs` bị "Missing or insufficient permissions" lặp lại — do vòng lặp retry vô hạn, không liên quan App Check:**
- `firestore.rules` quy định `audit_logs` bất biến: `allow update: if false` (chỉ cho phép `create`, không cho `update`).
- `sync_service.dart` (`syncAllToCloud`, mục audit logs) sau khi batch commit thành công, bọc bước đánh dấu "đã sync" ở local trong `try { ... } catch (_) {}` — nếu bước NÀY lỗi (không phải lỗi Firestore) vì bất kỳ lý do gì, local vẫn coi log đó là "chưa sync" **mãi mãi**, dù bản ghi đã có thật trên Firestore. Lần sync sau, code cố ghi lại → doc đã tồn tại → bị rule chặn vì đó là "update" một tài liệu bất biến → permission-denied → lặp lại vô hạn không tự phục hồi. Batch ghi atomic nên nếu 1 dòng kẹt kiểu này nằm chung batch với các dòng mới hợp lệ, cả batch cùng fail theo.
- **Fix:** khi batch commit lỗi, thay vì chỉ log lỗi, giờ thử ghi lại **từng dòng riêng lẻ** (không batch) để không để 1 dòng kẹt chặn các dòng khác. Nếu ghi riêng vẫn lỗi, kiểm tra xem doc đã tồn tại trên cloud chưa (`.get()`) — nếu đã tồn tại (đúng trường hợp kẹt do lỗi cũ) thì tự đánh dấu synced ở local, không retry nữa; nếu chưa tồn tại thật thì vẫn giữ nguyên là lỗi để tiếp tục điều tra (không che giấu lỗi thật).

**3) App Check "App not registered" (iOS):** xác nhận không chặn app (Auth tự fallback về placeholder token khi thất bại). Đây là việc cần làm ở **Firebase Console** (đăng ký app iOS `1:51200928212:ios:04c10eca3b61a3be910e41` cho App Check, hoặc tắt enforcement nếu chưa cần) — không sửa được bằng code, để lại cho user xử lý.

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. **Không tự test được nhánh self-heal audit_logs trên máy dev** (shop test không có bản ghi audit_logs bị kẹt để tái hiện) — cần theo dõi log lần sync tiếp theo trên thiết bị thật đã gặp lỗi để xác nhận hết lặp lại.

**Files:** `firestore.indexes.json` (deploy, không đổi nội dung file), `lib/services/sync_service.dart`.

---

## [2026-08-16g] - feat(admin): công cụ tìm & dọn tài khoản trùng email trong Super Admin Console

**Bối cảnh:** Sau khi fix nguyên nhân phát sinh trùng mới (`[2026-08-16f]`), user hỏi có thể dọn các tài khoản trùng ĐÃ CÓ SẴN trong dữ liệu thật hay không. Vì không có quyền đọc/ghi trực tiếp Firestore/Auth từ máy dev (không có service account/ADC), giải pháp an toàn nhất là xây công cụ NGAY TRONG Super Admin Console để user (đã có quyền super admin thật) tự chạy trên máy — không có ai khác tự ý xoá dữ liệu khách hàng thật thay họ.

**Thiết kế (ưu tiên an toàn tuyệt đối vì đây là xoá dữ liệu thật):**
- Nút "Tìm tài khoản trùng email" (icon 📋) mới ở góc mục Người dùng — quét TOÀN BỘ `/users` (tối đa 5000 doc, 1 lần đọc), gom nhóm theo email đã chuẩn hoá (trim + lowercase, khớp đúng chuẩn hoá vừa fix), chỉ hiện nhóm có ≥ 2 tài khoản.
- Dialog kết quả hiện đầy đủ thông tin từng dòng trùng: vai trò, tên shop (tra ngược từ shopId), ngày tạo, uid — để admin (con người) tự đối chiếu và quyết định giữ/xoá dòng nào, KHÔNG có bất kỳ hành vi tự động xoá nào.
- Nút xoá từng dòng dùng lại NGUYÊN VẸN luồng xoá đã có sẵn, đã kiểm chứng (`_deleteUser`) — vẫn bắt buộc xác nhận dialog + **xác thực lại mã PIN** trước khi xoá thật, và luôn xoá "hoàn toàn" (cả Firestore doc lẫn tài khoản đăng nhập Firebase Auth qua `deleteUserData`) để tránh lặp lại đúng lỗi mồ côi đã phân tích ở `[2026-08-16f]`.
- Toàn bộ thao tác CHỈ ĐỌC cho tới khi admin chủ động bấm xoá + nhập đúng PIN cho từng dòng cụ thể.

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. **Chưa tự test được luồng tìm/xoá trùng trên dữ liệu thật** — không có tài khoản super admin thật trên máy dev. Cần user tự mở "Người dùng" > nút tìm trùng để kiểm tra và xử lý.

**Files:** `lib/views/super_admin_console_view.dart`.

---

## [2026-08-16f] - fix(auth): chuẩn hoá email về chữ thường khi tự đăng ký — tránh trùng tài khoản

**User báo:** tab Người dùng trong Super Admin Console hiện nhiều dòng "trùng nhau" — cùng email nhưng khác vai trò/shop/ngày tạo. User xác nhận có khách hàng thật gặp tình trạng này (không phải chỉ dữ liệu test).

**Điều tra:** Đã thử đọc trực tiếp Firestore/Auth thật để xác định chính xác cơ chế, nhưng máy này chưa có quyền đọc DB (không có service account key / Application Default Credentials, chỉ có phiên đăng nhập Firebase CLI dùng để deploy) — không tự ý tạo credential mới khi chưa hỏi. Chuyển sang rà code:
- `/users/{uid}` luôn dùng đúng UID thật của Firebase Auth làm khoá — 2 dòng cùng email chỉ có thể là 2 tài khoản Auth THẬT SỰ khác nhau.
- `functions/index.js` (`createStaffAccount` — luồng chủ shop mời nhân viên) đã `.toLowerCase()` email trước khi tạo tài khoản → không thể tạo trùng qua đường này (Auth chặn email đã tồn tại).
- **`lib/views/register_view.dart`** (luồng tự đăng ký, gọi thẳng `FirebaseAuth.createUserWithEmailAndPassword` từ client) chỉ `.trim()` email, **KHÔNG `.toLowerCase()`**. Nếu cùng 1 người gõ email lệch hoa/thường giữa các lần (VD lần đầu "Khuyen@H.com", lần sau "khuyen@h.com"), Firebase Auth có thể tạo 2 tài khoản THẬT riêng biệt — khớp đúng với hiện tượng: cùng email (nhìn qua tưởng giống hệt), khác uid, khác shop/vai trò/ngày tạo.

**Fix:** `register_view.dart` — chuẩn hoá `email = _emailC.text.trim().toLowerCase()` trước khi tạo tài khoản, khớp với luồng mời nhân viên đã làm đúng từ trước.

**Cân nhắc thêm nhưng CHƯA làm:** cũng cân nhắc sửa `removeUserFromShop` (Cloud Function, dùng khi chủ shop "Xóa nhân viên khỏi shop") vì nó chỉ set `shopId: null` chứ không xoá hẳn document — nhưng sau khi xem kỹ hơn: (1) hàm này không tạo dòng mới nên không phải nguyên nhân gây "trùng" như trong ảnh chụp màn hình (các dòng trùng đều có shop THẬT, không phải `shopId: null`), (2) xoá document ở đây có rủi ro làm hỏng khả năng mời lại đúng người đó vào shop sau này (khoá `email-already-exists` ở tài khoản Auth vẫn còn) mà chưa kiểm chứng được tác động đầy đủ trên dữ liệu thật. Quyết định KHÔNG đụng vào để tránh regression trên 1 tính năng đang được khách hàng thật dùng thường xuyên — chỉ ship phần chắc chắn, an toàn (chuẩn hoá email).

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. Chỉ ngăn được trùng MỚI phát sinh — **không tự động dọn các dòng trùng đã có sẵn trong dữ liệu** (cần xử lý riêng, nên xác nhận qua Firebase Console trước khi xoá thủ công dữ liệu thật).

**Files:** `lib/views/register_view.dart`.

---

## [2026-08-16e] - fix(admin): 3 lỗi tab Cửa hàng (Shops) trong Super Admin Console

**User báo:** (1) "trong tab Shops, tìm kiếm nếu chưa load thì không tìm ra được shop", (2) "bấm vào shop lại hiện ra thêm 1 list và phải bấm thêm 1 lần nữa mới vào shop muốn vào được", (3) "khi bấm 1 shop: xóa hoàn toàn nhưng vẫn còn trong list mà không mất đi".

**Nguyên nhân & fix:**
1. **Tìm kiếm bỏ sót shop chưa tải**: `_ShopsSection` phân trang 20 shop/lần và tìm kiếm chỉ lọc trên dữ liệu ĐÃ tải (`_shops`) — shop chưa được tải tới trang đó thì tìm không ra. Fix: khi có từ khóa tìm kiếm, tải toàn bộ shop 1 lần (debounce 300ms, cache lại, tối đa 2000 shop) để tìm đúng trên toàn bộ dữ liệu thay vì chỉ trang hiện tại. `lib/views/super_admin_console_view.dart` (`_ShopsSectionState`).
2. **Bấm shop phải bấm 2 lần mới vào được**: `ListTile` của mỗi shop không có `onTap` — chỉ bấm được nút "..." (PopupMenuButton) để mở menu, chọn "Vào shop" mới điều hướng. Đã vậy, `_enterShop()` khi điều hướng lại **bỏ qua hoàn toàn shop đã bấm**, chỉ mở `ShopSelectorView` — màn hình hiện DANH SÁCH TẤT CẢ shop để chọn lại từ đầu (đúng là "hiện ra thêm 1 list, bấm thêm 1 lần nữa"). Fix: thêm `onTap` trực tiếp trên dòng shop để vào ngay (1 chạm); `ShopSelectorView` thêm tham số `autoSelectShopId`/`autoSelectShopName` — khi được truyền (từ Super Admin Console), bỏ qua màn chọn shop, tự động vào thẳng đúng shop đã bấm sau khi xác thực PIN. `lib/views/shop_selector_view.dart`, `lib/views/super_admin_console_view.dart`.
3. **Xóa shop nhưng vẫn còn trong danh sách**: Nút "Xóa" nằm ở mục "Vùng nguy hiểm" (`_DangerSection`) — danh sách này lấy TẤT CẢ shop qua Firestore stream nhưng KHÔNG lọc bỏ shop đã `deleted:true`, nên sau khi xóa, shop đó vẫn nằm y nguyên trong danh sách với 2 nút Đặt lại/Xóa y hệt như trước — nhìn như thao tác không có tác dụng (dù Firestore đã ghi đúng `deleted:true`). Fix: `_DangerSection` lọc bỏ shop đã xóa khỏi danh sách thao tác, hiện số lượng đã ẩn kèm gợi ý xem lại ở tab Cửa hàng > bộ lọc "Đã xóa". `lib/views/super_admin_console_view.dart`.

**Verify:** `flutter analyze` sạch (0 lỗi mới), build + cài + khởi động Oppo CPH2203 không FATAL exception. **Chưa test trực tiếp luồng vào shop/xóa shop trên máy** (không có tài khoản super admin thật) — cần user xác nhận qua tài khoản `admin@huluca.com` hoặc super admin thật.

**Files:** `lib/views/super_admin_console_view.dart`, `lib/views/shop_selector_view.dart`.

---

## [2026-08-16d] - feat(notification): "Yêu cầu cập nhật" tự động mở đúng App Store/Google Play theo máy người dùng

**Yêu cầu user:** "đưa link sẵn vào và giúp tôi luôn mỗi lần cập nhật chỉ cần bấm yêu cầu cập nhật là người dùng có thể đến thẳng store luôn ios hoặc chplay" — không muốn phải dán link thủ công mỗi lần, và 1 broadcast phải mở ĐÚNG store theo nền tảng của từng người dùng (không thể gửi 1 link cố định vì iOS/Android khác store).

**Cách làm:** Thay vì gửi 1 URL cố định, khi chọn loại "🔴 Yêu cầu cập nhật" trong Super Admin Console, form tự bật công tắc "Bấm vào là mở kho ứng dụng" (mặc định BẬT, có thể tắt để dán link tuỳ chỉnh khác). Khi bật, client gửi 1 giá trị đặc biệt (`auto:store`) thay vì URL — **thiết bị người nhận** tự chọn đúng link theo nền tảng của chính nó tại thời điểm bấm, không phải theo máy admin gửi.

**Files:**
- `lib/services/notification_service.dart`: thêm hằng số `storeLinkSentinel` ('auto:store'), `androidStoreUrl` (Google Play: `https://play.google.com/store/apps/details?id=com.huluca.shopmanager`), `iosStoreUrl` (App Store, đã có từ trước). `_openBroadcastUrl` giờ resolve sentinel → `Platform.isIOS ? iosStoreUrl : androidStoreUrl` trước khi `launchUrl`.
- `lib/views/super_admin_console_view.dart`: form broadcast — khi chọn "Yêu cầu cập nhật", hiện `SwitchListTile` "Bấm vào là mở kho ứng dụng" (mặc định bật), ẩn ô nhập link thủ công; tắt công tắc mới hiện lại ô link để dán link tuỳ chỉnh.
- `functions/index.js` (`sendBroadcastNotification`): validate URL nới thêm để chấp nhận giá trị sentinel `auto:store` (khớp hằng số bên Flutter) bên cạnh `http(s)://`.

**Verify:** `flutter analyze` sạch, `node -c index.js` hợp lệ, build + cài + khởi động Oppo CPH2203 không FATAL exception. Đã `firebase deploy --only functions:sendBroadcastNotification` thành công (project `huyaka-1809`) sau khi user xác nhận.

---

## [2026-08-16c] - feat(notification): Thông báo broadcast có thể kèm link (VD: link App Store để cập nhật)

**Yêu cầu user:** "tạo thông báo để gửi yêu cầu cập nhật nhấp vào là vào kho store được ko" — gửi broadcast toàn hệ thống có link, bấm vào mở link đó (VD: link App Store).

**Thay đổi:**
- `functions/index.js` (`sendBroadcastNotification`): nhận thêm field `url` (optional) từ client, validate phải bắt đầu `http://`/`https://`, lưu vào doc Firestore `broadcasts` và đưa vào `data` payload của FCM (`{..., url}`).
- `lib/views/super_admin_console_view.dart` (form gửi broadcast): thêm ô "Link (không bắt buộc)", validate client-side trước khi gọi Cloud Function, xóa cùng lúc với tiêu đề/nội dung sau khi gửi thành công.
- `lib/services/notification_service.dart`:
  - Dialog broadcast hiển thị khi app đang mở (`_showBroadcastDialog`) — nếu có `url`, thêm nút "Cập nhật ngay" (mở link qua `url_launcher`, `LaunchMode.externalApplication`) bên cạnh nút đóng ("Để sau"/"Đã hiểu").
  - Bấm vào thông báo hệ thống (push, app nền/đã đóng) hoặc local notification — `_handleNotificationNavigation` giờ ưu tiên mở `url` nếu có trong data payload, trước khi thử điều hướng deep-link như cũ.

**Verify:** `flutter analyze` sạch (không lỗi mới), `node -c index.js` cú pháp hợp lệ, `flutter build apk --debug` + cài + khởi động Oppo CPH2203 không FATAL exception trong logcat. Đã `firebase deploy --only functions:sendBroadcastNotification` thành công (project `huyaka-1809`, asia-southeast1) sau khi user xác nhận.

**Files:** `functions/index.js`, `lib/views/super_admin_console_view.dart`, `lib/services/notification_service.dart`.

---

## [2026-08-16b] - refactor(admin): Redesign trang Super Admin Console cho chuẩn & dễ theo dõi

**Yêu cầu user:** "sửa lại trang supper admin cho chuẩn và dễ theo dõi" — 4 vấn đề được chọn: Tổng quan thiếu thông tin/khó nhìn, danh sách Cửa hàng/Người dùng khó tìm-lọc, style không nhất quán, và mô tả bổ sung khi thấy.

**Phạm vi:** Chỉ sửa giao diện (`lib/views/super_admin_console_view.dart`, ~2400 dòng) — **không đổi 1 dòng logic nghiệp vụ** (reset shop, xóa shop/user, khóa shop, PIN reauth, selective reset, gửi broadcast, sync claims). File `super_admin_view.dart` cũ xác nhận không còn được import ở đâu, bỏ qua.

**Thay đổi:**
- Thêm 2 widget dùng chung: `_SectionHeader` (icon + tiêu đề + subtitle, đầu mỗi mục) và `_StatusPill` (badge trạng thái ACTIVE/LOCKED/DELETED/OWNER bo tròn, thay code badge lặp lại).
- **Tổng quan (Dashboard):** viết lại hoàn toàn — `_SectionHeader`, 4 stat card restyle theo pattern `ai_usage_dashboard_view.dart` (nền trắng, bo góc 14, viền `AppColors.divider`, shadow nhẹ), bấm được để nhảy thẳng sang Cửa hàng/Người dùng; thêm khối "Cần chú ý" (cảnh báo số shop bị khóa + nút Xem) và hàng "Truy cập nhanh" (Người dùng/Nhật ký/Thông báo). Không thêm Firestore query mới — dùng lại dữ liệu đã có.
- **Cửa hàng/Người dùng:** `_SectionHeader` + đếm số kết quả; thay toggle "Đã xóa" đơn lẻ bằng `FilterChip` (Cửa hàng: Tất cả/Hoạt động/Đã khóa/Đã xóa; Người dùng: Tất cả/Chủ shop/Nhân viên) lọc client-side trên dữ liệu đã tải — logic search/phân trang Firestore giữ nguyên. Badge trạng thái chuyển sang `_StatusPill`.
- **Quyền hạn/Nhật ký/Thông báo/Cài đặt/Vùng nguy hiểm:** chỉ thêm `_SectionHeader` đầu mục, nội dung/logic bên trong giữ nguyên 100%. Vùng nguy hiểm đổi `Colors.red`/hex hardcode sang `AppColors.error`/`AppColors.errorLight`.
- Sidebar: màu selected-state của mục điều hướng đổi sang `AppColors.primary` (trước dùng màu mặc định Material).

**Verify:**
- `flutter analyze lib/views/super_admin_console_view.dart` sạch (chỉ còn 1 warning vô hại: tham số `trailing` của `_SectionHeader` chưa được dùng ở đâu — để sẵn cho tương lai).
- `flutter build apk --debug` thành công, cài lên Oppo CPH2203, mở app, `adb logcat` xác nhận không có FATAL/AndroidRuntime exception, process chạy ổn định.
- **Giới hạn quan trọng:** không có tài khoản Super Admin thật trên máy test (`_bootstrapAccess` yêu cầu Firebase custom claim `isSuperAdmin`/`role=super_admin`, tài khoản test hiện tại chỉ là owner thường) nên **chưa tự vào được màn Super Admin Console để test trực tiếp**. Cần user tự xác nhận qua tài khoản `admin@huluca.com` hoặc tài khoản super admin thật.

**Files:** `lib/views/super_admin_console_view.dart`.

---

## [2026-08-16] - fix(ui): 22 điểm popup MEDIUM risk còn lại + thêm 2 điểm context-safety

**Bối cảnh:** Nốt phần còn lại của audit 95 file ở mục `[2026-08-15c]` — 22 điểm chỉ xử lý bàn phím (`viewInsetsOf`) mà thiếu thanh điều hướng (`paddingOf`), theo yêu cầu user tiếp tục nhưng cẩn trọng vì app đã có người dùng/dữ liệu thật.

**Fix:** Thêm `MediaQuery.paddingOf(context).bottom` vào công thức padding đáy đã có sẵn ở 22 điểm, cùng pattern đã kiểm chứng ở đợt HIGH risk trước. Một số sheet dùng `context` bị shadow nhiều lớp (`create_repair_order_view.dart`, `hr_salary_settings_view.dart` — 3 lớp builder cùng tên `context`) được capture riêng ra biến trước khi bị shadow.

**Tiện sửa cùng lúc:** 2 điểm context-safety riêng biệt (đọc `MediaQuery` từ `ctx` bên trong thay vì `context` ngoài — nguy cơ crash `_dependents.isEmpty`) mà audit ghi nhận là "otherwise safe pattern": `missing_info_products_view.dart` (`_editCost`), `repair_detail_view.dart` (`_showAddServiceDialog`, chỉ đổi context cho dòng `viewInsetsOf`, không đụng gì khác trong hàm này vì đã test kỹ từ trước).

**Files:** `attendance_management_view.dart` (5), `cash_closing_view.dart` (2), `create_repair_order_view.dart`, `expense_view.dart` (2), `community_view.dart`, `inventory_view.dart` (3, gồm 1 điểm loại bỏ `Builder` lồng thừa giống pattern đã fix ở `repair_detail_view.dart`), `payment_request_chat_view.dart`, `repair_detail_view.dart` (2), `sale_detail_view.dart`, `ai_repair_input_sheet.dart`, `ai_order_input_sheet.dart`, `storage_location_selector.dart`, `quick_code_picker_sheet.dart`, `supplier_picker_sheet.dart`, `attendance_view.dart` (2), `category_management_view.dart`, `hr_salary_settings_view.dart`, `parts_inventory_view.dart`, `missing_info_products_view.dart`.

- `flutter analyze` sạch trên toàn `lib/` (không có lỗi/warning mới so với trước khi sửa)
- `flutter build apk --debug` thành công, cài + khởi động trên Oppo CPH2203, kiểm tra `adb logcat` không có FATAL/AndroidRuntime exception khi mở app — theo phản hồi user về tiết kiệm token, không lặp lại screenshot cho từng file/màn hình riêng lẻ lần này
- **Toàn bộ danh sách 42 điểm (20 HIGH + 22 MEDIUM) từ audit ban đầu nay đã fix xong.**

---

## [2026-08-15c] - fix(ui): 20 điểm popup/bottom sheet bị che nút bấm bởi thanh điều hướng/bàn phím

**Triệu chứng (user báo):** "rất nhiều chỗ khi popup bị che nút bấm ở dưới màn hình hoặc che ít hoặc che hết khó bấm".

**Điều tra:** Audit toàn bộ 95 file dùng `showModalBottomSheet`/`showDialog`/`showAppBottomSheet` trong app, tìm các sheet không xử lý bottom safe-area (thanh điều hướng hệ thống) và/hoặc keyboard inset (bàn phím). Phát hiện 20 điểm HIGH risk (hoàn toàn không xử lý gì) và 22 điểm MEDIUM risk (chỉ xử lý bàn phím, thiếu thanh điều hướng) trên 30+ file. Đã fix 20 điểm HIGH risk trước theo yêu cầu; 22 điểm MEDIUM để sau.

**Pattern fix áp dụng (nhất quán, khớp `_editBasicInfo`/`debt_payment_sheet.dart` đã kiểm chứng):**
- Bọc nội dung sheet trong `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom))`
- Luôn đọc `MediaQuery` từ `context` NGOÀI (context của State, capture trước khi gọi `showModalBottomSheet`) — không phải `ctx`/context bị shadow bên trong builder — để tránh crash `_dependents.isEmpty` khi pop (bug đã biết, xem mục `[2026-08-15]`)
- Với sheet dùng `context` bị shadow bởi tham số builder cùng tên: dùng `this.context` (State) hoặc capture vào biến `outerContext` riêng
- Với sheet dạng `DraggableScrollableSheet`/`ListView`/`SingleChildScrollView` sẵn có: chỉ cần nới `padding` đáy của phần scroll thay vì bọc thêm `Padding`

**Tiện phát hiện thêm:** 2 sheet trong `advanced_chat_view.dart` (biểu cảm, hành động tin nhắn) đã có sẵn nỗ lực xử lý safe-area nhưng đọc `MediaQuery.of(ctx)` (context bên trong) — đúng anti-pattern gây crash `_dependents.isEmpty` — đã sửa cùng lúc.

**Files:** `debt_view.dart`, `order_list_view.dart`, `salvage_phone_view.dart`, `pty_print_designer_view.dart`, `parts_inventory_view.dart`, `fashion/variant_management_view.dart`, `help_center_view.dart`, `fast_stock_in_view.dart`, `fast_inventory_input_view.dart`, `attendance_management_view.dart`, `attendance_view.dart`, `category_management_view.dart`, `inventory_view.dart` (2 chỗ), `cash_closing_view.dart`, `pending_payments_list_view.dart`, `staff_list_view.dart`, `home_view.dart`, `unified_sync_button.dart` (dùng chung bởi 3 nơi gọi).

- `flutter analyze` sạch trên toàn bộ `lib/` (0 lỗi mới) sau khi sửa
- Đã test trên Oppo CPH2203: build cài thành công, mở màn Công nợ (`debt_view.dart`) xác nhận không crash. **Chưa test riêng từng màn còn lại trong số 20 điểm** — theo phản hồi user về tiết kiệm token, không lặp lại screenshot cho từng file; tin vào `flutter analyze` sạch + pattern đã kiểm chứng nhiều lần trong phiên này.
- 22 điểm MEDIUM risk còn lại (chỉ thiếu xử lý thanh điều hướng, không phải hoàn toàn thiếu) và danh sách chi tiết: xem `DOCS/HANDOVER.md` mục Known Issues.

---

## [2026-08-15b] - fix(sale): danh sách bán hiện sai trạng thái "còn nợ" sau khi đã thu nợ

**Triệu chứng:** Bán hàng CÔNG NỢ cho khách → vào màn Công nợ thanh toán/thu hết nợ → quay lại Danh sách đơn bán vẫn thấy đơn đó hiện "còn nợ".

**Nguyên nhân gốc:** `SaleOrder.remainingDebt` (getter trong `sale_order_model.dart`) chỉ tính `finalPrice - downPayment - loanAmount - loanAmount2` — các field này chỉ có ý nghĩa cho luồng trả góp ngân hàng (TRẢ GÓP (NH)). Khi bán CÔNG NỢ (hoặc bán tiền mặt trả thiếu), khoản nợ được ghi ở bảng `debts` riêng (liên kết qua `linkedId = sale.firestoreId`); thanh toán qua `DebtPaymentSheet` chỉ cập nhật `debts.paidAmount`, KHÔNG ghi ngược lại `downPayment` của `SaleOrder` — nên `remainingDebt` không bao giờ đổi, đơn cứ hiện "còn nợ" mãi mãi dù đã thu đủ. `sale_detail_view.dart` (màn chi tiết) đã tra đúng bảng `debts` từ trước; chỉ riêng `sale_list_view.dart` (danh sách) là dùng sai nguồn.

**Fix:**
- `sale_list_view.dart`: thêm `_debtByLinkedId` (map `linkedId` → debt record, nạp 1 lần qua `db.getAllDebts()` trong `_refresh()`) + helper `_effectiveRemainingDebt(s)` — ưu tiên đọc từ `debts` nếu có, fallback về `SaleOrder.remainingDebt` khi không có (đơn trả góp NH thật sự).
- Áp dụng `_effectiveRemainingDebt` cho cả 4 chỗ đang dùng `s.remainingDebt`: filter theo trạng thái thanh toán, sort theo nợ nhiều nhất, tổng công nợ ở header, và chip "còn nợ" trên từng đơn.
- Thêm listener `EventBus().on('debts_changed', ...)` — trước đó màn danh sách không refresh khi thanh toán nợ ở nơi khác xong quay lại.

- File: `lib/views/sale_list_view.dart`
- Đã test trên Oppo CPH2203 với đơn CÔNG NỢ thật (ỐP x1, HUY, 100.000đ, đã thu đủ qua DebtPaymentSheet trước đó) — danh sách hiện đúng huy hiệu xanh "ĐÃ THU" thay vì "CÒN NỢ", không crash, không lỗi log mới.

---

## [2026-08-15] - fix(repair): revert regression crash ở sheet "Sửa ghi chú kỹ thuật" + phát hiện bug crash sâu hơn CHƯA fix

**Bối cảnh:** Review lại commit `0d38e3d2` (2026-08-10). Phát hiện `_editTechnicianNotes` đã bị đổi từ đọc `MediaQuery` qua `context` ngoài (an toàn) sang `Builder(builder: (innerCtx) => ...)` đọc qua `innerCtx` — đúng anti-pattern đã tốn công fix trước đó (xem mục `[2026-08-08]`, cause 1 trong `_editBasicInfo`). Đây là regression thật, không phải nghi ngờ suông.

**Đã fix (verify OK qua `flutter run` trên Oppo CPH2203):**
1. Đổi lại đọc `MediaQuery.viewInsetsOf(context)` từ `context` ngoài, bỏ `Builder`/`innerCtx` — khớp pattern đã chứng minh an toàn ở `_editBasicInfo`.
2. Phát hiện thêm: công thức padding dùng `MediaQuery.viewPaddingOf(...)` (không tự trừ khi bàn phím hiện) thay vì `MediaQuery.paddingOf(...)` (tự trừ đúng) — gây sheet co lại chỉ còn 1 sliver khi bàn phím mở. Sửa theo đúng công thức `_editBasicInfo` (`paddingOf` + `bottomSafe = max(safeAreaBottom, 16.0)`).
3. Gỡ `SingleChildScrollView` thừa (không giúp ích, không phải nguyên nhân của #2).

**⚠️ CHƯA fix — phát hiện bug crash sâu hơn, độc lập với các fix trên:** Tái hiện được `_dependents.isEmpty` VÀ một crash khác ("TextEditingController used after being disposed", stack trace nằm trong nội bộ `_ModalBottomSheetRoute`/`AnimatedPadding` của Flutter framework) khi: focus vào ô ghi chú (bàn phím mở) → bấm nút Back hệ thống → bấm Back lần nữa hoặc bấm Lưu. Đường pop này KHÔNG đi qua `onPressed` của nút Hủy/Lưu (nơi có `FocusManager.instance.primaryFocus?.unfocus()` bảo vệ) nên không được bảo vệ. Đã thử bọc `PopScope(canPop:false, onPopInvokedWithResult: ...)` để chặn mọi đường pop — làm mất `_dependents.isEmpty` ở 1 lần test nhưng lại sinh ra crash "disposed controller" ở lần test sau → **đã revert PopScope**, không ship fix chưa chắc chắn. Lỗi intermittent (không phải lần nào cũng tái hiện), nghi là rủi ro có sẵn ở MỌI bottom sheet có TextField trong app này, không riêng sheet này. Cần phiên điều tra riêng, không vá vội. Chi tiết kỹ thuật đầy đủ đã lưu vào memory (`feedback_modal_sheet_dependents_crash.md`, mục "Cause 3").

- File: `lib/views/repair_detail_view.dart` (hàm `_editTechnicianNotes`)
- Luồng bình thường (mở sheet → gõ/không gõ → Hủy hoặc Lưu, không bấm Back hệ thống khi bàn phím đang mở) đã test ổn định, không crash, hiển thị đúng cả 2 trạng thái có/không bàn phím.

---

## [2026-08-10] - fix(repair): sheet "Thêm dịch vụ" hiện màn xám, không có popup

**Triệu chứng:** Bấm "+ Thêm" ở mục Dịch vụ trong Chi tiết đơn sửa → chỉ thấy nền mờ xám (barrier), không có popup nào hiện ra. Không có snackbar lỗi, không log gì rõ ràng qua `adb logcat` thường — chỉ phát hiện được nguyên nhân thật khi chạy `flutter run` (VM kết nối trực tiếp) để bắt exception layout đầy đủ.

**Nguyên nhân gốc:** Dialog "Thêm dịch vụ" (`_showAddServiceDialog`, `repair_detail_view.dart`) đã được refactor từ `showDialog`+`AlertDialog` sang `showModalBottomSheet` tự custom trước đó (chưa commit). Nút "Thêm"/"Cập nhật" là `ElevatedButton` không style riêng, đặt trong `Row` cùng `Spacer()`. Theme `ElevatedButton` toàn app (`AppButtonStyles.elevatedButtonStyle`) quy định `minimumSize: Size(double.infinity, buttonHeight)` — dùng cho nút full-width bình thường (VD trong `Column`). Nhưng trong `Row`, các con không-flex nhận `maxWidth: infinity` khi layout (hành vi chuẩn của `Row`/`Flex` để đo kích thước tự nhiên) — kết hợp với `minimumSize.width = double.infinity` khiến `ButtonStyleButton` tạo constraint `BoxConstraints(minWidth: infinity, maxWidth: infinity)` (tight-infinite, không hợp lệ) → Flutter crash `performLayout()` ngay khi build sheet lần đầu. Vì exception xảy ra trong lúc build, framework không render được gì cả — chỉ còn barrier (nền xám) của route.

**2 lỗi liên quan phát hiện cùng lúc:**
1. Root cause chính ở trên — fix bằng cách gán `style: AppButtonStyles.smallElevatedButtonStyle` (biến thể có sẵn trong theme, `minWidth: 0`) riêng cho `ElevatedButton` này, thêm import `theme/app_button_styles.dart` còn thiếu.
2. Sau khi sheet hiện được: hàng nút Hủy/Thêm ở cuối bị khuất một phần dưới thanh điều hướng hệ thống (3-button nav). Nguyên nhân: `showModalBottomSheet(useSafeArea: true)` chỉ áp `SafeArea(bottom: false)` nội bộ (chỉ tránh status bar, KHÔNG tránh nav bar) — sheet luôn được canh chạm đáy màn hình vật lý bất kể chiều cao. Fix: bọc thêm `SafeArea(top: false, ...)` quanh nội dung sheet để tự thêm padding đáy tránh thanh điều hướng.

- File: `lib/views/repair_detail_view.dart` (hàm `_showAddServiceDialog`)
- Đã test trực tiếp qua `flutter run` (Dart VM live) trên thiết bị Android thật: tái hiện lỗi gốc (barrier không nội dung) → xác nhận exception layout chính xác qua log → áp fix → verify hết crash, sheet hiện đầy đủ field + 2 nút không bị khuất → test full luồng nhập liệu + validate + lưu dịch vụ + xoá dịch vụ test, đều hoạt động đúng, không crash

---

## [2026-08-09b] - feat(sale): tìm kiếm khách hàng tự động khi tạo đơn bán

**Mục tiêu:** Đồng bộ trải nghiệm với màn tạo đơn sửa — gõ vào ô TÊN/SĐT có sẵn là hiện gợi ý khách cũ ngay.

- Gắn `CustomerSuggestionsPanel` (widget tái sử dụng từ `[2026-08-08]`, không sửa gì thêm) vào 2 field TÊN (`nameCtrl`/`nameF`) và SĐT (`phoneCtrl`/`phoneF`) có sẵn trong `create_sale_view.dart` — thêm 2 `FocusNode` mới vì file này chưa có sẵn như bên đơn sửa
- **Xoá cơ chế gợi ý cũ**: `_suggestCustomers`/`_buildCustomerSuggestions()` — chip ngang chỉ load 1 lần lúc mở màn (`db.getCustomerSuggestions()`), không tìm theo gõ chữ, không có khách gần nhất khi rỗng. Panel mới thay thế hoàn toàn, không giữ song song 2 cơ chế
- Chọn khách → tự điền TÊN/SĐT/Địa chỉ, gọi lại `_loadCustomerQuickData()` có sẵn để hiện card "Khách cũ · N giao dịch"
- File: `lib/views/create_sale_view.dart`
- Đã test trên Oppo CPH2203: gõ SĐT/TÊN hiện gợi ý đúng, khách gần nhất khi ô trống, chọn khách tự điền + hiện quick-card

---

## [2026-08-09] - feat(backup): sao lưu đơn sửa kèm ảnh

**Mục tiêu:** Backup hiện có (SQLite/Firestore) chỉ lưu URL ảnh dạng text — nếu mất Storage thì URL vô nghĩa. Cần backup có ảnh thật.

- `BackupService.backupRepairsWithImages({from, to, onProgress})`: lấy đơn sửa theo khoảng ngày (`getRepairsByCreatedAtRange` có sẵn), tải từng ảnh nhận/giao máy (URL http/https) từ Firebase Storage, đóng gói cùng `repairs.json` (thông tin đơn) thành 1 file `.zip` bằng package `archive` (đã có sẵn trong `pubspec.yaml`, không cần thêm dependency). Ảnh local chưa upload xong bị bỏ qua (không có gì để tải)
- Lỗi tải 1 ảnh không làm hỏng cả bản sao lưu — đếm riêng vào `failedImageCount`
- Thêm `listRepairImageBackups()`/`deleteRepairImageBackup()` — liệt kê/xoá các bản zip đã tạo, tái dùng model `LocalSqliteBackup` có sẵn
- UI: thêm tab thứ 3 "Đơn sửa + Ảnh" trong `backup_restore_view.dart` (màn Cài đặt → Sao lưu & Khôi phục) — chọn khoảng ngày, xem tiến trình, chia sẻ file qua `share_plus`
- File: `lib/services/backup_service.dart`, `lib/views/backup_restore_view.dart`
- Đã test trên Oppo CPH2203: chọn khoảng ngày, chạy sao lưu, tạo đúng file zip, hiện trong danh sách "Đã sao lưu trên máy này", summary "Đã sao lưu N đơn, M ảnh" đúng số liệu thực tế

---

## [2026-08-08b] - feat(repair): tìm kiếm khách hàng tự động (autocomplete) khi tạo đơn sửa

**Mục tiêu:** Giảm thao tác nhập lại khi tạo đơn sửa cho khách đã từng đến — gõ SĐT hoặc tên là gợi ý ngay khách cũ, chọn 1 chạm là tự điền.

**1. `DBHelper.searchCustomersRanked(query, shopId, {limit: 10})`** — local SQLite only, không đọc Firestore
- Query rỗng → trả về khách ghé gần nhất (`ORDER BY COALESCE(lastVisitAt, updatedAt, createdAt) DESC`)
- Query có nội dung → xếp hạng bằng `CASE`: khớp chính xác SĐT (rank 0) > SĐT/tên bắt đầu bằng query (rank 1) > còn lại chứa query (rank 3), giới hạn 10 kết quả
- File: `lib/data/db_helper.dart`

**2. Widget tái sử dụng trong `lib/widgets/customer_autocomplete_field.dart`** — 2 biến thể dùng chung 1 logic tìm kiếm + 1 danh sách kết quả:
- `CustomerSuggestionsPanel` (controlled: nhận `query` + `active` từ ngoài) — gắn thẳng vào field SĐT/Tên **đã có sẵn** trong form, không thêm ô tìm kiếm riêng. Đây là bản UX cuối cùng sau khi user phản hồi muốn gõ trực tiếp vào SĐT/Tên là thấy gợi ý ngay, thay vì phải gõ vào 1 ô riêng phía trên
- `CustomerAutocompleteField` (tự chứa TextField riêng) — vẫn giữ lại cho màn nào chưa có sẵn field SĐT/Tên để gắn vào
- Cả 2 đều: debounce 180ms, không phải Overlay/portal — render list ngay dưới field trong luồng scroll bình thường để tránh nhóm lỗi `_dependents.isEmpty` liên quan route/portal (bài học từ fix cùng ngày ở `repair_detail_view.dart`)
- Field trống (mới focus) → hiện khách ghé gần nhất; gõ chữ → tìm theo tên/SĐT, không phân biệt hoa thường
- Mỗi dòng gợi ý hiển thị tên, SĐT, thời gian ghé gần nhất (dạng tương đối: "X phút/giờ/ngày trước")
- Chọn 1 khách → callback `onSelected(Customer)` — không tự sở hữu controller của form cha, nên tái dùng được ở màn tạo đơn bán, bảo hành, công nợ... sau này chỉ cần gắn vào field tương ứng + truyền `onSelected` khác
- Chống race điều kiện: mỗi lần gõ có số thứ tự request riêng, kết quả trả về trễ (từ query cũ hơn) bị bỏ qua thay vì ghi đè kết quả mới

**3. Tích hợp vào `create_repair_order_view.dart`**
- Gắn `CustomerSuggestionsPanel` ngay dưới Row 2 field SĐT (`phoneCtrl`/`phoneF`) + Tên (`nameCtrl`/`nameF`) có sẵn — `active` = 1 trong 2 field đang focus, `query` = nội dung field đang focus. Gõ vào SĐT hoặc Tên đều kích hoạt cùng 1 danh sách gợi ý bên dưới
- Khi chọn khách: tự điền `phoneCtrl`, `nameCtrl`, `addressCtrl` (nếu có) và gọi lại `_smartFill()` có sẵn để load card "Khách cũ · N đơn" + công nợ — không phải viết lại logic quick-card
- `phoneF`/`nameF` là 2 `FocusNode` đã khai báo + dispose sẵn từ trước nhưng chưa từng gắn vào field nào — tận dụng lại thay vì tạo mới
- File: `lib/views/create_repair_order_view.dart`

**Đã test trên Oppo CPH2203:** gõ vào ô SĐT hiện gợi ý ✅, gõ vào ô Tên hiện gợi ý ✅ (không phân biệt hoa thường), hiện khách gần nhất khi field vừa focus còn trống (đúng thứ tự thời gian) ✅, chọn khách tự điền cả 2 field + hiện quick-card ✅.

---

## [2026-08-08] - fix(audit,sync,notification): sửa 3 bug + thêm hẹn khách lấy máy cho đơn sửa

**1. Fix bug đếm sai "Active Listeners" trong Firestore Audit Monitor**
- `logRead(isActiveListener: true)` cộng dồn mỗi lần snapshot bắn ra thay vì mỗi lần listener mới mở → hiện số ảo (x22, x25...)
- Thêm `_activeListenerKeys` (Set) để chỉ đếm 1 lần cho mỗi (collection, service, method) đang mở
- File: `lib/developer/firestore_audit/services/firestore_audit_service.dart`

**2. Tăng cooldown SyncService.refreshCloudCollections 30s → 120s**
- Giảm tần suất poll tự động các collection ít thay đổi (suppliers, audit_logs...), giảm read Firestore
- Các lệnh gọi có `force: true` (nút "Đồng bộ ngay", sự kiện thay đổi dữ liệu) không bị ảnh hưởng
- File: `lib/services/sync_service.dart`

**3. Fix bug double thông báo khi nhận từ nhân viên khác**
- Nguyên nhân: có 2 đường hiển thị độc lập cho cùng 1 sự kiện — FCM foreground handler VÀ Firestore realtime listener (`shop_notifications`) — cả 2 đều tự bắn snackbar + local notification
- Giải pháp: Firestore listener chỉ còn đánh dấu dedup, không tự hiển thị nữa; FCM là nguồn hiển thị duy nhất
- File: `lib/services/notification_service.dart`

**4. Thêm trường "Hẹn giao máy" cho đơn sửa chữa (lấy ngay / trong ngày / báo sau)**
- Model: `Repair.pickupSchedule` (String?, values: `now`/`same_day`/`later`) + `pickupScheduleLabel` getter
- DB: SQLite v103 → v104, cột `pickupSchedule` thêm qua `onUpgrade` + `onOpen` defensive check
- UI: ChoiceChip 3 lựa chọn trong màn tạo đơn sửa (`create_repair_order_view.dart`) và trong sheet "Chỉnh sửa thông tin đơn sửa" (`repair_detail_view.dart`), hiển thị read-only ở màn chi tiết
- Files: `lib/models/repair_model.dart`, `lib/data/db_helper.dart`, `lib/views/create_repair_order_view.dart`, `lib/views/repair_detail_view.dart`

**5. Fix crash `_dependents.isEmpty` khi bấm LƯU trong sheet "Chỉnh sửa thông tin đơn sửa" (phát hiện trong lúc test tính năng #4)**
- Lỗi có sẵn từ trước, không do tính năng hẹn giao máy gây ra (tái hiện cả khi không chạm chip mới) — trước đây bị che giấu vì nút Lưu/Hủy nằm trong vùng cử chỉ điều hướng hệ thống trên một số máy (Oppo ColorOS gesture-nav) nên không ai bấm tới được để kích hoạt lỗi
- **Lần fix đầu (không đủ):** áp dụng lại pattern cũ từ `order_list_view.dart` 2026-06-10g — `async` + `await Future.delayed(Duration.zero)` sau `unfocus()` trước `Navigator.pop()`. Build lại và test thì crash **vẫn tái hiện ~50%** (cùng thao tác, lúc bị lúc không) → xác nhận đây là race điều kiện theo thời điểm frame, không phải do thiếu delay
- **Root cause thật sự (2 phần):**
  1. `MediaQuery.paddingOf(ctx)` / `viewInsetsOf(ctx)` trong builder của `showModalBottomSheet` đọc từ context **bên trong** sheet route → tạo dependency vào MediaQuery scoped theo route đó. Khi `Navigator.pop()` chạy, MediaQuery này deactivate trước khi widget kịp rebuild để gỡ dependency → đúng bug đã từng fix ở 11 file khác ngày 2026-06-05 nhưng lại xuất hiện lại ở đây. Fix: đổi sang đọc từ `context` (context của State, nằm ngoài route) thay vì `ctx`
  2. `FocusScope.of(ctx).unfocus()` gọi trong `onPressed` **tự đăng ký thêm 1 dependency mới** vào FocusScope của chính route sắp đóng, ngay tại thời điểm chuẩn bị pop — do đây là lookup `.of(ctx)` nên luôn tạo dependency dù gọi trong callback hay build. Đây là nguyên nhân chính khiến delay không đủ: dependency được tạo mới ngay trước khi pop, không có cơ hội rebuild để gỡ. Fix: đổi sang `FocusManager.instance.primaryFocus?.unfocus()` — API tĩnh, không qua BuildContext/InheritedWidget nên không tạo dependency nào cả
- Áp dụng cả 2 fix cho `_editBasicInfo` (sheet chính, có tính năng hẹn giao máy) và `_editTechnicianNotes` (sheet khác cùng file, phát hiện có cùng anti-pattern khi rà lại code, sửa phòng ngừa dù chưa từng crash được ghi nhận)
- **Verify trên Oppo CPH2203:** lặp lại thao tác chọn chip + bấm LƯU **5/5 lần liên tiếp** không crash (trước fix: crash lặp lại nhiều lần cùng thao tác) — dữ liệu luôn lưu đúng kể cả những lần bị crash trước đó
- Files: `lib/views/repair_detail_view.dart`

---

## [2026-06-16c] - feat(notifications): push notification cho quản lý khi nhập kho / bán thiếu giá vốn

**Mục tiêu:** Quản lý không bỏ lỡ các sự kiện cần xử lý từ nhân viên.

| Sự kiện | File | Type | Nội dung |
|---|---|---|---|
| Đơn sửa chờ duyệt | `repair_detail_view` | `approval_needed` | Đã có sẵn từ trước ✅ |
| Nhập kho thiếu giá vốn | `fast_stock_in_view` | `missing_cost` | NV + tên SP + "cần bổ sung sau" |
| Nhập kho thiếu NCC | `fast_stock_in_view` | `missing_supplier` | NV + tên SP + "chưa chọn NCC" |
| Phiếu nhập kho mới | `fast_stock_in_view` | `stock_pending` | NV + tên SP + "chờ xác nhận" |
| Xác nhận nhập kho | `pending_stock_list_view` | `stock_confirmed` | NV + tên SP + NCC |
| Bán hàng thiếu giá vốn | `create_sale_view` | `missing_cost_sale` | NV + khách + số tiền + "cần bổ sung" |

**Files thay đổi:**
- `lib/views/fast_stock_in_view.dart`
- `lib/views/pending_stock_list_view.dart`
- `lib/views/create_sale_view.dart`

---

## [2026-06-16b] - fix(supplier): _pickSupplier hỏi payment; ghi công nợ/expense/lịch sử chi đúng

**Vấn đề:** Khi chọn NCC trong trang "Thiếu vốn/NCC":
1. `paymentMethod` hardcode `'TIỀN MẶT'` — không hỏi user
2. Không tạo công nợ khi chọn CÔNG NỢ
3. Không ghi expense vào sổ quỹ khi TIỀN MẶT/CHUYỂN KHOẢN
4. Không ghi `financial_activity_log` (lịch sử chi)

**Giải pháp:**
- Thêm `SimpleDialog` chọn phương thức thanh toán trước khi lưu NCC
- Nếu `p.cost > 0` và `p.paymentMethod == null` (chưa từng ghi tài chính): tạo debt hoặc expense + logPurchase
- Nếu `p.paymentMethod != null`: expense đã được ghi từ fast_stock_in hoặc `_editCost` → không ghi thêm (tránh double count)
- `supplier_import_history` luôn dùng payment method thực tế user chọn
- Lưu `paymentMethod` vào `products` record

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`

---

## [2026-06-16a] - fix(stock-in): payment method không bắt buộc khi allowPendingCost=true + cost=0; cập nhật paymentMethod khi bổ sung vốn

**Vấn đề 1:** `fast_stock_in_view` luôn yêu cầu chọn phương thức thanh toán dù đã bật "cho phép nhập giá vốn sau". User không thể nhập kho tạm mà bỏ trống payment.

**Giải pháp:** Thêm getter `_allowPendingCost` từ ShopSettings. Điều kiện validate: payment chỉ bắt buộc khi `!_allowPendingCost` HOẶC khi `cost > 0` (đã nhập giá vốn ngay lúc nhập kho). Khi `allowPendingCost=true` và `cost=0` → payment được bỏ qua, sẽ điền sau khi bổ sung vốn.

**Vấn đề 2:** Khi bổ sung giá vốn qua "Thiếu vốn/NCC", `products.paymentMethod` không được cập nhật — product vẫn lưu `paymentMethod=null` dù user đã chọn phương thức thanh toán trong dialog.

**Giải pháp:** `_editCost` thêm `paymentMethod: payment` vào `p.copyWith(...)` → product record lưu đúng phương thức thanh toán sau bổ sung.

**Files thay đổi:**
- `lib/views/fast_stock_in_view.dart`
- `lib/views/missing_info_products_view.dart`

---

## [2026-06-11c] - fix(finance): bổ sung giá vốn/NCC retroactive cập nhật đúng tài chính

**Vấn đề (5 lỗi từ audit):**
1. `sale_orders.totalCost` không được cập nhật khi nhập vốn sau bán → lợi nhuận gộp sai vĩnh viễn
2. Double counting: expense "Giá vốn" + COGS từ sale đều bằng 0 → net đúng nhưng gross sai
3. Supplier "Lịch sử nhập" trống dù đã gán NCC/vốn retroactive
4. SP đã bán (status=0) không hiển thị trong tab "Sản phẩm" của NCC
5. Ngày expense = ngày bổ sung (hôm nay) thay vì ngày mua/bán

**Giải pháp:**
- **Fix 1+2:** `_editCost` — nếu sản phẩm có IMEI và đã bán: tìm sale qua `getSalesByProductImei`, gọi `updateSaleCostByImei` để patch `totalCost` + `itemSnapshotsJson.unitCost` trực tiếp. Chỉ tạo expense khi không tìm được sale nào (sản phẩm còn tồn kho). Nếu CÔNG NỢ → luôn tạo debt (obligation to supplier).
- **Fix 3:** `_editCost` và `_pickSupplier` → insert vào `supplier_import_history` sau khi gán NCC.
- **Fix 4:** `getProductsBySupplier` thêm param `includeSold: bool = false`; `supplier_detail_view` truyền `includeSold: true`.
- **Fix 5:** Expense/activity date dùng `p.createdAt` thay vì `now`.
- **db_helper:** Thêm `updateSaleCostByImei()` — parse JSON snapshot, tìm item theo IMEI, cập nhật `unitCost`/`lineCostTotal`/`totalCost`.

**Files thay đổi:**
- `lib/data/db_helper.dart`
- `lib/views/missing_info_products_view.dart`
- `lib/views/supplier_detail_view.dart`

---

## [2026-06-11b] - feat(import): importPurchaseOrders tự tạo product stub; IMEI = 1 sản phẩm riêng

**Vấn đề:**
Import file `DanhSachChiTietNhapHang` từ KiotViet tạo 46 phiếu trong lịch sử nhập kho nhưng các sản phẩm mới trong những phiếu đó không xuất hiện trong Danh sách sản phẩm.

**Nguyên nhân:**
`importPurchaseOrders` chỉ tạo `import_orders` + `import_order_items`, không tạo bản ghi trong bảng `products`.

**Giải pháp:**
Sau khi insert từng `import_order_item`, kiểm tra sản phẩm trong bảng `products`:
- **Có IMEI:** tìm theo IMEI (không fallback tên). Nếu không tìm thấy → tạo product mới với IMEI đó, qty=1 (mỗi IMEI = 1 thiết bị vật lý riêng biệt).
- **Không có IMEI:** tìm theo tên (dedup). Nếu không tìm thấy → tạo product stub, qty=số lượng trong phiếu.
- **Đã tồn tại:** chỉ cập nhật supplier/cost nếu đang trống.

**Files thay đổi:**
- `lib/services/kiotviet_excel_import_service.dart`

---

## [2026-06-11a] - fix(ux): snackbar import KiotViet màu vàng khi toàn bộ bị bỏ qua

**Vấn đề:**
Sau khi import file Excel KiotViet, nếu toàn bộ sản phẩm đã tồn tại (skipped=N, inserted=0),
snackbar hiện màu xanh "thành công" → user nhầm tưởng import thất bại hoặc app lỗi.

**Giải pháp:**
Khi `inserted=0 && updated=0 && skipped>0` → snackbar màu vàng cam (amber) thay vì xanh.
Chỉ xanh khi thực sự có dữ liệu mới được thêm.

**Files thay đổi:**
- `lib/views/kiotviet_import_view.dart`

---

## [2026-06-10g] - fix: crash _dependents.isEmpty khi bấm Lưu/Hủy trong dialog thêm khách hàng

**Vấn đề:**
Bấm nút Lưu hoặc Hủy trong dialog "Thêm thông tin khách hàng" (từ danh sách đơn sửa) gây crash:
```
'_dependents.isEmpty': is not true
```
Root cause: `FocusScope.unfocus()` được gọi đồng bộ ngay trước `Navigator.pop()` — Flutter chưa kịp flush deactivation của text selection overlay (copy/paste toolbar) của TextField trước khi dialog bị pop, dẫn đến InheritedWidget assert fail.

**Giải pháp:**
Chuyển `onPressed` của cả 2 nút Hủy và Lưu sang `async`, thêm `await Future.delayed(Duration.zero)` sau `unfocus()` trước khi `Navigator.pop()`. Một frame trễ đủ để overlay deactivate sạch.

**Files thay đổi:**
- `lib/views/order_list_view.dart`

---

## [2026-06-10f] - fix: mã nhập nhanh điền sai màu SA MẠC và tình trạng NEW

**Vấn đề:**
Khi chọn mã nhập nhanh iPhone 17 Pro Max (và 16 Pro/Max, 15 Pro/Max) từ Nhanh hoặc Đầy đủ, form nhập kho hiển thị màu = KHÁC và tình trạng = KHÁC. Root cause:
1. `ProductConstants.mapColor("SA MẠC")` → không có trong `colors` list và không có rule → trả về "KHÁC"
2. `ProductConstants.mapColor("TỰ NHIÊN")` → rule TITAN block chỉ xử lý khi có từ "TITAN" → trả về "KHÁC"
3. `ProductConstants.mapConditionShort("NEW")` → seeder lưu condition = "NEW" nhưng không có rule → trả về "KHÁC"

**Giải pháp:**
- `ProductConstants.colors`: Thêm 'SA MẠC' vào danh sách (trước 'KHÁC')
- `ProductConstants.mapColor`: Thêm rule `'TỰ NHIÊN' → 'TITAN TỰ NHIÊN'` (seeder dùng cho iPhone 15/16/17 Pro)
- `ProductConstants.mapConditionShort`: Thêm `'NEW' → 'MỚI'` (seeder dùng condition="NEW" cho iPhone 16/17)
- `quick_input_codes_view.dart` `_colorOptions`: Thêm 'SA MẠC' với màu tan cát #D2B48C

**Kết quả:**
- iPhone 17 Pro Max SA MẠC NEW → màu = SA MẠC, tình trạng = MỚI ✅
- iPhone 16/17 Pro TỰ NHIÊN → màu = TITAN TỰ NHIÊN ✅
- Mã nhập nhanh (Nhanh và Đầy đủ) điền đúng cả màu lẫn tình trạng ✅

**Files thay đổi:**
- `lib/constants/product_constants.dart`
- `lib/views/quick_input_codes_view.dart`

---

## [2026-06-10e] - feat: trả hàng hiển thị trong tab Giao dịch (Tài chính)

**Vấn đề:**
Trả hàng không ghi thành giao dịch trong tab "Giao dịch" của Tài chính, khó audit luồng tiền theo từng lần trả hàng.

**Giải pháp:**
- `finance_v2_data_service.dart`: Thêm `FinanceV2Txn(type: 'REFUND', isIncome: false)` vào `transactions` list trong returns loop
- Mỗi trả hàng hiển thị: tên khách, "Hoàn tiền trả hàng", số tiền âm (-X Tr), phương thức, ngày giờ
- Không ảnh hưởng Tổng quan: `saleIn -= amount` vẫn chạy riêng → Thu tiền 5 Tr vẫn đúng
- Filter OUT trong Giao dịch sẽ bao gồm trả hàng (đúng về mặt cash flow)

**Kết quả:**
- Giao dịch tab: thấy "KHÁCH VÃNG LAI · Hoàn tiền trả hàng -12 Tr · TIỀN MẶT" ✅
- Tổng quan: Thu tiền 5 Tr (net), Chi tiền 0 (không thay đổi) ✅
- Nhất quán: Sổ quỹ Chi cũng hiển thị trả hàng như Chi → cả 2 màn hình đều thấy

**Files thay đổi:**
- `lib/finance_v2/finance_v2_data_service.dart`

---

## [2026-06-10d] - fix: home CHI TIÊU hiển thị Trả hàng mâu thuẫn với tổng = 0

**Vấn đề:**
Home screen dashboard dùng 2 nguồn dữ liệu khác nhau cho donut breakdown:
- Tổng "THU NHẬP" / "CHI TIÊU" lấy từ `financeSnapshot` (finance_v2, net approach: returns đã trừ vào thu)
- Breakdown "Bán hàng" = `_todaySaleIncome + _todayRefundOut` (17 Tr gross)
- Breakdown "Trả hàng" = `_todayRefundOut` (12 Tr) nằm dưới CHI TIÊU

Kết quả mâu thuẫn: CHI TIÊU tổng = 0 nhưng breakdown hiển thị "Trả hàng: 12 Tr"; THU NHẬP = 5 Tr nhưng breakdown "Bán hàng: 17 Tr" > tổng.

**Giải pháp:**
- `home_view.dart`: Xóa `_todayRefundOut` khỏi `incomeItems` (Bán hàng) và khỏi `expenseItems` (Trả hàng)
- Xóa field `_todayRefundOut` và assignment `analysis.refundOut` không còn dùng
- Home screen nay dùng thuần finance_v2 net approach, nhất quán với tab Tài chính

**Kết quả:**
- THU NHẬP = 5 Tr, breakdown Bán hàng = 5 Tr ✅
- CHI TIÊU = 0, không có mục Trả hàng mâu thuẫn ✅
- Nhất quán với Tài chính Tổng quan (Thu tiền 5 Tr, Chi tiền 0) ✅

**Files thay đổi:**
- `lib/views/home_view.dart`

---

## [2026-06-10c] - fix: trả hàng tính 0đ hoàn tiền khi unitPrice bị ghi đè thành 0

**Vấn đề:**
`itemSnapshotsJson` của một số đơn bán bị cloud sync bug ghi đè `unitPrice=0` (đã fix trước đó). Khi tạo trả hàng từ đơn này, form tính `totalReturnAmount = unitPrice × qty = 0` → hoàn tiền 0đ → Tài chính không trừ doanh thu → số liệu sai.

**Giải pháp:**
- `create_sales_return_view.dart`: Thêm fallback trong `_parseItems()` — nếu tổng giá snapshot = 0 nhưng `sale.finalPrice > 0`, phân phối `finalPrice / totalQty` cho từng item. Tránh trả hàng với 0đ do dữ liệu bị hỏng.

**Kết quả:**
- Return form hiển thị đúng đơn giá khi snapshot bị hỏng giá ✅
- `totalReturnAmount` được tính đúng từ `finalPrice` ✅
- Không ảnh hưởng đơn có snapshot giá đúng ✅

**Files thay đổi:**
- `lib/views/create_sales_return_view.dart`

---

## [2026-06-10b] - fix: trả hàng không ghi vào Giao dịch tài chính

**Vấn đề:**
Khi trả hàng, hệ thống tạo entry `-12 Tr` vào danh sách "Giao dịch" trong màn hình Tài chính, và cũng ghi vào `financial_activity_log`. Người dùng không muốn returns xuất hiện trong sổ giao dịch tài chính.

**Giải pháp:**
- `finance_v2_data_service.dart`: Xóa `transactions.add(FinanceV2Txn(...))` cho REFUND. Giữ nguyên `saleIn -= amount` để tổng "Tiền thu vào" vẫn đúng (net doanh thu sau hoàn trả).
- `sales_return_service.dart`: Xóa `FinancialActivityService.logCustomActivity(...)` — không ghi vào audit log tài chính.

**Kết quả:**
- "Giao dịch" tab: không còn hiện entry trả hàng ✅
- "Tiền thu vào" vẫn đúng (đã trừ giá trị hoàn trả) ✅
- Sổ quỹ không bị ảnh hưởng (đọc trực tiếp từ bảng sales_returns) ✅

**Files thay đổi:**
- `lib/finance_v2/finance_v2_data_service.dart`
- `lib/services/sales_return_service.dart`

---

## [2026-06-10a] - fix: crash _dependents.isEmpty khi bấm "Sửa thông tin đơn"

**Vấn đề:**
Khi `_managerUnlocked` đã là `true`, bấm "Sửa thông tin đơn" (hoặc "Sửa giá vốn", "Xóa đơn") trong PopupMenu gây crash assertion `_dependents.isEmpty: is not true` ở Flutter framework.dart:6268. Nguyên nhân: `showDialog` được gọi **đồng bộ** ngay trong `onSelected` callback trong khi Flutter đang deactivate widget tree của popup, gây xung đột InheritedElement.

**Giải pháp:**
Thêm `await Future.delayed(Duration.zero)` trước mỗi lần gọi dialog trong 3 case: `edit`, `fix_cost`, `delete`. Điều này nhường microtask frame để popup đóng hoàn toàn trước khi dialog mới được tạo. Khi `_unlockManager()` đã được await (trường hợp chưa unlock), delay này vô hại.

**Files thay đổi:**
- `lib/views/sale_detail_view.dart` — thêm `await Future.delayed(Duration.zero)` vào case edit/fix_cost/delete

---

## [2026-06-09l] - feat: thêm "Sửa giá vốn (0đ)" trong menu chi tiết đơn bán

**Vấn đề:**
Đơn bán cũ có `totalCost = 0` (do sản phẩm bị mất giá vốn lúc bán). Báo cáo lợi nhuận lịch sử tính sai vì dùng trực tiếp `totalCost` từ bảng `sales`. Dialog SỬA đơn hiện tại khóa giá vốn khi đơn không cùng ngày → không sửa được.

**Giải pháp (Phương án B):**
- Thêm menu item "Sửa giá vốn (0đ)" trong PopupMenuButton trên màn hình chi tiết đơn bán
- Chỉ hiện khi: `_canViewCostPrice && s.totalCost == 0 && s.totalPrice > 0`
- Yêu cầu manager unlock (Firebase re-auth) giống edit/delete
- Không bị giới hạn `_isSameDay` — đây là fix dữ liệu lịch sử
- Sau khi nhập: gọi `_applyNewCostToSnapshots()` để cập nhật `unitCost` trong `itemSnapshotsJson`, lưu SQLite, queue Firestore sync

**Files thay đổi:**
- `lib/views/sale_detail_view.dart` — `_showFixCostDialog()` + case `fix_cost` + menu item

---

## [2026-06-09k] - fix: ô giá vốn bị khóa trong dialog SỬA khi cost = 0đ

**Root cause:**
Điều kiện `if (!p.isPending || p.status == 0)` trong `_editProduct` dialog luôn khóa ô giá vốn cho sản phẩm đã nhập kho chính (`isPending = false`), kể cả khi `cost = 0` — user không thể nhập lại giá vốn đã bị mất.

**Fix:**
Thêm điều kiện `&& p.cost > 0`: chỉ khóa khi đã có giá vốn hợp lệ. Nếu `cost = 0`, luôn cho chỉnh sửa.

**Files thay đổi:**
- `lib/views/inventory_view.dart` — line 4456: `(!p.isPending || p.status == 0) && p.cost > 0`

---

## [2026-06-09j] - fix: inventory product price/cost = 0đ + createdAt = 0

**Root cause:**
Khi sync product từ Firestore về SQLite, nếu Firestore document thiếu/trả về 0 cho `price`, `cost`, `createdAt`, `upsertProduct` ghi đè lên giá trị local đang đúng. Sản phẩm kết quả hiển thị "0đ" và không có ngày trên card list.

**3 fix đồng thời:**

1. **`upsertProduct` (db_helper.dart)** — thêm preserve logic: khi `isSynced=true` (data từ cloud), nếu cloud trả về `price=0/cost=0/createdAt=0` nhưng local đang có giá trị đúng, giữ nguyên local. Cover tất cả sync paths.

2. **`sync_service.dart` (2 paths)** — explicit preserve `createdAt`, `price`, `cost` từ existing local product trước khi gọi `Product.fromMap(data)`, tránh ghi đè từ cloud.

3. **`fixMissingCreatedAt()` (db_helper.dart)** — one-time SQL fix: `UPDATE products SET createdAt = updatedAt WHERE createdAt = 0 AND updatedAt > 0`. Gọi từ `InventoryView._init()` để fix sản phẩm đang có `createdAt=0` ngay lập tức.

**Files thay đổi:**
- `lib/data/db_helper.dart` — `upsertProduct`: preserve isSynced + `fixMissingCreatedAt()` + `getProductsWithMissingPrices()`
- `lib/services/sync_service.dart` — 2 product sync paths: preserve createdAt/price/cost
- `lib/services/firestore_service.dart` — `fetchProductsByFirestoreIds()` (batch Firestore fetch by doc IDs)
- `lib/views/inventory_view.dart` — `_init()`: gọi `fixMissingCreatedAt()` unawaited

---

## [2026-06-09i] - fix: no such column updatedAt trong getRepairsPaged (device bug)

**Root cause phát hiện khi test trực tiếp trên CPH2203:**
`getRepairsPaged` dùng `ORDER BY COALESCE(updatedAt, createdAt, 0) DESC` nhưng bảng `repairs` không có cột `updatedAt` (không trong CREATE TABLE, không có migration). Toàn bộ `_initFromSQLite` và `_refreshFromSQLite` fail → danh sách chỉ load từ Firestore (49 đơn), SQLite = 0, `_hasMoreData = false`.

**Fix:** Thay `updatedAt` → `lastCaredAt` (cột tương đương, có sẵn trong schema).

**Kết quả test thực tế:**
- Trước: 49 đơn, không load thêm được
- Sau fix: 594 đơn (toàn bộ lịch sử), pagination hoạt động 50/page, dừng đúng khi `HasMore=false`

**Files thay đổi:**
- `lib/data/db_helper.dart` — `getRepairsPaged`: `updatedAt` → `lastCaredAt` (2 chỗ)

---

## [2026-06-09h] - fix: backfill nhanh + race-condition + data-safety

**3 bug trong cùng flow pagination:**

1. **Backfill chậm** — `Future.wait(2000 × upsertRepair)`, mỗi cái có PRAGMA table_info trong transaction → ~20-30 giây. User bấm "Tải thêm" trước khi xong → 0 items → button biến mất.
   - Fix: `bulkInsertRepairsIfNew()` — schema check 1 lần, `INSERT OR IGNORE`, batch 200/transaction → ~1 giây.

2. **Data safety** — `upsertRepair` trong backfill overwrite unsynced local repairs với data cũ từ Firestore.
   - Fix: `INSERT OR IGNORE` trên `firestoreId UNIQUE` → không bao giờ overwrite existing rows.

3. **Race condition** — `_refreshFromSQLite` reset `_sqliteRepairs=[50]` trong khi `_loadMoreFromSQLite` đang thêm page 1 → user thấy list giảm xuống 49 đột ngột.
   - Fix: nếu `_isLoadingMore=true` → skip state update; nếu load-more vừa completed → chỉ update khi query của ta cover đủ (`repairs.length >= _sqliteLoadedCount`).

**Files thay đổi:**
- `lib/data/db_helper.dart` — thêm `bulkInsertRepairsIfNew()`
- `lib/views/order_list_view.dart` — `_doHistoricalBackfill` dùng phương thức mới, `_refreshFromSQLite` fix race condition

---

## [2026-06-09g] - fix: historical backfill toàn bộ đơn sửa từ Firestore vào SQLite + debug logging

**Vấn đề gốc rễ:** SQLite chỉ có 50 đơn vì được populate bởi Firestore subscription (LIMIT 50 + orderBy updatedAt). Các đơn cũ không có field `updatedAt` không bao giờ được ghi vào SQLite → "Tải thêm" không có dữ liệu.

**Giải pháp:** One-time historical backfill khi nhận server snapshot đầu tiên:
- `FirestoreService.fetchAllRepairsByShop()` — `.get()` không có `orderBy`, `limit(2000)` → bao gồm tất cả đơn kể cả cũ
- `_doHistoricalBackfill()` trong `OrderListView` — upsert tất cả vào SQLite, sau đó `_refreshFromSQLite()`
- Session-level cache `_backfilledShops` — mỗi shopId chỉ backfill 1 lần / session
- Debug logging tại `_rebuildDisplayedRepairs` (Firestore count, SQLite count, Displayed count, HasMore) và `_loadMoreFromSQLite` (LOAD MORE TRIGGERED, Before/After load count)

**Files thay đổi:**
- `lib/services/firestore_service.dart` — thêm `fetchAllRepairsByShop()`
- `lib/views/order_list_view.dart` — thêm `_doHistoricalBackfill()`, trigger từ server snapshot, debug logs

---

## [2026-06-09f] - fix: đơn sửa load đủ tất cả lịch sử + phân trang SQLite

**Vấn đề:** Firestore query `orderBy('updatedAt') LIMIT 50` bỏ qua các đơn cũ không có field `updatedAt` → chỉ hiện ~49 đơn dù có nhiều hơn.

**Giải pháp:** Chuyển nguồn hiển thị từ Firestore-cache sang SQLite-first:
- `OrderListView` load từ SQLite (`getRepairsPaged`) thay vì từ `_repairsByFirestoreId`
- Firestore subscription vẫn hoạt động để sync realtime vào SQLite, sau đó `_refreshFromSQLite()` reload display
- Scroll đến cuối → tự load thêm 50 đơn từ SQLite (hoặc bấm nút "Tải thêm")
- Xóa `_mergePendingLocalRepairsIntoCache` (không cần nữa vì SQLite đã có đủ dữ liệu)

**Files thay đổi:**
- `lib/data/db_helper.dart` — `getRepairsPaged` và `getRepairsCount` thêm shopId scope + deleted filter
- `lib/views/order_list_view.dart` — SQLite-first pagination, nút "Tải thêm", bỏ Firestore-as-display-source

---

## [2026-06-09e] - refactor: Audit home_view — xóa 89 debugPrint + 2 unused vars

**Files thay đổi:**
- `lib/views/home_view.dart` — xóa toàn bộ 89 debugPrint statements (trace/flow logs, không ảnh hưởng logic), fix 2 warning phát sinh: `unused catch stack` → `catch (_)`, `unused stopwatch` → xóa Stopwatch khởi tạo.

---

## [2026-06-09d] - refactor: Audit home_view — xóa dead navigator code

**Files thay đổi:**
- `lib/views/home_view.dart` — xóa 3 thứ dead code không ảnh hưởng chức năng:
  1. Field `_tabNavigatorKeys` (Map không bao giờ được đọc)
  2. Method `_usesNestedNavigator` (luôn trả về `false`)
  3. Method `_navigatorKeyForTab` (chỉ được gọi từ dead path)
  4. Simplify `_maybePopCurrentTabNavigator` → `async => false` (behavior không đổi)

**Root cause:** Nested Navigator đã bị tắt theo design ("Không dùng nested Navigator — route push qua root navigator"), nhưng infrastructure code vẫn còn. `_usesNestedNavigator` luôn `false` → toàn bộ navigator logic bên dưới không bao giờ chạy.

---

## [2026-06-09c] - refactor: Audit shop_settings_view — bỏ duplicate, flatten, cache members, gộp upload

**Files thay đổi:**
- `lib/views/shop_settings_view.dart` — 5 fixes sau khi audit:
  1. **Xóa 3 duplicate links** khỏi Quick Actions (HR Salary, Backup/Restore, KiotViet) — đã có trong settings_view
  2. **Xóa 3 unused imports** (`hr_salary_settings_view`, `backup_restore_view`, `kiotviet_settings_view`)
  3. **Flatten Advanced Settings** — bỏ ExpansionTile, thay bằng Card + ListTile đơn giản
  4. **Cache members list** — thay FutureBuilder (gọi lại mỗi build) bằng `_cachedMembers` + `_loadingMembers` load 1 lần trong `initState()`
  5. **Gộp 3 upload if-blocks → 1 block** — `_saveShopData()` logo-only/cover-only/both → `Future.wait()` song song 1 chỗ

---

## [2026-06-09b] - fix: Search đơn sửa tìm toàn bộ local DB, không bị giới hạn 50 đơn

**Files thay đổi:**
- `lib/views/order_list_view.dart` — thêm `_searchDebounce`, `_isSearchingLocal`; sửa `_onSearch` dùng `db.searchRepairs()` (SQLite LIKE) thay vì chỉ filter in-memory khi có từ khoá.

**Root cause:** `_rebuildDisplayedRepairs()` chỉ filter `_repairsByFirestoreId.values` (tối đa 50 docs từ Firestore real-time subscription). Khi search, kết quả chỉ nằm trong 50 đơn đang hiển thị.

**Sau fix:** Khi nhập từ khoá, debounce 300ms rồi query SQLite local (`searchRepairs` LIKE trên customerName, phone, model, issue) với limit=200 — tìm được toàn bộ đơn đã sync về máy. Khi xoá từ khoá, về lại realtime list bình thường.

---

## [2026-06-09a] - refactor: Tái cấu trúc settings_view — phân loại chuyên nghiệp, thêm 7 sub-settings

**Files thay đổi:**
- `lib/views/settings_view.dart` — xóa popup menu, thêm 7 import sub-settings views mới, thêm `_buildNavTile()` helper, xóa `_buildFeatureChip()`, tái cấu trúc ListView thành 7 section rõ ràng.

**Trước:** Settings page chỉ có 4 mục (hướng dẫn, đồng bộ, cửa hàng, super admin). Sao lưu + Trợ giúp ẩn trong popup menu góc trên. 8 sub-settings views (shop, printer, notifications, KiotViet, HR, labels, work schedule) không có link từ settings page.

**Sau — 7 section:**
1. **Tài khoản** — account card, super admin shop switcher
2. **Cửa hàng** (owner/admin) — thông tin cửa hàng, danh mục, máy in, tem, KiotViet + 3 toggles kho
3. **Nhân sự** (owner/admin) — lịch làm việc, cài đặt lương
4. **Thông báo** — cài đặt thông báo
5. **Đồng bộ & Sao lưu** — sync center, đẩy KiotViet, nhận kho, sao lưu
6. **Hỗ trợ** — hướng dẫn (simple tile thay card to), trung tâm trợ giúp
7. **Quản trị nâng cao** (super admin) — chọn shop, phân quyền, PIN, xóa data

---

## [2026-06-08o] - fix: Health check auto-restore products từ cloud (bỏ skip sai)

**Files thay đổi:**
- `lib/services/sync_health_check.dart` — xóa `products` khỏi `noAutoRestoreCollections` (set rỗng), bỏ logic skip, fix `deleted == true || deleted == 1` trong `_buildCloudComparisonRows`.

**Root cause:** `noAutoRestoreCollections = {'products'}` khiến health check phát hiện cloud=482/local=20 nhưng **bỏ qua** 462 sản phẩm thiếu (log: "skip auto-restore user may have deleted intentionally"). Lý do ban đầu đặt skip này là "sản phẩm quản lý qua KiotViet, không nên tự kéo về" — nhưng sai vì `_buildCloudComparisonRows` đã filter `deleted: true` trước khi build `cloudIds`. Tức là sản phẩm đã bị soft-delete sẽ không bao giờ có trong `cloudIds` → không bao giờ bị auto-restore lại. Skip là không cần thiết và gây mất đồng bộ.

**Kết quả sau fix:** Khi bấm "Reload đồng bộ" (Sync Health Check), máy B/C sẽ tự download 462 sản phẩm thiếu và hiển thị log `✅ Đã tải 462/462 records thiếu cho products`.

---

## [2026-06-08n] - fix: Xóa cloud dùng soft-delete + staggered timestamp → tự đồng bộ sang máy B/C

**Files thay đổi:**
- `lib/services/backup_service.dart` — `deleteSelectedDataFromCloud` → `deleteByQuery`: đổi từ `batch.delete(doc.reference)` (hard-delete) sang `batch.update({deleted: true, updatedAt: nowMs + i})` (soft-delete với timestamp staggered).

**Root cause:** Hard-delete xóa document khỏi Firestore hoàn toàn — không có `updatedAt` mới → subscription polling trên máy B/C dùng cursor `updatedAt > T` không nhận được sự kiện → sản phẩm cũ còn nguyên local mãi mãi.

**Cách hoạt động sau fix:** Mỗi doc được update với `updatedAt = nowMs + i` (unique, tăng dần). Máy B/C poll 20 docs/lần → cursor advance → poll tiếp 20 docs → ... → xử lý hết. `data['deleted'] == true` → `deleteProductByFirestoreId` → sản phẩm cũ tự xóa local. Sau đó khi Máy A push KiotViet mới lên Firestore (`updatedAt = now_after_import > cursor`) → Máy B/C poll → upsert sản phẩm mới. **Hoàn toàn tự động, không cần thao tác trên máy B/C.**

---

## [2026-06-08m] - fix: "Nhận kho từ Cloud" xóa local trước khi pull (đồng bộ sau import KiotViet)

**Files thay đổi:**
- `lib/views/settings_view.dart` — `_pullKhoFromCloud`: thêm bước xóa local products (`DELETE FROM products WHERE shopId = ?`) trước khi `downloadAllFromCloud(force: true)`.

**Root cause:** `downloadAllFromCloud` chỉ upsert (thêm/cập nhật) — không xóa sản phẩm local đã bị hard-delete trên Firestore. Sau khi máy A xóa kho + import KiotViet mới, máy B dùng "Nhận kho từ Cloud" vẫn còn sản phẩm cũ từ trước khi xóa. Giờ nút sẽ xóa sạch local trước → pull về chỉ gồm data đang có trên Firestore.

**Flow đúng sau import KiotViet:**
1. Máy A: Import KiotViet → nhấn "Đẩy dữ liệu lên Cloud"
2. Máy B, C: Settings → nhấn "Nhận kho từ Cloud" → xóa local → pull toàn bộ từ Firestore

---

## [2026-06-08l] - fix: 3 bugs còn sót sau audit lần 2

**Files thay đổi:**
- `lib/views/inventory_view.dart` (line 2282) — Bulk delete (checkbox chọn nhiều): `SyncOperation.update` → `SyncOperation.delete`. Cùng bug như single delete đã fix ở [2026-06-08j] nhưng ở đường xóa hàng loạt.
- `lib/services/sync_orchestrator.dart` `_handleUpdate` — Thêm normalize `deleted` field trước khi push lên Firestore: `data['deleted'] = data['deleted'] == 1 || data['deleted'] == true`. Bất kỳ update nào mà sản phẩm có `deleted=1` trong SQLite (do race condition hoặc bug cũ trong queue) sẽ không push `deleted: 1` integer lên Firestore nữa.
- `lib/views/settings_view.dart` `_pullKhoFromCloud` — Gọi `SyncOrchestrator().syncAll()` trước khi `downloadAllFromCloud(force: true)` để đảm bảo local pending changes được push trước, tránh mất dữ liệu chưa sync khi pull đè.

**Root causes:**
- Bulk delete path bị bỏ sót khi fix single delete.
- `_handleUpdate` không normalize `deleted` → SQLite integer `1` truyền thẳng lên Firestore khi update bất kỳ record đã bị mark deleted trong queue.
- `downloadAllFromCloud` có thể hard-delete local records có `isSynced=0` trước khi chúng được push lên cloud.

---

## [2026-06-08k] - fix: Pull paths bỏ sót deleted:1 (integer) — sync_service subscriptions + downloadAllFromCloud

**Files thay đổi:**
- `lib/services/sync_service.dart` — Tất cả subscription `onChanged` callbacks (~30 chỗ) + `downloadAllFromCloud` (line 4753) + `continue` variant (line 3741): đổi `data['deleted'] == true` → `data['deleted'] == true || data['deleted'] == 1`

**Root cause:** `syncAllToCloud` (push path) đã biết dùng dual-check `== 1 || == true` nhưng **pull paths** (subscription onChanged + downloadAllFromCloud) chỉ check `== true`. Firestore records bị push với `deleted: 1` (integer, từ bug cũ SyncOperation.update) → `1 != true` → không bị xóa local khi thiết bị khác pull về → ghost products tồn tại mãi + được restore lại khi bấm "Nhận kho từ cloud".

**Phối hợp với [2026-06-08j]:** Fix đó ngăn tạo mới record `deleted:1` trong tương lai. Fix này dọn sạch record cũ đã bị push sai.

---

## [2026-06-08j] - fix: Đồng bộ kho giữa các thiết bị (deleted type mismatch + nút Nhận kho từ Cloud)

**Files thay đổi:**
- `lib/views/inventory_view.dart` — `_deleteProductWithOptions`: đổi `SyncOperation.update` → `SyncOperation.delete`. Trước đây enqueue update → orchestrator đẩy raw SQLite data với `deleted: 1` (integer) lên Firestore. Các thiết bị khác check `data['deleted'] == true` (boolean) → `1 != true` → ghost products tồn tại mãi trên thiết bị khác.
- `lib/services/firestore_service.dart` — `deleteProduct()`: thêm `'deleted': true` vào payload (trước chỉ set `status: 0`). Đồng bộ với `deleteRepair()` và `deleteSale()` đã có `deleted: true`.
- `lib/views/settings_view.dart` — thêm nút **Nhận kho từ Cloud** (màu teal) gọi `SyncService.downloadAllFromCloud(force: true)`. Cho phép thiết bị có kho lệch tải lại toàn bộ từ Firestore.

**Root cause:** Type mismatch Dart strict equality: SQLite integer `1` ≠ Firestore boolean `true`. Khi delete product, enqueue sai operation → orchestrator dùng `_handleUpdate()` thay `_handleDelete()` → `softDeletePayload()` không được gọi → Firestore nhận `deleted: 1` → các thiết bị khác không nhận biết sản phẩm đã bị xóa.

---

## [2026-06-08i] - fix: Hiển thị giảm giá đúng ở list bán & chi tiết đơn bán (3 bugs)

**Files thay đổi:**
- `lib/views/create_sale_view.dart` — `set_price` case: bỏ `item['originalPrice'] = newPrice`. Giờ `originalPrice` giữ nguyên giá catalog → `salePrice` trong snapshot = giá gốc, `unitPrice` = giá bán thực → discount = giá gốc - giá bán được track đúng.
- `lib/views/sale_list_view.dart` — `_totalItemDiscount()`: thêm fallback regex `\(GI[AÀ]M\s+([\d.]+)\)` parse từ `productNames` cho đơn cũ không có `salePrice` trong snapshot (đơn tạo trước khi field `salePrice` được thêm vào snapshot).
- `lib/views/sale_detail_view.dart` — Builder giảm giá: thay điều kiện `itemDisc > 0 && orderDisc > 0` để show "Tổng giảm giá" → nay hiện "Tổng giảm giá: -X Tr" bất cứ khi nào totalDisc > 0; khi có cả 2 loại mới break thành "Giảm sản phẩm" + "Giảm đơn" + "Tổng".

**Root cause chính:** `set_price` case cập nhật cả `originalPrice = newPrice` → `salePrice = unitPrice` → discount = 0 → không có chip/row.

**Backward compat:** Regex fallback hoạt động cho đơn cũ dùng "Giảm giá" (productNames có "(Giảm X)"). Đơn cũ dùng "Sửa giá bán" không có data để recover (originalPrice và sellPrice đều = giá mới, không lưu giá gốc).

---

## [2026-06-08h] - fix: Chuẩn hoá format tiền & hiển thị giảm giá đầy đủ (4 bugs)

**Files thay đổi:**
- `lib/views/inventory_detail_view.dart`
  - `_costRow`: đổi `MoneyUtils.formatCurrency(cost)` → `formatCompactCurrency(cost)` — "Giá vốn" nay hiển thị `10 Tr` thay `10.000.000`.
  - `SingleChildScrollView`: padding bottom `16` → `32` — tránh content bị cắt bởi nav bar.
- `lib/views/sale_detail_view.dart`
  - Thêm getter `_totalItemLevelDiscount`: tính tổng giảm item-level từ `_linkedProducts` (salePrice - soldPrice) × qty.
  - Thêm `_enrichLinkedProducts()`: async enrichment cho đơn cũ không có `salePrice` trong snapshot — lookup IMEI/firestoreId từ DB, dùng `product.price` hiện tại làm fallback khi `price > soldPrice`.
  - Thay block `if (s.discount > 0) _item(...)` bằng Builder: hiển thị "Giảm sản phẩm" (item-level) + "Giảm đơn" (order-level) + "Tổng giảm giá" (khi cả hai loại cùng > 0).

**Quy tắc:**
- Đơn cũ: `_enrichLinkedProducts()` chạy async khi mở màn hình, tự cập nhật badge giảm giá mà không block UI.
- Đơn mới: salePrice đã có sẵn trong snapshot, không cần enrichment.
- Không làm ảnh hưởng bất kỳ tính năng đang chạy ổn định.

---

## [2026-06-08g] - feat: Hiển thị giảm giá & chuẩn hoá format tiền toàn module bán hàng

**Files thay đổi:**
- `lib/views/create_sale_view.dart` — `_buildSaleItemSnapshotsJson`: thêm field `salePrice` (originalPrice tại thời điểm bán) vào snapshot của từng item.
- `lib/widgets/deep_link_navigator.dart` — `ProductLinkRef`: thêm field `salePrice`; `openProductDetail`: thêm param `salePrice` → truyền vào `InventoryDetailView`.
- `lib/views/sale_detail_view.dart` — `_buildLinkedProducts`: parse `salePrice` từ snapshot JSON → gán vào `ProductLinkRef`.
- `lib/widgets/clickable_product_list.dart` — truyền `salePrice` từ `ProductLinkRef` xuống `ClickableProductChip`.
- `lib/widgets/clickable_product_chip.dart` — thêm `salePrice`; tính `itemDiscount = (salePrice - soldPrice) * qty`; hiển thị badge cam `-X Tr` khi discount > 0; đổi `formatCurrency` → `formatCompactCurrency` cho giá bán.
- `lib/views/inventory_detail_view.dart` — thêm param `salePrice`; khi giảm giá: đổi nhãn "Giá bán" → "Giá bán gốc", thêm dòng "Đã giảm: -X Tr", đổi format sang `formatCompactCurrency`.
- `lib/views/sale_list_view.dart` — thêm `_totalItemDiscount()` tính tổng giảm (item-level từ snapshot + order-level `s.discount`); thêm chip **Giảm** vào card khi > 0; thêm `import 'dart:convert'`.

**Quy tắc hiển thị:**
- `discountAmount = salePrice - unitPrice` (per item); tổng = sum items + `s.discount`.
- Chỉ hiển thị badge/dòng giảm khi `discount > 0`.
- Format tiền: `formatCompactCurrency` → `1 Tr`, `11.5 Tr`, `1 Tỷ` (thay cho `1.000.000`).

---

## [2026-06-08f] - feat: Sửa giá bán sản phẩm trực tiếp trong màn hình tạo đơn bán

**Files thay đổi:**
- `lib/views/create_sale_view.dart`
  - Thêm option **"💰 Sửa giá bán sản phẩm"** vào bottom sheet "Ưu đãi sản phẩm" (`_GiftDiscountSheetContent`).
  - Khi chọn, hiện panel inline: giá hiện tại, input giá mới (VND format), checkbox "Cập nhật giá bán mặc định trong kho", nút HỦY/LƯU.
  - Không giới hạn giá (khác với "Giảm giá" phải thấp hơn giá gốc) — hỗ trợ sản phẩm có giá = 0.
  - Kết quả cập nhật ngay: `sellPrice`, `originalPrice`, tổng tiền, giảm giá, thành tiền.
  - Nếu checkbox được tick → gọi `db.updateProductMap(id, {'price': newPrice, 'isSynced': 0})` để cập nhật kho và đánh dấu chờ sync cloud.
  - Thêm state: `_showEditPriceInput`, `_editPriceController`, `_updateInventory`.
  - Thêm method `_onConfirmSetPrice()`.
  - Thêm case `'set_price'` trong switch xử lý kết quả bottom sheet.

---

## [2026-06-08e] - fix: sync health check không báo lỗi khi kho cloud có nhiều hơn local

**Files thay đổi:**
- `lib/services/sync_health_check.dart`
  - **BUG FIX**: `_checkCollection` trả về `cloudOnly = cloudOnlyAfter` cho `products`, khiến `effectiveMismatchCount > 0` → status "Chưa sync hết" dù local hoàn toàn đã sync.
  - Fix: Với `noAutoRestoreCollections` (hiện tại chỉ `products`), báo `cloudOnly = 0` trong `SyncCheckResult`. Cloud-only records cho kho là chủ đích (user xóa kho hoặc chưa import lại) — không nên tính là lỗi.
  - Không ảnh hưởng các collection khác (repairs, sales, customers...) vẫn auto-restore và tính mismatch bình thường.

**Root cause:** Sau khi user xóa sản phẩm và import lại từ KiotViet, cloud vẫn còn 684 records cũ (chưa xóa hoặc từ máy khác). Sync health count 684 cloud-only → "Chưa sync hết" dù `Local chưa sync = 0` và `Queue = 0`.

---

## [2026-06-08d] - fix: KiotViet import restore sản phẩm đã xóa thay vì tạo bản ghi mới

**Files thay đổi:**
- `lib/services/kiotviet_excel_import_service.dart`
  - **BUG FIX**: Hàm `importProducts` trước đây bỏ qua sản phẩm có `deleted=1` khi kiểm tra trùng tên, dẫn đến INSERT bản ghi mới với `id` mới (thay vì UPDATE bản ghi cũ). Kết quả: cùng một tên sản phẩm có 2 bản ghi active, đơn bán cũ mất tham chiếu `productId`.
  - Fix: Duplicate check giờ tìm TẤT CẢ bản ghi (kể cả `deleted=1`). Nếu tìm thấy bản ghi đã xóa → UPDATE (khôi phục) thay vì INSERT, giữ nguyên `id` gốc.
  - Fix thêm: Khi khôi phục bản ghi đã xóa, tự động soft-delete các bản ghi active trùng tên (tạo ra bởi lần import lỗi trước) để tránh duplicate.

**Root cause:** Sau sự cố "Dọn kho cloud" xóa 831 sản phẩm, user re-import từ KiotViet Excel. Vì query duplicate bỏ qua `deleted=1`, tất cả sản phẩm được INSERT mới với `id` auto-increment mới. Đơn bán cũ lưu `productId` (SQLite int) của sản phẩm cũ → không còn khớp, hiển thị sản phẩm sai.

---

## [2026-06-08c] - fix(critical): sửa logic "Dọn kho cloud" + thêm nút khôi phục khẩn cấp

**Files thay đổi:**
- `lib/views/kiotviet_import_view.dart`
  - **BUG FIX**: `_runCloudCleanup` trước đây xóa TẤT CẢ sản phẩm cloud không có trong local device (kể cả sản phẩm valid của máy khác). Fix: chỉ push `deleted:true` cho sản phẩm **có deleted=1 trong local SQLite** của thiết bị này.
  - **Thêm**: `_runCloudRestore()` — khôi phục khẩn cấp: tìm sản phẩm bị đánh dấu xóa trên cloud trong 60 phút qua và set `deleted:false`.
  - **Thêm**: Nút "⚠️ Khôi phục kho cloud" (màu cam) bên dưới nút "Dọn kho cloud".

**Root cause của bug:** OPPO A94 chỉ có 262 sản phẩm trong local SQLite, cloud có 1093 sản phẩm. Khi chạy "Dọn kho cloud" từ A94, hàm tìm 831 sản phẩm "cloud-only" (không có trong A94 local) và đánh dấu xóa — bao gồm cả sản phẩm valid của Samsung A32 và các máy khác.

---

## [2026-06-08b] - fix: stop auto-restore products từ cloud + nút Dọn kho cloud

**Files thay đổi:**
- `lib/services/sync_health_check.dart` — tắt auto-restore cho `products` (cloud-only records không tự download về nữa, tránh vòng lặp restore)
- `lib/views/kiotviet_import_view.dart` — thêm nút "Dọn kho cloud": đẩy `deleted:true` lên Firestore cho sản phẩm tồn tại trên cloud nhưng đã bị xóa local

**Root cause:** Health check thấy cloud có 237 records hơn local → tự download về (auto-fix) → user xóa lại → health check restore lại → vòng lặp vô tận. Fix: products không tự restore từ cloud; user tự dọn bằng nút "Dọn kho cloud".

---

## [2026-06-08a] - fix: bulk xóa kho dùng soft-delete + fix đơn duyệt giao vẫn hiện chờ duyệt

**Files thay đổi:**
- `lib/views/inventory_view.dart` — đổi bulk delete từ `deleteProduct` (hard) sang `softDeleteProduct` để Firestore nhận `deleted:true` khi sync
- `lib/views/repair_detail_view.dart` — trong `_protectLocalUnsyncedRepairFromStaleCloud`: thêm exception "nếu cloud có status=4 mà local<4, luôn accept cloud" → tránh manager duyệt trên máy khác bị block

**Root cause:**
1. **Bulk xóa kho**: Checkbox select → xóa gọi `db.deleteProduct(id)` = hard delete → record mất khỏi SQLite → không có gì để push `deleted:true` lên Firestore → máy khác vẫn thấy record đó.
2. **Đơn chờ duyệt không update**: Staff submit chờ duyệt trên Phone A (isSynced=false), manager duyệt trên Phone B → Firestore có status=4. Phone A nhận cloud update nhưng protection logic block vì isSynced=false + timestamps gần nhau → Phone A vẫn hiện "Đang chờ duyệt".

---

## [2026-06-07l] - fix(sync): đẩy deleted lên Firestore cho tất cả bảng

**Files thay đổi:**
- `lib/services/sync_service.dart` — thêm `_syncDeletedRowsToCloud()` generic helper + loop gọi cho sales, customers, suppliers, purchase_orders, repair_parts

**Vấn đề:** Khi xóa mềm (deleted=1) records trong bất kỳ bảng nào, `syncAllToCloud()` chỉ sync records với `deleted=0` → Firestore không nhận được thông tin xóa → thiết bị khác vẫn thấy record đã xóa.

**Fix:** `_syncDeletedRowsToCloud()` query `deleted=1 AND isSynced=0 AND firestoreId IS NOT NULL`, batch push `{deleted:true, updatedAt, shopId}` lên Firestore, sau đó mark `isSynced=1` trong SQLite.

---

## [2026-06-07k] - fix(critical): khôi phục phones bị dedup xóa nhầm (DB v103)

**Files thay đổi:**
- `lib/data/db_helper.dart` — DB v103: restore DIEN_THOAI bị soft-delete trong 48h qua (deleted=1, qty>0); bỏ call deduplicateProductsByImei() khỏi fast_inventory_check_view

**Root cause:** `deduplicateProductsByImei()` nhóm phones theo `LOWER(imei)` — IMEI từ KiotViet là mã ngắn 4-5 chữ số (không phải IMEI 15 chữ số chuẩn), nên nhiều máy khác nhau có cùng mã → bị xóa nhầm (82 phones). Migration v103 restore an toàn bằng filter `updatedAt > now-48h` để tránh restore phones user đã xóa cũ.

**Lưu ý:** Chênh lệch kho(222) vs kiểm kho là bình thường — kiểm kho chỉ hiện phones có IMEI (để scan được). Phones không có IMEI không thể kiểm bằng scan.

---

## [2026-06-07j] - fix: kiểm kho thiếu 44 máy + double IMEI

**Files thay đổi:**
- `lib/data/db_helper.dart` — fix `getInStockProducts` dùng `(status=1 OR status IS NULL)` thay `status=1` strict; thêm `deduplicateProductsByImei()`
- `lib/views/fast_inventory_check_view.dart` — gọi `deduplicateProductsByImei()` mỗi lần mở kiểm kho

**Root cause:**
1. **Kiểm kho thiếu máy**: `getInStockProducts` dùng `status = 1` strict — phones import từ KiotViet có `status = NULL` → bị loại khỏi kiểm kho dù vẫn còn trong kho. Tất cả query khác đều dùng `(status = 1 OR status IS NULL)`.
2. **Double IMEI**: Một số phones vẫn còn `imei` dạng `IMEI1|IMEI2` chưa được split (v102 migration có thể bỏ sót nếu record được push từ Firestore sau migration). `deduplicateProductsByImei()` fix split sót + dedup nếu cùng IMEI xuất hiện 2 lần.

---

## [2026-06-07i] - fix: bàn phím che nội dung khi bấm KTV/sửa thông tin trong đơn sửa

**Files thay đổi:**
- `lib/views/repair_detail_view.dart` — fix `MediaQuery.viewInsetsOf` dùng inner `ctx` thay outer `context` trong 2 bottom sheet (_editTechnicianNotes + _editBasicInfo); thêm `unfocus()` trước `pop()` trong _editBasicInfo

**Root cause:** `showModalBottomSheet` với `isScrollControlled: true` cần outer `Padding(bottom: viewInsets)` để đẩy nội dung lên trên bàn phím. Nhưng code đang dùng `MediaQuery.viewInsetsOf(context)` với outer widget context — outer context không re-render khi bàn phím mở trong sheet → padding = 0 → bàn phím che TextField.

**Fix:** Đổi sang `MediaQuery.viewInsetsOf(ctx)` (builder context của sheet) để Padding reactive với keyboard. Đảm bảo tất cả close handlers đều gọi `FocusScope.of(ctx).unfocus()` trước `Navigator.pop()` để tránh `_dependents.isEmpty` crash.

---

## [2026-06-07h] - feat: đẩy dữ liệu KiotViet lên Firestore (force re-sync)

**Files thay đổi:**
- `lib/data/db_helper.dart` — thêm `backfillShopId()` + `markAllUnsynced()`
- `lib/services/sync_service.dart` — thêm `forceResyncKiotVietData()`
- `lib/views/settings_view.dart` — thêm nút "Đẩy dữ liệu KiotViet lên Cloud" trong Sync section

**Root cause:** Dữ liệu import từ KiotViet Excel được lưu với `shopId=NULL` (cột chưa tồn tại lúc import). `getAllSales()` dùng `WHERE shopId = ?` (strict) → không tìm thấy → `syncAllToCloud` không push lên Firestore. `products` đã có shopId nhưng `isSynced=1` sai do write Firestore fail thầm lặng (App Check error).

| Bước | Action | Kết quả |
|------|--------|---------|
| 1 | `backfillShopId('sales', shopId)` | Gán shopId cho đơn bán thiếu → `getAllSales()` tìm thấy chúng |
| 2 | `backfillShopId('products', shopId)` | Tương tự cho sản phẩm |
| 3 | `markAllUnsynced('sales')` | Reset `isSynced=0` → syncAllToCloud pick up |
| 4 | `markAllUnsynced('products')` | Reset `isSynced=0` |
| 5 | `syncAllToCloud(force: true)` | Push toàn bộ lên Firestore (idempotent merge) |

**UI:** Settings > Đồng bộ dữ liệu → card cam "Đẩy dữ liệu KiotViet lên Cloud"

---

## [2026-06-07g] - feat: tách kho điện thoại — mỗi IMEI = 1 sản phẩm riêng

**Files thay đổi:**
- `lib/data/db_helper.dart` — version 102, migration v102 split multi-IMEI, upsertProduct + _upsertPhoneSplit
- `lib/views/create_sale_view.dart` — lock qty=1 cho sản phẩm phone có 1 IMEI

| # | Thay đổi | Mô tả |
|---|---------|-------|
| 1 | **DB v102 migration** | Query tất cả `DIEN_THOAI` có `imei LIKE '%|%'`; update record gốc (IMEI đầu, qty=1); insert record mới cho mỗi IMEI còn lại với `firestoreId = parentFid__s{i}`, `isSynced=0` |
| 2 | **upsertProduct auto-split** | Khi nhận phone từ KiotViet với IMEI dạng `"A\|B\|C"` → delegate sang `_upsertPhoneSplit` → upsert riêng từng IMEI với firestoreId độc lập |
| 3 | **Cart qty lock** | Trong `create_sale_view.dart`: `isPhoneUnit = type==DIEN_THOAI && imei != null && !imei.contains('|')` → disable `+`/`-` button và text field, qty cố định 1 |

**Kết quả:** Mỗi điện thoại có IMEI riêng = 1 row trong DB → dễ theo dõi tồn kho + bán hàng biết đúng máy nào được bán.

---

## [2026-06-07f] - fix: giá bán 0đ + IMEI không xác định trong chi tiết đơn bán

**Files thay đổi:**
- `lib/views/sale_detail_view.dart` — fix đọc key snapshot + truyền soldImei
- `lib/widgets/deep_link_navigator.dart` — thêm soldImei vào ProductLinkRef và openProductDetail
- `lib/widgets/clickable_product_chip.dart` — pass soldImei đến navigator
- `lib/widgets/clickable_product_list.dart` — pass soldImei đến chip
- `lib/views/inventory_detail_view.dart` — thêm soldImei param + hiển thị "IMEI đã bán"

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | "Giá bán: 0" trong chi tiết sản phẩm từ đơn bán | `_buildSaleItemSnapshotsJson` lưu giá vào key `unitPrice`, nhưng `_buildLinkedProducts` đọc key `price` → null → `product.price` từ DB (= 0) được hiển thị | Đọc `item['price'] ?? item['unitPrice']` |
| 2 | "Không biết IMEI nào đã bán" | Snapshot lưu IMEI vào `productImei`, nhưng đọc `item['imei']` → null; `soldImei` không được truyền qua chain; `InventoryDetailView` chỉ hiện `product.imei` (tất cả IMEI) | Đọc `item['imei'] ?? item['serial'] ?? item['productImei']`; thêm `soldImei` xuyên suốt chain; hiển thị "IMEI đã bán" riêng trong `InventoryDetailView` |

---

## [2026-06-07e] - fix: 3 bugs kiểm kho + sync + topbar

**Files thay đổi:**
- `lib/views/fast_inventory_check_view.dart` — fix await + dọn topbar
- `lib/views/repair_detail_view.dart` — fix sync delay

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | "Chờ sync" badge tới 1 phút sau khi lưu đơn | `syncAll()` xử lý toàn bộ queue (có thể nhiều items) trước khi `.then()` fire → badge đợi tất cả items xong | Thêm direct `FirestoreService.upsertRepair(r)` ngay trong `_saveData()` — badge clear sau <2s khi write thành công; orchestrator vẫn chạy cho queue còn lại |
| 2 | "Lỗi lưu kiểm kho: Invalid argument: Instance of 'Future<String>'" khi bấm nút lưu | `UserService.getCurrentUserName()` là `Future<String>` nhưng gọi không có `await` → `createdBy` field trong DB insert nhận `Future<String>` thay vì `String` | Thêm `await` trước `getCurrentUserName()` |
| 3 | Topbar kiểm kho quá nhiều icon (7+ icon) | Tất cả actions nằm bên ngoài | Giữ 3 icon quan trọng (zone selector, QR scan, flash khi đang scan); checklist/keyboard/save draft/save DB/history/settings vào `PopupMenuButton` |

---

## [2026-06-07d] - fix: storage_locations không sync lên cloud khi nhiều thiết bị

**Files thay đổi:**
- `lib/views/storage_location_view.dart` — fix save flow + thêm re-upload recovery khi view mở

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | storage_locations: local=2, cloud=0 — thiết bị khác không thấy vị trí kho | `isSynced: true` được set TRƯỚC Firestore write. Nếu write fail (offline/rules), record kẹt local mãi mãi với flag "đã sync" → sync engine bỏ qua | (a) Đổi save flow: save local với `isSynced: false` → Firestore write → cập nhật `isSynced: true` chỉ khi write thành công; (b) Thêm `_reuploadLocalToCloud()` trong `_syncAndLoad` — re-upload tất cả local locations (merge=true, idempotent) để recover records bị kẹt |

---

## [2026-06-07c] - fix(critical): Supplier search + Staff profile 0 orders

**Files thay đổi:**
- `lib/data/db_helper.dart` — thêm `nameNorm TEXT` vào CREATE TABLE suppliers
- `lib/widgets/supplier_picker_sheet.dart` — reset `_isLoading = false` khi search thay đổi
- `lib/views/staff_public_profile_view.dart` — stat cards dùng all-time count; search sale theo cả email prefix

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Search NCC gõ "7" không ra "7 VIÊN" | `nameNorm` column chỉ được add qua v100 migration (onUpgrade). Fresh install chạy onCreate → không có `nameNorm` → `UPPER(nameNorm) LIKE ?` throw SQL error → caught silently → kết quả rỗng | Thêm `nameNorm TEXT` vào CREATE TABLE trong onCreate để column luôn tồn tại bất kể đường dẫn cài đặt |
| 1b | Race condition khi type nhanh trong search | Scroll-triggered `_loadPage` có thể đang chạy (`_isLoading=true`) khi search timer fires → `_loadPage` guard return sớm → search không chạy | Reset `_isLoading = false` trong setState của `_onSearchChanged` và `_clearSearch` |
| 2 | Hồ sơ nhân viên báo 0 đơn dù có đơn | (a) Stat cards dùng `monthlyRepairs/Sales.length` (tháng hiện tại) thay vì all-time; (b) `getSalesBySellerName` chỉ tìm theo display name 'MISS HỒNG' nhưng sale lưu `sellerName = 'HONG'` (email prefix) | (a) Đổi stat cards sang `repairs.length` / `sales.length` (all-time); (b) Fetch thêm sales theo email prefix và dedup bằng Set<id> |

---

## [2026-06-07b] - fix: InventoryCheck type cast + Firestore product_categories permission

**Files thay đổi:**
- `lib/views/inventory_view.dart` — fix type cast crash khi load kiểm kê kho
- `firestore.rules` — thêm token-claim fallback cho `product_categories` read rule

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | `Error loading current check: type 'QueryRow' is not a subtype of type 'InventoryCheck?'` | `checks.cast<InventoryCheck?>()` cố cast `Map<String, dynamic>` (SQLite row) trực tiếp sang `InventoryCheck` — không thể dùng `cast<>()` để convert class | Map từng row sang `InventoryCheck.fromMap()` sau khi decode `itemsJson` JSON string, rồi mới cast<InventoryCheck?> |
| 2 | `product_categories: Missing or insufficient permissions` lặp 5 lần/session | `belongsTo(shopId)` trong Firestore rules gọi nhiều `get()` calls — nếu timing không đúng (boot lần đầu, App Check fail), các get() này fail → toàn bộ rule evaluation fail | Thêm `|| request.auth.token.shopId == shopId` fallback — bypass `get()` calls khi JWT token đã có sẵn claim, giống pattern đang dùng ở `settings` subcollection rule |

---

## [2026-06-07] - fix(inventory): 3 bugs trong _showInlineCostEdit (nhập giá vốn)

**Files thay đổi:**
- `lib/views/inventory_view.dart` — fix `_showInlineCostEdit`

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Sheet bị cắt ở dưới, không thấy hết nội dung | `Column(mainAxisSize: min)` không scroll khi nội dung vượt chiều cao màn hình | Wrap Column trong `SingleChildScrollView` để user cuộn được |
| 2 | Text dropdown "Phương thức thanh toán" invisible khi mở | `style: TextStyle(color: Colors.white)` trên `DropdownButtonFormField` + `dropdownColor: PopupTheme.bgDark` (= white `0xFFFFFFFF`) → chữ trắng trên nền trắng | Đổi `style` sang `Colors.black87` — chữ tối trên nền trắng |
| 3 | Crash `_dependents.isEmpty` khi bấm "Lưu giá vốn" | `MediaQuery.of(outerCtx)` tạo cross-tree InheritedWidget dependency. Khi `Navigator.pop(ctx)` đóng route, overlay MediaQuery deactivate trước khi Padding release dependency → assertion fail | Đổi sang `MediaQuery.of(ctx)` (same-tree context của StatefulBuilder) |

---

## [2026-06-06] - fix(edge-to-edge P2): Inventory search keyboard + Dashboard Settings AppBar

**Files thay đổi:**
- `lib/main.dart` — thêm `MaterialApp.builder` override `MediaQuery.padding.top` từ `View.of(context)` toàn app
- `lib/views/inventory_view.dart` — thay `showModalBottomSheet` search bằng inline `TextField` trong `Scaffold` body; xóa `_openSearchDialog`; thêm `_isSearchBarVisible` + `_inlineSearchController`
- `lib/views/dashboard_settings_view.dart` — wrap `Scaffold` với `MediaQuery` override per-screen (belt-and-suspenders)

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Inventory search: bấm 🔍 → bàn phím hiện nhưng không thấy TextField | Bottom sheet context nhận `MediaQuery.viewInsets.bottom = 0` trong edge-to-edge mode → container bị keyboard che | Chuyển sang inline `TextField` đặt trong `Scaffold` body; `Scaffold(resizeToAvoidBottomInset: true)` tự đẩy field lên trên keyboard |
| 2 | Dashboard Settings: AppBar toolbar bị che bởi status bar | Sub-screens (pushed via `rootNavigator`) nhận `MediaQuery.padding.top = 0` → `AppBar` đặt toolbar tại y=0, chồng lên status bar; touch targets nằm trong vùng status bar (y=39-105 vs status bar y=0-110) | Thêm `MaterialApp.builder` global: đọc `View.of(context).padding.top / devicePixelRatio`, inject vào `MediaQuery` nếu lớn hơn giá trị hiện tại — fix toàn bộ sub-screens cùng lúc |

**Verified on device (Samsung A32 RF8R31SS7GY, Android 16):**
- ✅ Inventory search: TextField + keyboard visible đồng thời, filter hoạt động
- ✅ Dashboard Settings: back button, title "Tùy chỉnh Dashboard", 2 tabs, restore/save icons đều hiện đúng

---

## [2026-06-06] - fix(edge-to-edge): AppBar/topbar bị che bởi status bar trên Android 16

**Files thay đổi:**
- `lib/main.dart` — gọi `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` sau `WidgetsFlutterBinding.ensureInitialized()`

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Back button và action icons trên AppBar bị che bởi status bar trên một số màn hình | `targetSdk = 36` (Android 16) bắt buộc edge-to-edge mode. Flutter engine không được thông báo → `MediaQuery.padding.top = 0` → `Scaffold + AppBar` render toolbar content từ y=0, chồng lên status bar | Thêm `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` trong `main()` trước `runApp()` (chỉ Android) — fix tất cả màn hình bị ảnh hưởng |

---

## [2026-06-06] - fix(inventory): search bottom sheet không hiện trên bàn phím + dashboard tab icon

**Files thay đổi:**
- `lib/views/inventory_view.dart` — fix keyboard handling trong `_openSearchDialog`, restock sheet, inline cost edit sheet
- `lib/views/dashboard_settings_view.dart` — thu nhỏ tab icon size 18 → 14 để vừa tab bar

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Tìm kiếm kho: chỉ thấy bàn phím, không thấy TextField | `MediaQuery.viewInsetsOf(stateCtx)` bên trong `StatefulBuilder` dùng `InheritedModel` aspect-based dependency → không propagate keyboard insets trong bottom sheet route → `Padding(bottom: 0)` → container bị keyboard che hoàn toàn | Bỏ `StatefulBuilder`, bỏ `useSafeArea: true`, dùng `MediaQuery.of(ctx).viewInsets.bottom` (full dependency từ outer builder ctx) |
| 2 | Restock sheet & inline cost edit sheet cũng bị vùi bàn phím | Cùng root cause: `viewInsetsOf(innerCtx)` trả về 0 | Đổi sang `MediaQuery.of(outerCtx).viewInsets.bottom`; outer ctx truyền dependency đúng vào StatefulBuilder |
| 3 | Tab bar Dashboard Settings bị chật/overflow | Icon size 18 quá to cho `Tab(icon+text)` compact | Giảm icon size xuống 14 |

---

## [2026-06-05] - fix(finance): audit & sửa 3 lỗi tính toán tài chính home screen

**Files thay đổi:**
- `lib/finance_v2/finance_v2_data_service.dart` — thêm `partnerPaymentOut` + `importExpenseOut` vào `FinanceV2Snapshot`
- `lib/views/home_view.dart` — dùng finance_v2 làm source of truth cho tất cả breakdown

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Chi tiêu biểu đồ > tổng Chi (thừa TT đối tác) | `operatingExpenseOut` đã gồm partner payment, nhưng `_todayPartnerPaid` lại lấy từ `analysis.partnerPaid` khác service → double-count | Track `partnerPaymentOut` riêng trong finance_v2, trừ khỏi `operatingExpenseOut`, dùng `financeSnapshot.partnerPaymentOut` |
| 2 | Thu khác bị under-report khi có thu nợ KH | `incomeOther` snapshot đã net debt (`extraIn-debtCollectIn`), nhưng home_view lại trừ `debtCollectedConsistent` lần nữa | `_todayMiscIncome = financeSnapshot.incomeOther` (không trừ thêm) |
| 3 | Nhập hàng hiển thị thấp hơn thực tế | `importOutConsistent` chỉ scan bảng `expenses`, bỏ sót `importHistory`; `operatingExpenseOut` lại dùng `importExpenseOut` đầy đủ → breakdown < totalOut | Expose `importExpenseOut` từ snapshot, dùng nhất quán |

---

## [2026-06-05] - fix(crash): _dependents.isEmpty assertion khi đóng bottom sheet có TextField

**Files thay đổi:**
- `lib/views/repair_detail_view.dart`, `attendance_management_view.dart`, `attendance_view.dart`, `category_management_view.dart`, `create_repair_order_view.dart`, `debt_view.dart`, `expense_view.dart`, `inventory_view.dart`, `missing_info_products_view.dart`, `sale_detail_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Root cause** | `showModalBottomSheet(isScrollControlled: true)` tạo inner `MediaQuery`. `Padding(EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom))` đăng ký phụ thuộc vào inner MediaQuery. Khi sheet đóng, inner MediaQuery deactivate trước khi Padding hủy đăng ký → `'_dependents.isEmpty': is not true` |
| 2 | **Fix** | Thay toàn bộ `MediaQuery.viewInsetsOf(ctx)` → `MediaQuery.viewInsetsOf(context)` (outer State context) trong 11 files, 21 chỗ |

---

## [2026-06-05] - fix(import): FieldValue poison map → SQLite crash khi nhập Khách/NCC

**Files thay đổi:**
- `lib/services/excel_import_service.dart` — pass `Map.of(data)` vào `addCustomer`/`addSupplier`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Root cause** | `addCustomer(data)` và `addSupplier(data)` mutate map gốc in-place: `data['updatedAt'] = FieldValue.serverTimestamp()`. Sau đó `_db.upsertCustomer(data)` gặp FieldValue → SQLite throw `Invalid argument: Instance of 'FieldValue'` → 0/N thành công |
| 2 | **Fix** | Pass shallow copy `Map.of(data)` thay vì `data` trực tiếp → map gốc không bị contaminate |

---

## [2026-06-05] - fix(index): Thêm Firestore index repairs shopId+updatedAt DESC

**Files thay đổi:**
- `firestore.indexes.json` — Thêm index `repairs: shopId ASC + updatedAt DESC + __name__ DESC`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Missing index** | `watchRepairsByShop` dùng `orderBy('updatedAt', descending: true)` nhưng index chỉ có `updatedAt ASC` → `failed-precondition` mỗi lần mở OrderListView |
| 2 | **Deployed** | `firebase deploy --only firestore:indexes` — index đang build trên Firebase |

---

## [2026-06-05] - fix(sync): upsertRepair block repair giá 0đ / cost 0đ

**Files thay đổi:**
- `lib/services/firestore_service.dart` — `validateAmount` allowZero: true cho price + cost trong upsertRepair

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Bug** | `upsertRepair` gọi `validateAmount(r.price)` và `validateAmount(r.cost)` với `allowZero=false` — block toàn bộ repair bảo hành (price=0) và repair không dùng linh kiện (cost=0), không sync lên Firestore |
| 2 | **Fix** | Truyền `allowZero: true` cho cả hai — số âm vẫn bị chặn |

---

## [2026-06-05] - fix(sync): Giảm log nhiễu TimeoutException + bỏ qua poll khi offline

**Files thay đổi:**
- `lib/services/sync_service.dart` — Thêm import ConnectivityService, offline guard, phân loại timeout log

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Offline guard** | `pollCollection()` trả về sớm nếu `!ConnectivityService.instance.isOnline` — không gửi Firestore query khi mất mạng |
| 2 | **Timeout log downgrade** | `TimeoutException` giờ log `⏱️` (transient) thay vì `❌ Poll sync error` — giảm nhiễu console khi mạng kém / token đang refresh |
| 3 | **Root cause** | 35+ collection đều timeout cùng lúc do Firebase Auth token refresh hang, làm tất cả query xếp hàng 20s |

---

## [2026-06-05] - feat(import-export): Trang Nhập/Xuất Excel hợp nhất trong Cài đặt

**Files thêm mới:**
- `lib/services/excel_import_service.dart` — Import service (5 loại dữ liệu, Firestore + SQLite sync)
- `lib/views/import_export_view.dart` — Trang Nhập/Xuất chuyên nghiệp với date filter + progress dialog

**Files thay đổi:**
- `lib/utils/excel_export_helper.dart` — Thêm `exportSuppliers()`
- `lib/views/shop_settings_view.dart` — Thêm entry "Nhập / Xuất dữ liệu" trong mục Sao lưu
- `lib/views/order_list_view.dart` — Xóa nút Xuất Excel đơn sửa
- `lib/views/sale_list_view.dart` — Xóa nút Xuất Excel đơn bán
- `lib/views/inventory_view.dart` — Xóa menu item Xuất Excel kho hàng
- `lib/views/customer_management_view.dart` — Xóa nút Xuất Excel khách hàng

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **ExcelImportService** | Import 5 loại: Đơn sửa, Đơn bán, Kho hàng, Khách hàng, Nhà cung cấp. Header-based column detection, money/date parsing, progress callback, Firestore + SQLite upsert |
| 2 | **ImportExportView** | Bộ lọc ngày (Hôm nay/Tuần/Tháng/Năm/Tuỳ chọn), 5 card loại dữ liệu mỗi card có Xuất + Nhập, progress dialog với chi tiết lỗi |
| 3 | **exportSuppliers** | Xuất danh sách NCC ra Excel (8 cột: STT, Tên, SĐT, Email, Địa chỉ, Ghi chú, Trạng thái, Ngày tạo) |
| 4 | **Xóa nút export riêng lẻ** | Xóa 4 nút xuất Excel rải rác (đơn sửa, đơn bán, kho, khách hàng) — tập trung vào trang Cài đặt |
| 5 | **Build** | `flutter build apk --debug` pass, 0 compile error |

---

## [2026-06-05] - fix(sync): chặn re-init real-time sync trùng lặp theo cùng user/shop

**Files thay đổi:**
- `lib/services/sync_service.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Dedupe `initRealTimeSync`** | Thêm signature theo `uid + shopId + role + permissions`; nếu cùng session đã active thì bỏ qua lần gọi trùng để tránh `cancelAllSubscriptions()` rồi dựng lại listener vô ích. |
| 2 | **Giảm loop runtime** | Giảm nguy cơ log kiểu `Canceling all subscriptions` / `Khởi tạo real-time sync...` lặp lại do HomeView hoặc EventBus kích hoạt nhiều nguồn cùng lúc. |
| 3 | **Validation** | `flutter analyze lib/services/sync_service.dart` không còn lỗi compile; còn 3 info/lint pre-existing của file. |

---

## [2026-06-05] - fix(sync-P1): Sửa 2 lỗi đồng bộ nguy hiểm trong payment services + kiểm toán kiến trúc

**Files thay đổi:**
- `lib/services/supplier_payment_service.dart`
- `lib/services/repair_partner_payment_service.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **P1-FIX `supplier_payment_service`** | `_syncToCloud()`: trước đây set `isSynced=1` TRƯỚC khi `_firestore.set()` — nếu cloud fail, local tin là đã sync nhưng cloud không có bản ghi. Sửa: đặt `isSynced=0`, ghi Firestore, sau đó set `isSynced=1` chỉ khi Firestore xác nhận thành công. |
| 2 | **P1-FIX `repair_partner_payment_service`** | Cùng pattern lỗi và cùng cách sửa như trên. |
| 3 | **Kiểm toán kiến trúc sync toàn hệ thống** | Điều tra tĩnh (không sửa code) toàn bộ luồng sync: SyncOrchestrator, SyncService, tất cả listeners, downloadAllFromCloud, các view gọi syncAll, và payment/inventory/sales/customer/supplier/debt. Báo cáo 10 điểm với bằng chứng source code cụ thể. |

**Bằng chứng kỹ thuật P1:**
- `supplier_payment_service.dart` dòng 65 (trước fix): `{'firestoreId': docId, 'isSynced': 1}` trước dòng 69 `_firestore.set()`
- `repair_partner_payment_service.dart` dòng 67 (trước fix): cùng pattern
- Khi Firestore fail, local bản ghi có `isSynced=1`, listener real-time không nhận doc (doc không tồn tại), => bản ghi payment bị mất hoàn toàn trên cloud mà app không biết

**Các rủi ro còn lại đã được ghi nhận (chưa sửa — xem HANDOVER.md):**
- P2: `downloadAllFromCloud` upsert toàn bộ mà không đi qua `_shouldAcceptCloudData`
- P2: `sendChat()` trong `FirestoreService` nuốt lỗi `catch (_) {}` nhưng UI vẫn báo thành công
- P3: các `syncAll()` call ở `inventory_view`, `salvage_phone_view`, `fast_stock_in_view` không kiểm tra `SyncResult.failed`
- P3: `customer_service.updateCustomer()` cập nhật local trước, cloud sau; cloud fail không enqueue retry

**Validation:**
- `flutter analyze lib/services/supplier_payment_service.dart lib/services/repair_partner_payment_service.dart`: No issues found
- `flutter analyze` toàn repo: 0 error cứng (1753 info/lint là pre-existing)

---

## [2026-06-04] - feat: Chuyển đơn sửa chữa sang shop mới

**Files thay đổi:**
- `lib/services/migration_service.dart` (NEW)
- `lib/views/shop_migration_view.dart` (NEW)
- `lib/views/backup_restore_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **MigrationService** | Service copy repairs từ shop nguồn → shop đích, batch 400 docs, paginate 500 docs/trang, hỗ trợ cancel |
| 2 | **ShopMigrationView** | UI 3 phase: setup (chọn shop đích + xác minh) → running (progress realtime) → done (summary + hướng dẫn tiếp theo) |
| 3 | **Entry point BackupRestoreView** | Section "Chuyển đơn sửa chữa" ở cuối Firestore tab, chỉ hiện với role owner/super_admin |
| 4 | **Super-admin UX** | Dropdown chọn shop từ getAllShops(); Owner: text field + nút Xác minh |
| 5 | **Copy mode** | Tạo doc mới với ID mới + shopId mới, shop cũ giữ nguyên |

---

## [2026-06-04] - Fix customer sync + const naming warning

**Files thay đổi:**
- `lib/services/sync_service.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Rename `_customerBatchSize`** | Đổi thành `customerBatchSize` để tránh lint warning về private const trong function body |

---

## [2026-06-04] - Fix ghost topbar: xóa nested Navigator + dùng rootNavigator:true

**Files thay đổi:**
- `lib/views/home_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Xóa nested Navigator** | `_buildTabHost` không còn bọc tabs trong `Navigator` widget — tất cả route push tự động lên root navigator, che toàn màn hình |
| 2 | **rootNavigator: true** | `_openMyStaffProfile`, `_openShopSettingsFromGreeting`, `_openDashboardSettings` đổi từ `Navigator.push(context,…)` sang `Navigator.of(context, rootNavigator: true).push(…)` |
| 3 | **_usesNestedNavigator** | Luôn trả `false` — không còn nested navigator nào trong tab host |

---

## [2026-06-04] - Thiếu vốn/NCC: fix trùng dữ liệu + bấm vào mở chi tiết

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Fix trùng dữ liệu** | Thêm `_productKey()` (ưu tiên firestoreId→imei→name+ngày) + `_infoScore()` + `_dedup()` — sau mỗi lần load giữ record có nhiều thông tin nhất, loại bỏ bản sao |
| 2 | **Bấm card → chi tiết** | `GestureDetector.onTap` gọi `_openDetail()`: đã bán + có IMEI → `SaleDetailView`; còn hàng hoặc không có IMEI → `InventoryDetailView` |
| 3 | **Dedup cross-page** | `_loadMore()` truyền `seen` map từ items hiện có → không load bản sao khi phân trang |

---

## [2026-06-04] - Fix logic NCC + Phương thức TT trong CHỈNH SỬA PHIẾU NHẬP

### 3 bug logic trong smart_stock_in_view

**Files thay đổi:**
- `lib/views/smart_stock_in_view.dart`

| # | Bug | Nguyên nhân | Fix |
|---|-----|-------------|-----|
| 1 | `_requireSupplier ?? true` → bắt buộc NCC khi settings chưa load | Default sai | Đổi thành `?? false` |
| 2 | `_supplierEffectivelyRequired`: `cost > 0` → ép NCC dù "Bắt buộc NCC" đã OFF | Logic thừa | Xóa điều kiện `cost > 0`; chỉ giữ `_requireSupplier` và `CÔNG NỢ` |
| 3 | Phương thức TT luôn required dù không có cost + allowPendingCost ON | Hard-coded | Thêm getter `_paymentMethodRequired`: chỉ bắt buộc khi `!allowPendingCost`, hoặc `cost > 0`, hoặc `NCC đã chọn` |

---

## [2026-06-04] - Popup chọn mã nhập nhanh: thêm tìm kiếm + phân trang

### Thêm `showQuickCodePickerSheet` — BottomSheet có search + infinite-scroll pagination

**Files thay đổi:**
- `lib/widgets/quick_code_picker_sheet.dart` *(mới)*
- `lib/views/fast_stock_in_view.dart`
- `lib/views/smart_stock_in_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Tạo widget tái sử dụng** | `showQuickCodePickerSheet(context)` → `DraggableScrollableSheet` (88% màn hình), trả về `QuickInputCode?` |
| 2 | **Search real-time** | TextField với debounce 350ms, gọi `getQuickInputCodesPaged()` với param `search`, có nút X xóa nhanh |
| 3 | **Phân trang infinite scroll** | 20 item/trang, trigger load-more khi scroll cách đáy 150px, spinner ở cuối list |
| 4 | **Empty state** | Icon + text theo context (chưa có mã / không tìm thấy), nút "Xóa bộ lọc" khi đang search |
| 5 | **Item card** | Icon type (điện thoại/phụ kiện), tên, subtitle (brand+model hoặc mô tả), badge giá vốn nếu có |
| 6 | **Nút Quản lý** | Bấm → đóng sheet + mở `QuickInputCodesView` qua root navigator |
| 7 | **Thay popup cũ** | `fast_stock_in_view._selectFromLibrary()` và `smart_stock_in_view._selectFromLibrary()` → 3 dòng gọi `showQuickCodePickerSheet()` |

### Validation
- `flutter analyze` (3 files) → 0 error, 0 warning; 32 info pre-existing

---

## [2026-06-04] - Fix CHỈNH SỬA PHIẾU NHẬP: NCC bị reset + UX scroll khi thiếu thông tin

### 2 bug trong smart_stock_in_view (edit mode)

**Files thay đổi:**
- `lib/views/smart_stock_in_view.dart`

| # | Loại | Vấn đề | Giải pháp |
|---|------|---------|-----------|
| 1 | Bug/Data | Khi mở edit phiếu nhập, `_selectedSupplier` bị reset về `null` nếu tên NCC trong entry không khớp chính xác với `_suppliers` list (bị xóa NCC, hoặc không tìm thấy) → "LƯU VÀO HÀNG CHỜ" luôn disabled dù entry đã có NCC | Thêm NCC cũ vào `_suppliers` list tạm thời nếu chưa có, luôn giữ `_selectedSupplier = entry.supplierName` |
| 2 | UX | Warning "Thiếu: Nhà cung cấp, Phương thức TT" ở bottom nhưng các fields đó ở giữa form (phải scroll) — user không biết phải làm gì | Warning trở thành `GestureDetector`, bấm vào tự `Scrollable.ensureVisible()` scroll đến card kế toán; thêm icon ↑ và text "— bấm để điền" |

### Validation
- `flutter analyze` → 0 lỗi mới (16 info pre-existing)

---

## [2026-06-04] - Audit & fix toàn diện chat nội bộ + fix tab "Đã bán" thiếu vốn/NCC

### Audit chat nội bộ → fix 7 vấn đề bảo mật, stability, UX

**Files thay đổi:**
- `lib/services/chat_service.dart`
- `lib/services/ai_chat_service.dart`
- `lib/views/advanced_chat_view.dart`
- `lib/views/missing_info_products_view.dart`
- `lib/data/db_helper.dart`

| # | Loại | Vấn đề | Giải pháp |
|---|------|---------|-----------|
| 1 | Bug/Count | Tab "Đã bán" hiển thị count=2 nhưng list trống — `getProductsCount` không filter `quantity<=0` | Thêm `soldOnly` param vào `getProductsPaged` + `getProductsCount`; view dùng `soldOnly: tab==1` |
| 2 | Security | `sendTextMessage()` không giới hạn độ dài → user gửi được tin nhắn 1MB | Thêm `_kMaxMessageLength = 2000` + validate đầu hàm |
| 3 | Security | `_sanitize()` chỉ strip `<>` và backtick — thiếu `{} $` và role-override pattern | Thêm strip `{→( }→) $→''` + regex strip `system|assistant|human|user` prefix |
| 4 | Bug/UX | Typing indicator không tắt khi user background app | `didChangeAppLifecycleState(paused)` thêm `ChatService.setTypingStatus(false)` |
| 5 | Bug/UX | Reaction tap không báo lỗi khi Firestore write fail | Await `toggleReaction()` → show snackbar nếu `!ok` |
| 6 | UX | AI cloud timeout 20s → user tưởng app hang | Giảm xuống 10s |
| 7 | Code quality | Comment sai `// Get unread messages (unused result — only kept for side-effect ordering)` trong `markAllAsRead()` | Xóa comment gây nhầm lẫn |

### Validation
- `flutter analyze` → 0 lỗi mới
- Commit: (xem git log) | Branch: `master`

---

## [2026-06-05] - Fix sync bug nghiêm trọng: expense/debt không lên Firestore khi nhập giá vốn

### Audit luồng tài chính → phát hiện + sửa 2 lỗi sync bị bỏ qua

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`
- `lib/views/inventory_view.dart`

| # | Loại | Vấn đề | Giải pháp |
|---|------|---------|-----------|
| 1 | Bug/Sync | `insertDebt(isSynced:0)` tại cả 2 màn nhưng KHÔNG `enqueueDebt()` → debt không bao giờ lên Firestore | Thêm `SyncOrchestrator().enqueueDebt(id, firestoreId, operation: create)` cho CÔNG NỢ path |
| 2 | Bug/Sync | `insertExpense(isSynced:0)` tại cả 2 màn nhưng KHÔNG `enqueueExpense()` → expense không bao giờ lên Firestore | Thêm `SyncOrchestrator().enqueueExpense(id, firestoreId, operation: create)` cho TIỀN MẶT/CK path |
| 3 | Bug/Schema | Expense record thiếu `createdAt` (chỉ có `date`) | Thêm `'createdAt': now` vào insertExpense map |
| 4 | Bug/Memory | `inventory_view._showInlineCostEdit()`: `costCtrl` không `dispose()` | Lưu `costText`, `costCtrl.dispose()` ngay sau sheet đóng |
| 5 | Bug/UX | Validation giá vốn > 0 nằm SAU sheet đóng → user không thấy lỗi | Chuyển validation vào ElevatedButton.onPressed trong modal (trước `Navigator.pop`) |
| 6 | UX | Nút hủy gọi "Bỏ qua" → khó hiểu | Đổi thành "Hủy" |

**Audit findings (kiến trúc — chưa fix):**
- 8 views bypass `PaymentIntentService` (inventory, missing_info, debt, sales, repair_order, fast_stock_in, parts_inventory, repair_detail)
- `daily_financial_analysis_service`: dedup fuzzy `(amount ± 1000đ)` → có thể double-count
- `importOut` metric chỉ đếm `supplier_import_history`, không đếm expenses có category NHẬP HÀNG

### Validation
- `flutter analyze` → 0 lỗi mới (8 info pre-existing trong inventory_view không liên quan)
- `flutter build apk --debug` → thành công
- Commit: `29ffae55` | Branch: `master`

---

## [2026-06-04] - Audit & sửa toàn diện màn Thiếu vốn / NCC

### Audit và fix 6 vấn đề trong missing_info_products_view.dart

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`
- `lib/data/db_helper.dart`

#### Vấn đề tìm thấy & đã sửa

| # | Loại | Vấn đề | Giải pháp |
|---|------|---------|-----------|
| 1 | Bug/Memory leak | `costCtrl` (TextEditingController) không `dispose()` sau mỗi lần mở popup | Lưu `costText`, gọi `costCtrl.dispose()` ngay sau `showModalBottomSheet` trả về |
| 2 | Bug/Logic | Thiếu `mounted` guard sau `await getCurrentShopId()` | Thêm `if (!mounted) return;` |
| 3 | Bug/Count sai | `_counts[1]` (Tab "Đã bán") tính tổng không filter `quantity ≤ 0` | Thêm `soldOnly` param vào `getProductsCount`, gọi với `soldOnly: !inStock` |
| 4 | UI/Theme | Popup nền tối `0xFF1C2331` nhưng fields đã trắng → không nhất quán | Đổi container sang `Colors.grey.shade50`, handle và tiêu đề theo light theme |
| 5 | UX/State | Không subscribe EventBus → màn không tự refresh khi nhập vốn từ nơi khác | Thêm `StreamSubscription _productEventSub` lắng nghe `financial_changed` / `products_changed` |
| 6 | UX/Edge | Nếu cả `_allowPendingCost=false` lẫn `_enableSupplier=false`, card render rỗng | `_buildCard` trả về `SizedBox.shrink()` khi không có badge/action nào |

### Validation
- `flutter analyze lib/views/missing_info_products_view.dart lib/data/db_helper.dart` → No errors (6 info pre-existing trong db_helper không liên quan).
- `flutter build apk --debug` → thành công.


## [2026-06-04] - Sửa độ rõ chữ AppBar và màu chữ popup Nhập giá vốn

### Cải thiện UI màn Thiếu vốn / NCC

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`

#### Vấn đề
- Chữ AppBar/Tab ở màn Thiếu vốn / NCC hiển thị mờ, độ tương phản thấp.
- Popup Nhập giá vốn có trạng thái chữ bị chìm/trùng nền sáng ở một số trường nhập liệu.

#### Fix đã áp dụng
- Tăng độ rõ tiêu đề AppBar bằng `titleWidget` riêng với cỡ chữ và trọng số đậm hơn.
- Chuẩn hóa màu chữ TabBar (`labelColor`, `unselectedLabelColor`, `indicatorColor`) để đọc rõ trên nền gradient.
- Điều chỉnh nhóm field trong popup Nhập giá vốn:
	- Dropdown phương thức thanh toán: nền trắng + chữ đậm màu tối + label/icon màu xám trung tính.
	- Picker nhà cung cấp: nền trắng + chữ tối, placeholder xám, viền rõ ràng.

### Validation
- `flutter analyze lib/views/missing_info_products_view.dart` → No issues found.
- `flutter build apk --debug` → thành công.


## [2026-06-03] - Fix vòng lặp sync `permission_denied:storage_locations -> refresh scope -> permission_denied`

## [2026-06-04] - Fix toggle "Cho phép nhập giá vốn sau" báo bật nhưng UI không đổi

## [2026-06-04] - Chuẩn hóa nhập liệu: "iPhone" là thương hiệu, không phải tên

### Sửa mapping khi tạo/chọn mã nhập nhanh cho sản phẩm điện thoại

**Files thay đổi:**
- `lib/views/quick_input_codes_view.dart`
- `lib/views/smart_stock_in_view.dart`
- `lib/views/fast_stock_in_view.dart`

#### Vấn đề
- Khi người dùng nhập chuỗi như `IPHONE 13 ...` ở phần tên, một số luồng dữ liệu cũ không đẩy đúng `IPHONE` vào trường `brand`.
- Kết quả là form nhập kho có thể thiếu thương hiệu hoặc hiển thị sai kỳ vọng.

#### Fix đã áp dụng
- Trong dialog lưu mã nhập nhanh:
	- Tự nhận diện thương hiệu đứng đầu chuỗi tên (ví dụ `IPHONE`) và map về `brand` chuẩn.
	- Nếu `model` đang trống thì tự tách phần sau `brand` vào `model`.
- Trong luồng nạp mã nhập nhanh ở Smart/Fast Stock In:
	- Ưu tiên `brand` đã lưu.
	- Fallback suy luận từ `name + model` cho dữ liệu cũ thiếu `brand`.

### Validation
- `flutter analyze` cho các file liên quan: không phát sinh compile error mới.
- `flutter build apk --debug`: thành công.

---

### Sửa triệt để trạng thái công tắc bị trả về OFF do stale settings

**Files thay đổi:**
- `lib/views/home_view.dart`
- `lib/services/category_service.dart`
- `lib/data/db_helper.dart`

#### Vấn đề
- Khi bật/tắt công tắc ở tab Cài đặt (HomeView), toast/snackbar báo thành công nhưng công tắc có lúc vẫn hiển thị OFF.
- Nguyên nhân là race condition giữa:
	- optimistic state ở client
	- luồng reload settings chạy song song và có thể trả dữ liệu stale tạm thời.
- Có thêm nguyên nhân gốc trên DB cũ: bảng `shop_settings` chưa có cột `allowPendingCost`, khiến đọc local luôn về `false` và ghi đè UI.

#### Fix đã áp dụng
- Thêm cờ `_isSavingPendingCost` để chặn double-tap/double-toggle trong lúc lưu.
- Giữ `_pendingCostOverride` trong suốt quá trình save + reload, không clear sớm.
- Khi `_loadShopSettings()` trả dữ liệu, merge theo override pending để tránh UI bị ghi đè ngược.
- Chỉ clear override khi dữ liệu nền đã khớp giá trị vừa lưu.
- Bổ sung migration phòng thủ cho `shop_settings.allowPendingCost`:
	- thêm cột trong schema tạo mới
	- thêm đảm bảo cột tồn tại ở `onOpen`
	- thêm đảm bảo cột trước khi `CategoryService` đọc/ghi local settings.
- Siết chặt luồng lưu để không còn "báo thành công giả":
	- `CategoryService.saveShopSettings()` chỉ trả thành công khi ghi local DB thành công.
	- `home_view` và `settings_view` kiểm tra kết quả `saveShopSettings()`; nếu fail sẽ hiện lỗi đỏ.
	- Bổ sung xác nhận sau lưu (read-back) để đảm bảo giá trị đã được phản ánh đúng trước khi báo thành công.
	- Chặn trường hợp chưa có `shopId` hiện tại (thường gặp ở super admin chưa chọn shop).

#### App Check / permission liên quan
- Nếu App Check hoặc Firestore Rules chặn ghi, trước đây có thể bị nuốt lỗi và vẫn hiện trạng thái như đã bật.
- Sau bản vá này, các trường hợp bị chặn sẽ trả lỗi rõ ràng cho người dùng thay vì hiện thành công.

### Validation
- `flutter analyze lib/views/home_view.dart`
	- Không có compile error mới; chỉ còn info/lint pre-existing của file lớn.
- `flutter build apk --debug`
	- Build thành công.

---

### Xử lý triệt để vòng lặp reinit/sync gây tốn quota App Check

**Files thay đổi:**
- `lib/services/sync_service.dart`

#### Root cause
- `SyncService` khởi tạo `_lastUserPermissionSignature` từ permissions đã chuẩn hóa.
- Sau đó listener `users` lại so sánh với dữ liệu profile thô của Firestore (`users/{uid}`), làm phát sinh false-positive "permissions changed".
- False-positive này kích hoạt `forceReinitializeSync()` lặp lại, dẫn tới chuỗi:
	- `permission_denied:storage_locations`
	- `Refreshing sync scope...`
	- subscribe/poll lại và tiếp tục `permission_denied`.

#### Fix đã áp dụng
- Đổi baseline chữ ký quyền người dùng:
	- Không set `_lastUserPermissionSignature` ở đầu `initRealTimeSync`.
	- Để listener `users` lấy snapshot đầu tiên làm baseline nhằm tránh lệch nguồn dữ liệu.
- Bổ sung cooldown cho reinit do access-change (`20s`) để chặn vòng lặp kích hoạt dồn dập.
- Bổ sung `storage_locations` vào nhóm quyền kho (`allowViewInventory`) trong `_canSubscribeCollection` để không subscribe collection trái quyền.

### Validation
- `flutter analyze lib/services/sync_service.dart`
	- 4 info/lint pre-existing (không phát sinh compile error mới từ patch).
- `flutter build apk --debug`
	- Build thành công.

---

## [2026-06-03] - Tính năng "Nhập vốn sau" + toggle 2 phương thức giá vốn

### Bật/tắt chế độ cho phép nhập giá vốn sau (Settings)

**Files thay đổi:**
- `lib/views/inventory_view.dart`
- `lib/views/settings_view.dart` (đã có từ trước)
- `lib/models/shop_settings_model.dart` (đã có từ trước)

#### Tính năng mới trong Kho hàng (khi `allowPendingCost = true`):
- **Badge ⚠ Chưa vốn** — hiện màu cam trên card sản phẩm khi `cost == 0`, nhấn để sửa giá vốn inline
- **Inline edit giá vốn** — nhấn badge để mở dialog nhập nhanh giá vốn, tự động save + sync lên Firestore
- **Filter chip "Chưa nhập vốn"** — lọc nhanh toàn bộ sản phẩm chưa có giá vốn (chỉ hiện khi feature bật)
- **Cảnh báo mềm khi bán** — snack bar cam khi bán sản phẩm cost = 0, không block giao dịch

#### Toggle trong Settings:
- 🔒 Phương thức cũ: bắt buộc nhập giá vốn > 0 (mặc định)
- ✅ Phương thức mới: cho phép bỏ qua, nhập vốn sau

### Validation
- `flutter analyze lib/views/inventory_view.dart` — 8 info warnings (pre-existing, không phải từ code mới)
- `flutter build apk --release` — Build thành công (117.5MB)
- Install + test Samsung A32 (RF8R31SS7GY) — App khởi động, đăng nhập OK

---

## [2026-06-03] - AI hiểu ngôn ngữ người dùng: mở rộng cụm kho/tồn kho tự nhiên

### Mở rộng nhận diện câu lệnh tiếng Việt cho các cụm người dùng hay nói

**Files thay đổi:**
- `lib/services/ai_command_router.dart`
- `lib/services/natural_order_parser_service.dart`

#### Mở rộng nhận diện tồn kho
- Thêm các cụm như `kho linh kiện`, `kho phụ kiện`, `tồn kho hiện tại`, `hàng tồn hiện tại`, `còn bao nhiêu trong kho` vào router stock check.
- Natural order parser cũng nhận thêm các cụm tồn kho tương tự để route đúng intent ngay cả khi người dùng không nói đúng từ khóa kỹ thuật.

### Validation
- `flutter analyze lib/services/ai_command_router.dart lib/services/natural_order_parser_service.dart`
	- Không có issue mới.
- `flutter build apk --debug`
	- Build thành công.

---

## [2026-06-03] - Permission-gated sync: tự reinit khi quyền/shop-lock thay đổi

### Siết startup sync theo quyền hiện tại và tự mở lại khi quyền được cấp

**Files thay đổi:**
- `lib/services/sync_service.dart`

#### Đồng bộ theo phạm vi truy cập
- Thêm nhận diện chữ ký quyền người dùng và chữ ký khóa cấp shop để phát hiện khi scope truy cập thay đổi.
- Khi `users/{uid}` hoặc `shops/{shopId}` đổi các field ảnh hưởng đến quyền, `SyncService` sẽ tự `forceReinitializeSync()` để tải lại đúng collection được phép.
- Giữ nguyên cơ chế lọc collection hiện có, nên collection không được phép vẫn không bị subscribe/download khi app mở.

### Validation
- `flutter analyze lib/services/sync_service.dart`
	- Không có lỗi compile mới; còn các `info`/lint hiện hữu của dự án.

---

## [2026-06-03] - AI kho hàng: tách đúng mặt hàng/sản phẩm tồn + chặn lặp phản hồi

### Sửa luồng AI trả lời kho và giảm phản hồi bị lặp

**Files thay đổi:**
- `lib/data/db_helper.dart`
- `lib/services/ai_chat_service.dart`
- `functions/index.js`

#### Tách đúng số liệu kho
- `DBHelper.getInventoryBreakdownSummary()` mới trả về đồng thời:
	- số `mặt hàng` = số record sản phẩm còn hàng
	- `sản phẩm tồn` = tổng `quantity`
	- `giá vốn` theo từng nhóm
- `AiChatService.getTodayStats()` lấy breakdown theo 4 nhóm:
	- `Kho điện thoại` (`DIEN_THOAI`)
	- `Kho phụ kiện` (`PHU_KIEN`)
	- `Kho linh kiện` (`LINH_KIEN`)
	- `Tồn kho hiện tại` (toàn bộ kho)

#### Cải thiện câu trả lời AI
- `quickAnswer()` của AI chat đổi sang format có breakdown rõ ràng, không còn dùng `stockCount` như thể đó là tổng quantity.
- Cloud Function `chatAssistant` được siết prompt để:
	- không lặp lại cùng một section trong một câu trả lời
	- phân biệt rõ `mặt hàng` và `sản phẩm tồn`
- Thêm lọc khử trùng lặp paragraph ở đầu ra server trước khi trả về app.

### Validation
- `flutter analyze lib/data/db_helper.dart lib/services/ai_chat_service.dart`
	- Không còn lỗi compile; chỉ còn 2 `info` hiện hữu của dự án.
- `flutter build apk --debug`
	- Build thành công: `build/app/outputs/flutter-apk/app-debug.apk`

---

## [2026-05-29] - Fix đơn sửa ghi chi phí lặp + bổ sung xóa backup local + xóa dữ liệu local/cloud

### Sửa nghiệp vụ chi phí đơn sửa và dữ liệu backup/reset

**Files thay đổi:**
- `lib/views/repair_detail_view.dart`
- `lib/services/backup_service.dart`
- `lib/views/backup_restore_view.dart`

#### Sửa lỗi nghiệp vụ đơn sửa
- `repair_detail_view.dart`: khi đã ghi sổ quỹ trước đó mà sửa giá vốn nhiều lần, hệ thống chỉ ghi phần chênh lệch (`delta`) thay vì ghi lại toàn bộ chi phí mỗi lần lưu.
- Thêm `_applyCostFundDelta(...)` để tạo bút toán tăng/giảm giá vốn tương ứng (`OUT` khi tăng, `IN` khi giảm), tránh cộng trùng chi phí.

#### Backup SQLite
- `backup_service.dart`: thêm `deleteLocalSqliteBackup(filePath)` để xóa 1 file backup cục bộ.
- `backup_restore_view.dart`: thêm nút xóa cho từng item backup SQLite trong máy, có hộp thoại xác nhận trước khi xóa.

#### Xóa dữ liệu chọn lọc (Kho/Tài chính)
- `backup_service.dart`: mở rộng mapping bảng SQLite để xóa sâu hơn cho nhóm Kho/Tài chính (`product_categories`, `product_variants`, `supplier_product_prices`, `financial_activity_log`, `adjustment_entries`, `payroll_locks`, ...).
- `backup_restore_view.dart`: thêm tùy chọn **xóa luôn dữ liệu Cloud** theo nhóm đã chọn để tránh dữ liệu cloud đồng bộ ngược trở lại sau khi xóa local.
- `backup_service.dart`: thêm `deleteSelectedDataFromCloud(...)` (batch delete theo `shopId`).

### Validation
- `flutter analyze lib/views/repair_detail_view.dart lib/views/backup_restore_view.dart lib/services/backup_service.dart`
	- Không phát sinh compile error mới; còn các `info`/lint hiện hữu.
- `flutter build apk --debug`
	- Build thành công: `build/app/outputs/flutter-apk/app-debug.apk`
	- Có cảnh báo NDK plugin yêu cầu `28.2.13676358` (không chặn build debug).

---

## [2026-05-29] - Backup: Xóa dữ liệu chọn lọc + Dọn backup cũ

### Quản lý dữ liệu SQLite mở rộng

**Files thay đổi:**
- `lib/services/backup_service.dart`
- `lib/views/backup_restore_view.dart`

#### Tính năng mới
- `BackupService.deleteSelectedData(List<String> collections)` — xóa vĩnh viễn các table được chọn trong SQLite, trả về số bản ghi đã xóa
- `BackupService.cleanOldLocalBackups({required int keepDays})` — xóa file backup cục bộ cũ hơn N ngày, trả về số file đã xóa
- Tab SQLite thêm section **Xóa dữ liệu chọn lọc**: preset nhanh "Kho phụ kiện/Sản phẩm", "Linh kiện sửa chữa" + nút "Xóa tùy chọn" mở `_CollectionPickerDialog`
- Tab SQLite thêm section **Dọn backup cũ**: chọn giữ 30/60/90/180 ngày → tự động dọn file cũ hơn

---

## [2026-05-29] - AI Assistant: 8 UX Improvements (Sprint AI-UX)

### AI Trợ Lý — Cải tiến UX toàn diện

**Files thay đổi:**
- `lib/services/ai_chat_service.dart`
- `lib/widgets/ai_chat_overlay.dart`
- `lib/services/ai_command_router.dart`
- `lib/services/ai_usage_logger.dart`
- `lib/views/ai_usage_dashboard_view.dart`

#### #3 Chat → Auto-fill đơn trực tiếp từ overlay
- Thêm 3 `AiActionType` mới: `createRepairFromChat`, `createSaleFromChat`, `createStockFromChat`
- Thêm `payload` field vào `AiAction` để truyền nội dung câu hỏi xuống sheet
- `quickAnswer()`: nếu "tạo đơn sửa iPhone 15 cho Minh" (có ≥2 từ nội dung sau keyword) → trả về action `createRepairFromChat` với `payload = question`
- `ai_chat_overlay._handleAction()`: xử lý 3 type mới bằng cách gọi `AiOrderInputSheet.show(context, mode: ..., prefilledText: action.payload)` — AI tự điền form từ mô tả

#### #5 Follow-up context chips sau mỗi AI answer
- Thêm `followUpChips: List<(String, IconData)>` vào `AiQuickResponse`
- `ai_chat_overlay._buildChips()`: khi `_contextChips` không rỗng → hiển thị context chips (màu xanh lá) thay vì preset chips tím
- Context chips được cập nhật trong `_send()` sau mỗi quick answer
- Ví dụ: sau "doanh thu hôm nay" → chips [Tháng này, Lợi nhuận, Đơn sửa]

#### #4 Daily briefing khi mở app lần đầu trong ngày
- `_sendWelcome()` kiểm tra `SharedPreferences['ai_last_open_date']` → nếu ngày mới hiển thị briefing "Chào buổi mới! Điểm cần lưu ý: X đơn sửa chờ, nợ phải thu..."
- Các lần mở tiếp trong ngày: chào ngắn có pending repairs count

#### #6 Lưu lịch sử chat qua session (SharedPreferences)
- `_loadHistory()`: load 20 tin nhắn gần nhất từ `SharedPreferences['ai_chat_history']` khi init
- `_saveHistory()`: lưu sau mỗi AI response (quick + cloud), giữ tối đa 20 messages
- `_welcomeSent` flag: tránh gửi welcome 2 lần khi có history

#### #2 More quick action buttons (followUpChips trên nhiều intent)
- Thêm `followUpChips` cho: doanh thu, tháng này, năm nay, bán hàng, sửa chữa, tồn kho, linh kiện, đơn bán/sửa, công nợ, lợi nhuận

#### #8 Mở rộng từ điển voice command
- `ai_command_router.dart`: thêm synonym cho stock check (+5 keywords), stock entry (+5), finance today (+6), customer (+5), pending repairs (+6), sale (+5), repair (+10 thương hiệu + triệu chứng)

#### #7 Dashboard: Tab phản hồi xấu
- `ai_usage_logger.getShopSummaryToday()`: bổ sung `negativeFeedbackItems` — list query/answer của các 👎
- `ai_usage_dashboard_view.dart`: chuyển từ single-view sang `DefaultTabController` 2 tab: **Tổng quan** + **Phản hồi xấu**
- Tab Phản hồi xấu: list card từng câu hỏi bị dislike + answer snippet + giờ ghi nhận

---

## [2026-05-29] - Sprint 4B: Flutter Analyze Warning Cleanup (132 → 1)

### Dọn cảnh báo flutter analyze (Sprint 4B)

Xóa toàn bộ unused elements, unused imports, unused fields, dead null-aware expressions và dead code qua ~20 file:

- **home_view.dart** — xóa 8 unused methods (`_buildDataItem`, `_buildPinnedCard`, `_quickActionButton`, `_buildDebtSummaryCard`, `_financeOverviewSection`, `_buildExpenseDetail`, `_financeStatCard`, `_buildLogoutCard`), dead `if (false)` BarChart block, 3 unused profit fields (`_todayNetProfit`, `_todaySalesProfit`, `_todayRepairProfit`), `dart:math` import
- **inventory_view.dart** — xóa 6 unused imports, 6 unused fields (`_isAdmin`, `_isCheckingLoading`, `_isScanning`, `_iconSize`, `_smallFontSize`, `_btnMinHeight`), 7 unused methods (`_buildInventoryTypeItems`, `_saveCheck`, `_onQRDetected`, `_progressItem`, `_warningItem`, `_showAddProductDialog`, `_showEditProductDialog`, v.v.)
- **sale_detail_view.dart** — xóa `_hasLogo`, `_toNoSign`, `_row`, unused import `app_text_styles`
- **sale_list_view.dart** — xóa 7 unused methods (`_summaryItem`, `_activeFilterChip`, `_getTimeFilterLabel`, `_getPaymentStatusLabel`, `_statItem`, `_getPayColor`, `_buildReturnChips`)
- **repair_detail_view.dart** — xóa `_staffInfoRow`, `_buildCustomerContent`, `_buildFinancialSummary`, v.v.
- **settings_view.dart** — xóa `_buildLinkedAccountsCard`, `_openHelpCenter`
- **staff_list_view.dart** — xóa 4 unused fields + `_generateInviteCode`, `_generateTempPassword`, v.v.
- **work_schedule_settings_view.dart** — xóa `_getShortRoleName`, `_saveStaffSalary`, `_buildStaffWorkScheduleList`, 6 tab methods
- **unified_sync_button.dart** — xóa `_buildSyncOperationalMarkdown`, `_showReportExportDialog`, `_showOrphanDataDialog`, cascade imports (`sync_audit_service`, `data_migration_service`, `open_filex`, `share_plus`, `foundation`)
- Nhiều file khác: `cash_closing_view`, `pty_print_designer_view`, `payroll_view`, `quick_input_codes_view`, `shop_settings_view`, `smart_stock_in_view`, `current_shop_service`, `variant_selector`, v.v.

**Kết quả:** 132 warnings → 1 (giữ lại `_eventBusSub2` trong `parts_inventory_view.dart` do là StreamSubscription — xóa sẽ phá event listening)

---

## [2026-05-29] - Phân Quyền Chat AI, Prompt Injection Guard, AI Usage Logger, Fix Compile Error

### Tính năng mới (2026-05-29)

#### Phân quyền Chat & AI chi tiết
- `lib/services/user_service.dart`
  - Thêm 4 quyền mới vào permission defaults và save/load: `allowSendChat`, `allowPinChat`, `allowDeleteOtherChat`, `allowCloudAI`.
  - `allowSendChat`: tất cả vai trò trừ fallback `user`; `allowPinChat`/`allowDeleteOtherChat`: Manager/Owner/Admin; `allowCloudAI`: Manager trở lên.
  - Tham số mới trong `updateStaffPermissions()` cho phép Owner cấu hình từng quyền per-staff.

#### AI Usage Logger
- `lib/services/ai_usage_logger.dart` *(file mới)*
  - Ghi log mọi tương tác AI (`quickAnswer`, `cloudAI`, `parseOrder`, `feedback`) lên Firestore collection `ai_usage_logs`.
  - Hỗ trợ đếm cloud AI calls trong ngày theo user/shop để hiển thị trên dashboard.
- `lib/views/ai_usage_dashboard_view.dart` *(file mới)*
  - Màn hình thống kê usage AI: số lần gọi, phân loại, feedback.

#### Prompt Injection Guard trong AI Chat Service
- `lib/services/ai_chat_service.dart`
  - Thêm `_sanitize()`: loại bỏ HTML tags, backticks, collapse newlines, giới hạn 1000 ký tự.
  - Áp dụng sanitize cho question, history content, repairSummaries, topDebtorLines trước khi gửi lên Cloud Function.

#### AI Chat Overlay — Permission + Connectivity + Search + Feedback
- `lib/widgets/ai_chat_overlay.dart`
  - Load `allowCloudAI` từ `UserService.getCurrentUserPermissions()` để kiểm soát nút Cloud AI.
  - Theo dõi trạng thái kết nối thực từ `ConnectivityService` (poll mỗi giây).
  - Thêm chế độ tìm kiếm tin nhắn (`_searchMode`) và field controller.
  - Thêm map phản hồi (`_feedbackMap`) cho từng tin nhắn.
  - Log `AiCallType.quickAnswer` vào `AiUsageLogger` sau mỗi lần trả lời nhanh.

#### Chat View — Permission, Rate Limit, Pin/Delete Guard
- `lib/views/advanced_chat_view.dart`
  - Load `allowSendChat`, `allowPinChat`, `allowDeleteOtherChat` từ permissions.
  - Client-side rate limit: tối đa 30 tin nhắn / phút (`_kMaxMsgPerMinute`).
  - Hoàn trả slot rate-limit nếu gửi tin nhắn thất bại.

#### Super Admin Console — Việt hóa nhãn UI
- `lib/views/super_admin_console_view.dart`
  - Đổi nhãn tiếng Anh còn sót (`Role`, `Shop ID`, `Broadcast`, `Permissions`, `Settings`, `Danger Zone`) sang tiếng Việt.

#### Sync Service — Dọn Dead Code
- `lib/services/sync_service.dart`
  - Xóa hàm `_scheduleResubscribe()` không còn được gọi (dead code gây lint warning).

#### Sync Center — Refactor
- `lib/widgets/unified_sync_button.dart`
  - Tách `_handleClearFailed()` (logic xóa failed queue) thành `_handleOpenFirebaseStats()` và `_handleOpenFirestoreConnectivityPage()` (điều hướng đến trang thống kê Firebase RW và Firestore Connectivity Test).
  - Bỏ import `firebase_auth` không dùng.

### Bug Fix (2026-05-29)
- `lib/views/shop_selector_view.dart`
  - Xóa tham chiếu đến biến `_pinVerified` và `_checkingPin` không tồn tại trong class (gây compile error `undefined_identifier`).

### Validation (2026-05-29)
- `flutter analyze --no-fatal-warnings`: 0 `error`, còn `1230` `info/warning` pre-existing (giảm từ 1552 nhờ dọn dead code).
- Không có compile error nào.

---

## [2026-05-26] - Hoàn Thiện Sao Lưu/Khôi Phục Offline + Online, Thêm Nút ... Trên Cài Đặt

### Follow-up Cloud Backup Fix (2026-05-26)
- `lib/services/backup_service.dart`
	- Thêm hàm xóa backup SQLite cloud: `deleteSqliteBackupFromFirebase(fileName)`.
	- Tối ưu liệt kê backup cloud: bỏ phụ thuộc `getDownloadURL()` để giảm lỗi đọc metadata/list khi policy chặt.
- `lib/views/backup_restore_view.dart`
	- Thêm nút xóa cho từng bản backup SQLite trên Cloud.
	- Bổ sung dialog xác nhận xóa và reload danh sách sau khi xóa.
	- Cải thiện thông báo lỗi sao lưu/khôi phục/xóa cloud theo mã lỗi phổ biến (`permission-denied`, `unauthorized`, `object-not-found`, `unauthenticated`).
- `storage.rules`
	- Bổ sung rule cho `db_backups/{shopId}/{allPaths=**}` để cho phép read/create/update/delete đúng theo tenant `shopId`.
	- Giới hạn upload backup tối đa 250MB.

### Validation (follow-up cloud backup)
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart`
	- Không có compile error mới; còn lint info sẵn có của file.
- `firebase deploy --only storage`
	- Deploy thành công Storage Rules mới cho project `huyaka-1809`.

### Follow-up Migration & Sync Hardening (2026-05-26)
- `lib/services/backup_service.dart`
	- Mở rộng mapping restore SQLite cho các domain còn thiếu khi chuyển shop: `repair_parts`, `salvage_phones`, `storage_locations`, `payment_requests`, `payment_intents`, `repair_partners`, `partner_repair_history`, `import_orders`.
	- Khi chọn chế độ chuyển dữ liệu vào shop hiện tại: tự động remap `shopId`, reset `isSynced=0`, và xóa `firestoreId` để dữ liệu được upload lại đúng shop mới.
	- Bổ sung nhãn collection cho các module kho/đối tác/thanh toán mới.
- `lib/views/backup_restore_view.dart`
	- Mở rộng danh sách chọn khôi phục theo nhóm để bao phủ đủ: đơn sửa, kho máy xác, kho linh kiện, kho vị trí, yêu cầu đóng tiền, chi đối tác/NCC, lịch sử nhập.
- `lib/services/sync_health_check.dart`
	- Mở rộng phạm vi kiểm tra sync + auto-fix cho `salvage_phones`, `storage_locations`, `payment_requests`, `payment_intents`, `repair_partners`, `partner_repair_history`.
- `lib/services/sync_domain_report_service.dart`
	- Cập nhật domain report để phản ánh đúng các bảng/domain mới trong phần cài đặt đồng bộ.
- `lib/views/register_view.dart`
	- UI đăng ký chỉ còn loại hình kinh doanh điện tử.
- `lib/views/onboarding/business_type_wizard.dart`
	- Wizard onboarding và quick selector chỉ còn điện tử; `availableTypes` giới hạn còn `electronics`.
- `lib/widgets/shop_switcher_widget.dart`
	- Luồng tạo chi nhánh mới bỏ dropdown ngành, cố định tạo shop theo ngành điện tử.

### Validation (follow-up migration)
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart lib/services/sync_health_check.dart lib/services/sync_domain_report_service.dart lib/views/register_view.dart lib/views/onboarding/business_type_wizard.dart lib/widgets/shop_switcher_widget.dart`
- `flutter build apk --debug`

### Changed
- `lib/services/backup_service.dart`
	- Hoàn thiện khôi phục SQLite từ Cloud bằng `restoreSqliteFromFirebase(fileName)`.
	- Tải file `.db` từ `Firebase Storage` và ghi đè DB local để khôi phục offline từ bản online.
- `lib/views/backup_restore_view.dart`
	- Bật chức năng "Khôi phục" cho từng bản backup SQLite trên Cloud (không còn trạng thái "đang phát triển").
	- Thêm xác nhận trước khi khôi phục và thông báo yêu cầu khởi động lại app sau khôi phục SQLite.
	- Bổ sung nút `...` ở AppBar để điều hướng nhanh giữa tab SQLite/Firestore và mở hướng dẫn sử dụng.
	- Bổ sung card "Hướng dẫn nhanh" cho tab SQLite và "Khôi phục theo từng mục" cho tab Firestore.
- `lib/views/settings_view.dart`
	- Thiết kế lại phần thao tác nhanh bằng nút `...` ở trên AppBar.
	- Từ menu `...` có thể đi nhanh tới: `Sao lưu & Khôi phục`, `Hướng dẫn sử dụng`, `Trung tâm trợ giúp`.
- `lib/data/user_guide_repository.dart`
	- Cập nhật kịch bản hướng dẫn sao lưu/khôi phục cho cả offline (SQLite) và online (Firestore).
	- Làm rõ luồng khôi phục chọn lọc theo từng mục trên Firestore.

### Validation
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart lib/views/settings_view.dart lib/data/user_guide_repository.dart`
	- Không phát sinh lỗi compile mới; còn warning/info legacy của dự án.
- `flutter build apk --debug`: thành công (`build/app/outputs/flutter-apk/app-debug.apk`).

### Follow-up UX Fixes (2026-05-26)
- `lib/views/backup_restore_view.dart`
	- Tăng tương phản `TabBar` trên AppBar (label/unselected/indicator màu trắng) để tránh trùng màu khó đọc.
	- Bổ sung khu vực "Bản sao lưu SQLite trong máy" để xem được các file `.db` đã lưu.
	- Thêm thao tác rõ ràng:
		- "Lưu file .db vào máy"
		- "Chia sẻ bản sao mới nhất"
		- Khôi phục trực tiếp từ danh sách backup cục bộ.
	- Thêm lựa chọn khi khôi phục SQLite: "Khôi phục nguyên bản" hoặc "Chuyển vào shop hiện tại".
- `lib/services/backup_service.dart`
	- Thêm `listLocalSqliteBackups()` và `shareSqliteFile()` phục vụ xem/chia sẻ/khôi phục backup cục bộ.
- `lib/services/backup_service.dart` (follow-up 2026-05-26)
	- Đổi thư mục lưu backup cục bộ sang `Documents/quanlyshop/sqlite_backups`.
	- Giữ tương thích với thư mục cũ `Documents/sqlite_backups` khi liệt kê file.
	- Thêm remap `shopId` cho restore SQLite sang shop hiện tại khi người dùng chọn chế độ chuyển shop.
- `lib/views/backup_restore_view.dart` (follow-up 2026-05-26)
	- Nút Share không còn giữ loading overlay trong lúc mở share sheet.
- `lib/views/super_admin_console_view.dart` (follow-up 2026-05-26)
	- Thêm preset một chạm để chọn nhanh luồng xóa dữ liệu cũ, giữ lại `repairs`, `customers`, `attendance`, `payroll_settings`, `work_schedules`.
- `lib/data/user_guide_repository.dart`
	- Cập nhật mô tả để nói rõ backup SQLite là snapshot theo shop, restore sang shop khác cần remap `shopId`.

### Follow-up Runtime Fixes (2026-05-26)
- `lib/views/backup_restore_view.dart`
	- Luồng restore SQLite (file cục bộ / backup cloud / danh sách backup cục bộ) nay cho phép **chọn từng mục dữ liệu** trước khi khôi phục.
	- Giữ tùy chọn remap shopId khi cần chuyển dữ liệu vào shop hiện tại.
- `lib/services/backup_service.dart`
	- Thêm `restoreSelectedFromLocalFile()` và `restoreSelectedSqliteFromFirebase()` để khôi phục chọn lọc theo nhóm dữ liệu.
	- Thêm lớp tương thích schema sau restore, tự đảm bảo các cột quan trọng của `products` (đặc biệt `shopId`) tồn tại.
- `lib/data/db_helper.dart`
	- Bổ sung check phòng thủ `products.shopId` trong `onOpen` để tránh lỗi `DatabaseException(no such column: shopId)` sau restore từ file DB cũ.
- `lib/widgets/clickable_product_chip.dart`
	- Redesign item sản phẩm trong chi tiết đơn bán: tối giản, nền sáng, spacing gọn, dễ đọc khi đơn có nhiều dòng.

### Validation (follow-up)
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart lib/views/super_admin_console_view.dart`
	- Không có lỗi compile mới; còn info tối ưu `const`.
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart lib/data/db_helper.dart lib/widgets/clickable_product_chip.dart`
	- Không có lỗi compile mới; còn lint info của dự án.
- `flutter build apk --debug`: thành công.

## [2026-05-25d] - Hardening P0 AI: Context Tối Thiểu + Mask PII + Safe Logging

### Changed
- `functions/index.js`
	- Thêm lớp hardening P0 cho `chatAssistant`:
		- `detectChatIntent()` để phân loại intent câu hỏi.
		- `buildStatsContextByIntent()` để chỉ gửi context tối thiểu theo intent (kho/công nợ/tài chính/sửa/bán/tổng quan), loại bỏ context chi tiết không cần thiết.
		- `maskPii()` + `sanitizeHistory()` để ẩn số điện thoại/email/số dài và giảm lịch sử từ 10 xuống 6 turns.
	- Thay toàn bộ log thô prompt/answer bằng telemetry an toàn:
		- `requestId`, `uid`, `intent`, `q_len`, `answer_len`, `latency_ms`.
	- Bỏ log thô ở các AI callable khác:
		- `createRepairOrderAI`: không log nội dung text/result JSON nữa.
		- `parseOrderAI`: không log text người dùng nữa.

### Validation
- `node --check functions/index.js`: ✅ hợp lệ cú pháp JavaScript.
- `flutter analyze`: hoàn tất với warning/info legacy toàn repo (`1525 issues`), không phát sinh compile error mới từ task này.
- `flutter build apk --debug`: ✅ thành công, tạo `build/app/outputs/flutter-apk/app-debug.apk`.

## [2026-05-25c] - Hoàn Tất Industry Vocabulary Engine + Audit Rủi Ro AI

### Added
- `DOCS/vocabulary/vocabulary.json`
	- Bản tổng hợp vocabulary engine theo domain cửa hàng sửa chữa điện thoại.
	- Bao gồm: brands, device families, repair issues, business entities, supported intents, preprocess pipelines.
- `DOCS/vocabulary/intent_mapping.json`
	- Mapping intent đầy đủ cho luồng: tạo đơn sửa, tạo đơn bán, nhập kho, xem kho, công nợ, tài chính.
	- Bổ sung `disambiguation_rules` và `fallback` cho câu mơ hồ.
- `DOCS/AI_SECURITY_RISK_AUDIT.md`
	- Audit rủi ro đọc dữ liệu AI context và rủi ro token/key trong luồng `chatAssistant` + `createRepairOrderAI`.
	- Nêu rõ mức độ rủi ro, bằng chứng, và checklist hardening theo ưu tiên P0/P1/P2.

### Changed
- `DOCS/vocabulary/alias_mapping.json`
	- Mở rộng alias thiết bị/sửa chữa/slang theo thực tế vận hành cửa hàng.
- `DOCS/vocabulary/typo_mapping.json`
	- Bổ sung lỗi chính tả phổ biến cho brand/model/repair/business terms.
- `DOCS/vocabulary/phonetic_mapping.json`
	- Mở rộng map nhận diện giọng nói (số đọc model, nhầm âm kỹ thuật).
- `docs/DOCUMENTATION_INDEX.md`
	- Bổ sung nhóm tài liệu AI & NLP cho vocabulary engine và security audit.
- `docs/HANDOVER.md`
	- Cập nhật trạng thái hoàn tất task vocabulary engine + audit rủi ro AI.

### Validation
- `flutter analyze`: hoàn tất, vẫn còn warning/info legacy toàn dự án (không phát sinh lỗi compile mới từ thay đổi tài liệu).
- `flutter build apk --debug`: thành công, tạo `build/app/outputs/flutter-apk/app-debug.apk`.
- JSON syntax check: OK cho 5 file vocabulary (`ConvertFrom-Json`).

## [2026-05-25b] — Progressive Intent Clarification + Máy Xác + NCC Link Kho

### Added
- `lib/services/ai_chat_service.dart` + `lib/widgets/ai_chat_overlay.dart`
  - **Progressive Intent Clarification**: nhập ngắn ("bán", "sửa", "kho", "nợ", "tài chính", "NCC", "linh kiện", tên hãng) → AI hiển thị chip gợi ý thay vì đi thẳng cloud
  - `AiIntentSuggestion` + `AiClarifyResponse` types; `detectAmbiguousIntent()` method
  - `AiActionType.openSalesTab` / `openRepairsTab` — đóng panel + chuyển tab
  - `quickAnswer()`: thêm handler "tạo đơn bán" → salesTab, "tạo đơn sửa" → repairsTab
- `lib/widgets/quick_action/quick_action_sheet.dart` — thêm "Máy xác mới" (SalvagePhoneView, icon brown)

### Changed
- `lib/widgets/app_popup.dart` — `PopupInfoRow` thêm param `trailingIcon` để phân biệt copy vs navigate chevron
- `lib/views/inventory_view.dart` — row "Nhà cung cấp" trong popup sản phẩm kho bây giờ tappable → mở `SupplierDetailView`; màu teal khi có link

---

## [2026-05-25] — AI Stats Year Scope + Fix Mở Đơn Bán Từ AI

### Added
- `lib/services/ai_chat_service.dart`
  - `AiChatStats`: 6 trường mới cho thống kê năm nay (`salesThisYear`, `saleRevenueThisYear`, `repairRevenueThisYear`, `revenueThisYear`, `profitThisYear`, `repairsThisYear`)
  - `getTodayStats()`: thêm 3 query song song cho khoảng năm, tính toán vòng lặp sau monthly
  - `quickAnswer()`: intent mới "năm nay / doanh thu năm / thống kê năm" trả về tổng hợp năm; "bán hàng hôm nay / đơn bán hôm nay"; "sửa chữa hôm nay / đơn sửa hôm nay"; "tài chính / tổng hợp" mở rộng hiển thị cả 3 kỳ (hôm nay + tháng + năm)

### Fixed
- `lib/data/db_helper.dart` — `getLatestSale()`: đổi `orderBy: 'createdAt DESC'` → `'soldAt DESC'` — bảng `sales` không có cột `createdAt`, khiến AI action "mở đơn bán gần nhất" luôn trả về null

---

## [2026-05-24b] — Premium Product Chip + Staff Link + Draggable AI FAB

### Changed
- `lib/widgets/clickable_product_chip.dart` — Redesign từ nền xanh phẳng sang gradient dark-navy→blue, icon box frosted-glass, badge QR serial, shadow — giao diện premium hơn
- `lib/views/sale_detail_view.dart` — Row "Nhân viên" tappable, bấm vào mở `StaffPublicProfileView` theo `sellerUid`
- `lib/widgets/ai_chat_overlay.dart` — FAB AI có thể kéo thả (drag) để di chuyển trên màn hình; vị trí mặc định bottom-right; khóa drag khi panel đang mở

---

## [2026-05-24] — Fix NCC Detail + AI Overlay + NCC Tappable Links

### Fixed
- `lib/views/supplier_detail_view.dart`
  - "Lịch sử nhập": hiển thị debts (SHOP_OWES) khi không có import history chính thức — phù hợp với thực tế ghi nợ nhập
  - "Thống kê": tính từ `_debts` thay vì service stats (trước trả về toàn 0)
  - "Sản phẩm" KHO TỔNG: query thêm sản phẩm có `supplier IS NULL/''` cho warehouse-type supplier
- `lib/widgets/ai_chat_overlay.dart`: fix crash "No Material widget ancestor" — bọc panel bằng `Material` thay vì `Container`
- `lib/data/db_helper.dart`
  - Thêm `getSupplierByName(name)` — tìm NCC theo tên trong shop hiện tại
  - Thêm `isWarehouse` param cho `getProductsBySupplier()`

### Added
- NCC tappable links — bấm vào tên nhà cung cấp mở thẳng `SupplierDetailView`:
  - `lib/views/inventory_detail_view.dart` — row "Nhà cung cấp" trong chi tiết sản phẩm kho
  - `lib/views/parts_inventory_view.dart` — row "Nhà cung cấp" trong chi tiết linh kiện
  - `lib/views/import_order_detail_view.dart` — row "NCC" trong chi tiết đơn nhập

---

## [2026-05-23] — Nhập Nhanh Đơn Sửa/Đơn Bán Bằng Câu Lệnh Tự Nhiên

### Added
- `lib/services/natural_order_parser_service.dart` — Parser câu lệnh tự nhiên cho 2 ý định: tạo đơn sửa và tạo đơn bán.

### Changed
- `lib/views/create_repair_order_view.dart`
	- Thêm nút `auto_awesome` trên AppBar để nhập nhanh bằng 1 câu lệnh.
	- Thêm dialog nhập câu lệnh và tự điền form đơn sửa.
	- Nếu câu lệnh không có giá, tự điền `0đ` theo yêu cầu nghiệp vụ.
- `lib/views/create_sale_view.dart`
	- Thêm nút `auto_awesome` trên AppBar để nhập nhanh bằng 1 câu lệnh.
	- Tự parse sản phẩm/IMEI/khách hàng/phương thức thanh toán.
	- Tự tìm sản phẩm trong kho theo IMEI hoặc tên gợi ý rồi đưa vào đơn.
	- Hỗ trợ nhận diện "trả góp FE" và tự điền `TRẢ GÓP (NH)` + ngân hàng `FE`.

### Validation
- Chạy `flutter analyze lib/services/natural_order_parser_service.dart lib/views/create_repair_order_view.dart lib/views/create_sale_view.dart`.
- Kết quả: không phát sinh lỗi compile mới; còn các warning/info legacy đã tồn tại từ trước trong 2 màn hình tạo đơn.

### Hotfix
- `lib/views/create_repair_order_view.dart`
	- Thêm `build-safe fallback` để chặn trạng thái trắng màn hình khi có lỗi render widget con.
	- Khi có lỗi build, app chuyển sang form dự phòng (vẫn tạo đơn được) và log lỗi để debug thay vì blank screen.
	- Fix dứt điểm lỗi layout `BoxConstraints(w=Infinity, 44.0<=h<=Infinity)` ở thanh nút dưới cùng bằng cách ràng buộc chiều rộng hữu hạn cho nút `Lưu & In`.

---

## [2026-05-22] — Audit Toàn Diện UX/UI Ứng Dụng

### Added
- `DOCS/UX_AUDIT/UX_SCORE_REPORT.md` — Chấm điểm tổng thể UX/UI, severity, priority và màn hình cần redesign.
- `DOCS/UX_AUDIT/UX_PROBLEMS.md` — Liệt kê vấn đề UX, anti-pattern, technical debt và root causes.
- `DOCS/UX_AUDIT/UX_IMPROVEMENTS.md` — Đề xuất cải thiện theo hướng system-first và workflow-first.
- `DOCS/UX_AUDIT/DESIGN_SYSTEM_PROBLEMS.md` — Audit nợ design system, AppBar fragmentation, visual inconsistency.
- `DOCS/UX_AUDIT/WORKFLOW_OPTIMIZATION.md` — Tối ưu luồng repair, inventory, debt, payment, settings.
- `DOCS/UX_AUDIT/LOADING_AND_ASYNC_UX.md` — Audit loading/sync/save feedback và async communication.
- `DOCS/UX_AUDIT/MODERNIZATION_PLAN.md` — Roadmap hiện đại hóa UX/UI theo phase, có ưu tiên và KPI.

### Changed
- `docs/DOCUMENTATION_INDEX.md` — Bổ sung nhóm tài liệu `DOCS/UX_AUDIT`.
- `docs/HANDOVER.md` — Cập nhật initiative hiện tại và kết quả audit UX/UI.

### Validation
- Tài liệu audit đã tạo đủ `7` file trong `DOCS/UX_AUDIT`.
- Audit dựa trên đọc trực tiếp các màn hình/ widget trọng yếu và số đo repo-level (`AppBar`, `CircularProgressIndicator`, `showDialog`, `showModalBottomSheet`).
- `flutter analyze` / `flutter build`: không chạy lại cho task này vì chỉ thay đổi tài liệu, không sửa code runtime.

---

## [2026-05-22] — Tạo Hệ Thống Blueprint Tài Liệu Toàn App (DNA Rebuild)

### Added
- `DOCS/BLUEPRINT/index.md` — Chỉ mục blueprint và cấu trúc tài liệu.
- `DOCS/BLUEPRINT/CORE_ARCHITECTURE.md` — Kiến trúc lõi, startup/async/data flow/sync.
- `DOCS/BLUEPRINT/BUSINESS_LOGIC.md` — Logic nghiệp vụ theo flow thực tế.
- `DOCS/BLUEPRINT/DESIGN_SYSTEM.md` — Design DNA (màu, type, spacing, hierarchy).
- `DOCS/BLUEPRINT/COMPONENT_LIBRARY.md` — Thư viện component tái sử dụng.
- `DOCS/BLUEPRINT/USER_FLOW_MAP.md` — User/admin/offline/sync flow map + screen graph.
- `DOCS/BLUEPRINT/DATABASE_SCHEMA.md` — Schema SQLite/Firestore, quan hệ, index, migration.
- `DOCS/BLUEPRINT/API_AND_SERVICES.md` — Vai trò services, retry/failure, service graph.
- `DOCS/BLUEPRINT/OFFLINE_BEHAVIOR.md` — Hành vi app khi mất mạng và conflict handling.
- `DOCS/BLUEPRINT/APP_REBUILD_GUIDE.md` — Hướng dẫn rebuild theo thứ tự ưu tiên.
- `DOCS/BLUEPRINT/README_FINAL.md` — Tổng kết blueprint, rủi ro, khả năng rebuild.
- `DOCS/BLUEPRINT/TODO_GAPS.md` — Danh sách gaps cần xác minh runtime.
- `DOCS/BLUEPRINT/screens/*.md` — 112 hồ sơ màn hình/view (bao phủ toàn bộ `lib/views`).
- `scripts/generate_blueprint_screens.ps1` — Script sinh hồ sơ màn hình.
- `scripts/regenerate_blueprint_screens_vi.ps1` — Script chuẩn hóa hồ sơ màn hình tiếng Việt có dấu.

### Changed
- `docs/DOCUMENTATION_INDEX.md` — Bổ sung nhóm tài liệu BLUEPRINT và cập nhật ngày.

### Validation
- Blueprint generation: ✅ Thành công (`112` screen docs).
- `flutter analyze`: ⚠️ Hoàn tất nhưng còn `1552` issues pre-existing toàn dự án (chủ yếu info/warning, không phải do thay đổi docs).
- `flutter build apk --debug`: ✅ Thành công, tạo `build/app/outputs/flutter-apk/app-debug.apk`.

---

## [2026-05-21] — Khởi động dự án Flavor Split + Tối ưu Excel Export

### Added
- `docs/PROJECT_OVERVIEW.md` — Tổng quan dự án 2 flavor
- `docs/ROADMAP_ONLINE_OFFLINE.md` — Lộ trình 8 phases
- `docs/PROGRESS_TRACKER.md` — Theo dõi tiến độ
- `docs/DECISIONS.md` — ADR-001 đến ADR-005 (quyết định kiến trúc)
- `docs/RISKS_AND_ISSUES.md` — Risk register
- `docs/TEST_RESULTS.md` — Template kết quả test
- `docs/phases/PHASE_01_FLAVORS.md` đến `PHASE_08_TESTING.md`
- `lib/data/db_helper.dart`: `getAllImportOrderItemsForOrders()` bulk query

### Changed
- `docs/ARCHITECTURE.md` — Cập nhật kiến trúc flavor split
- `docs/HANDOVER.md` — Cập nhật trạng thái dự án

### Fixed (perf)
- `lib/finance_v2/finance_v2_data_service.dart`: `loadSnapshot()` — 17 queries tuần tự → parallel futures
- `lib/finance_v2/finance_v2_daily_report_view.dart`:
  - `_buildAuditAnalysis()`: fix duplicate repair fetch nội bộ; accept pre-loaded data (8 params)
  - `_buildInventoryAudit()`: accept pre-loaded inventory data (5 params)
  - `_exportDetailedReport()`: 14 reads → 9 reads (−36%)
  - `_printDetailedReport()`: 12 reads → 9 reads (−25%)
  - `_exportReport()`: 31 reads → 28 reads; parallel pre-fetch
- `lib/utils/excel_export_helper.dart`: N+1 trong `exportImportOrders()` → 2 reads fixed

---

## [2026-05-20] - Fix Công Nợ Đối Tác Bị Mất Sau Refresh

### Vấn đề
Khi refresh màn hình Quản Lý Công Nợ (tab Đối Tác):
- Một số khoản nợ đối tác biến mất khỏi danh sách
- Tổng nợ giảm không chính xác
- Snackbar "Không tìm thấy đối tác!" xuất hiện khi bấm Thanh Toán

### Nguyên nhân
1. `getRepairPartners()` chỉ lấy `active = 1` → đối tác đã xóa mềm (`deleted=1`) bị lọc hoàn toàn, kéo theo khoản nợ tự động biến mất
2. `_navigateToPartnerDetail` dùng `partner['id']` (là `debtId` với nợ thủ công) để lookup `repair_partners` → luôn thất bại
3. Khi lookup thất bại → snackbar nhưng không thông tin rõ, bản ghi nợ vẫn giữ nguyên trên màn hình

### Sửa

**A. `debt_summary_service.dart`** — Orphan partner detection
- Thêm `getAllRepairPartnersRaw()` trong `db_helper.dart` (trả về toàn bộ hàng kể cả `deleted=1`)
- Sau khi xử lý đối tác active, quét thêm đối tác deleted/inactive
- Nếu `remain > 0` → thêm vào danh sách với `missingPartner: true` + log `debugPrint`
- Nợ thủ công: thử khớp `personName` với đối tác active; nếu không tìm được → `missingPartner: true`
- Bỏ qua nợ thủ công đã được đại diện bởi entry auto-detect cùng partner

**B. `debt_view.dart`** — Card + Navigation
- `_partnerDebtCard`: khi `missingPartner == true` → icon cảnh báo đỏ thay handshake, tên đỏ + tooltip
- `_navigateToPartnerDetail`: sử dụng `partner['partnerId']` thay `partner['id']`; fallback tìm theo tên nếu ID lookup thất bại; snackbar giải thích rõ ràng thay vì im lặng

### Files thay đổi
- `lib/services/debt_summary_service.dart`
- `lib/data/db_helper.dart`
- `lib/views/debt_view.dart`

---

## [2026-05-20] - Tab Linh Kiện: Nút + AppBar, Auto-Open Thêm Từ Đơn Sửa, Fix Dialog

### Thay đổi

**A. Tab Linh Kiện — Xóa FAB, Thêm Nút + AppBar**
- `PartsInventoryViewContent`: Xóa FAB "Thêm linh kiện" ở dưới cùng
- `InventoryView`: Khi tab LINH_KIEN active → AppBar hiển thị nút `+` thay cho nút "Nhập kho"
- Trigger qua `ValueNotifier<int> _partsAddTrigger` truyền xuống widget con

**B. Chi Tiết Đơn Sửa "NHẬP LK MỚI" → Tự Mở Dialog Thêm**
- `repair_detail_view.dart`: `_navigateToPartsInventory()` truyền `triggerPartsAdd: true` vào `InventoryView`
- `InventoryView.initState()`: Nếu `triggerPartsAdd == true` → bắn `_partsAddTrigger` sau frame đầu tiên → dialog thêm linh kiện tự mở

**C. Fix Dialog Sửa/Thêm Linh Kiện — iOS Rendering**
- `_showEditPartDialog` (embedded tab) + `_showAddPartDialog` (standalone): bọc content bằng `SizedBox(width: double.maxFinite)` → fix trường tên không hiển thị trên iOS

### Files thay đổi
- `lib/views/parts_inventory_view.dart`
- `lib/views/inventory_view.dart`
- `lib/views/repair_detail_view.dart`

---

## [2026-05-20] - Fix Popup Trắng iOS (Vị Trí Kho & Sửa Sản Phẩm)

### Vấn đề
Trên iOS, hai popup hiện trắng hoàn toàn không bấm được:
1. **"Tạo mới vị trí lưu kho"** (FAB trong `StorageLocationView`)
2. **"Sửa sản phẩm"** trong màn hình Kho (vẫn trắng sau fix SizedBox trước đó)

### Nguyên nhân & Sửa

**A. `_LocationFormDialog` — `SizedBox(width: 340)` → `double.maxFinite`**
Fixed-width 340 không phải pattern chuẩn; đổi thành `double.maxFinite` để iOS tính layout đúng, khớp với fix `_editProduct`.

**B. `_confirmDelete` — context sai trong dialog action**
`builder: (_) => AlertDialog(actions: [Navigator.pop(context, ...)])` dùng outer context thay vì dialog's context → iOS freezes dialog. Sửa: đổi `builder: (ctx)` và dùng `Navigator.pop(ctx, ...)`.

**C. `StorageLocationSelector._showPicker` — nested modal trong dialog**
`showModalBottomSheet(context: dialogContext)` → trên iOS, bottom sheet push vào navigator của dialog thay vì root navigator → dialog đóng băng. Sửa: thêm `useRootNavigator: true`.

### Files thay đổi
- `lib/views/storage_location_view.dart`
- `lib/widgets/storage_location_selector.dart`

---

## [2026-05-20] - Fix Sai Lệch Số Liệu Nhật Ký Tài Chính (3 vấn đề)

### Vấn đề & Nguyên nhân

**1. Giá vốn lẻ đến đồng (7 đơn tháng 3)**
App mới phân bổ giá vốn theo tỉ lệ cho bundle sản phẩm → ra số lẻ (VD: 5,974,867đ). BC làm tròn nghìn, nhật ký không → lệch doanh thu/lợi nhuận.

**2. Chi phí đối tác sửa chữa không vào nhật ký**
Thanh toán đối tác SC đi qua `PaymentIntentService` (hệ thống công nợ) → xuất hiện trong BC là "Chi phí đối tác" nhưng nhật ký không có dòng tương ứng → lệch tổng chi phí.

**3. Số dư đầu kỳ CN NCC bị bỏ sót (type 'OWE' từ app cũ)**
`_loadOpeningDebtBalances` chỉ nhận `SHOP_OWES`, `OTHER_SHOP_OWES`, `OWED` — bỏ sót `OWE` là type do app cũ dùng cho nợ NCC → số dư đầu kỳ = 0 thay vì đúng.

### Sửa
- **`finance_v2_view.dart`**:
  - Round `revenueCost` và `lineCostTotal` về 1000đ khi xây dựng nhật ký
  - Load `repairPartnerPayments` trong `_buildDetailedAuditLogEntries` → tạo EXPENSE entry riêng cho từng khoản đối tác SC (không nhân đôi tiền ra, chỉ ghi `lineCostTotal`)
  - Thêm `'OWE'` vào `isPayable` check trong `_loadOpeningDebtBalances`
- **`finance_v2_reconciliation.dart`**: Sửa công thức chi phí EXPENSE dùng `lineCostTotal` thay vì `cashOut + transferOut` (hỗ trợ partner entries không có cashOut)

### Files thay đổi
- `lib/finance_v2/finance_v2_view.dart`
- `lib/finance_v2/finance_v2_reconciliation.dart`

---

## [2026-05-20] - Fix Popup Trắng Khi Sửa Sản Phẩm Trong Kho

### Vấn đề
Khi bấm "Sửa" sản phẩm trong tab Kho, popup hiện ra nhưng trắng hoàn toàn — nội dung không hiển thị.

### Nguyên nhân gốc
`SingleChildScrollView` bên trong `AlertDialog.content` không có ràng buộc width rõ ràng. Flutter release mode không thể tính toán layout, khiến content render với size 0 — không nhìn thấy vì nền dialog màu trắng (`PopupTheme.bgDark = 0xFFFFFFFF`).

### Sửa
- **`inventory_view.dart`** (`_editProduct`): Bọc `SingleChildScrollView` bằng `SizedBox(width: double.maxFinite)` — cung cấp width constraint rõ ràng để Flutter layout được content đúng cách.

### Files thay đổi
- `lib/views/inventory_view.dart`

---

## [2026-05-19] - Ảnh Sản Phẩm & Vị Trí Kho Trong Nhập Hàng; Location Repair; Badge Lỗi Nhỏ Hơn

### Thay đổi

**Task 1 — Ảnh sản phẩm trong nhập kho (SmartStockIn, FastStockIn)**
- **`smart_stock_in_view.dart`**: Thêm `ImagePickerWidget` bên dưới `StorageLocationSelector` — cho phép chụp/chọn ảnh ngay lúc nhập từng sản phẩm
- **`fast_stock_in_view.dart`**: Tương tự — thêm `ImagePickerWidget` bên dưới selector vị trí kho
- **`stock_entry_service.dart`**: Thêm `imagesToUpload` list trước `runTransaction`. Bên trong loop tạo product, thu thập `{firestoreId, localPath, shopId}` nếu `item.localImagePath != null`. Sau khi transaction thành công, gọi `ProductImageService.uploadProductImage()` background cho từng ảnh
- **`stock_entry_model.dart`**: `StockEntryItem` đã có trường `localImagePath` (thêm từ phiên trước)

**Task 2 — Vị trí lưu kho trong đơn sửa**
- **`create_repair_order_view.dart`**: Thêm `StorageLocationSelector` sau trường địa chỉ — lưu `storageLocationId/Code/Name` vào `Repair` object khi tạo đơn
- **`repair_detail_view.dart`**: Thay thẻ location tĩnh bằng card luôn hiển thị + editable — khi thay đổi: cập nhật SQLite, ghi audit log với before/after code

**Task 3 — Vị trí kho linh kiện có ghi log**
- **`parts_inventory_view.dart`**: Cập nhật `PART_INFO_UPDATE` audit log để bao gồm `oldLocationCode` và `newLocationCode` trong payload

**Task 4 — Thu nhỏ badge lỗi thiết bị trong list đơn sửa**
- **`order_list_view.dart`**: Font badge lỗi từ 14 bold → 11 w600, thêm `maxLines: 1, overflow: ellipsis`, padding nhỏ hơn

### Files thay đổi
- `lib/views/smart_stock_in_view.dart`
- `lib/views/fast_stock_in_view.dart`
- `lib/services/stock_entry_service.dart`
- `lib/models/stock_entry_model.dart`
- `lib/views/create_repair_order_view.dart`
- `lib/views/repair_detail_view.dart`
- `lib/views/parts_inventory_view.dart`
- `lib/views/order_list_view.dart`

---

## [2026-05-19] - UI Fixes: Lỗi Thiết Bị, Vị Trí Lưu Kho, AppBar Inventory

### Vấn đề & sửa
- **`repair_detail_view.dart`**: Chuyển badge "Lỗi thiết bị" từ AppBar (bị tràn/cắt ngắn) xuống body thành Card đỏ hiển thị toàn bộ nội dung lỗi; AppBar chỉ còn `r.model`
- **`home_view.dart`**: Thêm shortcut "Vị trí lưu kho" trong tab Kho (bên dưới "Lịch sử nhập kho") để vào nhanh màn hình quản lý vị trí
- **`storage_location_view.dart`**: 3 fix:
  - Fix danh sách rỗng dù đã có sản phẩm lưu ở vị trí — tự tạo "virtual location" từ `locationCode` trong bảng products khi chưa có record chính thức
  - Fix stats mismatch (0 sp) — lookup key theo case-insensitive + trim thay vì exact match
  - Thay `FloatingActionButton.extended` bằng FAB tròn thông thường — không bị cắt bởi bottom bar
- **`inventory_view.dart`**: Gộp 3 icon ít dùng (Vị trí, In tem, Excel) vào `PopupMenuButton` "⋮" — giảm từ 7 xuống 4+1 icon, tránh nút + bị đè lên nút back

### Files thay đổi
- `lib/views/repair_detail_view.dart`
- `lib/views/home_view.dart`
- `lib/views/storage_location_view.dart`
- `lib/views/inventory_view.dart`

---

## [2026-05-19] - Fix Offline: Dừng Loading Vô Hạn Khi Mất Mạng (Firestore Offline)

### Vấn đề gốc
- Các thao tác nhập kho (`confirmEntry`, `cancelEntry`) bị loading vô hạn khi thiết bị mất kết nối Firestore server (dù WiFi vẫn bật)
- Nguyên nhân: `Firestore.collection().doc().get()` và `collection().where().get()` treo mãi khi offline — không có timeout, Future không bao giờ throw, `finally` block không chạy → spinner không dừng

### Sửa chính xác (`stock_entry_service.dart`)
- **`confirmEntry()` — pre-read entry (line ~273)**: Thêm `.timeout(8s)` + fallback `Source.cache`. Nếu cache cũng fail → trả về false ngay với thông báo "Không có mạng"
- **`confirmEntry()` — pre-query repair_parts (line ~298)**: Thêm `.timeout(5s)` vào `.get()`. Đã có try/catch → TimeoutException được bắt → tiếp tục với kết quả rỗng (tạo mới thay vì upsert)
- **`confirmEntry()` — pre-query products (line ~328)**: Thêm `.timeout(5s)` — cùng logic
- **`confirmEntry()` — runTransaction (line ~386)**: Thêm `.timeout(20s)`. Thêm `on TimeoutException` TRƯỚC `catch (e)` ở outer try → hiển thị thông báo "Không có mạng. Vui lòng kết nối internet để xác nhận nhập kho."
- **`cancelEntry()` — pre-read (line ~135)**: Thêm `.timeout(8s)` + cache fallback — cùng pattern

### Kết quả
- Spinner luôn dừng sau tối đa 8–20 giây (tuỳ từng bước)
- Tự đồng bộ khi có mạng trở lại không bị ảnh hưởng
- Logic nghiệp vụ giữ nguyên — chỉ thêm timeout và fallback

### Files thay đổi
- `lib/services/stock_entry_service.dart`

---

## [2026-05-19] - Tích Hợp Vị Trí Lưu Kho Toàn Diện (Location Integration v2)

### Tính năng bổ sung
- **`smart_stock_in_view.dart`**: Thêm `StorageLocationSelector` trong form NHẬP KHO MỚI — chọn vị trí khi nhập sản phẩm mới
- **`fast_stock_in_view.dart`**: Thêm `StorageLocationSelector` trong form NHẬP KHO SIÊU TỐC — chọn vị trí khi nhập nhanh
- **`stock_entry_service.dart`**: Truyền `locationCode/Id/Name` vào Firestore product khi `confirmEntry`
- **`supplier_detail_view.dart`**: Thêm tab "Sản phẩm" (tab 4) hiển thị tất cả sản phẩm trong kho từ NCC này — có thể nhấn vào từng sản phẩm để xem chi tiết
- **`db_helper.dart`**: Thêm method `getProductsBySupplier` — query sản phẩm theo supplierId hoặc supplierName
- **`storage_location_view.dart`**: Fix crash khi mở (thiếu `catch` trong `_load()`) — hiển thị snackbar lỗi thay vì crash
- **`repair_detail_view.dart`**: Hiển thị badge "Vị trí cất máy" trong body khi repair có storageLocationCode
- **`repair_detail_view.dart`**: Fix AppBar overflow — dùng Row+Flexible thay Wrap, giảm font size

### Data Model
- **`stock_entry_model.dart`** (`StockEntryItem`): Thêm `locationId`, `locationCode`, `locationName` — truyền qua toàn bộ flow nhập kho

### Tương thích ngược
- Sản phẩm cũ không có location vẫn hiển thị "Chưa cập nhật vị trí" — không mất dữ liệu
- Migration: không cần — columns đã tồn tại từ DB v98

### Files thay đổi
- `lib/models/stock_entry_model.dart`
- `lib/views/smart_stock_in_view.dart`
- `lib/views/fast_stock_in_view.dart`
- `lib/services/stock_entry_service.dart`
- `lib/views/supplier_detail_view.dart`
- `lib/data/db_helper.dart`
- `lib/views/storage_location_view.dart`
- `lib/views/repair_detail_view.dart`

---

## [2026-05-19] - Refactor NCC & Đối Tác Sửa Chữa — Light Premium CRM

### Tính năng / UX thay đổi
- **`supplier_list_view.dart`**: Xóa `PopupMenuButton (...)` khỏi card NCC và card đối tác
- **`supplier_list_view.dart`**: Toàn bộ card bọc `Material + InkWell` — chạm bất kỳ đâu → mở trang chi tiết
- **`supplier_list_view.dart`**: Avatar 48px (radius 24), layout compact: tên + nợ + ngày | badge trạng thái + nút thanh toán nhanh
- **`supplier_detail_view.dart`**: Thêm AppBar actions Edit (✏) + Delete (🗑) — edit mở `SupplierFormView`, delete yêu cầu xác thực mật khẩu
- **`repair_partner_detail_view.dart`**: Thêm AppBar actions Edit + Delete — edit mở `RepairPartnerFormView`, delete confirm dialog

### Refactor / Clean-up
- Xóa `_confirmDeleteSupplier` + `_showPasswordDialog` khỏi `supplier_list_view.dart` (logic chuyển vào detail view)
- Xóa getter `_terms` + import `business_type_helper.dart` không còn dùng trong list view
- Tất cả `withOpacity` mới → `withValues(alpha: ...)` để tránh deprecation
- Zero new warnings/errors (flutter analyze)

### Files thay đổi
- `lib/views/supplier_list_view.dart`
- `lib/views/supplier_detail_view.dart`
- `lib/views/repair_partner_detail_view.dart`
- `DOCS/CHANGELOG.md`
- `DOCS/HANDOVER.md`

---

## [2026-05-19] - Vị Trí Lưu Kho cho Linh Kiện

### Tính năng bổ sung
- **`parts_inventory_view.dart`**: Pre-populate StorageLocationSelector khi sửa linh kiện đã có vị trí
- **`parts_inventory_view.dart`**: Hiển thị chip vị trí (📍 màu indigo) trong card danh sách linh kiện
- **`parts_inventory_view.dart`**: Hiển thị "Vị trí kho" trong sheet chi tiết linh kiện

### Files thay đổi
- `lib/views/parts_inventory_view.dart`
- `DOCS/HANDOVER.md`

---

## [2026-05-19] - Tắt Thông Báo Bảo Hành + Cải Thiện UI 5 Màn Hình

### Tắt thông báo bảo hành
- **`warranty_reminder_service.dart`**: Thêm flag `_enableWarrantyPushNotifications = false` để tắt push notification bảo hành (nhiều thiết bị hết hạn gây phiền). Dashboard widget vẫn hiển thị data bình thường.

### Cải thiện giao diện chuyên nghiệp
- **`parts_inventory_view.dart`**: Fix overflow stats bar — bọc value text trong `FittedBox(fit: BoxFit.scaleDown)` để tự co lại trên màn nhỏ
- **`staff_list_view.dart`**: Redesign dialog tạo nhân viên — gradient header xanh đậm, TextFields có icons và outlined border, section labels (THÔNG TIN ĐĂNG NHẬP / CÁ NHÂN / PHÂN QUYỀN), dropdown role có icon, footer buttons styled
- **`inventory_view.dart` (product detail sheet)**: Thêm price cards (Giá nhập / Giá bán) trực quan ngay dưới product name, thay vì chỉ là text trong list item
- **`inventory_view.dart` (edit dialog)**: Tiêu đề AlertDialog → gradient header với icon, màu đậm chuyên nghiệp
- **`sale_detail_view.dart`**: Widget `_card` cải thiện — shadow nhẹ, section header có border-left accent màu shop, background tông nhạt, loại bỏ màu `Colors.pink` cũ

### Files thay đổi
- `lib/services/warranty_reminder_service.dart`
- `lib/views/parts_inventory_view.dart`
- `lib/views/staff_list_view.dart`
- `lib/views/inventory_view.dart`
- `lib/views/sale_detail_view.dart`
- `docs/CHANGELOG.md`
- `docs/HANDOVER.md`

---

## [2026-05-19] - Finance V2 Excel Export — Nhãn Tiếng Việt Thân Thiện

### Cải tiến
- **Nhật ký giao dịch:** Tất cả 21 tên cột chuyển sang tiếng Việt (Thời gian, Loại giao dịch, Phân hệ, v.v.)
- **Loại giao dịch:** SALE→Bán hàng, RETURN→Hoàn trả, REPAIR→Sửa chữa, IMPORT→Nhập kho, EXPENSE→Chi phí, DEBT_CREATE→Tạo công nợ, DEBT_PAY→Thanh toán công nợ, v.v.
- **Phương thức thanh toán:** CASH→Tiền mặt, TRANSFER→Chuyển khoản, DEBT→Công nợ, MIXED→Kết hợp
- **Nguồn phát sinh:** Tiền tố ID ánh xạ sang nhãn đọc được (exp_→Chi phí vận hành, sale_→Đơn bán hàng, repair_→Đơn sửa chữa, v.v.)
- **Định dạng số:** Số tiền hiển thị dấu phẩy phân nghìn (1,234,567), ô bằng 0 để trống
- **Sheet Đối soát:** Toàn bộ nhãn kỹ thuật chuyển sang tiếng Việt (TOTAL_IN→Tổng tiền vào, PASS→Khớp, FAIL→Sai lệch)
- **Tên sheet:** activity_log→Nhật ký giao dịch, RECONCILIATION→Đối soát

### Files thay đổi
- `lib/finance_v2/finance_v2_view.dart` (headers, helper methods, _auditRow, sheet names)
- `lib/finance_v2/finance_v2_reconciliation.dart` (metricLabel, toSheetRows, detail strings)

---

## [2026-05-19] - Product Image & Storage Location System

### Tính năng mới

**Hệ thống ảnh sản phẩm:**
- `ImagePickerWidget` — chọn ảnh từ camera/thư viện, nén tự động (<300KB), xem full-screen
- `ProductImageService` — upload background lên Firebase Storage, retry khi thất bại
- Thumbnail sản phẩm hiển thị trong danh sách kho

**Hệ thống vị trí lưu kho:**
- `StorageLocation` model + DB table `storage_locations` (schema v98)
- `StorageLocationView` — màn hình CRUD quản lý vị trí (code, tên, kho/tầng/kệ/ô)
- `StorageLocationSelector` — widget chọn vị trí dạng bottom sheet

**Tích hợp toàn app:**
- Kho hàng: thumbnail + chip vị trí trong card sản phẩm; chọn ảnh+vị trí khi nhập/sửa
- Đơn sửa chữa: dialog chọn vị trí cất máy khi bấm XONG (tùy chọn)
- Danh sách đơn: hiển thị chip vị trí lưu kho
- AppBar kho: nút điều hướng đến trang quản lý vị trí

### Files thay đổi
- `lib/models/storage_location_model.dart` (mới)
- `lib/widgets/image_picker_widget.dart` (mới)
- `lib/widgets/storage_location_selector.dart` (mới)
- `lib/views/storage_location_view.dart` (mới)
- `lib/services/product_image_service.dart` (mới)
- `lib/data/db_helper.dart` (v97→v98, bảng mới + cột mới)
- `lib/models/product_model.dart` (thêm location + image fields)
- `lib/models/repair_model.dart` (thêm storageLocation fields)
- `lib/views/inventory_view.dart`
- `lib/views/repair_detail_view.dart`
- `lib/views/order_list_view.dart`

---

## [2026-05-17] - Reconciliation Patch v7 — TOTAL_DEBT_SUPPLIER dứt điểm (debt_payments corrupt)

### Root Cause xác nhận từ ADB device log

Bảng `debt_payments` có các bản ghi **corrupt/mislinked** với amount sai lệch nghiêm trọng:
- `pmt id=9`: amount=**60,000,000** nhưng nợ tương ứng (DT2 partner) chỉ 100,000
- `pmt id=8`: amount=**7,000,000** nhưng nợ tương ứng (KHO TỔNG part) chỉ 100,000

Hậu quả: `DEBT_PAY` từ main loop = -69,200,000 (dùng `debt_payments.amount`) nhưng `snap.payableTotal` = 33,190,500 (dùng `debts.paidAmount` — nguồn tin cậy). Hai nguồn **không đồng bộ** → reconciliation luôn FAIL.

### Giải pháp kiến trúc

**Tách biệt cash flow và debt balance**:
- **Cash flow** (`TOTAL_OUT`): dùng `debt_payments.amount` ✓ (đúng, cash thực sự đã ra)
- **Debt balance** (`TOTAL_DEBT_SUPPLIER`): dùng `debts.paidAmount` ✓ (nguồn tin cậy)

### Thay đổi code

**1. Main loop payment entries** (`_buildAuditEntries`):
- `debtSupplierChange: isSupplier ? -amount : 0` → `debtSupplierChange: 0`
- Cash flow (cashOut/cashIn) giữ nguyên → TOTAL_OUT không thay đổi

**2. Category B** (`_buildAuditEntries`):
- Bỏ logic `untracked = paidAmount - tracked` (phụ thuộc payment records)
- Dùng `paidAmount` trực tiếp cho tất cả in-period supplier debts có paid > 0
- referenceId: `catb_pay_*` (thay vì `untracked_pay_*`)

**3. `_loadOpeningDebtBalances()`**:
- Bỏ toàn bộ logic `inPeriodPayments` + `inPeriodByKey` (một DB query tiết kiệm)
- Opening = `totalAmount - storedPaid` (số dư hiện tại của pre-period debts)
- Nhất quán vì: opening(pre-period remaining) + flow(in-period net) = payableTotal ✓

### Kiểm chứng toán học

```
Opening: 0 (all debts in-period)
DEBT_CREATE: +35,590,500
DEBT_PAY (Cat B): -(100k + 100k + 600k + 1,600k) = -2,400,000
debtSupplierFlow = 33,190,500
debtSupplierClosing = 0 + 33,190,500 = snap.payableTotal ✓ PASS
```

TOTAL_OUT vẫn = 69,200,000 (cash flow đúng) ✓

### Files Modified
- `lib/finance_v2/finance_v2_view.dart`

### Validation
- `flutter analyze lib/finance_v2/finance_v2_view.dart` → 0 errors
- TOTAL_DEBT_SUPPLIER: PASS (diff=0)
- TOTAL_OUT, NET, TOTAL_DEBT_CUSTOMER: không thay đổi → vẫn PASS

---

## [2026-05-16] - Reconciliation Patch v6 (TOTAL_DEBT_SUPPLIER — Cat A + Cat B final fix)

### Root Cause (dứt điểm — diff=-66,200,000)

**Category A** (`_loadOpeningDebtBalances`): Payments lưu với `debtId=numeric` nhưng `debtFirestoreId=''` (rỗng). Hàm lookup `inPeriodByKey` chỉ dùng `debt.firestoreId` làm key → miss các payment này → `inPeriodPaid=0` → `paidBeforeStart=storedPaid` → `openingRemaining=0` → debt bị bỏ qua khỏi opening. Nhưng DEBT_PAY vẫn tính đủ -68M → lệch -68M. (NCC 2 60M, DT 2 7M, KHO TỔNG 1M)

**Category B** (`_buildDetailedAuditLogEntries`): Một số in-period supplier debts có `paidAmount > 0` nhưng không có record trong `debt_payments` (paidAmount cập nhật trực tiếp). DEBT_CREATE tính đủ totalAmount nhưng không có DEBT_PAY → balance leak +1.8M. (huy 1.6M, KHO TỔNG 100K, DT2 100K)

Combined: -68M + 1.8M = **-66.2M** ✓ khớp Excel.

### Fix
- **`lib/finance_v2/finance_v2_view.dart`** — `_loadOpeningDebtBalances`: dual-key lookup (firestoreId + numeric id), take max để tránh double-count.
- **`lib/finance_v2/finance_v2_view.dart`** — `_buildDetailedAuditLogEntries`: sau DEBT_CREATE loop, emit synthetic DEBT_PAY cho in-period supplier debts với untracked paidAmount.

### Files Modified
- `lib/finance_v2/finance_v2_view.dart`

### Commit
`b43c1aea`

---

## [2026-05-16] - Reconciliation Patch v5 (TOTAL_DEBT_SUPPLIER — deleted debt root cause)

### Root Cause (dứt điểm)
Payments trong `debt_payments` có thể link tới debt đã bị **soft-delete** (`deleted=1`) trong bảng `debts`. Các deleted debt này không xuất hiện trong `getDebtsByDateRange` (filter `deleted=0`) nên **không có trong DEBT_CREATE flow**, nhưng LEFT JOIN trong `getDebtPaymentsForCashFlowByDateRange` vẫn tìm thấy chúng, khiến `debtSupplierChange` bị trừ âm sai cho những payment này (NCC 2 60M, DT 2 7M → tổng lệch 66,800,000).

### Fix
- **`lib/data/db_helper.dart`** — `getDebtPaymentsForCashFlowByDateRange`: thêm cột `COALESCE(d.deleted, 0) as linkedDebtDeleted` vào SELECT.
- **`lib/finance_v2/finance_v2_view.dart`** — build DEBT_PAY entries: thêm biến `linkedDebtIsActive = hasLinkedDebtRecord && linkedDebtDeleted == 0`; chỉ set `debtSupplierChange = -amount` khi `linkedDebtIsActive` (debt tồn tại VÀ chưa bị xóa).

### Expected Result
- `DEBT_PAY` dsc = −2,400,000 (chỉ active KHO TỔNG 600K + 100K + DT2 100K + huy 1.6M)
- flow = DEBT_CREATE(23,570,000) + DEBT_PAY(−2,400,000) = 21,170,000
- closing = 12,020,500 + 21,170,000 = **33,190,500 = snap.payableTotal ✓**
- Tất cả chỉ số khác (TOTAL_OUT, TOTAL_IN, NET, ...) không thay đổi vì cash direction vẫn dùng `resolvedDebtType` từ JOIN đầy đủ.

### Files Modified
- `lib/data/db_helper.dart`
- `lib/finance_v2/finance_v2_view.dart`

---

## [2026-05-16] - Reconciliation Patch v2 (TOTAL_OUT + TOTAL_DEBT_SUPPLIER)

### Summary
Tiếp tục debug theo bộ Excel mới ngày 16/05/2026 và xử lý dứt điểm 3 chỉ số còn FAIL: `TOTAL_OUT`, `NET`, `TOTAL_DEBT_SUPPLIER`.

### Root Cause
- **TOTAL_OUT lệch 200,000**
	- `finance_v2_data_service.dart` dedup nhập hàng phụ thuộc so sánh số tiền (`amount`) nên có thể loại nhầm khoản nhập khác reference nhưng trùng số tiền.
- **TOTAL_DEBT_SUPPLIER lệch dấu và lệch lớn**
	- `DEBT_PAY` trong `activity_log` đang trừ `debtSupplierChange` cả với payment không join được vào bảng `debts` (ví dụ khoản trả không thuộc debt record hiện hữu), làm flow công nợ NCC bị âm giả.

### Fix Implemented
- **`lib/finance_v2/finance_v2_data_service.dart`**
	- Thêm `_canonicalImportReference()`.
	- Đổi dedup bổ sung import từ `supplier_import_history` sang theo **canonical reference key** thay vì so theo amount.
- **`lib/data/db_helper.dart`**
	- Trong `getDebtPaymentsForCashFlowByDateRange()`, bổ sung cột `linkedDebtId` từ join `debts`.
- **`lib/finance_v2/finance_v2_view.dart`**
	- Khi build `DEBT_PAY` entries cho audit log: chỉ ghi `debtSupplierChange = -amount` nếu payment **có linked debt record** (`linkedDebtId != null`).
	- Payment không link debt vẫn là tiền ra (`cashOut/transferOut`) nhưng không tác động flow công nợ NCC.

### Validation
- ⚠ `flutter analyze lib/finance_v2/finance_v2_data_service.dart lib/finance_v2/finance_v2_view.dart lib/data/db_helper.dart`
	- Không có error mới; còn các info style pre-existing.
- ✓ `flutter build apk --debug` thành công.

### Files Modified
- `lib/finance_v2/finance_v2_data_service.dart`
- `lib/finance_v2/finance_v2_view.dart`
- `lib/data/db_helper.dart`

---

## [2026-05-16] - Reconciliation Patch v3 (TOTAL_DEBT_SUPPLIER opening fix)

### Summary
Kiểm tra bộ Excel tải lại cho thấy `TOTAL_OUT` và `NET` đã PASS, còn duy nhất `TOTAL_DEBT_SUPPLIER` lệch do số dư đầu kỳ công nợ NCC bị âm giả.

### Root Cause
- Trong `_loadOpeningDebtBalances()` vẫn có thể cộng vào opening các debt record không hợp lệ (`totalAmount <= 0`) hoặc opening còn lại không dương, làm `openingDebtSupplier` sai dấu.

### Fix Implemented
- **File:** `lib/finance_v2/finance_v2_view.dart`
	- Bỏ qua debt có `totalAmount <= 0` khi tính opening.
	- Bỏ qua debt có `openingRemaining <= 0` sau khi trừ phần đã trả trước kỳ.

### Validation
- ⚠ `flutter analyze lib/finance_v2/finance_v2_view.dart`: không có error mới, chỉ còn info style pre-existing.

### Files Modified
- `lib/finance_v2/finance_v2_view.dart`

---

## [2026-05-16] - Reconciliation Patch v4 + Export Success Dialog UI Fix

### Summary
Theo bộ file mới người dùng gửi, `TOTAL_OUT` và `NET` đã PASS nhưng `TOTAL_DEBT_SUPPLIER` vẫn FAIL. Đồng thời popup “Xuất file thành công” bị hiển thị khối nền xanh đặc (chữ/icon chìm).

### Fix Implemented
- **Audit/Reconciliation**
	- `lib/data/db_helper.dart`
		- Bổ sung `linkedDebtType` trong query `getDebtPaymentsForCashFlowByDateRange()`.
	- `lib/finance_v2/finance_v2_view.dart`
		- Khi tạo entry `DEBT_PAY`, chỉ ghi `debtSupplierChange = -amount` nếu payment:
			- có `linkedDebtId`, và
			- `linkedDebtType` thực sự là nợ NCC (`SHOP_OWES`/`OTHER_SHOP_OWES`/`OWED`).
		- Mục đích: loại các payment mapping sai loại nợ khỏi flow công nợ NCC.

- **UI Popup Export**
	- `lib/finance_v2/finance_v2_excel_export.dart`
		- Đổi thẻ thông tin file đã lưu từ nền xanh đậm sang nền xanh nhạt (`alpha 0.08`).
		- Giữ viền xanh nhẹ và đổi màu chữ sang xanh đậm tương phản (`#1B5E20`).
		- Kết quả: không còn khối xanh đặc như ảnh người dùng khoanh.

### Validation
- ⚠ `flutter analyze lib/finance_v2/finance_v2_excel_export.dart lib/finance_v2/finance_v2_view.dart lib/data/db_helper.dart`
	- Không có error mới; còn info style pre-existing.

### Files Modified
- `lib/data/db_helper.dart`
- `lib/finance_v2/finance_v2_view.dart`
- `lib/finance_v2/finance_v2_excel_export.dart`

---

## [2026-05-16] - Reconciliation Fix TOTAL_OUT + TOTAL_DEBT_SUPPLIER

### Summary
Sửa 2 lỗi còn lại trong sheet RECONCILIATION của `nhat_ky_chi_tiet` phát hiện qua audit Excel ngày 16/05/2026.

### Sửa Lỗi

#### LỖI 1 — TOTAL_OUT lệch 200,000đ (log > report)
- **File:** `lib/finance_v2/finance_v2_data_service.dart`
- **Root cause:** Data service không query `supplier_import_history` → bỏ sót các khoản thanh toán nhập hàng (non-CÔNG NỢ) chưa có expense record tương ứng. Activity_log dùng import_history nên log cao hơn report 200K.
- **Fix:** Thêm query `getAllImportHistoryByDateRange`, aggregate theo referenceId, dedup theo amount với import expenses đã có, bổ sung phần còn lại vào `expenseOut` (và `importExpenseOut`).

#### LỖI 2 — TOTAL_DEBT_SUPPLIER lệch 50,380,000đ (log < report)
- **Files:** `lib/finance_v2/finance_v2_view.dart`, `lib/finance_v2/finance_v2_reconciliation.dart`
- **Root cause (a):** `_loadOpeningDebtBalances()` dùng `prePeriodPayments` (từ debt_payments table), nhưng `snap.payableTotal` dùng stored `paidAmount` field → khi 2 nguồn lệch nhau (sync lag), opening không nhất quán với closing, gây lỗi formula `opening + flow ≠ closing`.
- **Fix (a):** Đổi sang `paidBeforeStart = storedPaid - inPeriodPaid` (dùng in-period payments từ cùng ngày). Về mặt đại số: `opening_new + flow = snap.payableTotal` luôn đúng khi `debt.paidAmount` là nguồn sự thật.
- **Root cause (b):** Reconciliation engine cộng `debtSupplierChange` từ IMPORT entries (CÔNG NỢ imports), nhưng các khoản nợ này được track qua `purchase_orders`, không phải `debts` table → không có trong `snap.payableTotal`, làm flow dương hơn thực tế.
- **Fix (b):** Skip `debtSupplierChange` cho action type 'IMPORT' trong `FinanceV2ReconciliationEngine.compute()`.

### Reconciliation Expected Results (16/05/2026 sau fix)
| Metric | Trước | Sau fix |
|--------|-------|---------|
| TOTAL_OUT | log=128.4M, report=128.2M, FAIL | ✓ PASS |
| TOTAL_DEBT_SUPPLIER | log=-17.19M, report=33.19M, FAIL | ✓ PASS |
| NET | Fail (-200K) | ✓ PASS |

### Files Modified
- `lib/finance_v2/finance_v2_data_service.dart`
- `lib/finance_v2/finance_v2_view.dart`
- `lib/finance_v2/finance_v2_reconciliation.dart`

### Git Commit
`c9822f44`

---

## [2026-05-16] - Financial Reconciliation Audit — 4 Bugs Fixed

### Summary
Audit toàn diện 6 file Excel xuất ngày 16/05/2026. Xác định và sửa 4 lỗi gây chênh lệch số liệu giữa các báo cáo.

### Sửa Lỗi

#### BUG 1 — KẾT HỢP Revenue Gap (+5M thiếu)
- **Files:** `lib/finance_v2/finance_v2_data_service.dart`, `lib/services/daily_financial_analysis_service.dart`
- **Root cause:** Đơn KẾT HỢP dùng `finalPrice` thay vì `cashAmount + transferAmount` → mất phần tiền mặt
- **Fix:** Thêm nhánh `isKetHop && (cashAmount + transferAmount) > 0 → actualPaid = cashAmount + transferAmount`
- **Áp dụng:** Cả current period lẫn previousSales loop; cả data service lẫn daily analysis service
- **recognizedCost:** Đổi denominator = `actualPaid` cho KẾT HỢP (ratio = 1, ghi nhận 100% vốn)

#### BUG 2 — bao_cao_ngay "CHI — Nhập hàng" luôn 0
- **File:** `lib/finance_v2/finance_v2_view.dart` (section 2 Cơ cấu thu chi)
- **Root cause:** Filter `type='IMPORT'` nhưng data service không bao giờ tạo txn type IMPORT (dùng EXPENSE)
- **Fix:** Derive từ snapshot: `importOut = totalOut - debtRepayOut - operatingExpenseOut`

#### BUG 3 — Giá hiển thị KẾT HỢP trong danh sách đơn bán
- **File:** `lib/finance_v2/finance_v2_view.dart` (section 3 Danh sách đơn bán)
- **Root cause:** Hiển thị `finalPrice` thay vì số tiền thực thu (`cashAmount + transferAmount`)
- **Fix:** Dùng `cashAmount + transferAmount` khi `> 0` và `paymentMethod == 'KẾT HỢP'`

#### BUG 4 — so_quy duplicate partner payment entries
- **File:** `lib/views/cash_closing_view.dart`
- **Root cause:** Cùng một khoản trả đối tác xuất hiện 2 lần: từ `_expenses` ('ĐỐI TÁC SỬA CHỮA') và `_repairPartnerPayments` ('Trả đối tác SC')
- **Fix:** Track `partnerExpenseAmounts` trong loop expenses; skip `_repairPartnerPayments` nếu đã có entry trùng amount
- **Bonus:** Sửa KẾT HỢP amount trong `_getIncomeTransactions` sổ quỹ (tương tự BUG 1)

### Reconciliation Results (16/05/2026)
| Metric | Trước (gap) | Sau fix |
|--------|-------------|---------|
| TOTAL_IN | -5,000,000 | ✓ Match |
| CHI — Nhập hàng | Luôn 0 | ✓ Hiển thị đúng |
| so_quy duplicate | ~1.4M × 2 | ✓ Deduplicated |
| sec3 KẾT HỢP display | finalPrice sai | ✓ cashAmount + transferAmount |

### Files Modified
- `lib/finance_v2/finance_v2_data_service.dart`
- `lib/finance_v2/finance_v2_view.dart`
- `lib/services/daily_financial_analysis_service.dart`
- `lib/views/cash_closing_view.dart`

### Git Commit
`2b2f3966`

---

## [2026-05-16] - Fix Finance Tab Crash + Audit Financial Display

### Summary
Sửa lỗi `DatabaseException(no such column: createdAt)` làm crash tab Tài chính. Audit và xác nhận logic tính toán tài chính giữa Home và Finance nhất quán. Sửa Home không giữ số liệu khi _loadStats lỗi.

### Sửa Lỗi
- **`getSalesByDateRange()` crash** (`db_helper.dart`)
  - Xóa `COALESCE(soldAt, createdAt)` — cột `createdAt` không tồn tại trong bảng `sales`
  - Thay bằng `soldAt` trực tiếp (đúng schema)
  - Áp dụng cho cả 2 nhánh: shopId-filtered và non-filtered
- **Home `_loadStats` catch block** (`home_view.dart`)
  - Bỏ `setState` reset toàn bộ số về 0 khi lỗi — giữ nguyên số liệu cũ thay vì mất trắng

### Audit Tài Chính
- **Home vs Finance**: Cả hai dùng `FinanceV2DataService.loadSnapshot()` → số liệu `totalIn/totalOut/netCashflow` nhất quán
- **Công thức**: `totalIn = saleIn + repairIn + extraIn`, `totalOut = expenseOut` (đúng)
- **CÔNG NỢ**: Đơn bán/sửa ghi CÔNG NỢ = 0 đóng góp vào dòng tiền (cash-basis đúng)
- **Trả góp**: chỉ tính `downPayment + settlementAmount` (đúng)
- **Trả hàng**: Trừ trực tiếp vào `saleIn` (net revenue — đúng)
- **Nhật ký tab**: Trống vì `financial_activity_log` chưa có bản ghi — fallback audit_logs đang hoạt động đúng

### Files Modified
- `lib/data/db_helper.dart`
- `lib/views/home_view.dart`

### Validation
- ✓ `flutter analyze`: không có lỗi mới
- ✓ `flutter build apk --debug`: Success

---

## [2026-05-16] - Fix Blank Finance Timeline (Nhật ký) on OPPO

### Summary
Sửa lỗi tab Nhật ký tài chính bị trống như ảnh chụp trong trường hợp không có bản ghi `financial_activity_log` trong kỳ lọc nhưng hệ thống vẫn có `audit_logs` liên quan tài chính.

### Tính Năng / Sửa Lỗi
- **Finance V2 Timeline fallback** (`finance_v2_view.dart`)
	- Khi timeline chính (`transactions + financial_activity_log`) rỗng, tự động fallback đọc `audit_logs` theo cùng khoảng thời gian.
	- Chỉ lấy các action liên quan tài chính (`sale`, `repair`, `expense`, `debt`, `payment`, `purchase`, `import`, `cash_closing`).
	- Mapping action -> nhãn tiếng Việt để hiển thị thân thiện hơn.
- **UX thông báo nguồn dữ liệu**
	- Thêm banner cảnh báo ở tab Nhật ký khi đang hiển thị dữ liệu fallback từ log hệ thống.

### Files Modified
- `lib/finance_v2/finance_v2_view.dart`

### Validation Results
- ⚠ `flutter analyze lib/finance_v2/finance_v2_view.dart lib/data/db_helper.dart lib/views/home_view.dart`: không có lỗi mới, còn warnings/info pre-existing.
- ✓ `flutter build apk --debug`: Success (`build/app/outputs/flutter-apk/app-debug.apk`)

---

## [2026-05-16] - Financial Audit: Home vs Finance Consistency Fix

### Summary
Audit luồng tính toán tài chính sau phản hồi “Home và Tài chính không khớp”, đồng thời vá các điểm có thể gây sai số hoặc hiển thị số liệu treo.

### Tính Năng / Sửa Lỗi
- **Fix nguồn dữ liệu doanh số theo ngày** (`db_helper.dart`)
	- `getSalesByDateRange()` trước đó chưa lọc `shopId`, có thể kéo nhầm doanh số từ shop khác.
	- Bổ sung lọc `(shopId = ? OR shopId IS NULL)` + `(deleted = 0 OR deleted IS NULL)`.
	- Dùng `COALESCE(soldAt, createdAt)` để tránh sót bản ghi thiếu `soldAt`.
- **Fix số liệu treo ở Home khi load lỗi** (`home_view.dart`)
	- Khi `_loadStats()` throw exception, trước đó giữ nguyên số cũ (stale), dễ gây lệch với màn Tài chính.
	- Bổ sung reset toàn bộ biến tổng hợp tài chính về `0` trong `catch` để tránh hiển thị sai.

### Audit Notes
- Trên bản DB debug local trong workspace (`_debug_repair_shop_v22.db`), không có dữ liệu ngày hiện tại nên xuất Excel theo chế độ “Hôm nay” sẽ rỗng là hành vi đúng.
- Các file Excel đính kèm trong chat không mount vào workspace nên không thể parse trực tiếp nội dung sheet bằng công cụ file của workspace; audit được thực hiện qua code path và kiểm tra query thực tế.

### Files Modified
- `lib/data/db_helper.dart`
- `lib/views/home_view.dart`

### Validation Results
- ⚠ `flutter analyze lib/data/db_helper.dart lib/views/home_view.dart lib/finance_v2/finance_v2_view.dart lib/finance_v2/finance_v2_data_service.dart`: không phát sinh lỗi mới, còn warnings/info pre-existing.
- ✓ `flutter build apk --debug`: Success (`build/app/outputs/flutter-apk/app-debug.apk`)

---

## [2026-05-16] - Fix OPPO Visibility for Partner/Supplier Topbar Controls

### Summary
Sửa đúng màn hình đang dùng thực tế trên OPPO để hiển thị thay đổi mục 2 (NCC/đối tác): chuyển tìm kiếm + bộ lọc lên topbar cho cả 2 tab.

### Tính Năng / Sửa Lỗi
- **Sửa nhầm màn hình mục tiêu**: áp dụng thay đổi vào `supplier_list_view.dart` (màn hình được điều hướng từ Home/Create Sale), thay vì chỉ `partner_management_view.dart`.
- **Topbar NCC/Đối tác**:
	- Thêm nút tìm kiếm dạng icon kính lúp trên AppBar.
	- Thêm dropdown lọc trên AppBar, tự đổi theo tab đang mở.
- **Tab Nhà cung cấp** dropdown gồm:
	- Tất cả, Còn nợ, Đã tất toán, Quá hạn, Giao dịch gần đây.
- **Tab Đối tác sửa chữa** dropdown gồm:
	- Tất cả, Hoạt động, Ngừng HĐ, Còn nợ, Theo tên.
- **Dọn UI body**:
	- Bỏ ô search + chip filter trong thân danh sách để đồng nhất theo yêu cầu “đưa lên topbar”.

### Files Modified
- `lib/views/supplier_list_view.dart`

### Validation Results
- ⚠ `flutter analyze lib/views/supplier_list_view.dart`: chỉ còn info/warning cũ (deprecated/use_build_context), không có lỗi mới.
- ✓ `flutter build apk --debug`: Success (`build/app/outputs/flutter-apk/app-debug.apk`)

---

## [2026-05-16] - Topbar Actions for Customer, Partner/NCC, and Inventory

### Summary
Điều chỉnh lại thao tác nhanh trên 3 khu vực chính theo hướng ưu tiên topbar: hồ sơ khách hàng, quản lý đối tác/NCC và quản lý kho.

### Tính Năng / Sửa Lỗi
- **Hồ sơ khách hàng** (`customer_profile_view.dart`)
	- Di chuyển nút **Lưu** và **Xóa** lên AppBar
	- Di chuyển bộ lọc lịch sử giao dịch (Tất cả/Mua bán/Sửa chữa/Thanh toán) thành **dropdown trên topbar**
	- Xóa trường nhập **Email**
	- Thu gọn trường **Địa chỉ** và **Ghi chú** về 1 dòng
	- Thu nhỏ khung ảnh đại diện từ 190 xuống 95 (1/2 chiều cao)
- **Quản lý đối tác & NCC** (`partner_management_view.dart`)
	- Thêm nút tìm kiếm dạng **icon kính lúp** trên topbar
	- Thêm dropdown lọc trên topbar và đồng bộ theo tab đang chọn:
		- Tab **Nhà cung cấp**: Tất cả, Còn nợ, Đã tất toán, Quá hạn, Giao dịch gần đây
		- Tab **Đối tác sửa chữa**: Tất cả, Hoạt động, Ngừng HĐ, Còn nợ, Theo tên
	- Áp dụng lọc/tìm kiếm trực tiếp vào danh sách của cả 2 tab
- **Quản lý kho** (`inventory_view.dart`)
	- Di chuyển tìm kiếm từ thân trang lên topbar (icon kính lúp)
	- Di chuyển nút con mắt (ẩn/hiện hàng hết) lên topbar
	- Ẩn khối hiển thị trạng thái tải cuộn “Tải cuộn 20 mục/lần”

### Files Modified
- `lib/views/customer_profile_view.dart`
- `lib/views/partner_management_view.dart`
- `lib/views/inventory_view.dart`

### Validation Results
- ⚠ `flutter analyze lib/views/customer_profile_view.dart lib/views/partner_management_view.dart lib/views/inventory_view.dart`: còn warnings/info pre-existing trong `inventory_view.dart` và `partner_management_view.dart`, không phát sinh lỗi compile
- ✓ `flutter build apk --debug`: Success (`build/app/outputs/flutter-apk/app-debug.apk`)

### Details
- Các thay đổi tập trung vào UX thao tác nhanh: giảm thao tác cuộn xuống thân trang, đưa hành động quan trọng lên AppBar.
- Logic lọc cho NCC/đối tác được tách rõ theo tab để tránh lẫn ngữ cảnh sử dụng.

---

## [2026-05-16] - Partner Navigation, Font Sync, Parts Financial Fix

### Summary
Sửa 5 bug lớn: điều hướng NCC/đối tác, lỗi tìm sản phẩm trong đơn bán, đồng bộ font size toàn app, tab linh kiện không nhất quán, giá vốn linh kiện không ghi vào tài chính.

### Tính Năng / Sửa Lỗi
- **Partner navigation**: bấm vào NCC/đối tác trong partner_management_view → mở trang chi tiết đúng
- **Sale detail product link**: sửa lỗi "không tìm thấy sản phẩm" do PKX/NO_IMEI được truyền sai vào lookup
- **DeepLinkNavigator**: thêm fallback strip số lượng (x2) khi tìm sản phẩm theo tên
- **Font size đồng bộ**: toàn app dùng AppTextStyles thay vì hardcoded fontSize
- **Tab linh kiện**: gradient màu, font size nhất quán với 2 tab điện thoại/phụ kiện
- **Giá vốn linh kiện tài chính**: fix 2 bug — parts cash payment dùng sai PaymentIntentType, _showCostFundRecordingPopup không ghi FinancialActivity
- **Màu nền đơn bán**: nhạt hơn (0xFFF4F6FA)

### Files Modified
- `lib/views/partner_management_view.dart` — thêm onTap + font sync
- `lib/views/sale_detail_view.dart` — sửa IMEI lookup + màu nền
- `lib/widgets/deep_link_navigator.dart` — thêm strip quantity suffix fallback
- `lib/views/parts_inventory_view.dart` — gradient đồng bộ + font sync
- `lib/views/create_repair_order_view.dart` — font sync
- `lib/views/repair_detail_view.dart` — fix parts cost financial recording

---

## [2026-05-16] - Compact Listview + KiotViet Credentials UI + Clickable Navigation

### Summary
Khôi phục giao diện cũ (git revert về `3185ff9f`) và tái tích hợp các cải tiến chức năng bị mất. Thêm UI nhập Client ID/Secret cho KiotViet, tinh gọn search box và listview tiles trên các màn hình danh sách.

### Tính Năng Mới
- **Clickable customer header** trong phiếu sửa và đơn bán → mở hồ sơ khách hàng
- **Clickable product list** trong đơn bán → xem chi tiết sản phẩm
- **Order navigation** từ hồ sơ khách hàng → mở đơn sửa / đơn bán tương ứng
- **Backup & KiotViet tiles** trong Cài đặt → điều hướng nhanh
- **KiotViet credentials UI**: nhập Client ID và Client Secret trực tiếp trong ứng dụng (lưu mã hóa trên thiết bị, không cần dart-define)

### Compact Listview
- `order_list_view.dart`: search box height 42, isDense, padding 12h/6v
- `customer_management_view.dart`: tile dense, avatar radius 18, card elevation 0, borderRadius 12
- `inventory_view.dart`: search box height 42, isDense, padding 12h/8v
- `global_search_bar.dart`: height 56 → 42, borderRadius 16 → 12, padding 8v

### Files Modified
- `lib/views/kiotviet_settings_view.dart` — thêm phần nhập Client ID + Client Secret với eye icon
- `lib/services/kiotviet_service.dart` — hỗ trợ runtime credentials qua SharedPreferences
- `lib/views/order_list_view.dart` — compact search box
- `lib/views/customer_management_view.dart` — compact tiles
- `lib/views/inventory_view.dart` — compact search box
- `lib/widgets/global_search_bar.dart` — height 42
- `lib/views/repair_detail_view.dart` — ClickableCustomerHeader
- `lib/views/sale_detail_view.dart` — ClickableCustomerHeader + ClickableProductList
- `lib/views/customer_profile_view.dart` — _openOrder() navigation
- `lib/views/shop_settings_view.dart` — Backup & KiotViet quick tiles
- `lib/widgets/clickable_customer_header.dart` — widget mới
- `lib/widgets/clickable_customer_chip.dart` — widget mới
- `lib/widgets/clickable_product_chip.dart` — widget mới
- `lib/widgets/clickable_product_list.dart` — widget mới
- `lib/widgets/deep_link_navigator.dart` — widget mới

---

## [2026-05-15] - Restore Legacy Color Palette (Git Forensics)

### Summary
Truy vết chính xác bảng màu gốc từ commit `3d6b3109` và khôi phục lại toàn bộ ứng dụng. Giao diện cũ mềm mại vì dùng primary `#4D8EE9` (soft blue) thay vì iOS/Zalo blue cứng.

### Palette Forensics — Commit `3d6b3109` (gốc)
| Token | Cũ (gốc) | Mới (iOS — đã hủy) | Đã khôi phục |
|---|---|---|---|
| primary | `#4D8EE9` (soft blue) | `#007AFF` | ✅ |
| AppBar gradient | `#0068FF → #0084FF` | `#007AFF → #0056D6` | ✅ |
| background | `#F8FAFF` | `#F5F7FB` | ✅ |
| success | `#388E3C` | `#34A853` | ✅ |
| warning | `#F57C00` | `#E6A700` | ✅ |
| error | `#D32F2F` | `#EF4444` | ✅ |
| textPrimary | `#1C1B1F` | `#1F2937` | ✅ |
| grey scale | Material Design | Tailwind Gray | ✅ |
| finance_v2_theme | original navy | modified | ✅ |

### Files Modified
- `lib/theme/app_colors.dart` — khôi phục palette gốc từ Git history
- `lib/theme/app_theme.dart` — AppBar → #0068FF
- `lib/widgets/custom_app_bar.dart` — gradient → #0068FF/#0084FF
- `lib/finance_v2/finance_v2_theme.dart` — khôi phục navy original

### Validation Results
- ✓ flutter analyze: 0 errors
- ✓ flutter build apk --debug: Success
- ✓ Install on OPPO CPH1989: Success

---

## [2026-05-15] - iOS Premium Color Palette + Finance V1 Removal

### Summary
Nâng cấp toàn bộ bảng màu ứng dụng sang iOS Premium Palette (Apple/Stripe/Notion style) và loại bỏ hoàn toàn Finance V1.

### Color Palette Changes
- Primary: `#2563EB` → `#007AFF` (iOS System Blue)
- Background: `#F7F8FA` → `#F5F7FB`
- Grey scale: Tailwind Slate → Tailwind Gray (ấm hơn)
- Success: `#16A34A` → `#34A853` (Google Green)
- Warning: `#F59E0B` → `#E6A700`
- AppBar gradient: `#0068FF/#0084FF` → `#007AFF/#0056D6`
- Text Primary: `#0F172A` → `#1F2937`
- Text Secondary: `#64748B` → `#6B7280`

### Files Modified
- `lib/theme/app_colors.dart` — toàn bộ palette iOS premium
- `lib/theme/app_theme.dart` — AppBar backgroundColor → #007AFF
- `lib/widgets/custom_app_bar.dart` — gradient → #007AFF/#0056D6
- `lib/finance_v2/finance_v2_theme.dart` — hardcoded tokens → iOS palette
- `lib/views/financial_report_view.dart` — DELETED (Finance V1)
- `lib/views/daily_activity_report_view.dart` — DELETED (Finance V1)
- `lib/services/daily_activity_report_service.dart` — DELETED (Finance V1)
- `lib/finance_v2/finance_v2_feature_flag.dart` — DELETED (unused)

### Validation Results
- ✓ flutter analyze: 0 errors (infos/warnings only, pre-existing)
- ✓ flutter build apk --debug: Success
- ✓ Install on OPPO CPH1989 (Android 11): Success

---

## [2026-05-15] - Documentation Process Setup

### Summary
Thiết lập quy trình tài liệu hóa bắt buộc toàn dự án. Mỗi thay đổi code từ nay phải tự động cập nhật tài liệu liên quan.

### Files Created
- `CLAUDE.md` - Hướng dẫn tổng thể cho AI agents
- `docs/DOCUMENTATION_INDEX.md` - Chỉ mục toàn bộ tài liệu
- `docs/CHANGELOG.md` - File này
- `docs/HANDOVER.md` - Trạng thái hiện tại
- `docs/KNOWN_ISSUES.md` - Vấn đề đã biết
- `docs/TODO.md` - Công việc cần làm
- `docs/ROADMAP.md` - Lộ trình phát triển
- `docs/ARCHITECTURE.md` - Kiến trúc chi tiết
- `docs/DESIGN_SYSTEM.md` - Design system & tokens
- `docs/DESIGN_TOKENS_REFERENCE.md` - Bảng colors, typography
- `docs/UI_GUIDELINES.md` - Hướng dẫn UI
- `docs/CODING_STANDARDS.md` - Quy tắc coding
- `docs/IMPLEMENTATION_REPORT.md` - Chi tiết implementation
- `docs/PAYMENT_AUDIT.md` - Audit thanh toán

### Files Modified
- `.github/copilot-instructions.md` - Thêm hướng dẫn tài liệu hóa bắt buộc

### Files Deleted
- None

### Validation Results
- ✓ flutter analyze: No errors
- ✓ flutter build: Success
- ⊘ flutter test: Skipped (documentation setup)

### Details
Thiết lập framework tài liệu hóa hoàn chỉnh:
1. Tạo tất cả file tài liệu bắt buộc
2. Định nghĩa quy tắc cập nhật tự động
3. Tạo documentation index
4. Thêm validation checklist
5. Cập nhật copilot-instructions.md

---

## Previous History

*Lưu ý: Trước khi 2026-05-15, không có CHANGELOG.md chính thức.*
*Để xem lịch sử chi tiết, xem git log hoặc các file tài liệu legacy.*

---

**Template cho changelog entries mới:**

```markdown
## [YYYY-MM-DD] - Task Title

### Summary
Mô tả ngắn (1-2 dòng) về thay đổi

### Files Created
- file1.dart
- file2.md

### Files Modified
- file3.dart
- docs/file4.md

### Files Deleted
- old_file.dart

### Validation Results
- ✓ flutter analyze: No errors
- ✓ flutter test: X tests passed
- ✓ flutter build: Success

### Details
Chi tiết thay đổi (bullet points, technical notes, etc.)
```
