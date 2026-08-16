# HANDOVER - HULUCA Shop Manager

Trạng thái hiện tại dự án, tasks đã hoàn thành, tasks pending, known issues, next steps.

---

## ⚡ Trạng thái hiện tại

**Version:** 1.x (develop) → Production live  
**Last Updated:** 2026-08-16  
**Build Status:** ✅ `flutter build apk --debug` OK, đã cài + khởi động trên Oppo CPH2203 (adb logcat không có FATAL exception) — chưa test Samsung A32 (không có máy trong phiên này)  
**Analyze Status:** ✅ 0 compile error (chỉ info/warning có sẵn từ trước)  
**Database Version:** SQLite v104  
**Branch:** master  
**Active Initiative:** Multi-fix session 2026-08-08/10 (audit tool, sync cost, double notification, hẹn giao máy, autocomplete khách hàng, backup đơn sửa kèm ảnh, fix sheet Thêm dịch vụ) + review/fix regression + fix danh sách bán còn nợ sai + fix 42 popup che nút (toàn bộ audit) 2026-08-15/16 + redesign Super Admin Console + broadcast có link + auto store-link theo nền tảng + fix 3 lỗi tab Cửa hàng + fix trùng tài khoản khi đăng ký + công cụ tìm/dọn trùng + deploy index thiếu + fix audit_logs retry vô hạn + fix đơn "Đã giao" hiện sai trạng thái + danh sách không bỏ sót đơn + cảnh báo quá hạn + mở khoá sửa đơn đã giao + xem đơn tương tự + ẩn giá vốn khỏi nhân viên ở "Giá tham khảo"/"Đơn tương tự" + Công cụ điều chỉnh dữ liệu (xóa đơn dư/miễn nợ/sửa kho) + dọn giao diện màn Công nợ + fix đơn sửa từ máy khác không cập nhật kịp thời + fix build iOS lỗi do thiếu file + cho phép bỏ qua yêu cầu SĐT khi giao máy + fix tab "Tất cả" trong Kho trống dữ liệu + fix overflow Firestore Audit Monitor + đổi nhãn menu Thao tác nhanh + gom mối công nợ/trả góp NH rải rác 2026-08-16
**🔴 Đã fix khẩn (2026-08-16p):** build iOS lỗi "No such file or directory" do `other_apps_view.dart` chưa từng được commit dù `home_view.dart` đã tham chiếu — đã commit đủ + push. **User cần tự pull code mới nhất và build lại trên Mac để xác nhận hết lỗi** (máy làm việc là Windows, không tự build iOS được).
**ℹ️ Cảnh báo Apple (không gấp):** email App Store Connect báo `MinimumOSVersion` hiện 14.0, từ mùa xuân 2027 Apple bắt buộc tối thiểu 15.0 mới cho gửi app — bản 3.3.0/541 đã gửi thành công, không phải lỗi. Cần nâng `IPHONEOS_DEPLOYMENT_TARGET` trong `ios/Podfile` + `Runner.xcodeproj` lên 15.0 trước mùa xuân 2027, chưa gấp.
**⚠️ Cần user tự xác nhận (2026-08-16r):** fix tab "Tất cả" trống dữ liệu trong Kho — không tái hiện được lỗi gốc trên dữ liệu test (quá ít sản phẩm), chỉ xác nhận qua code review + test cơ chế hoạt động đúng trên tập dữ liệu nhỏ. **Cần user tự mở app kiểm tra lại trên dữ liệu thật** sau khi cập nhật để chắc chắn 100%.
**✅ Đã fix + test đầy đủ (2026-08-16s):** overflow 6 thẻ ở Firestore Audit Monitor — đã xác nhận hết overflow trên máy thật (logcat sạch, không còn "OVERFLOWED"). Đổi nhãn menu "Thao tác nhanh" (thêm "Tạo" trước mỗi mục) — chỉ đổi chuỗi text, không kiểm tra trực tiếp trên UI được (nút nổi kéo thả, không có nhãn accessibility để tự động dò vị trí qua adb) nhưng an toàn vì chỉ là thay đổi text thuần.
**⚠️ Cần user tự xác nhận (2026-08-16t):** 2 mục mới ở khung "CẦN XỬ LÝ" trang chủ (công nợ quá hạn, đơn trả góp chờ NH tất toán) — đã xác nhận query DB không lỗi qua logcat nhưng KHÔNG tự thấy mục thực sự hiện trên UI (dữ liệu test hiện không có công nợ nào quá 30 ngày/đơn trả góp nào). Nút "Xem đơn gốc" trong lịch sử công nợ ĐÃ test xong trên đơn thật, hoạt động đúng.
**ℹ️ Tài khoản test riêng:** `m@m.com`/shop "M" trên máy Oppo CPH2203 là tài khoản test user chủ động tạo/đăng nhập để mình test thoải mái, tách biệt khỏi dữ liệu HULUCA STORE thật — không phải bất thường, không cần báo lại mỗi lần thấy.
**⚠️ Known issue chưa fix:** crash intermittent trong bottom sheet có TextField qua đường Back hệ thống — xem Known Issues bên dưới (mục "Crash `_dependents.isEmpty`"). Toàn bộ 42 điểm popup che nút từ audit ban đầu (20 HIGH + 22 MEDIUM) đã fix xong, KHÔNG còn mục nào tồn đọng.
**⚠️ Chưa test trực tiếp:** Toàn bộ thay đổi Super Admin Console (redesign + fix tab Cửa hàng + công cụ tìm trùng) chỉ verify qua `flutter analyze` + build + logcat, KHÔNG có tài khoản super admin thật trên máy test để tự vào xem UI/luồng vào-shop/xóa-shop/tìm-trùng — cần user tự mở app xác nhận qua tài khoản `admin@huluca.com` hoặc super admin thật.
**⚠️ Cần user tự làm (Công cụ điều chỉnh dữ liệu):** (1) xóa giúp 1 đơn sửa test vô hại còn sót lại trong danh sách thật: "SAMSUNG TÉTMODEL / TẼTOACC / 0900000000", giá 0đ, không nợ không phụ tùng — tạo ra trong lúc test, không xóa được vì cần mật khẩu chủ shop. (2) Tự thử thực hiện 1 lần thao tác xóa/miễn nợ/sửa kho thật trên tool mới (Cài đặt > Công cụ điều chỉnh dữ liệu) để xác nhận bước SAU KHI nhập mật khẩu chạy đúng — phần này chưa tự test được (không có mật khẩu để adb test tới cùng), chỉ mới xác nhận qua code review + logic mirror đúng luồng đã chạy thật nhiều năm.
**➡️ Việc cần user tự làm:** (1) vào Super Admin Console > Người dùng > bấm nút "Tìm tài khoản trùng email" (icon 📋 cạnh tiêu đề) để xem danh sách trùng thật + tự quyết định xoá dòng nào (bắt buộc nhập PIN cho từng dòng, không có xoá hàng loạt tự động). (2) Firebase Console > App Check > đăng ký app iOS `1:51200928212:ios:04c10eca3b61a3be910e41` (hoặc xác nhận enforcement đang tắt) — lỗi "App not registered" trong log iOS không sửa được bằng code.
**✅ Đã kết luận (không còn treo):** case "đơn hiện sai trạng thái" trên Máy A — kiểm tra trực tiếp Firestore Console xác nhận `status: 1` là dữ liệu THẬT (đơn chưa từng được cập nhật trong app, không phải bug đồng bộ). Đã fix xong phần liên quan thật (đơn CHƯA giao không còn bị `.limit()` cắt bớt khỏi danh sách + thêm cảnh báo quá 7 ngày chưa xử lý) ở `[2026-08-16j]`.
**⚠️ Cân nhắc nhưng chưa sửa:** `removeUserFromShop` (Cloud Function, "Xóa nhân viên khỏi shop") chỉ set `shopId: null` chứ không xoá hẳn document — cân nhắc dọn nhưng có rủi ro regression (có thể chặn mời lại đúng người vào shop sau này) nên tạm giữ nguyên, xem chi tiết ở `[2026-08-16f]`.

### ✅ Vừa hoàn thành (2026-08-16t): feat: gom mối công nợ/trả góp NH đang rải rác
- User: "khi đơn hàng bán công nợ, bán trả góp, hay trả nợ thì nằm rải rác muốn thanh toán phải tìm từng chỗ" — hỏi giải pháp, sau khi mình đề xuất tận dụng khung "CẦN XỬ LÝ" có sẵn (thay vì xây màn hình mới), user đồng ý theo đề xuất
- Khảo sát trước: `debt_view.dart` có sẵn `linkedId` trỏ về đơn gốc nhưng chưa dùng để điều hướng; báo cáo trả góp NH là màn riêng chỉ mở qua 1 shortcut; khung "CẦN XỬ LÝ" trang chủ chưa gồm công nợ/trả góp
- Thêm nút "Xem đơn gốc" trong lịch sử công nợ (`debt_view.dart`) — thử tìm đơn bán trước, không thấy thì tìm đơn sửa, dùng `linkedId` sẵn có
- Thêm 2 mục mới vào "CẦN XỬ LÝ" (`dashboard_cards.dart` + `home_view.dart`): công nợ quá hạn >30 ngày (cùng ngưỡng debt_view.dart đang dùng), đơn trả góp NH chưa tất toán — mỗi mục bấm vào mở đúng màn liên quan
- **Đã test trên đơn thật:** "Xem đơn gốc" mở đúng đơn bán ABC (CÔNG NỢ, ỐP x2), không crash. **2 mục CẦN XỬ LÝ mới chưa tự thấy trên UI** được (dữ liệu test không đủ điều kiện kích hoạt) — chỉ xác nhận query chạy không lỗi
- `flutter analyze` sạch, build + cài Oppo CPH2203
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16t]`

### ✅ Vừa hoàn thành (2026-08-16s): fix(ui): overflow Firestore Audit Monitor + đổi nhãn menu Thao tác nhanh
- User gửi 2 ảnh: (1) 6 thẻ ở Firestore Audit Monitor (dev tool) đều bị "BOTTOM OVERFLOWED BY 11 PIXELS", (2) muốn thêm chữ "Tạo" trước mỗi mục trong menu "Thao tác nhanh" (nút nổi kéo thả) cho dễ đọc
- Overflow do `GridView.count(childAspectRatio: 1.65)` ép ô lưới hơi thấp hơn nội dung thẻ — giảm còn `1.3` để đủ chỗ
- Đổi 6 nhãn trong `quick_action_sheet.dart`: "Sửa mới/Bán mới/Sản phẩm mới/Công nợ mới/Thu chi mới/Máy xác mới" → "Tạo sửa mới/Tạo bán mới/Tạo sản phẩm mới/Tạo công nợ mới/Tạo thu chi mới/Tạo máy xác mới"
- **Đã test overflow trên thiết bị thật:** mở lại Firestore Audit Monitor, xác nhận 6 thẻ hiện đủ nội dung, logcat không còn "OVERFLOWED", không crash. Đổi nhãn menu chỉ xác nhận qua code review (nút nổi không có accessibility label để tự dò vị trí test qua adb) — thay đổi text thuần, rủi ro thấp
- `flutter analyze` sạch, build + cài Oppo CPH2203
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16s]`

### ✅ Vừa hoàn thành (2026-08-16r): fix(inventory): tab "Tất cả" trong Kho hiện trống dù tổng vốn/số lượng vẫn đúng
- User gửi ảnh: tab "Tất cả" trong Quản lý kho hiện "Kho hàng đang trống" dù khối tổng (TỔNG KHO, VỐN TỒN KHO) vẫn hiện số khác 0 — tab "Điện thoại" vẫn hiện đúng 160 sản phẩm bình thường
- Điều tra ra: tab "Tất cả" dùng riêng đường tải phân trang (`getProductsPaged`, tối ưu tốc độ) khác hẳn các tab khác (dùng `getAllProducts` tải toàn bộ + lọc client) — 2 đường không nhất quán trên dữ liệu thật của user. Số 527.367/500.603 trong ảnh KHÔNG phải lỗi — đó là tổng SỐ LƯỢNG tồn kho cộng dồn, không phải số dòng sản phẩm
- Fix: bỏ hẳn nhánh phân trang riêng, mọi tab dùng chung 1 đường tải (`_needsFullData` luôn `true`) — đơn giản hoá, giảm khả năng lệch dữ liệu giữa các tab
- `flutter analyze` sạch, build + cài + test trên tài khoản test: tab "Tất cả" hiện đúng, chuyển qua lại giữa các tab vẫn đúng, không crash. **KHÔNG tái hiện được lỗi gốc** trên dữ liệu test (quá ít sản phẩm) — cần user tự kiểm tra trên dữ liệu thật
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16r]`

### ✅ Vừa hoàn thành (2026-08-16q): feat(repair): cho phép bỏ qua yêu cầu SĐT khi giao máy
- User có đơn cũ chỉ có tên khách, không có SĐT — hỏi có bỏ qua được yêu cầu cập nhật khi giao máy không
- Trước đây dialog "Thiếu thông tin khách hàng" chỉ có Hủy/Cập nhật ngay — không có lối thoát, đơn thiếu SĐT không giao được
- Thêm nút "Bỏ qua, giao máy luôn" — CHỈ hiện khi đã có tên khách nhưng thiếu SĐT (thiếu cả tên vẫn chặn cứng, không xác định được đơn của ai). Áp dụng cả 2 luồng: nhân viên gửi chờ duyệt và quản lý duyệt giao
- **Đã test trên thiết bị thật** (tài khoản test): tạo đơn có tên không SĐT, chuyển tới SỬA XONG, bấm GIAO → dialog mới hiện đúng 3 nút → bấm bỏ qua → vào thẳng màn duyệt → bấm DUYỆT → đơn chuyển đúng "ĐÃ GIAO" thành công, không crash
- `flutter analyze` sạch, build + cài Oppo CPH2203
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16q]`

### ✅ Vừa hoàn thành (2026-08-16p): fix(build): commit file bị thiếu khiến build iOS lỗi
- User gửi ảnh Xcode báo lỗi ngay sau fix trước, nghi do mình gây ra: `Error when reading 'lib/views/other_apps_view.dart': No such file or directory` + `Not a constant expression` ở `home_view.dart:6289`
- Xác minh: KHÔNG liên quan fix sync trước đó (thuần Dart, không đụng iOS/Xcode) — nguyên nhân thật là tính năng "Ứng dụng khác" làm dở từ phiên trước: `home_view.dart` đã bị commit kèm import/entry (do `git add lib/views/home_view.dart` ở 1 commit khác gộp luôn phần này), nhưng `other_apps_view.dart` (file định nghĩa class) thì chưa từng được add — chỉ tồn tại local trên máy Windows, máy Mac pull về thiếu hẳn file
- Commit nốt 4 file còn treo: `other_apps_view.dart` (file thiếu — nguyên nhân chính), `super_admin_console_view.dart` (mục quản lý), `firestore.rules` (đã deploy production từ trước), `pubspec.yaml` (bump version 3.3.0+541)
- `flutter analyze` sạch, build Android debug APK thành công (xác nhận gián tiếp hết lỗi thiếu file, cùng Dart frontend compiler với iOS) — **chưa tự build iOS được** (không có Xcode), cần user tự pull + build lại trên Mac để xác nhận dứt điểm
- **Bài học rút ra:** khi 1 file có nhiều thay đổi dở dang từ nhiều tính năng, cần soát kỹ trước khi `git add` theo tên file, tránh gộp nhầm phần chưa sẵn sàng
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16p]`

### ✅ Vừa hoàn thành (2026-08-16o): fix(sync): đơn sửa từ máy khác không hiện tới khi thoát app vào lại
- User báo sau đợt tối ưu Firestore read cho repair: đơn mới/đổi trạng thái ở máy khác không hiện trên máy mình, phải thoát app vào lại mới thấy — hỏi có phương án tối ưu hơn không
- Điều tra ra: đợt tối ưu trước (`55b4870e`) đổi `repairs` (và ~20 collection khác) từ `snapshots()` realtime sang `get()` polling 1 lần lúc mở app, nhưng không có gì kích hoạt fetch lại sau đó — không polling định kỳ, không refresh khi resume, màn Danh sách đơn sửa cũng không nằm trong các nơi gọi `refreshCloudCollections()` sẵn có
- Fix có chủ đích KHÔNG quay lại `snapshots()` toàn phần (sẽ đội read cost trở lại): thêm `Timer.periodic` 45s CHỈ cho riêng `repairs` (gọi thẳng refresher của 1 collection, không kéo theo ~20 collection khác) + thêm refresh khi app resume từ nền (ảnh hưởng tất cả collection nhưng chỉ 1 lần mỗi lần resume, không lặp)
- Tái dùng `_pollingTimers` — hạ tầng cleanup đã có sẵn từ trước nhưng chưa từng được dùng tới — nên tự dừng đúng khi đổi shop/đăng xuất, không cần thêm code dọn dẹp mới
- **Đã test qua logcat trên thiết bị thật:** xác nhận cả 3 cơ chế fetch chạy đúng lịch (initial lúc mở app, tick định kỳ đúng 45s sau, và resume trigger khi đưa app từ nền lên) không lỗi, không crash. **Chưa mô phỏng được đúng kịch bản 2 máy thật** (chỉ có 1 thiết bị test, không có Admin SDK credentials để giả lập ghi từ "máy khác")
- `flutter analyze` sạch, build + cài + mở màn Danh sách đơn sửa (13 đơn thật) không crash
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16o]`

### ✅ Vừa hoàn thành (2026-08-16n): fix(debt): dọn giao diện màn Công nợ — bớt cấn, chuyên nghiệp hơn
- User gửi 2 ảnh chụp màn "Quản lý công nợ", nhận xét trải nghiệm "cấn cấn không chuyên nghiệp" — mình review đối chiếu code, chỉ ra 4 điểm cụ thể, user đồng ý sửa cả 4
- Tiêu đề AppBar bị cắt chữ ("QUẢN LÝ CÔN...") → rút gọn còn "CÔNG NỢ"
- Mỗi thẻ nợ lặp lại chỉ báo "thu/trả" 3 lần (số thứ tự + icon mũi tên + chữ "Phải thu/Phải trả") → bỏ số thứ tự (không mang ý nghĩa gì) + bỏ chip chữ trùng lặp, chỉ giữ icon + chip cảnh báo khi thật sự cần (quá hạn/đã trả đủ). Áp dụng cho cả thẻ nợ khách/NCC lẫn thẻ nợ đối tác sửa chữa
- Khối "TỔNG NỢ ĐỐI TÁC SỬA CHỮA" bị cắt cụt giữa chừng (nguyên nhân chính gây cảm giác giật) — do code cũ chia màn theo tỷ lệ cố định 3:2 giữa 2 danh sách → gộp thành 1 `ListView` cuộn liền mạch, cao theo đúng nội dung
- Nút "+" đè sát thẻ cuối → thêm padding-bottom 88 cho danh sách để né FAB
- Đi kèm: nút lọc "Đã trả" đổi thành "Hiện đã trả" + thêm icon phễu lọc cho rõ là bộ lọc bấm được
- `flutter analyze` sạch, `flutter gen-l10n` chạy lại, build + cài + test trên thiết bị thật (shop "M", có cả nợ khách + nợ đối tác) — xác nhận đủ 4 điểm sửa đúng, không crash. **Chưa tái hiện đúng 1:1 kịch bản cắt cụt gốc trong ảnh** (tài khoản test hiện tại ít dữ liệu nợ NCC hơn HULUCA STORE) — độ tin cậy dựa trên việc gỡ bỏ hoàn toàn cơ chế gây lỗi (tỷ lệ flex cố định), không phải fix theo dữ liệu cụ thể
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16n]`

### ✅ Vừa hoàn thành (2026-08-16m): feat(admin): Công cụ điều chỉnh dữ liệu (xóa đơn dư/miễn nợ/sửa kho)
- User giao toàn quyền thiết kế: "đơn sửa đơn bán và 1 số dữ liệu khác bạn làm theo ý bạn làm công cụ điều chỉnh dữ liệu" — bối cảnh shop có nhiều đơn test/nhập nhầm muốn dọn mà không làm sai lệch báo cáo tài chính
- Khảo sát kỹ trước khi làm (2 agent + tự verify): xóa đơn sửa hiện tại để mồ côi công nợ/payment; xóa đơn bán (`_deleteSale`) đã làm tốt — dùng làm logic tham chiếu; `softDeleteDebt` có sẵn nhưng chưa từng dùng, `reason` bị bỏ qua; chưa có khái niệm điều chỉnh tồn kho
- Xây HOÀN TOÀN MỚI, KHÔNG sửa `order_list_view.dart`/`sale_detail_view.dart` để tránh hồi quy lên luồng xóa đang chạy thật — mọi thao tác xóa đều chọn rõ "kèm hoàn tài chính" hay "chỉ xóa, giữ sổ sách", bắt buộc xác nhận lại mật khẩu
- File mới: `data_reconciliation_service.dart` (logic), `data_reconciliation_view.dart` (UI 4 tab: Đơn sửa | Đơn bán | Công nợ | Kho & SP). Sửa nhỏ: `softDeleteDebt` lưu đúng `reason`, thêm nhãn `REPAIR_VOID`/`SALE_VOID`, thêm mục Settings gated `hasFullAccess`
- **Đã test trên thiết bị thật, dữ liệu shop thật** (chủ shop huy@huluca.com): cả 4 tab tải đúng, không crash; chọn/bỏ chọn đúng; dialog Sửa số lượng/Miễn nợ đúng dữ liệu + validation đúng; tạo 1 đơn test giả hoàn toàn → chọn → tóm tắt đúng → màn xác nhận mật khẩu hiện đúng (xác nhận cơ chế bảo vệ hoạt động)
- **CHƯA test được:** bước SAU KHI nhập mật khẩu (không có mật khẩu thật để adb test tới cùng, không tự đoán mật khẩu) — logic thực thi chỉ xác nhận qua code review (mirror đúng luồng đã chạy thật). Còn sót 1 đơn test vô hại "SAMSUNG TÉTMODEL" cần user tự xóa
- `flutter analyze` sạch (0 lỗi), build + cài Oppo CPH2203 không FATAL exception
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16m]`

### ✅ Vừa hoàn thành (2026-08-16l): fix(repair): ẩn giá vốn/lợi nhuận khỏi nhân viên trong "Giá tham khảo" + "Đơn sửa tương tự"
- User hỏi "giá vốn trong lịch sử sửa giá có ẩn với nhân viên chưa" khi đang ở giữa 1 việc khác (thiết kế Công cụ điều chỉnh dữ liệu) — user chọn hoàn tất thiết kế trước, sửa giá vốn sau
- Kiểm tra phát hiện 2 chỗ MỚI thêm ở `[2026-08-16k]` (thẻ "GIÁ THAM KHẢO" lúc tạo đơn mới + trang `SimilarRepairHistoryView`) hiện Vốn/Lợi nhuận không kiểm tra quyền — rò rỉ giá vốn cho nhân viên
- `similar_repair_history_view.dart` thêm `showCost` (mặc định `false`, an toàn theo hướng đóng); `create_repair_order_view.dart` gate theo `_canViewCostPrice`; `repair_detail_view.dart` gate theo `canShowCost` (biến quyền có sẵn) khi mở trang tương tự
- **Đã test trực tiếp trên thiết bị thật bằng tài khoản nhân viên** (không có quyền xem giá vốn): thẻ "GIÁ THAM KHẢO" chỉ hiện "Thu khách", trang "9 đơn tương tự" chỉ hiện giá thu trên từng thẻ, không còn Vốn/Lãi/Lỗ. Không FATAL exception
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16l]`

### ✅ Vừa hoàn thành (2026-08-16k): feat(repair): cho sửa giá/thông tin đơn đã giao + xem chi tiết "đơn tương tự"
- User yêu cầu: (1) đơn "Đã giao" vẫn sửa được giá vốn/giá thu/thông tin chung (trước đây khoá hoàn toàn), (2) dòng "Lịch sử tương tự" (Bảng giá thông minh) bấm vào phải xem được từng đơn cụ thể trong lịch sử đó, ở cả màn Tạo đơn mới và Chi tiết đơn — kèm yêu cầu đặc biệt cẩn thận không được phát sinh bug khác
- Đọc kỹ toàn bộ 10 điểm khoá theo `status==4` trong `repair_detail_view.dart` trước khi sửa, chỉ gỡ đúng 2 điểm liên quan tới giá + thông tin chung, không đụng các khoá khác (nút trạng thái cuối, sửa dịch vụ...)
- `_editFinancials()`/`_editBasicInfo()`: gỡ chặn `status==4`; nút "Chỉnh sửa thông tin" hiện luôn thay vì ẩn khi đã giao. Logic tính chênh lệch giá/vốn (tránh nhân đôi chi phí sổ quỹ) đã có sẵn từ trước, không đổi
- `PricingSuggestion` thêm `matchedRepairs`; file mới `similar_repair_history_view.dart` (màn chỉ đọc, liệt kê từng đơn trong lịch sử tương tự, bấm vào mở thẳng chi tiết đơn đó)
- **Đã test trực tiếp trên thiết bị thật, dữ liệu shop thật:** mở 1 đơn "ĐÃ GIAO" thật, xác nhận cả 2 dialog (Sửa giá, Chỉnh sửa thông tin) đều mở đúng — đã bấm HỦY cả 2, không lưu, để không đụng dữ liệu tài chính thật khi test. Bấm "Lịch sử tương tự" mở đúng trang liệt kê khớp số liệu. Không crash trong toàn bộ quá trình
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception
- **Cập nhật thêm** theo phản hồi user: thẻ đơn trong "Đơn sửa tương tự" giờ hiện đủ khách hàng/SĐT/ngày/KTV/trạng thái ngay trên danh sách + nút "Xem chi tiết" rõ ràng — đã test lại trên đơn thật, mở đúng chi tiết, không crash
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16k]`

### ✅ Vừa hoàn thành (2026-08-16j): feat(repair): danh sách không bỏ sót đơn chưa giao + cảnh báo đơn treo quá 7 ngày
- Sau khi xác nhận case "đơn hiện sai" là do dữ liệu chưa cập nhật (không phải bug), phát hiện vấn đề thật: đơn cũ không cập nhật trạng thái biến mất khỏi danh sách chính (chỉ tìm bằng search mới thấy) — do query realtime đơn CHƯA giao có `.limit()` sắp xếp theo `updatedAt` mới nhất trước
- `firestore_service.dart`: bỏ `.limit()` khi `activeOnly=true` — tập hợp đơn chưa giao bị chặn tự nhiên nên an toàn tải hết, không bỏ sót đơn dù cũ đến đâu
- Thêm cảnh báo đơn "Tiếp nhận"/"Sửa xong" (chưa giao) treo quá 7 ngày — chip đỏ trên từng đơn + đếm số lượng ở header danh sách
- **Đã test trực tiếp trên thiết bị thật:** xác nhận danh sách hiện đủ 62 đơn, cảnh báo "QUÁ HẠN X NGÀY" hiện đúng trên các đơn thật đang treo lâu (10/59/62 ngày)
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16j]`

### ✅ Vừa hoàn thành (2026-08-16i): fix(repair): đơn "Sửa xong" hiện sai dù đã "Đã giao" ở thiết bị khác
- User báo Máy A (chủ shop, bản test) hiện đơn "SỬA XONG" dù thực chất đã "ĐÃ GIAO" từ lâu; Máy B (nhân viên, bản release App Store) hiện đúng
- Nguyên nhân: `order_list_view.dart` chỉ live-track đơn CHƯA giao (status<4) qua realtime listener, đơn đã giao dựa vào SQLite cache. Khi 1 đơn chuyển sang "Đã giao" ở THIẾT BỊ KHÁC, Firestore đúng đắn loại nó khỏi kết quả realtime (`removed`) — nhưng code cũ chỉ xoá khỏi map trong bộ nhớ, KHÔNG cập nhật gì vào SQLite, nên bản ghi cục bộ giữ nguyên trạng thái cũ mãi mãi
- Fix: khi đơn bị `removed` khỏi realtime, refetch 1 lần từ Firestore và ghi đè đúng trạng thái mới nhất vào SQLite
- **Giới hạn:** chỉ ngăn phát sinh mới, KHÔNG tự sửa dữ liệu ĐÃ sai sẵn trên Máy A — cần dùng "Nhận kho từ Cloud" trong Cài đặt để làm sạch ngay
- User báo thêm đơn "Tiếp nhận" cũng sai — đang điều tra tiếp, nghi liên quan cơ chế ưu tiên local-unsynced, xem mục "Đang điều tra thêm" ở trên
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16i]`

### ✅ Vừa hoàn thành (2026-08-16h): fix(sync,firestore): deploy composite index bị thiếu + fix audit_logs retry vô hạn
- User dán log iOS đã qua phân tích của công cụ khác — kiểm chứng lại bằng code thật, phát hiện 2 điểm phân tích gốc chưa chính xác
- **Composite index cho repairs (và ~55 collection khác) đã khai báo trong `firestore.indexes.json` nhưng CHƯA từng deploy** — xác minh bằng `firebase firestore:indexes` (đọc index thật đang chạy) chỉ thấy `attendance`. Đây là nguyên nhân trực tiếp gây "Realtime fallback mode" cho query repairs trong `OrderListView` và khả năng cao cũng gây mismatch Firestore/SQLite count ở đó. Đã `firebase deploy --only firestore:indexes` — xác nhận tăng từ 5 lên 60 collectionGroup có index
- **`audit_logs` permission-denied lặp lại KHÔNG liên quan App Check** — do vòng lặp retry vô hạn: `sync_service.dart` sau khi ghi batch thành công, bọc bước đánh dấu synced ở local trong `try {} catch (_) {}`; nếu bước đó lỗi, local coi log là chưa sync mãi mãi dù cloud đã có — lần sau ghi lại bị rule `allow update: if false` (audit_logs bất biến) chặn vĩnh viễn, và vì ghi theo batch atomic nên 1 dòng kẹt kéo cả batch fail theo
- Fix: khi batch lỗi, ghi lại từng dòng riêng lẻ; nếu vẫn lỗi thì kiểm tra doc đã tồn tại cloud chưa — nếu có thì tự đánh dấu synced (self-heal), nếu không thì giữ nguyên lỗi để tiếp tục điều tra
- App Check "App not registered" (iOS) xác nhận không chặn app (Auth tự fallback) — cần xử lý ở Firebase Console, không sửa được bằng code
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception
- **Chưa tự test được nhánh self-heal trên dữ liệu thật** — shop test không có audit log bị kẹt để tái hiện, cần theo dõi log lần sync tiếp theo trên thiết bị đã gặp lỗi
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16h]`

### ✅ Vừa hoàn thành (2026-08-16g): feat(admin): công cụ tìm & dọn tài khoản trùng email
- User hỏi có thể dọn tài khoản trùng đã có sẵn không — không có quyền đọc/ghi trực tiếp DB từ máy dev nên xây công cụ ngay trong Super Admin Console để user (đã có quyền super admin thật) tự chạy
- Nút "Tìm tài khoản trùng email" ở mục Người dùng — quét toàn bộ `/users` (≤5000 doc), gom theo email chuẩn hoá, chỉ hiện nhóm ≥2 tài khoản kèm đủ vai trò/shop/ngày tạo/uid để admin tự đối chiếu
- Xoá từng dòng dùng lại nguyên luồng `_deleteUser` đã có sẵn — vẫn bắt buộc dialog xác nhận + xác thực PIN, luôn xoá "hoàn toàn" (Firestore + Auth qua `deleteUserData`) để không lặp lại lỗi mồ côi đã phân tích ở `[2026-08-16f]`
- Toàn bộ chỉ ĐỌC cho tới khi admin chủ động xoá từng dòng — không có xoá hàng loạt/tự động
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception
- **Chưa tự test được trên dữ liệu thật** — không có tài khoản super admin, cần user tự mở app kiểm tra
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16g]`

### ✅ Vừa hoàn thành (2026-08-16f): fix(auth): chuẩn hoá email lowercase khi tự đăng ký — tránh trùng tài khoản
- User báo tab Người dùng trong Super Admin Console có nhiều dòng "trùng nhau" (cùng email, khác vai trò/shop/ngày) — xác nhận có khách hàng thật gặp, không chỉ dữ liệu test
- Thử đọc trực tiếp Firestore/Auth thật để xác minh nhưng máy này không có quyền đọc DB (không có service account/ADC) — không tự tạo credential khi chưa hỏi, chuyển sang rà code
- Tìm ra: `register_view.dart` (tự đăng ký, gọi thẳng Firebase Auth từ client) chỉ `.trim()` email, thiếu `.toLowerCase()` — trong khi luồng mời nhân viên (`createStaffAccount`, server) đã chuẩn hoá đúng từ trước. Nếu cùng 1 người gõ email lệch hoa/thường giữa 2 lần đăng ký, Auth có thể tạo 2 tài khoản thật khác uid — khớp đúng hiện tượng trong ảnh chụp
- Fix: thêm `.toLowerCase()` vào `register_view.dart`
- Cân nhắc sửa thêm `removeUserFromShop` nhưng quyết định KHÔNG làm — không khớp đúng triệu chứng (không tạo dòng mới) và có rủi ro regression trên tính năng khách hàng thật đang dùng thường xuyên
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception
- **Chưa dọn dữ liệu trùng đã có sẵn** — chỉ ngăn phát sinh mới
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16f]`

### ✅ Vừa hoàn thành (2026-08-16e): fix(admin): 3 lỗi tab Cửa hàng (Shops) trong Super Admin Console
- User báo: (1) tìm kiếm không ra shop chưa tải, (2) bấm vào shop phải bấm 2 lần mới vào được, (3) xóa shop xong vẫn còn trong danh sách
- (1) Tìm kiếm giờ tải toàn bộ shop (debounce 300ms, cache, tối đa 2000) khi có từ khóa thay vì chỉ lọc trang 20 shop đã tải
- (2) `_enterShop()` trước đây bỏ qua shop đã bấm, mở `ShopSelectorView` hiện lại TOÀN BỘ danh sách để chọn lại — giờ thêm `onTap` 1 chạm trên dòng shop + `ShopSelectorView` nhận `autoSelectShopId` để vào thẳng đúng shop sau khi xác thực PIN
- (3) "Vùng nguy hiểm" trước đây không lọc shop đã `deleted:true` nên xóa xong shop vẫn nằm y nguyên trong danh sách với đủ 2 nút Đặt lại/Xóa — giờ tự ẩn khỏi danh sách sau khi xóa
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception
- **Chưa test trực tiếp luồng vào-shop/xóa-shop** — không có tài khoản super admin thật trên máy, cần user xác nhận
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16e]`

### ✅ Vừa hoàn thành (2026-08-16d): feat(notification): "Yêu cầu cập nhật" tự mở đúng App Store/Google Play theo máy người dùng
- Yêu cầu user: không muốn dán link thủ công mỗi lần gửi broadcast cập nhật; 1 broadcast phải tự mở đúng store theo nền tảng của TỪNG người dùng (iOS → App Store, Android → Google Play `https://play.google.com/store/apps/details?id=com.huluca.shopmanager`)
- Chọn loại "Yêu cầu cập nhật" → tự bật switch "Bấm vào là mở kho ứng dụng" (mặc định bật, ẩn ô link thủ công); gửi giá trị sentinel `auto:store` thay vì URL cố định — thiết bị người NHẬN tự resolve đúng store khi bấm, không phải theo máy admin gửi
- `notification_service.dart`: thêm `storeLinkSentinel`/`androidStoreUrl`/`iosStoreUrl`, `_openBroadcastUrl` resolve theo `Platform.isIOS`
- `functions/index.js`: validate URL nới thêm để chấp nhận sentinel `auto:store`
- `flutter analyze` sạch, `node -c` hợp lệ, build + cài + khởi động Oppo CPH2203 không FATAL exception
- **Đã deploy** `firebase deploy --only functions:sendBroadcastNotification` thành công lên project `huyaka-1809`, sau khi user xác nhận
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16d]`

### ✅ Vừa hoàn thành (2026-08-16c): feat(notification): Broadcast có thể kèm link (VD: link App Store)
- Yêu cầu user: gửi thông báo broadcast, bấm vào mở link App Store để cập nhật app
- `functions/index.js`: `sendBroadcastNotification` nhận thêm `url` (optional, validate http/https), lưu Firestore + đưa vào FCM data payload
- Form gửi broadcast (Super Admin Console) thêm ô "Link (không bắt buộc)"
- `notification_service.dart`: dialog broadcast thêm nút "Cập nhật ngay" khi có url; bấm push notification (app nền/đóng) cũng ưu tiên mở url nếu có
- `flutter analyze` sạch, `node -c` cú pháp Cloud Function hợp lệ, build + cài + khởi động Oppo CPH2203 không FATAL exception
- **Đã deploy** `firebase deploy --only functions:sendBroadcastNotification` thành công lên project `huyaka-1809` (asia-southeast1), sau khi user xác nhận
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16c]`

### ✅ Vừa hoàn thành (2026-08-16b): refactor(admin): Redesign trang Super Admin Console
- Yêu cầu user: "sửa lại trang supper admin cho chuẩn và dễ theo dõi" (Tổng quan thiếu info, Cửa hàng/Người dùng khó lọc, style không nhất quán)
- Chỉ sửa UI (`super_admin_console_view.dart`), giữ nguyên 100% logic nghiệp vụ (reset/xóa shop, xóa user, khóa shop, PIN reauth, broadcast, sync claims)
- Thêm `_SectionHeader`/`_StatusPill` dùng chung; viết lại Dashboard (stat card bấm được, khối "Cần chú ý", "Truy cập nhanh"); thêm `FilterChip` lọc trạng thái cho Cửa hàng/Người dùng; đồng bộ `AppColors`/`AppTextStyles` toàn bộ 8 section + sidebar
- `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception trong logcat
- **Giới hạn:** không có tài khoản super admin thật trên máy test nên chưa tự vào được màn hình để xem trực tiếp — cần user xác nhận
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16b]`

### ✅ Vừa hoàn thành (2026-08-16): fix(ui): 22 điểm popup MEDIUM risk còn lại — hoàn tất toàn bộ audit 42 điểm
- Nốt phần MEDIUM risk còn lại từ audit `[2026-08-15c]` — thêm `MediaQuery.paddingOf(context).bottom` vào 22 điểm chỉ xử lý bàn phím mà thiếu thanh điều hướng, cùng pattern đã kiểm chứng
- Tiện sửa thêm 2 điểm context-safety (`missing_info_products_view.dart`, `repair_detail_view.dart` — chỉ đổi dòng đọc MediaQuery, không đụng gì khác)
- `flutter analyze` sạch, `flutter build apk --debug` thành công, cài + khởi động trên Oppo CPH2203 không FATAL exception trong logcat — không lặp lại screenshot từng file (theo phản hồi user về token)
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16]`

### ✅ Vừa hoàn thành (2026-08-15c): fix(ui): 20 điểm popup/bottom sheet bị che nút bấm
- User báo "rất nhiều chỗ khi popup bị che nút bấm" — audit 95 file dùng `showModalBottomSheet`/`showDialog`/`showAppBottomSheet`, tìm ra 20 điểm HIGH risk (không xử lý safe-area/keyboard gì cả) + 22 điểm MEDIUM risk (chỉ thiếu xử lý thanh điều hướng) trên 30+ file
- Đã fix 20 điểm HIGH risk theo pattern nhất quán (`Padding` + `MediaQuery.viewInsetsOf`/`paddingOf` đọc từ context ngoài, tránh crash `_dependents.isEmpty`) trên 19 file — xem danh sách đầy đủ ở `docs/CHANGELOG.md` mục `[2026-08-15c]`
- Tiện phát hiện + fix 2 chỗ trong `advanced_chat_view.dart` đã đọc nhầm `MediaQuery.of(ctx)` (context trong, có nguy cơ crash) khi cố xử lý safe-area
- `flutter analyze` sạch trên toàn `lib/`. Đã build cài + xác nhận màn Công nợ (đại diện) không crash trên Oppo CPH2203 — **chưa test riêng từng màn còn lại trong 20 điểm** (theo phản hồi user tiết kiệm token, không lặp lại screenshot từng file)
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-15c]`

### ✅ Vừa hoàn thành (2026-08-15b): fix(sale): danh sách bán hiện sai trạng thái "còn nợ" sau khi đã thu nợ
- `sale_list_view.dart` dùng `SaleOrder.remainingDebt` (chỉ tính từ downPayment/loanAmount, dành cho trả góp NH) để hiện chip "còn nợ" — không biết gì về các khoản đã thu qua bảng `debts` riêng (CÔNG NỢ, trả thiếu tiền mặt), nên đơn đã thu đủ nợ vẫn hiện sai
- Fix: thêm `_effectiveRemainingDebt()` ưu tiên tra bảng `debts` qua `linkedId`, áp dụng cho filter/sort/tổng nợ/chip — đồng thời thêm listener `debts_changed` để tự refresh khi thanh toán nợ xong ở màn khác
- Đã test trên Oppo CPH2203 với đơn CÔNG NỢ thật đã thu đủ — hiện đúng "ĐÃ THU" (xanh), không crash
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-15b]`

### ✅ Vừa hoàn thành (2026-08-15): fix(repair): revert regression crash ở sheet "Sửa ghi chú kỹ thuật"
- Review code commit 08-10 phát hiện regression: đọc `MediaQuery` qua `Builder`/`innerCtx` thay vì `context` ngoài — đúng anti-pattern đã tốn công fix ngày 08-08. Đã revert về pattern an toàn (khớp `_editBasicInfo`)
- Phát hiện + fix thêm: dùng nhầm `viewPaddingOf` thay vì `paddingOf` khiến sheet co lại còn 1 sliver khi bàn phím mở
- **Phát hiện bug crash sâu hơn, CHƯA fix** (xem Known Issues mục 6) — đã thử `PopScope` nhưng gây crash khác nên revert, không ship fix chưa chắc chắn
- Đã test trên Oppo CPH2203: luồng bình thường (không bấm Back hệ thống khi bàn phím mở) ổn định, không crash
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-15]`

### ✅ Vừa hoàn thành (2026-08-10): fix(repair): sheet "Thêm dịch vụ" hiện màn xám, không có popup
- Root cause: `ElevatedButton` (nút Thêm/Cập nhật) trong `Row` cùng `Spacer()` không có `style` riêng → kế thừa `minimumSize: Size(double.infinity, buttonHeight)` từ theme toàn app → tạo constraint tight-infinite không hợp lệ khi Row đo layout → crash `performLayout()` ngay khi mở sheet, chỉ còn nền xám (barrier), không log lỗi rõ ràng qua adb logcat thường
- Fix: gán `style: AppButtonStyles.smallElevatedButtonStyle` cho riêng nút này + thêm import còn thiếu
- Lỗi phụ phát hiện cùng lúc: hàng nút Hủy/Thêm bị khuất dưới thanh điều hướng hệ thống vì `useSafeArea: true` của `showModalBottomSheet` chỉ tránh status bar (`SafeArea(bottom: false)` nội bộ), không tránh nav bar — fix bằng bọc thêm `SafeArea(top: false)` quanh nội dung sheet
- Debug bằng `flutter run` (Dart VM live) để bắt được exception layout đầy đủ — `adb logcat` thường không đủ tin cậy (buffer bị ghi đè bởi log hệ thống)
- Đã test trên thiết bị Android thật: tái hiện lỗi gốc → verify fix hết crash → test full luồng thêm/sửa/xoá dịch vụ, không crash
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-10]`

### ✅ Vừa hoàn thành (2026-08-09b): feat(sale): tìm kiếm khách hàng tự động khi tạo đơn bán
- Gắn `CustomerSuggestionsPanel` (tái dùng từ tính năng đơn sửa) vào field TÊN/SĐT có sẵn trong `create_sale_view.dart`
- Xoá cơ chế gợi ý cũ (`_suggestCustomers`, chip ngang load 1 lần) — thay hoàn toàn bằng panel tìm theo gõ chữ + khách gần nhất
- Đã test trên Oppo CPH2203: gõ SĐT/TÊN hiện gợi ý, chọn khách tự điền + hiện quick-card
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-09b]`

### ✅ Vừa hoàn thành (2026-08-09): feat(backup): sao lưu đơn sửa kèm ảnh
- `BackupService.backupRepairsWithImages()`: đóng gói `repairs.json` + ảnh tải từ Firebase Storage (theo khoảng ngày) thành 1 file `.zip`, chia sẻ qua `share_plus`
- Tab mới "Đơn sửa + Ảnh" trong Cài đặt → Sao lưu & Khôi phục
- Backup cũ (SQLite/Firestore JSON) chỉ có URL text, không có ảnh thật — tính năng này lấp lỗ hổng đó
- Đã test trên Oppo CPH2203: chạy sao lưu, tạo đúng file, danh sách + summary đúng
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-09]`

### ✅ Vừa hoàn thành (2026-08-08b): feat(repair): tìm kiếm khách hàng tự động khi tạo đơn sửa
- `lib/widgets/customer_autocomplete_field.dart`: 2 widget dùng chung logic — `CustomerSuggestionsPanel` (controlled, gắn thẳng vào field có sẵn) và `CustomerAutocompleteField` (tự chứa TextField riêng, cho màn chưa có field sẵn). Debounce 180ms, local SQLite only, không phải Overlay nên không dính nhóm lỗi `_dependents.isEmpty`
- `DBHelper.searchCustomersRanked()` — xếp hạng exact phone > prefix > substring, rỗng → khách ghé gần nhất
- Tích hợp vào `create_repair_order_view.dart`: **gõ trực tiếp vào ô SĐT hoặc Tên KH có sẵn** hiện gợi ý ngay bên dưới (không phải ô tìm riêng — đã đổi theo phản hồi user sau bản đầu). Chọn khách tự điền cả 2 field + trigger `_smartFill()` có sẵn (quick-card công nợ/lịch sử)
- Chưa tích hợp vào các màn khác (bán hàng, bảo hành, công nợ) — `CustomerSuggestionsPanel` đã tái sử dụng được, chỉ cần gắn vào field tương ứng khi có yêu cầu
- Đã test trên Oppo CPH2203: gõ SĐT hiện gợi ý, gõ tên hiện gợi ý (không phân biệt hoa thường), khách gần nhất khi field vừa focus còn trống, auto-fill cả 2 field — đều OK
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-08b]`

### ✅ Vừa hoàn thành (2026-08-08): fix(audit,sync,notification) + feat(repair): hẹn giao máy
- Fix đếm sai "Active Listeners" trong Firestore Audit Monitor (dev tool, an toàn)
- Tăng cooldown SyncService.refreshCloudCollections 30s → 120s (giảm read Firestore không cần thiết)
- Fix double thông báo khi nhận từ nhân viên khác (2 đường hiển thị FCM + Firestore listener → chỉ còn FCM)
- Thêm `Repair.pickupSchedule` (lấy ngay/trong ngày/báo sau, nhãn UI "Hẹn giao máy"): model + DB v104 + UI ở màn tạo đơn và sheet sửa thông tin
- Phát hiện + fix crash `_dependents.isEmpty` có sẵn từ trước ở sheet sửa thông tin đơn sửa. **Fix lần đầu (Future.delayed) không đủ** — retest sau build vẫn crash ~50%. Đào sâu tìm ra 2 root cause thật: (1) `MediaQuery.of(ctx)` đọc từ context trong route thay vì context ngoài, (2) `FocusScope.of(ctx).unfocus()` tự tạo dependency mới ngay trước khi pop → đổi sang `FocusManager.instance.primaryFocus?.unfocus()`. Verify lại 5/5 lần không crash. Áp dụng phòng ngừa cho `_editTechnicianNotes` (cùng file, cùng anti-pattern).
- **Đã test kỹ trên Oppo CPH2203** (adb, không có Samsung A32 lúc test). Chưa test trên Samsung A32 — cần verify chéo khi có máy.
- Chi tiết đầy đủ: xem `docs/CHANGELOG.md` mục `[2026-08-08]`

### ✅ Vừa hoàn thành (2026-06-16c): feat(notifications): push notification cho quản lý
- `fast_stock_in_view`: gửi notification sau khi tạo phiếu nhập — phân biệt thiếu giá vốn / thiếu NCC / bình thường
- `pending_stock_list_view`: gửi notification khi xác nhận nhập kho thành công
- `create_sale_view`: gửi notification khi bán hàng mà `totalCost=0` (thiếu giá vốn)
- Đơn sửa chờ duyệt: đã có sẵn từ trước (`repair_detail_view` type `approval_needed`)

### ✅ Vừa hoàn thành (2026-06-16b): fix(supplier): _pickSupplier ghi đúng công nợ/expense/lịch sử
- `missing_info_products_view.dart`: `_pickSupplier` thêm SimpleDialog chọn payment method
- Nếu `p.cost>0 && p.paymentMethod==null`: ghi debt (CÔNG NỢ) hoặc expense (TIỀN MẶT/CK) + `logPurchase`
- Nếu `p.paymentMethod!=null`: tài chính đã ghi rồi → không ghi thêm (tránh double count)
- `supplier_import_history` dùng payment method thực tế; lưu vào `products.paymentMethod`

### ✅ Vừa hoàn thành (2026-06-16a): fix(stock-in): payment method flow khi allowPendingCost=true
- `fast_stock_in_view.dart`: thêm getter `_allowPendingCost` từ ShopSettings; payment method chỉ bắt buộc khi `!_allowPendingCost` hoặc `cost > 0` — cho phép nhập kho tạm mà không cần chọn thanh toán khi cost=0
- `missing_info_products_view.dart`: `_editCost` thêm `paymentMethod: payment` vào `p.copyWith(...)` — product record lưu đúng phương thức thanh toán sau khi bổ sung giá vốn

### ✅ Vừa hoàn thành (2026-06-11c): fix(finance): bổ sung giá vốn/NCC retroactive cập nhật đúng tài chính
- `db_helper.dart`: thêm `updateSaleCostByImei()` — patch totalCost + itemSnapshotsJson khi nhập vốn sau bán
- `missing_info_products_view.dart`: `_editCost` cập nhật sale_orders.totalCost trực tiếp (thay vì tạo expense gây double counting); expense chỉ tạo khi không tìm được sale. Cả `_editCost` và `_pickSupplier` insert vào `supplier_import_history`. Date dùng p.createdAt.
- `supplier_detail_view.dart`: `includeSold: true` → hiện cả SP đã bán trong tab Sản phẩm của NCC

### ✅ Vừa hoàn thành (2026-06-11b): importPurchaseOrders tự tạo product stub; IMEI = 1 SP riêng
- `kiotviet_excel_import_service.dart`: sau khi insert import_order_item, kiểm tra products table
- Có IMEI → tìm theo IMEI only (không fallback tên) → nếu không thấy: tạo product qty=1 (1 IMEI = 1 máy)
- Không IMEI → tìm theo UPPER(name) → nếu không thấy: tạo product stub qty=số lượng phiếu
- Đã tồn tại → chỉ fill supplier/cost nếu đang trống
- **Kết quả:** import DanhSachChiTietNhapHang → sản phẩm mới tự xuất hiện trong Danh sách SP

### ✅ Vừa hoàn thành (2026-06-10g): Fix crash _dependents.isEmpty khi bấm Lưu/Hủy thêm khách hàng
- `order_list_view.dart`: nút Lưu/Hủy chuyển sang `async`, thêm `await Future.delayed(Duration.zero)` sau `unfocus()` trước `Navigator.pop()` — một frame trễ đủ để text overlay deactivate sạch

### ✅ Vừa hoàn thành (2026-06-10f): Fix mã nhập nhanh điền sai màu/tình trạng
- `ProductConstants.colors`: Thêm 'SA MẠC' vào list
- `mapColor("TỰ NHIÊN")` → 'TITAN TỰ NHIÊN' (seeder dùng 'TỰ NHIÊN' cho iPhone 15/16/17 Pro)
- `mapConditionShort("NEW")` → 'MỚI' (seeder lưu condition='NEW' cho iPhone 16/17)
- `_colorOptions` trong quick_input_codes_view thêm 'SA MẠC' #D2B48C

### ✅ Vừa hoàn thành (2026-06-10e): Trả hàng hiển thị trong Giao dịch tab
- Thêm `FinanceV2Txn(type: 'REFUND', isIncome: false)` vào returns loop trong `finance_v2_data_service.dart`
- Giao dịch tab: tên khách + "Hoàn tiền trả hàng" + số tiền âm + phương thức
- Tổng quan không thay đổi: `saleIn -= amount` vẫn tính riêng
- Filter OUT trong Giao dịch bao gồm trả hàng (đúng về cash flow)

### ✅ Vừa hoàn thành (2026-06-10d): Fix home CHI TIÊU mâu thuẫn Trả hàng 12 Tr vs tổng 0
- **Root cause:** Home donut dùng 2 nguồn: tổng từ finance_v2 (net, 5 Tr) nhưng breakdown "Bán hàng" cộng thêm `analysis.refundOut` (17 Tr gross), "Trả hàng" 12 Tr nằm dưới CHI TIÊU dù tổng = 0
- **Fix:** Xóa `_todayRefundOut` khỏi `incomeItems` và `expenseItems`; xóa field + assignment
- **File:** `lib/views/home_view.dart`
- **Kết quả:** Home nhất quán với Tài chính — Thu 5 Tr = Bán hàng 5 Tr, CHI TIÊU 0 không có Trả hàng

### ✅ Vừa hoàn thành (2026-06-10c): Fix return form tính 0đ hoàn tiền khi snapshot giá bị hỏng
- **Root cause:** `itemSnapshotsJson.unitPrice=0` do cloud sync bug cũ ghi đè → `totalReturnAmount=0` → finance không trừ doanh thu
- **Fix:** Fallback trong `_parseItems()` — nếu tổng snapshot giá = 0 mà `sale.finalPrice > 0`, phân phối `finalPrice/totalQty` cho từng item
- **File:** `lib/views/create_sales_return_view.dart`
- **Lưu ý:** Data cũ đã lưu 0 Tr không tự sửa được; fix áp dụng cho future returns

### ✅ Vừa hoàn thành (2026-06-10b): Fix trả hàng không ghi vào Giao dịch tài chính
- Xóa `transactions.add` cho REFUND trong `finance_v2_data_service.dart` — Giao dịch tab sạch
- Xóa `FinancialActivityService.logCustomActivity` cho returns trong `sales_return_service.dart`
- Giữ `saleIn -= amount` → "Tiền thu vào" vẫn net chính xác sau hoàn trả
- Sổ quỹ không bị ảnh hưởng (dùng bảng sales_returns riêng)

### ✅ Vừa hoàn thành (2026-06-10a): Fix crash _dependents.isEmpty khi bấm "Sửa thông tin đơn"
- **Root cause:** `showDialog` gọi đồng bộ trong `PopupMenuButton.onSelected` khi `_managerUnlocked=true`, xung đột với quá trình deactivate popup's InheritedElement
- **Fix:** Thêm `await Future.delayed(Duration.zero)` trước mỗi `showDialog` call (case edit/fix_cost/delete) để nhường frame, đảm bảo popup đóng hoàn toàn
- **File:** `lib/views/sale_detail_view.dart` lines 1636–1648

### ✅ Vừa hoàn thành (2026-06-09j): Fix inventory price/cost = 0đ
- **Root cause:** `upsertProduct` khi sync từ cloud ghi đè `price/cost/createdAt=0` lên giá trị local đúng
- **Fix 1:** `upsertProduct()` — preserve local values khi `isSynced=true` và cloud trả 0
- **Fix 2:** `sync_service.dart` (2 paths) — explicit preserve trước `Product.fromMap`
- **Fix 3:** `fixMissingCreatedAt()` — one-time SQL fix `createdAt` từ `updatedAt` khi `createdAt=0`
- **Note:** Sản phẩm đang có `price=0` genuine (không phải sync bug) vẫn cần user sửa tay qua nút SỬA trong detail

### ✅ Vừa hoàn thành (2026-06-09i): Fix repair list pagination — updatedAt column missing
- `getRepairsPaged` → `lastCaredAt` thay vì `updatedAt` (không tồn tại trong schema)
- 594 đơn hiển thị đúng, pagination 50/page

### ✅ Vừa hoàn thành (2026-06-09e): Audit home_view — xóa 89 debugPrint
- Xóa toàn bộ 89 debugPrint (trace/flow logs không ảnh hưởng logic)
- Fix 2 warning phát sinh: `catch (e, stack)` → `catch (_)`, xóa `Stopwatch` không dùng
- 0 errors, 0 warnings sau khi clean

### ✅ Vừa hoàn thành (2026-06-09d): Audit home_view — xóa dead navigator code
- Xóa `_tabNavigatorKeys`, `_usesNestedNavigator`, `_navigatorKeyForTab` — không bao giờ được thực thi (nested Navigator tắt theo design)
- Simplify `_maybePopCurrentTabNavigator` → `async => false`
- 0 errors sau khi xóa

### ✅ Vừa hoàn thành (2026-06-09c): Audit shop_settings_view — 5 fixes
- **Xóa 3 duplicate links** khỏi Quick Actions (đã có trong settings_view)
- **Flatten ExpansionTile** → Card + ListTile cho Advanced Settings
- **Cache members**: `_cachedMembers` + `_loadingMembers` trong `initState()`, không FutureBuilder
- **Gộp upload**: 3 if-blocks (logo/cover/both) → 1 block `Future.wait()` song song

### ✅ Vừa hoàn thành (2026-06-09b): Fix search đơn sửa — tìm toàn bộ local DB
- **Bug**: Search chỉ tìm trong 50 đơn đã load từ Firestore. Đơn cũ hơn không ra dù đã sync về máy.
- **Fix**: `_onSearch` debounce 300ms → query `db.searchRepairs()` (SQLite LIKE, limit 200) thay vì filter in-memory. Khi xóa từ khoá → về realtime list.

### ✅ Vừa hoàn thành (2026-06-09a): Tái cấu trúc settings_view — 7 section chuyên nghiệp
- **Vấn đề**: 8 sub-settings views (shop, printer, notifications, KiotViet, HR, labels, work schedule) không có link từ settings page. Sao lưu + Trợ giúp ẩn trong popup menu.
- **Fix**: `settings_view.dart` — thêm 7 imports, `_buildNavTile()` helper, tái cấu trúc ListView thành 7 section (Tài khoản / Cửa hàng / Nhân sự / Thông báo / Đồng bộ & Sao lưu / Hỗ trợ / Quản trị nâng cao). Xóa popup menu, xóa `_buildFeatureChip`.
- **Không ảnh hưởng sync hay logic**: chỉ thay đổi UI/navigation.

### ✅ Vừa hoàn thành (2026-06-08o): Fix health check bỏ skip auto-restore products
- **Root cause**: `noAutoRestoreCollections = {'products'}` → health check thấy cloud=482/local=20 nhưng skip 462 sản phẩm thiếu với lý do "user may have deleted intentionally".
- **Tại sao sai**: `_buildCloudComparisonRows` đã filter `deleted: true` → `cloudIds` chỉ chứa sản phẩm active. Nếu cloud có sản phẩm active mà local thiếu → chắc chắn là chưa sync, không phải user xóa.
- **Fix**: `sync_health_check.dart` — `noAutoRestoreCollections = <String>{}` (rỗng). Khi reload đồng bộ, 462 sản phẩm thiếu được tự download và upsert local.

### ✅ Vừa hoàn thành (2026-06-08n): Xóa cloud → tự đồng bộ sang máy B/C (soft-delete + staggered timestamp)
- **Root cause**: `deleteSelectedDataFromCloud` hard-delete → không có `updatedAt` → polling cursor không advance → máy B/C không nhận được sự kiện xóa.
- **Fix**: `backup_service.dart` `deleteByQuery` dùng `batch.update({deleted: true, updatedAt: nowMs + i})` thay hard-delete. Staggered timestamps đảm bảo poll 20 docs/lần advance cursor đúng.
- **Kết quả**: Máy A xóa kho + đẩy KiotViet → Máy B/C tự động nhận xóa + nhận hàng mới qua polling. Không cần thao tác thủ công trên máy B/C.

### ✅ Vừa hoàn thành (2026-06-08m): Fix "Nhận kho từ Cloud" đồng bộ sạch sau import KiotViet
- **Bug**: `downloadAllFromCloud` chỉ upsert → sản phẩm cũ hard-deleted trên Firestore vẫn còn local trên máy B.
- **Fix**: `settings_view._pullKhoFromCloud` xóa local products (`DELETE WHERE shopId`) trước khi pull.
- **Flow sau import KiotViet**: Máy A import → "Đẩy lên Cloud" → Máy B "Nhận kho từ Cloud" → sạch + đúng.

### ✅ Vừa hoàn thành (2026-06-08l): Fix 3 bugs còn sót sau audit lần 2
- **Bulk delete (inventory_view:2282)**: `SyncOperation.update` → `SyncOperation.delete` (cùng bug như single delete đã fix, nhưng ở path xóa hàng loạt bằng checkbox).
- **_handleUpdate normalize**: `sync_orchestrator.dart` — thêm `data['deleted'] = data['deleted'] == 1 || data['deleted'] == true` trước khi push Firestore. Bất kỳ SyncOperation.update nào mà data có `deleted=1` sẽ không corrupt Firestore.
- **_pullKhoFromCloud safety**: `settings_view.dart` — `SyncOrchestrator().syncAll()` trước `downloadAllFromCloud(force: true)` → push pending trước khi pull đè tránh mất dữ liệu.

### ✅ Vừa hoàn thành (2026-06-08k): Fix pull paths bỏ sót deleted:1 — root cause chính lệch kho
- **Root cause thực sự**: `syncAllToCloud` đã biết dùng `== 1 || == true` nhưng **tất cả subscription callbacks + downloadAllFromCloud** chỉ check `== true` → Firestore record `deleted: 1` (integer, từ bug cũ) không bị xóa local → ghost products restore lại khi pull.
- **Fix**: `sync_service.dart` — replace all 30+ `data['deleted'] == true` → `data['deleted'] == true || data['deleted'] == 1` trong toàn bộ pull paths.
- **Kết hợp với [2026-06-08j]**: Fix j ngăn tạo mới sai. Fix k dọn sạch cũ + ngăn restore.

### ✅ Vừa hoàn thành (2026-06-08j): Fix đồng bộ kho giữa các thiết bị
- **Root cause**: `_deleteProductWithOptions` enqueue `SyncOperation.update` → orchestrator push `deleted: 1` (SQLite integer) lên Firestore → `data['deleted'] == true` trả về false → ghost products tồn tại trên thiết bị khác mãi.
- **Fix 1 (inventory_view)**: Đổi `SyncOperation.update` → `SyncOperation.delete` → orchestrator gọi `_handleDelete()` → `softDeletePayload()` → `deleted: true` (boolean) đúng chuẩn.
- **Fix 2 (firestore_service)**: `deleteProduct()` thêm `'deleted': true` — đồng bộ với `deleteRepair()` / `deleteSale()`.
- **Fix 3 (settings_view)**: Nút "Nhận kho từ Cloud" (teal) → `downloadAllFromCloud(force: true)` — thiết bị lệch kho nhấn 1 lần là đồng bộ lại hoàn toàn.

### ✅ Vừa hoàn thành (2026-06-08i): Fix hiển thị giảm giá ở list bán & chi tiết đơn
- **Root cause**: `set_price` case trong `create_sale_view.dart` update cả `originalPrice = newPrice` → `salePrice = unitPrice` → discount = 0.
- **Fix 1 (create_sale_view)**: Bỏ dòng `item['originalPrice'] = newPrice` → giờ `originalPrice` giữ nguyên giá catalog.
- **Fix 2 (sale_list_view)**: `_totalItemDiscount()` thêm fallback regex parse "(Giảm X)" từ productNames cho đơn cũ.
- **Fix 3 (sale_detail_view)**: Builder giảm giá nay luôn hiển thị "Tổng giảm giá: -X Tr" khi totalDisc > 0.

### ✅ Vừa hoàn thành (2026-06-08h): Fix 4 bugs giảm giá & format tiền
- **Giá vốn format**: `inventory_detail_view.dart` `_costRow` — `formatCurrency` → `formatCompactCurrency` (hiển thị `10 Tr` thay `10.000.000`).
- **Scroll bị cắt**: `SingleChildScrollView` padding bottom tăng từ `16` → `32` px.
- **Sale detail tổng giảm**: thêm Builder hiển thị "Giảm sản phẩm" (item) + "Giảm đơn" (order) + "Tổng giảm giá" khi cả hai loại cùng có.
- **Backward compat**: `_enrichLinkedProducts()` async enrichment cho đơn cũ (không có `salePrice` snapshot) — lookup DB lấy giá hiện tại làm fallback, setState khi có discount.

### ✅ Vừa hoàn thành (2026-06-08g): Hiển thị giảm giá + chuẩn hoá format tiền toàn module bán hàng
- **Sale list card**: thêm chip cam **Giảm: -X Tr** khi đơn có giảm (item-level hoặc order-level).
- **Sale detail product list**: badge cam `-X Tr` trên từng sản phẩm được giảm.
- **Chi tiết sản phẩm (InventoryDetailView)**: nhãn "Giá bán gốc" + dòng "Đã giảm: -X Tr" + "Giá bán trong đơn".
- **Format tiền**: `formatCompactCurrency` thay `formatCurrency` tại chip, product detail → hiển thị `11 Tr` thay `11.000.000`.
- **Data**: snapshot item nay lưu `salePrice` (originalPrice tại thời điểm bán) để tính discount chính xác kể cả khi giá kho thay đổi sau.

### ✅ Vừa hoàn thành (2026-06-08f): Thêm tính năng sửa giá bán sản phẩm trong màn hình tạo đơn bán
- **Feature**: Popup "Ưu đãi sản phẩm" có thêm option "💰 Sửa giá bán sản phẩm".
- **Flow**: Nhấn → hiện panel inline (giá hiện tại, input giá mới VND, checkbox cập nhật kho) → LƯU → cập nhật ngay giá/tổng/giảm/thành tiền trong đơn.
- **Checkbox tick**: Gọi `db.updateProductMap` cập nhật `price` + `isSynced=0` trong SQLite, đánh dấu chờ sync cloud.
- **Không có hạn chế giá**: Cho phép nhập giá 0 hoặc bất kỳ, khác với "Giảm giá" phải thấp hơn giá gốc.
- **File**: `lib/views/create_sale_view.dart` — `_GiftDiscountSheetContent` + case `set_price` trong `_showGiftDiscountSheet`.

### ✅ Vừa hoàn thành (2026-06-08e): Fix sync health báo "Chưa sync hết" sai khi kho cloud nhiều hơn local
- **Bug**: Cloud có 684 records cũ → `cloudOnly=684` → `effectiveMismatchCount=684` → "Chưa sync hết" dù `Local chưa sync=0` và `Queue=0`.
- **Fix**: `sync_health_check.dart` — với `noAutoRestoreCollections` (products), báo `cloudOnly=0` trong `SyncCheckResult`. Cloud-only records cho kho là chủ đích, không phải lỗi.

### ✅ Vừa hoàn thành (2026-06-08d): Fix KiotViet import tạo bản ghi trùng sau sự cố xóa kho
- **Bug**: Sau sự cố "Dọn kho cloud", sản phẩm bị `deleted=1` local. Re-import từ KiotViet tạo sản phẩm MỚI với `id` auto-increment mới (vì query duplicate bỏ qua `deleted=1`). Đơn bán cũ lưu `productId` cũ → không khớp → hiển thị sản phẩm sai.
- **Fix**: `kiotviet_excel_import_service.dart` — duplicate check không filter `deleted`, nếu tìm thấy bản ghi đã xóa → UPDATE (khôi phục) giữ nguyên `id` gốc + xóa mềm bất kỳ bản active trùng tên nào từ lần import lỗi trước.

### ✅ Vừa hoàn thành (2026-06-07h): Force re-sync dữ liệu KiotViet lên Firestore
- **Root cause**: KiotViet Excel import lưu sales với `shopId=NULL` → `getAllSales(shopId=X)` không tìm thấy → `syncAllToCloud` skip → 3892 đơn bán và 521 sản phẩm kẹt local-only
- **Fix**: `backfillShopId()` gán shopId cho rows thiếu + `markAllUnsynced()` reset isSynced=0 + `syncAllToCloud(force:true)`
- **UI trigger**: Settings > Đồng bộ dữ liệu > card cam "Đẩy dữ liệu KiotViet lên Cloud"

### ✅ Vừa hoàn thành (2026-06-07g): Tách kho điện thoại — mỗi IMEI = 1 record
- **DB v102 migration**: Query `DIEN_THOAI` có `imei LIKE '%|%'` → split từng IMEI thành record riêng (qty=1, firestoreId = `parentFid__s{i}`, isSynced=0 cho bản mới)
- **upsertProduct auto-split**: KiotViet sync phone với IMEIs gộp → `_upsertPhoneSplit` tách và upsert từng IMEI độc lập
- **Cart qty lock**: Trong `create_sale_view.dart`, phone với IMEI đơn → disable `+`/`-`/textField, qty cố định 1

### ✅ Vừa hoàn thành (2026-06-07e): Fix 3 bugs kiểm kho nhanh
- **Bug 1 (Chờ sync 1 phút)**: `syncAll()` đợi toàn bộ queue → thêm direct `FirestoreService.upsertRepair` trong `_saveData()` → badge clear trong <2s
- **Bug 2 (crash lưu kiểm kho)**: `getCurrentUserName()` thiếu `await` → `Future<String>` vào SQLite → crash → thêm `await`
- **Bug 3 (topbar quá nhiều icon)**: 7+ icon cùng lúc → giữ zone selector + QR scan + flash; còn lại vào `PopupMenuButton` "..."

### ✅ Vừa hoàn thành (2026-06-07d): Fix storage_locations không sync lên cloud
- **Root cause**: `isSynced: true` set TRƯỚC Firestore write → nếu write fail thì record kẹt local mãi mãi (sync engine bỏ qua vì thấy flag "đã sync")
- **Fix 1 (preventive)**: Save flow đúng thứ tự: local `isSynced: false` → Firestore → `isSynced: true` chỉ khi thành công
- **Fix 2 (recovery)**: `_reuploadLocalToCloud()` chạy khi view mở — upload lại tất cả local locations với `firestoreId` lên Firestore (idempotent vì dùng merge=true) → recover 2 records đang bị kẹt

### ✅ Vừa hoàn thành (2026-06-07c): Fix supplier search + staff profile 0 đơn
- **Bug 1 (search NCC)**: `nameNorm` không có trong CREATE TABLE → fresh install thiếu column → SQL error bị catch silently → kết quả rỗng → thêm `nameNorm TEXT` vào CREATE TABLE
- **Bug 1b (race condition)**: `_isLoading=true` khi scroll đang load → search timer fires → guard return sớm → search không chạy → reset `_isLoading=false` khi search thay đổi
- **Bug 2 (staff 0 đơn)**: Stat cards dùng monthly count (June=0) + `getSalesBySellerName` không tìm theo email prefix → đổi cards sang all-time count + fetch theo cả display name và email prefix với dedup

### ✅ Vừa hoàn thành (2026-06-07b): Fix 2 lỗi từ iOS log review
- **Bug 1 (InventoryCheck type cast crash)**: `checks.cast<InventoryCheck?>()` fail vì SQLite trả về `Map<String, dynamic>` không thể cast trực tiếp → Đổi sang `checks.map((raw) { decode itemsJson; return InventoryCheck.fromMap(m); })` — thêm `dart:convert` import
- **Bug 2 (product_categories permission-denied)**: Firestore rules `belongsTo()` dùng `get()` calls có thể fail timing → Thêm `|| request.auth.token.shopId == shopId` fallback, deploy `firestore.rules` lên production

### ✅ Vừa hoàn thành (2026-06-07): Fix 3 bugs trong sheet Nhập giá vốn
- **Bug 1 (cut-off)**: Thêm `SingleChildScrollView` wrapper quanh `Column` → user có thể cuộn khi keyboard lên
- **Bug 2 (dropdown invisible)**: Đổi `style: Colors.white` → `Colors.black87` trên `DropdownButtonFormField` → chữ tối hiển thị trên nền trắng (`PopupTheme.bgDark = 0xFFFFFFFF`)
- **Bug 3 (crash `_dependents.isEmpty`)**: Đổi `MediaQuery.of(outerCtx)` → `MediaQuery.of(ctx)` → không còn cross-tree InheritedWidget dependency khi route đóng

### ✅ Vừa hoàn thành (2026-06-06 P3): Inventory inline search + Dashboard Settings AppBar fix toàn diện
- **Root cause cuối**: Sub-screens nhận `MediaQuery.padding.top = 0` → AppBar touch targets nằm tại y=39-105 bên trong status bar region (y=0-110) → system UI intercept tất cả tap → search button không hoạt động; toolbar bị status bar che
- **Fix global** (`main.dart`): Thêm `MaterialApp.builder` đọc `View.of(context).padding.top / devicePixelRatio` và inject vào `MediaQuery` nếu lớn hơn — fix tất cả sub-screens cùng lúc
- **Fix inventory search** (`inventory_view.dart`): Thay `showModalBottomSheet` (keyboard insets không propagate) bằng inline `TextField` trong `Scaffold` body; `Scaffold(resizeToAvoidBottomInset: true)` tự đẩy field lên trên keyboard
- **Verified trên Samsung A32**: Inventory search — TextField + keyboard visible đồng thời ✅; Dashboard Settings — full AppBar với back button, title, tabs, action icons ✅

### ✅ Vừa hoàn thành (2026-06-06): Fix AppBar/topbar bị che status bar — Android 16 edge-to-edge
- **Root cause**: `targetSdk = 36` → Android 16 bắt buộc edge-to-edge, nhưng Flutter engine không nhận window insets đúng → `MediaQuery.padding.top = 0` → toolbar content (back button, action icons) render tại y=0, chồng lên status bar
- **Fix**: Thêm 3 dòng trong `main()` — `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` trước `runApp()` — một thay đổi duy nhất fix tất cả màn hình bị ảnh hưởng
- **Xác nhận**: User test trên thiết bị — các màn hình bị ảnh hưởng đã hiển thị AppBar đúng vị trí bên dưới status bar

### ✅ Vừa hoàn thành (2026-06-06 v2): Fix search bottom sheet THỰC SỰ hiện trên bàn phím
- **Root cause thực sự**: `MediaQuery.viewInsetsOf(stateCtx)` dùng `InheritedModel` aspect-based dependency → KHÔNG propagate keyboard insets trong bottom sheet route → `Padding(bottom: 0)` → container bị keyboard che
- **Fix `_openSearchDialog`**: Bỏ `StatefulBuilder`, bỏ `useSafeArea: true`, dùng `MediaQuery.of(ctx).viewInsets.bottom` (full dependency, outer builder ctx)
- **Fix restock sheet**: Đổi outer param `ctx` → `outerCtx`, dùng `MediaQuery.of(outerCtx).viewInsets.bottom` — giữ `StatefulBuilder` cho UI state updates
- **Fix inline cost edit**: Tương tự restock sheet

### ✅ Vừa hoàn thành (2026-06-05): Audit & fix tài chính home screen (3 bugs)
- **Bug 1**: TT đối tác (partner payment) double-count trong biểu đồ Chi tiêu → thêm `partnerPaymentOut` field trong `FinanceV2Snapshot`, trừ khỏi `operatingExpenseOut`
- **Bug 2**: Thu khác bị under-report khi có thu nợ → `_todayMiscIncome = financeSnapshot.incomeOther` (không double-trừ debt)
- **Bug 3**: Nhập hàng chart thiếu import từ `importHistory` → expose `importExpenseOut` từ snapshot, dùng nhất quán
- Sau fix: `Chi phí + Nhập hàng + Trả nợ NCC + TT đối tác = totalOut` chính xác 100%

### ✅ Vừa hoàn thành (2026-06-05): Fix crash _dependents.isEmpty khi đóng bottom sheet
- **Root cause**: `MediaQuery.viewInsetsOf(ctx)` trong builder của `showModalBottomSheet` tạo dependency vào inner MediaQuery. Khi sheet đóng, inner MediaQuery deactivate trước Padding → assertion crash
- **Fix**: Thay tất cả `viewInsetsOf(ctx)` → `viewInsetsOf(context)` (outer context) trong 11 files, 21 vị trí
- Cũng đã thêm `FocusScope.of(ctx).unfocus()` trước `Navigator.pop` trong tất cả dialog/sheet có TextField

### ✅ Vừa hoàn thành (2026-06-05): Fix sync timeout log noise
- **Root cause**: Firebase Auth token refresh hang → 35+ collection query xếp hàng → tất cả hit 20s timeout cùng lúc
- `pollCollection()` bỏ qua ngay nếu offline (`ConnectivityService.instance.isOnline`)
- `TimeoutException` giờ log `⏱️` (transient) thay vì `❌ Poll sync error` — giảm nhiễu console

### ✅ Vừa hoàn thành (2026-06-05): Import/Export Excel hợp nhất
- **Cài đặt → Nhập/Xuất dữ liệu**: Trang mới thay thế tất cả nút xuất rời rạc
- Import 5 loại: Đơn sửa, Đơn bán, Kho hàng, Khách hàng, NCC — sync Firestore + SQLite
- Export: Bộ lọc ngày (Hôm nay/Tuần/Tháng/Năm/Tuỳ chọn), xuất từng loại ra XLSX
- Progress dialog trực quan (thanh tiến trình + đếm hàng + chi tiết lỗi)

---

## 🔴 RỦIRO ĐỒNG BỘ CÒN LẠI — ĐÃ GHI NHẬN, CHƯA SỬA

> **Đây là đầu vào quan trọng nhất cho chu kỳ bảo trì tiếp theo.**  
> P1 đã được sửa. P2-P4 không gây mất dữ liệu ngay lập tức nhưng cần xử lý trước khi scale.

### P1 — ĐÃ SỬA (2026-06-05)
| Mô tả | File | Trạng thái |
|-------|------|------------|
| `isSynced=1` đặt TRƯỚC khi Firestore xác nhận trong `supplier_payment_service` | `lib/services/supplier_payment_service.dart` | ✅ ĐÃ SỬA |
| `isSynced=1` đặt TRƯỚC khi Firestore xác nhận trong `repair_partner_payment_service` | `lib/services/repair_partner_payment_service.dart` | ✅ ĐÃ SỬA |

### P2 — CHƯA SỬA (rủi ro trung bình-cao)
| Mô tả | File | Vị trí |
|-------|------|--------|
| `downloadAllFromCloud` upsert toàn bộ doc không qua `_shouldAcceptCloudData` — có thể đạp local mới | `lib/services/sync_service.dart` | dòng 4576 |
| `sendChat()` nuốt lỗi `catch (_) {}` — UI báo thành công giả khi Firestore fail | `lib/services/firestore_service.dart` | dòng 514 |
| Conflict check `_shouldAcceptCloudData` chỉ bảo vệ riêng `repairs` — các collection khác (sales/products/debts) dùng timestamp field thay thế (soldAt/date) không chuẩn | `lib/services/sync_service.dart` | dòng 746-770 |

### P3 — CHƯA SỬA (rủi ro thấp-trung bình)
| Mô tả | File | Vị trí |
|-------|------|--------|
| Gọi `syncAll()` sau lưu kho nhưng không kiểm tra `SyncResult.failed` — không thông báo khi queue fail | `lib/views/inventory_view.dart` | dòng 1441, 3760 |
| Gọi `syncAll()` trong `salvage_phone_view` bọc bởi `catch (_) {}` — nuốt lỗi hoàn toàn | `lib/views/salvage_phone_view.dart` | dòng 963, 1002 |
| `customer_service.updateCustomer()` cập nhật local trước, cloud sau; cloud fail không có retry queue | `lib/services/customer_service.dart` | dòng 75-78 |
| `supplier_service.addSupplier()` trả thành công kể cả khi Firestore fail | `lib/services/supplier_service.dart` | dòng 281-284 |

### P4 — CHƯA SỬA (rủi ro thấp)
| Mô tả | File |
|-------|------|
| EventBus emit sau batch dù có thể có doc lỗi cục bộ — UI reload với trạng thái không nhất quán | `lib/services/sync_service.dart` |
| `import_order_service.dart` set `isSynced=1` dựa trên fact Firestore đã được gọi — không check kết quả | `lib/services/import_order_service.dart` |

### ĐÃ GIẢM RỦI RO TRONG PHIÊN NÀY
| Mô tả | File | Kết quả |
|-------|------|---------|
| Re-init real-time sync trùng lặp theo cùng user/shop/role/permissions | `lib/services/sync_service.dart` | ✅ Đã chặn duplicate init để tránh `cancelAllSubscriptions()` lặp vô ích |

---

## ✅ CHECKLIST CHỐT BÀN GIAO PRODUCTION

> Dùng checklist này mỗi lần chuẩn bị release lên production với user thực.

### Trước khi build release
- [ ] `flutter analyze` → không có `error` cứng
- [ ] `flutter build apk --release` → build thành công
- [ ] Kiểm tra tất cả P1 bug đã được sửa (xem bảng trên)
- [ ] Chạy test quan trọng: tạo đơn sửa, bán hàng, nhập kho, thanh toán NCC

### Kiểm tra dữ liệu production
- [ ] Mở app với user thực → không có crash khi khởi động
- [ ] Kiểm tra sync badge ở đầu app → 0 bản ghi pending quá 5 phút
- [ ] Thử tạo 1 thanh toán NCC → kiểm tra Firestore console có bản ghi không
- [ ] Thử offline → online: dữ liệu sync lại đúng

### Giám sát sau release
- [ ] Theo dõi Firebase Crashlytics 24 giờ đầu
- [ ] Kiểm tra Firestore console: `supplier_payments`, `repair_partner_payments` có đủ bản ghi không
- [ ] Kiểm tra `sync_queue` SQLite local không có item stuck ở trạng thái `failed`

### Tài liệu bàn giao tối thiểu
- [ ] CHANGELOG.md cập nhật
- [ ] HANDOVER.md cập nhật (file này)
- [ ] Rủi ro còn lại được ghi rõ (bảng P2-P4 ở trên)

---

## 🎯 Phase hiện tại

**Phase đang thực hiện:** Stabilization (sửa lỗi kiến trúc, không thêm tính năng mới)  
**Tài liệu đã khởi tạo:** Toàn bộ `docs/` structure  
**Tiến độ:** P1 sync bugs → đã fix | P2-P4 → backlog có kiểm soát

---

## ✅ Vừa hoàn thành (2026-06-05) — Kiểm toán kiến trúc sync + Fix P1 payment services

1. **Chặn re-init real-time sync trùng lặp**
  - `sync_service.dart`: thêm signature cho session realtime sync theo `uid + shopId + role + permissions`.
  - Nếu sync đã active và cùng session gọi lại, app bỏ qua lần init trùng thay vì hủy toàn bộ subscription rồi dựng lại.
  - Mục tiêu: giảm nguy cơ loop runtime kiểu `Init → Fetch → Destroy → Init lại` quan sát từ log iPhone.
  - Validation: `flutter analyze lib/services/sync_service.dart` không phát sinh lỗi compile; còn 3 info/lint pre-existing.

1. **Kiểm toán kiến trúc đồng bộ dữ liệu toàn hệ thống (điều tra tĩnh)**
   - Phân tích đầy đủ: SyncOrchestrator, SyncService listeners, `_shouldAcceptCloudData`, `downloadAllFromCloud`, tất cả `syncAll()` call sites, payment services, inventory, sales, customer, supplier, debt.
   - Kết quả: 10-point risk report với bằng chứng source code cụ thể theo từng dòng.
   - Xếp hạng P1→P4 và ghi vào mục "RỦI RO ĐỒNG BỘ CÒN LẠI" ở trên.

2. **P1-FIX: `supplier_payment_service.dart`**
   - Nguyên nhân: `isSynced=1` đặt TRƯỚC khi `_firestore.set()` → nếu cloud fail thì local tin là đã sync nhưng Firestore không có bản ghi.
   - Sửa: đặt `isSynced=0` → ghi Firestore → chỉ đặt `isSynced=1` sau khi Firestore xác nhận thành công.

3. **P1-FIX: `repair_partner_payment_service.dart`** — cùng pattern và cùng sửa.

4. **Validation:** `flutter analyze` 2 file → No issues. Toàn repo → 0 error cứng.

---

## ✅ Vừa hoàn thành (2026-06-04) — Tính năng Chuyển đơn sửa chữa sang shop mới

1. **`MigrationService`** (`lib/services/migration_service.dart`) — copy repairs theo batch 400, paginate, hỗ trợ cancel
2. **`ShopMigrationView`** (`lib/views/shop_migration_view.dart`) — UI 3 phase: setup → running (progress) → done
3. **Entry point** trong `BackupRestoreView` Firestore tab — chỉ hiện với owner/super_admin
4. **Copy mode**: tạo doc mới với shopId mới, shop cũ giữ nguyên

---

## ✅ Vừa hoàn thành (2026-06-04) — Fix ghost topbar trên toàn app

1. **Xóa nested Navigator khỏi `_buildTabHost`** — `home_view.dart`
   - `_buildTabHost` không còn bọc tabs trong `Navigator` widget; `_usesNestedNavigator` luôn `false`
   - `_openMyStaffProfile`, `_openShopSettingsFromGreeting`, `_openDashboardSettings` dùng `rootNavigator: true`
   - Tất cả route push từ bất kỳ tab nào sẽ che toàn màn hình, không còn ghost white topbar

---

## ✅ Vừa hoàn thành (2026-06-04) — Fix logic NCC + PT thanh toán phiếu nhập

1. **Fix `_requireSupplier ?? true` → `?? false`** — tránh bắt buộc NCC khi settings chưa load
2. **Fix `_supplierEffectivelyRequired`** — bỏ điều kiện `cost > 0`; chỉ bắt buộc khi setting ON hoặc CÔNG NỢ
3. **Thêm `_paymentMethodRequired` getter** — PT thanh toán chỉ bắt buộc khi `!allowPendingCost` hoặc `cost > 0` hoặc `NCC đã chọn`

---

## ✅ Vừa hoàn thành (2026-06-04) — Popup chọn mã nhập nhanh có search + pagination

1. **Tạo `showQuickCodePickerSheet` — widget tái sử dụng cho phiếu nhập**
   - `lib/widgets/quick_code_picker_sheet.dart`: `DraggableScrollableSheet`, search debounce 350ms, infinite scroll 20 item/trang
   - Dùng `getQuickInputCodesPaged()` + `countQuickInputCodes()` với `activeOnly: true`
   - `fast_stock_in_view._selectFromLibrary()` và `smart_stock_in_view._selectFromLibrary()` → 3 dòng

---

## ✅ Vừa hoàn thành (2026-06-04) — Fix CHỈNH SỬA PHIẾU NHẬP

1. **Fix NCC bị reset + scroll UX trong edit phiếu nhập**
   - `_loadEditData()`: Giữ `_selectedSupplier` từ entry, thêm NCC cũ vào `_suppliers` tạm nếu cần
   - Warning "Thiếu" bấm được → `Scrollable.ensureVisible(_accountingKey)` scroll đến card kế toán
   - Thêm `ScrollController _scrollCtrl` + `GlobalKey _accountingKey`

---

## ✅ Vừa hoàn thành (2026-06-04) — Chat nội bộ audit

1. **Audit & fix chat nội bộ: 7 vấn đề security/stability/UX**
   - `chat_service.dart`: thêm `_kMaxMessageLength=2000` validate đầu vào; xóa comment sai trong `markAllAsRead()`.
   - `ai_chat_service.dart`: giảm cloud AI timeout 20s→10s; tăng cường `_sanitize()` strip `{} $` + role-override pattern.
   - `advanced_chat_view.dart`: `didChangeAppLifecycleState(paused)` thêm `setTypingStatus(false)`; reaction tap await + snackbar khi fail.
   - `missing_info_products_view.dart` + `db_helper.dart`: fix count Tab "Đã bán" — thêm `soldOnly` param, bỏ client-side filter.

---

## ✅ Vừa hoàn thành (2026-06-05)

1. **Fix sync bug nghiêm trọng: expense/debt không lên Firestore khi nhập giá vốn (2026-06-05)**
   - `missing_info_products_view._editCost()` + `inventory_view._showInlineCostEdit()`:
     - Thêm `enqueueDebt()` cho CÔNG NỢ path — trước đó `isSynced=0` nhưng không bao giờ enqueue.
     - Thêm `enqueueExpense()` cho TIỀN MẶT/CK path — cùng vấn đề.
     - Thêm `createdAt` vào expense record cho nhất quán với schema.
   - `inventory_view._showInlineCostEdit()`:
     - Sửa `costCtrl` memory leak: `dispose()` ngay sau sheet đóng.
     - Chuyển validation giá vốn > 0 vào modal button (trước `Navigator.pop`).
     - Đổi "Bỏ qua" → "Hủy".
   - Commit: `29ffae55` (master).

## ✅ Vừa hoàn thành (2026-06-04)

1. **Audit & sửa toàn diện màn Thiếu vốn / NCC (2026-06-04)**
  - `lib/views/missing_info_products_view.dart` + `lib/data/db_helper.dart`:
    - Sửa memory leak: `costCtrl.dispose()` sau mỗi lần đóng popup.
    - Thêm `mounted` guard sau `await getCurrentShopId()`.
    - Fix count Tab "Đã bán": thêm `soldOnly` param vào `getProductsCount`, filter đúng `quantity ≤ 0`.
    - Đổi popup Nhập giá vốn sang light theme (`Colors.grey.shade50`) — nhất quán với fields trắng.
    - Thêm `StreamSubscription _productEventSub` lắng nghe EventBus (`financial_changed`, `products_changed`) → màn tự refresh khi nhập vốn từ màn khác.
    - `_buildCard` skip card rỗng (không badge, không action) khi cả 2 feature `allowPendingCost` và `enableSupplier` đều tắt.
  - Validation: analyze = 0 error, build thành công.

1. **Sửa độ rõ AppBar + popup Nhập giá vốn ở màn Thiếu vốn / NCC (2026-06-04)**
  - `missing_info_products_view.dart`:
    - Tăng độ rõ phần chữ AppBar bằng `titleWidget` riêng (font đậm hơn, dễ đọc hơn trên nền gradient).
    - Chuẩn hóa màu chữ TabBar (`Còn hàng`, `Đã bán`) để trạng thái chọn/không chọn rõ ràng.
    - Sửa popup `Nhập giá vốn`: đổi màu chữ/label/icon của dropdown và chọn NCC sang tông tối trên nền trắng để không còn hiện tượng chữ trùng nền.
  - Validation:
    - `flutter analyze lib/views/missing_info_products_view.dart`: không có issue.
    - `flutter build apk --debug`: thành công.

1. **Chuẩn hóa nhập liệu: "iPhone" là thương hiệu, không phải tên (2026-06-04)**
  - `quick_input_codes_view.dart`:
    - Khi lưu mã nhập nhanh loại điện thoại, tự suy luận và chuẩn hóa brand từ chuỗi tên (ví dụ `IPHONE ...`).
    - Nếu model trống, tự tách phần sau brand vào model.
  - `smart_stock_in_view.dart` + `fast_stock_in_view.dart`:
    - Fallback suy luận brand từ dữ liệu cũ (`name + model`) khi field brand chưa có.
  - Kết quả:
    - Nhập `IPHONE` sẽ đi đúng vào trường thương hiệu trong các luồng mã nhập nhanh và nhập kho.
  - Validation:
    - `flutter analyze` các file liên quan: không có compile error mới.
    - `flutter build apk --debug`: thành công.

1. **Fix toggle "Cho phép nhập giá vốn sau" báo bật nhưng UI không đổi (2026-06-04)**
  - `home_view.dart`:
    - Thêm guard `_isSavingPendingCost` để chặn double-tap khi đang lưu.
    - Giữ `_pendingCostOverride` qua vòng save/reload để tránh bị dữ liệu stale ghi đè ngược về OFF.
    - Merge settings từ `_loadShopSettings()` theo override pending và chỉ clear override khi backend đã phản ánh đúng.
  - `db_helper.dart` + `category_service.dart`:
    - Xác nhận nguyên nhân gốc trên DB cũ: thiếu cột `shop_settings.allowPendingCost`.
    - Thêm migration phòng thủ để tự thêm cột khi mở DB và trước khi CategoryService đọc/ghi settings local.
    - `saveShopSettings` chỉ trả thành công khi local DB ghi thành công.
  - `settings_view.dart` + `home_view.dart`:
    - Không còn báo thành công giả: bắt buộc check kết quả save + read-back xác nhận giá trị.
    - Nếu chưa có shop hiện tại hoặc bị chặn quyền/App Check, hiển thị lỗi rõ ràng và rollback UI.
  - Kết quả:
    - Công tắc đổi trạng thái ổn định theo thao tác người dùng, không còn hiện tượng chỉ báo snackbar mà switch không đổi.
  - Validation:
    - `flutter analyze lib/views/home_view.dart`: không có compile error mới (còn info/lint pre-existing).
    - `flutter build apk --debug`: thành công.

1. **Fix vòng lặp sync `permission_denied:storage_locations -> refresh scope -> permission_denied` (2026-06-03)**
  - `sync_service.dart`:
    - Sửa baseline chữ ký quyền người dùng: không còn set từ permissions đã chuẩn hóa ở đầu `initRealTimeSync`; lấy snapshot đầu tiên từ `users/{uid}` làm baseline để tránh false-positive "permissions changed".
    - Bổ sung cooldown `20s` cho reinit theo access-change để chặn vòng lặp reinit dồn dập.
    - Gắn `storage_locations` vào gate quyền kho (`allowViewInventory`) để không subscribe/poll collection trái quyền.
  - Kết quả:
    - Chặn chuỗi lặp gây tiêu hao quota App Check khi user không có quyền đọc `storage_locations`.
    - Không thay đổi hành vi của các collection hợp lệ đang có quyền.
  - Validation:
    - `flutter analyze lib/services/sync_service.dart`: không có compile error mới (còn info/lint pre-existing).
    - `flutter build apk --debug`: thành công.

1. **AI hiểu ngôn ngữ người dùng: mở rộng cụm kho/tồn kho tự nhiên (2026-06-03)**
  - `ai_command_router.dart`:
    - Thêm các cụm người dùng hay nói như `kho linh kiện`, `kho phụ kiện`, `tồn kho hiện tại`, `hàng tồn hiện tại`, `còn bao nhiêu trong kho` vào stock check.
  - `natural_order_parser_service.dart`:
    - Parser đơn tự nhiên cũng nhận thêm các biến thể tồn kho này để route đúng intent ngay từ lớp ngôn ngữ.
  - Validation:
    - `flutter analyze lib/services/ai_command_router.dart lib/services/natural_order_parser_service.dart`: sạch.
    - `flutter build apk --debug`: thành công.

1. **Permission-gated sync: tự reinit khi quyền/shop-lock thay đổi (2026-06-03)**
  - `sync_service.dart`:
    - Thêm chữ ký quyền người dùng và chữ ký khóa cấp shop để phát hiện scope truy cập đổi trong lúc app đang mở.
    - Khi `users/{uid}` hoặc `shops/{shopId}` đổi các field ảnh hưởng quyền, sync sẽ tự khởi tạo lại để chỉ tải collection được phép.
    - Giữ nguyên lọc collection hiện có ở startup/download, nên collection không được phép vẫn không bị subscribe/download.
  - Validation:
    - `flutter analyze lib/services/sync_service.dart`: không phát sinh lỗi compile mới.

---

## ✅ Vừa hoàn thành (2026-05-29)

1. **AI kho hàng: tách đúng mặt hàng / sản phẩm tồn + chặn lặp phản hồi (2026-06-03)**
  - `db_helper.dart`:
    - Thêm `getInventoryBreakdownSummary()` để trả về breakdown theo loại hàng với 3 chỉ số: `mặt hàng`, `sản phẩm tồn`, `giá vốn`.
  - `ai_chat_service.dart`:
    - Đổi các câu trả lời kho sang format đúng nghĩa nghiệp vụ.
    - Tách riêng `Kho điện thoại`, `Kho phụ kiện`, `Kho linh kiện`, `Tồn kho hiện tại`.
  - `functions/index.js`:
    - Siết prompt Cloud AI để không lặp lại section và phân biệt rõ `mặt hàng` với `sản phẩm tồn`.
    - Thêm lọc khử trùng lặp paragraph ở output trước khi trả về app.
  - Validation:
    - `flutter analyze lib/data/db_helper.dart lib/services/ai_chat_service.dart`: không có lỗi compile.
    - `flutter build apk --debug`: thành công.

1. **Fix 3 vấn đề vận hành thực tế: đơn sửa, backup, reset dữ liệu (2026-05-29)**
  - `repair_detail_view.dart`:
    - Chặn ghi chi phí lặp khi sửa giá vốn nhiều lần trên cùng đơn.
    - Khi đã ghi sổ quỹ trước đó, lần sửa sau chỉ ghi phần chênh lệch (`delta`) thay vì ghi lại full giá vốn.
  - `backup_restore_view.dart` + `backup_service.dart`:
    - Thêm nút **xóa từng file backup SQLite cục bộ**.
    - Mở rộng mapping xóa dữ liệu SQLite cho nhóm **Kho/Tài chính** để xóa sâu hơn các bảng liên quan.
    - Thêm tùy chọn **xóa luôn dữ liệu Cloud theo nhóm** để tránh dữ liệu sync ngược sau khi đã xóa local.
  - Validation:
    - `flutter analyze` 3 file thay đổi: không có compile error mới.
    - `flutter build apk --debug`: thành công.

1. **Backup: Xóa dữ liệu chọn lọc + Dọn backup cũ (2026-05-29)**
  - `BackupService.deleteSelectedData()`: xóa table SQLite theo danh sách collection, trả về số bản ghi xóa
  - `BackupService.cleanOldLocalBackups(keepDays)`: dọn file backup cục bộ cũ hơn N ngày
  - Tab SQLite tab: section "Xóa dữ liệu chọn lọc" (preset kho phụ kiện, linh kiện, tùy chọn tự do) + section "Dọn backup cũ" (30/60/90/180 ngày)
  - Files: `backup_service.dart`, `backup_restore_view.dart`

2. **AI Assistant — 8 UX Improvements (2026-05-29)**
  - #3 Auto-fill đơn từ chat: "tạo đơn sửa iPhone 15 cho Minh" → mở `AiOrderInputSheet` với text pre-filled
  - #5 Context chips xanh sau mỗi answer (followUpChips per intent)
  - #4 Daily briefing lần mở đầu trong ngày: hiển thị pending repairs, nợ phải thu/trả
  - #6 Lưu/khôi phục lịch sử chat (SharedPreferences, max 20 messages)
  - #2 followUpChips trên 12+ intent khác nhau
  - #8 Mở rộng voice command vocabulary (+40 keywords)
  - #7 Dashboard tab "Phản hồi xấu": xem từng query bị dislike
  - Files: `ai_chat_service.dart`, `ai_chat_overlay.dart`, `ai_command_router.dart`, `ai_usage_logger.dart`, `ai_usage_dashboard_view.dart`

2. **Sprint 4B: Flutter Analyze Warning Cleanup (2026-05-29)**
  - Xóa 130+ unused elements, fields, imports, dead code qua ~20 file.
  - Kết quả: 132 warnings → 1 (giữ `_eventBusSub2` StreamSubscription intentionally).
  - Files chính: `home_view`, `inventory_view`, `sale_detail_view`, `sale_list_view`, `repair_detail_view`, `settings_view`, `staff_list_view`, `work_schedule_settings_view`, `unified_sync_button`.

2. **Phân quyền Chat & Cloud AI (2026-05-29)**
  - Thêm 4 quyền mới: `allowSendChat`, `allowPinChat`, `allowDeleteOtherChat`, `allowCloudAI` vào `UserService`.
  - `advanced_chat_view`: load quyền và áp dụng rate-limit 30 tin/phút.
  - `ai_chat_overlay`: kiểm tra `allowCloudAI` trước khi gọi Cloud AI.

2. **AI Usage Logger + Dashboard (2026-05-29)**
  - Tạo `lib/services/ai_usage_logger.dart`: ghi log mọi AI interaction lên Firestore.
  - Tạo `lib/views/ai_usage_dashboard_view.dart`: màn hình thống kê cho Owner.

3. **Prompt Injection Guard (2026-05-29)**
  - `ai_chat_service.dart`: thêm `_sanitize()` làm sạch question/history trước khi gửi LLM.

4. **Fix compile error `_pinVerified` (2026-05-29)**
  - `shop_selector_view.dart`: xóa tham chiếu biến không tồn tại.

5. **Việt hóa UI Super Admin Console (2026-05-29)**
  - Đổi nhãn tiếng Anh còn sót sang tiếng Việt.

6. **Dọn dead code Sync (2026-05-29)**
  - Xóa `_scheduleResubscribe()` không dùng trong `sync_service.dart`.

---

## ✅ Vừa hoàn thành (2026-05-25)

1. **Fix lỗi sao lưu/khôi phục Cloud + thêm xóa backup DB (2026-05-26)**
  - Thêm khả năng xóa từng bản backup SQLite trên Cloud trực tiếp trong màn hình Sao lưu/Khôi phục.
  - Cải thiện thông báo lỗi cloud thân thiện theo mã lỗi Firebase Storage phổ biến.
  - Vá `storage.rules` cho đường dẫn `db_backups/{shopId}/{allPaths=**}` để backup/restore/xóa cloud hoạt động đúng theo tenant.
  - Đã deploy Storage Rules mới thành công lên Firebase project `huyaka-1809`.

2. **Validation đợt cloud backup fix (2026-05-26)**
  - `flutter analyze` cho `backup_service.dart` và `backup_restore_view.dart`: không phát sinh compile error mới.
  - `firebase deploy --only storage`: thành công.

1. **Hardening restore cross-shop đầy đủ domain (2026-05-26)**
  - Mở rộng selective restore cho các miền dữ liệu còn thiếu khi khôi phục toàn bộ: đơn sửa, kho linh kiện, kho máy xác, kho vị trí, yêu cầu đóng tiền, đối tác sửa chữa, lịch sử đối tác, nhập kho.
  - Khi restore sang shop mới (remap shopId), dữ liệu local được reset trạng thái sync (`isSynced=0`) và bỏ `firestoreId` để đồng bộ lại đúng shop đích.

2. **Cập nhật báo cáo đồng bộ theo domain (2026-05-26)**
  - Mở rộng phạm vi Sync Health và Domain Sync Report cho `salvage_phones`, `storage_locations`, `payment_requests`, `payment_intents`, `repair_partners`, `partner_repair_history`.
  - Mục tiêu: giảm tình trạng báo lệch/mất coverage sau khi restore shop mới.

3. **Khóa loại hình kinh doanh chỉ còn điện tử (2026-05-26)**
  - `register_view`: chỉ còn lựa chọn điện tử.
  - `business_type_wizard`: chỉ cho chọn điện tử; `availableTypes` còn `electronics`.
  - `shop_switcher_widget` (tạo chi nhánh): bỏ dropdown ngành, cố định điện tử.

4. **Validation của đợt cập nhật mới**
  - Đã lên kế hoạch chạy `flutter analyze` cho các file thay đổi và `flutter build apk --debug` ngay sau patch.

1. **Follow-up fix UI Sao lưu/Khôi phục (2026-05-26)**
  - Fix tương phản chữ/tab với AppBar trong `backup_restore_view` để tránh trùng màu.
  - Bổ sung danh sách backup SQLite cục bộ để người dùng nhìn thấy file đã lưu.
  - Bổ sung thao tác chia sẻ/khôi phục trực tiếp từ danh sách backup cục bộ.
  - Làm rõ flow lưu file .db -> xem danh sách -> chia sẻ/khôi phục.
  - Đổi thư mục backup cục bộ sang `quanlyshop/sqlite_backups` để dễ nhận diện trên máy.
  - Thêm preset trong luồng xóa chọn lọc để giữ lại dữ liệu cốt lõi: sửa chữa, khách hàng, chấm công, cài đặt lương, lịch làm việc.
  - Thêm lựa chọn khi restore SQLite: giữ nguyên shop gốc hoặc chuyển dữ liệu vào shop hiện tại bằng remap `shopId`.
  - Thêm restore SQLite chọn lọc từng mục dữ liệu cho cả file cục bộ và backup cloud.

2. **Fix runtime lỗi Kho sau restore**
  - Bổ sung đảm bảo `products.shopId` tồn tại sau restore DB cũ để chặn lỗi:
    - `DatabaseException(no such column: shopId ...)`
  - Thêm check phòng thủ trong `DBHelper.onOpen` cho cột `shopId` của bảng `products`.

3. **Cải tiến UI chi tiết đơn bán**
  - Redesign item sản phẩm sang phong cách sáng, gọn, sạch, chuyên nghiệp khi đơn có nhiều sản phẩm.

2. **Validation follow-up**
  - `flutter analyze` cho `backup_service.dart` và `backup_restore_view.dart`: không có compile error mới.
  - `flutter build apk --debug`: thành công.

---

## ✅ Vừa hoàn thành (2026-05-25)

1. **Hoàn thiện backup/restore offline + online (2026-05-26)**
  - Đã bật khôi phục SQLite từ Cloud (Firebase Storage) theo từng bản backup `.db`.
  - Firestore giữ cơ chế khôi phục chọn lọc theo từng mục (collection) và bổ sung hướng dẫn rõ hơn trong UI.
  - Luồng xác nhận khôi phục và thông báo sau khôi phục SQLite đã đầy đủ.

2. **Thiết kế lại thao tác trang Cài đặt bằng nút `...` trên AppBar (2026-05-26)**
  - Thêm menu nhanh đi tới:
    - Sao lưu & Khôi phục
    - Hướng dẫn sử dụng
    - Trung tâm trợ giúp
  - Giảm thao tác cuộn sâu và gom các action quan trọng lên đầu.

3. **Cập nhật hướng dẫn sử dụng backup/restore (2026-05-26)**
  - Cập nhật user guide mô tả rõ 2 chế độ:
    - Offline: SQLite file `.db`
    - Online: Firestore backup/restore theo từng mục

4. **Validation kỹ thuật cho đợt này**
  - `flutter analyze` (4 file thay đổi chính): không có compile error mới do task.
  - `flutter build apk --debug`: thành công.

---

## ✅ Vừa hoàn thành (2026-05-25)

1. **Triển khai Hardening P0 cho AI cloud functions (2026-05-25)**
  - `functions/index.js`:
    - Áp dụng phân loại intent cho `chatAssistant` và chỉ gửi context tối thiểu theo intent.
    - Mask PII trong question/history trước khi gửi lên model.
    - Giảm lịch sử hội thoại gửi AI từ 10 xuống 6 turns.
    - Bỏ hoàn toàn log thô prompt/answer; thay bằng telemetry an toàn (requestId, len, latency, intent).
    - Bỏ log text/raw result ở `createRepairOrderAI` và `parseOrderAI`.
  - Mục tiêu đạt được: giảm rủi ro lộ dữ liệu qua context/log và giảm token không cần thiết.

2. **Validation kỹ thuật cho hardening P0 (2026-05-25)**
  - `node --check functions/index.js`: pass.
  - `flutter analyze`: chạy xong, còn `1525` warning/info legacy toàn repo.
  - `flutter build apk --debug`: thành công.

---

## ✅ Vừa hoàn thành (2026-05-25)

1. **Hoàn tất Industry Vocabulary Engine (2026-05-25)**
  - Tạo đủ 5 output theo yêu cầu tại `DOCS/vocabulary/`:
    - `vocabulary.json`
    - `alias_mapping.json`
    - `typo_mapping.json`
    - `phonetic_mapping.json`
    - `intent_mapping.json`
  - Chuẩn hóa theo pipeline normalize -> typo -> alias -> intent.
  - Bổ sung coverage cho thiết bị, lỗi sửa chữa, kho, tài chính, và intent điều hướng.

2. **Audit rủi ro đọc dữ liệu và rủi ro token AI (2026-05-25)**
  - Tạo `DOCS/AI_SECURITY_RISK_AUDIT.md`.
  - Kết luận chính:
    - API key DeepSeek đang an toàn ở server-side secret.
    - Rủi ro còn lại chủ yếu nằm ở data minimization/context over-sharing và logging prompt/answer.
  - Đưa ra kế hoạch hardening theo P0/P1/P2.

3. **Validation kỹ thuật cho đợt cập nhật tài liệu (2026-05-25)**
  - `flutter analyze`: chạy xong, còn warning/info legacy (không có compile error mới do task này).
  - `flutter build apk --debug`: thành công.
  - JSON syntax check cho 5 file vocabulary: OK.

---

## ✅ Vừa hoàn thành (2026-05-22)

1. **Nhập nhanh đơn sửa/đơn bán bằng câu lệnh tự nhiên (2026-05-23)**
  - Thêm parser `natural_order_parser_service.dart` để nhận diện câu lệnh tạo đơn sửa và đơn bán.
  - `create_repair_order_view`: thêm nút nhập nhanh trên AppBar, parse và tự điền model/lỗi/khách/SĐT/giá; mặc định `0đ` khi thiếu giá.
  - `create_sale_view`: thêm nút nhập nhanh trên AppBar, parse sản phẩm/IMEI/khách/SĐT/phương thức thanh toán; tự map trả góp FE.
  - Luồng lưu đơn, sync, transaction kho/công nợ/thanh toán vẫn dùng nguyên pipeline hiện tại (không ghi tắt bypass service).

2. **Validation kỹ thuật cho thay đổi mới**
  - Đã chạy `flutter analyze` cho 3 file thay đổi chính.
  - Không có lỗi compile mới; còn warning/info legacy ở các file màn hình lớn.

3. **Hotfix trắng màn hình đơn sửa mới (2026-05-23)**
  - Thêm cơ chế fallback render trong `create_repair_order_view.dart`.
  - Nếu build UI chính phát sinh exception, màn hình tự chuyển sang form dự phòng để vẫn thao tác tạo đơn.
  - Có log debug chi tiết để truy dấu nguyên nhân runtime thay vì hiển thị màn hình trống.
  - Root-cause fix: ràng buộc width hữu hạn cho nút `Lưu & In` ở bottom action bar để loại bỏ lỗi `BoxConstraints forces an infinite width`.

---

## ✅ Vừa hoàn thành (2026-05-22)

1. **Audit toàn diện UX/UI ứng dụng ở cấp sản phẩm thương mại**
  - Tạo đầy đủ thư mục `DOCS/UX_AUDIT/` với `7` tài liệu: score report, problem list, improvement plan, design-system debt, workflow optimization, loading/async UX, modernization roadmap.
  - Audit dựa trên đọc trực tiếp các màn hình trọng yếu như `home_view`, `create_repair_order_view`, `repair_detail_view`, `inventory_view`, `debt_view`, `finance_v2_view`, nhóm settings và widgets sync/loading.
  - Bổ sung số đo repo-level để lượng hóa UX debt: AppBar trực tiếp, spinner trực tiếp, dialog, bottom sheet.

2. **Cập nhật chỉ mục tài liệu**
  - `docs/DOCUMENTATION_INDEX.md` bổ sung nhóm tài liệu `DOCS/UX_AUDIT`.

---

## ✅ Vừa hoàn thành (2026-05-22)

1. **Tạo hệ thống tài liệu BLUEPRINT toàn app (DNA Rebuild)**
  - Tạo đầy đủ thư mục `DOCS/BLUEPRINT/` với các tài liệu lõi kiến trúc/nghiệp vụ/design/service/offline/rebuild.
  - Sinh `112` tài liệu màn hình trong `DOCS/BLUEPRINT/screens/` (bao phủ toàn bộ `lib/views`).
  - Tạo graph: dependency graph, screen relationship graph, service relationship graph.
  - Tạo `README_FINAL.md` tổng kết độ hoàn thiện, rủi ro, khả năng rebuild.
  - Tạo `TODO_GAPS.md` để theo dõi các điểm cần xác minh runtime/thực địa.

2. **Cập nhật chỉ mục tài liệu**
  - `docs/DOCUMENTATION_INDEX.md` bổ sung nhóm tài liệu BLUEPRINT.

---

## ✅ Vừa hoàn thành (2026-05-21)

1. **Tối ưu DB reads Excel export** — commit `c86c152e`
   - `loadSnapshot()`: 17 queries song song (parallel futures)
   - `_exportDetailedReport`: 14 → 9 reads (−36%)
   - `_exportReport`: 31 → 28 reads + parallel pre-fetch
   - N+1 fix trong `exportImportOrders`: 51 → 2 reads (với 50 đơn)

2. **Khởi tạo toàn bộ cấu trúc docs/ cho dự án Flavor Split**
   - `PROJECT_OVERVIEW.md`, `ROADMAP_ONLINE_OFFLINE.md`, `PROGRESS_TRACKER.md`
   - `DECISIONS.md` (ADR-001 đến ADR-005)
   - `RISKS_AND_ISSUES.md`, `TEST_RESULTS.md`
   - `docs/phases/PHASE_01` đến `PHASE_08`

3. **Enrich activity feed** — commit `2200ad95`
   - Bán hàng hiện tên sản phẩm + người bán
   - Thu/trả nợ hiện tên khách/NCC
   - Trả NCC hiện tên thực thay vì raw ID

4. **Fix Finance V2 3-checkpoint reconciliation** — commit `e6584072`
   - REPAIR_PARTNER type nhất quán ở 3 điểm kiểm tra
   - Thu khác không còn bị thổi phồng bởi thu nợ KH

---

## 🔴 Lỗi còn tồn tại

| Lỗi | File | Mức độ |
|-----|------|--------|
| `withOpacity` deprecated (pre-existing) | Nhiều file UI | Thấp |
| Kho location chưa test đầy đủ offline | salvage_phone_view | Trung bình |

---

## 📋 Ưu tiên tiếp theo

1. **Chuyển audit UX/UI thành execution spec**
  - Chốt AppBar strategy, loading states, sync feedback language, card taxonomy, settings IA.

2. **Ưu tiên redesign kiến trúc trải nghiệm**
  - `home_view.dart`
  - `debt_view.dart`
  - `inventory_view.dart`
  - `shop_settings_view.dart`

3. **Nếu quay lại roadmap flavor split**
  - Bắt đầu Phase 01 — Flavors Setup
  - Tạo `FlavorConfig`, `AppFlavor`
  - Cấu hình `android/app/build.gradle`
  - Tạo `main_online.dart` + `main_offline.dart`

---

## 🔧 Lệnh build/test quan trọng

```bash
# Analyze
flutter analyze

# Run (current — single flavor)
flutter run

# Build release (current)
flutter build apk --release

# Sau khi hoàn thành Phase 01:
flutter run --flavor online -t lib/main_online.dart
flutter run --flavor offline -t lib/main_offline.dart
flutter build apk --flavor online -t lib/main_online.dart --release
flutter build apk --flavor offline -t lib/main_offline.dart --release
```

---

## 📁 Tài liệu quan trọng

| File | Đọc khi nào |
|------|------------|
| `docs/ROADMAP_ONLINE_OFFLINE.md` | Hiểu lộ trình |
| `docs/PROGRESS_TRACKER.md` | Xem tiến độ hiện tại |
| `docs/ARCHITECTURE.md` | Hiểu kiến trúc mục tiêu |
| `docs/DECISIONS.md` | Hiểu lý do quyết định |
| `docs/phases/PHASE_01_FLAVORS.md` | Bắt đầu từ Phase 01 |
| `CLAUDE.md` | Rules và conventions |

---

## 📝 Ghi chú cho AI / lập trình viên tiếp theo

1. **Không sửa FirestoreService trực tiếp** trong Phase 02 — chỉ thêm interface wrapper
2. **Không xóa Firebase code** — guard bằng `FlavorConfig.isOnline`
3. **Online flavor phải không regression** — test toàn bộ trước mỗi phase
4. **SQLite schema không thay đổi** — cả 2 flavor dùng chung `DBHelper`
5. **Mỗi phase hoàn thành** → cập nhật `PROGRESS_TRACKER.md` + `CHANGELOG.md` + file phase tương ứng

---

## 📦 Recent commits

```
c86c152e perf(excel): reduce DB reads on Excel export — eliminate duplicates & N+1
2200ad95 feat(home): enrich "Hoạt động hôm nay" activity feed with contextual details
e6584072 fix(finance): sync REPAIR_PARTNER type across all 3 debt-balance checkpoints
```


---

## Completed Tasks (Recent)

- [x] **Fix Công Nợ Đối Tác Bị Mất Sau Refresh (2026-05-20)**
  - `debt_summary_service.dart`: Phát hiện orphan partner (deleted/inactive) vẫn có nợ còn lại; thêm `missingPartner: true` flag; log debugPrint
  - `db_helper.dart`: Thêm `getAllRepairPartnersRaw()` — trả toàn bộ hàng kể cả deleted
  - `debt_view.dart`: Card hiển thị icon cảnh báo đỏ nếu `missingPartner`; navigation dùng `partnerId` đúng + fallback tìm theo tên; snackbar giải thích rõ

- [x] **Tab Linh Kiện: Nút + AppBar, Auto-Open Từ Đơn Sửa, Fix Dialog iOS (2026-05-20)**
  - `parts_inventory_view.dart`: Xóa FAB "Thêm linh kiện"; thêm `ValueNotifier<int> addTrigger` param cho `PartsInventoryViewContent`
  - `inventory_view.dart`: AppBar tự đổi sang nút `+` khi tab LINH_KIEN; truyền `_partsAddTrigger` xuống; thêm `triggerPartsAdd` param
  - `repair_detail_view.dart`: `_navigateToPartsInventory` truyền `triggerPartsAdd: true` → dialog thêm LK tự mở
  - Fix iOS: `_showEditPartDialog` + `_showAddPartDialog` bọc content bằng `SizedBox(width: double.maxFinite)`

- [x] **Fix Popup Trắng iOS — Vị Trí Kho & Sửa Sản Phẩm (2026-05-20)**
  - `storage_location_view.dart`: `_LocationFormDialog` width 340→`double.maxFinite`; `_confirmDelete` dùng builder ctx thay vì outer context
  - `widgets/storage_location_selector.dart`: `showModalBottomSheet` thêm `useRootNavigator: true` — fix cả inventory's `_editProduct` vẫn trắng do nested modal

- [x] **Fix Sai Lệch Số Liệu Nhật Ký Tài Chính (2026-05-20)**
  - `finance_v2_view.dart`: Round giá vốn về 1000đ; load đối tác SC vào nhật ký; fix type 'OWE' cho CN NCC đầu kỳ
  - `finance_v2_reconciliation.dart`: EXPENSE cost dùng `lineCostTotal` thay `cashOut+transferOut`

- [x] **Fix Popup Trắng Khi Sửa Sản Phẩm Trong Kho (2026-05-20)**
  - `inventory_view.dart` (`_editProduct`): Bọc `SingleChildScrollView` bằng `SizedBox(width: double.maxFinite)` — fix layout constraint khiến content không hiển thị trong release mode

- [x] **Ảnh Sản Phẩm & Vị Trí Kho Trong Nhập Hàng; Location Repair; Badge Lỗi (2026-05-19)**
  - `smart_stock_in_view.dart` + `fast_stock_in_view.dart`: Thêm `ImagePickerWidget` (chụp/chọn ảnh sản phẩm khi nhập kho)
  - `stock_entry_service.dart`: Sau confirmEntry thành công → upload ảnh background qua `ProductImageService.uploadProductImage()`
  - `create_repair_order_view.dart`: Thêm `StorageLocationSelector` để ghi nhận vị trí cất máy lúc tiếp nhận
  - `repair_detail_view.dart`: Card vị trí cất máy editable, thay đổi ghi audit log before/after
  - `parts_inventory_view.dart`: Audit log `PART_INFO_UPDATE` bổ sung `oldLocationCode` / `newLocationCode`
  - `order_list_view.dart`: Badge lỗi thiết bị font 14→11, ellipsis tránh chiếm quá nhiều diện tích

- [x] **UI Fixes: Lỗi Thiết Bị, Vị Trí Lưu Kho, AppBar Inventory (2026-05-19)**
  - `repair_detail_view.dart`: Issue badge xuống body (Card đỏ), AppBar sạch
  - `home_view.dart`: Shortcut "Vị trí lưu kho" trong tab Kho
  - `storage_location_view.dart`: Fix list rỗng (virtual locations từ products), stats case-insensitive, FAB tròn
  - `inventory_view.dart`: Gộp 3 icon ít dùng vào PopupMenu "⋮" → tránh nút + đè nút back

- [x] **Fix Offline: Dừng Loading Vô Hạn Khi Mất Mạng (2026-05-19)**
  - `stock_entry_service.dart`: timeout + cache fallback cho confirmEntry/cancelEntry
  - Spinner dừng, hiển thị thông báo tiếng Việt khi offline

- [x] **Refactor NCC & Đối Tác Sửa Chữa — Light Premium CRM (2026-05-19)**
  - Xóa popup `...` khỏi tất cả card; toàn bộ card tappable → mở detail view
  - `supplier_list_view.dart`: compact card (avatar 48px, badge + quick-pay), không còn `PopupMenuButton`
  - `supplier_detail_view.dart`: AppBar actions Edit + Delete (password auth trước khi xóa)
  - `repair_partner_detail_view.dart`: AppBar actions Edit + Delete
  - Logic xóa NCC chuyển từ list view → detail view; `_confirmDeleteSupplier` + `_showPasswordDialog` đã xóa khỏi list view

- [x] **Product Image & Storage Location System (2026-05-19)**
  - `StorageLocation` model + DB table `storage_locations` (schema v98)
  - `StorageLocationView` — màn hình CRUD quản lý vị trí kho
  - `StorageLocationSelector` widget — bottom sheet chọn vị trí
  - `LocationBadge` widget — hiển thị badge vị trí
  - `ImagePickerWidget` — chọn ảnh camera/thư viện, nén tự động <300KB
  - `ProductImageService` — upload background lên Firebase Storage
  - Tích hợp: thumbnail + chip vị trí trong card sản phẩm kho
  - Tích hợp: chọn vị trí cất máy khi đánh dấu sửa XONG
  - Tích hợp: chip vị trí trong danh sách đơn sửa chữa
  - Nút điều hướng đến StorageLocationView từ AppBar kho

- [x] **Tắt Thông Báo Bảo Hành + Cải Thiện UI 5 Màn Hình (2026-05-19)**
  - Tắt push notification bảo hành: `_enableWarrantyPushNotifications = false` trong `WarrantyReminderService`
  - Fix overflow stats bar linh kiện: `FittedBox(fit: BoxFit.scaleDown)`
  - Redesign dialog tạo nhân viên: gradient header, icons, section labels
  - Cải thiện product detail bottom sheet: price cards trực quan
  - Cải thiện edit product dialog: gradient header thay text đơn giản
  - Cải thiện `_card` widget sale detail: shadow, accent border, loại bỏ Colors.pink

- [x] **Reconciliation Patch v7 — TOTAL_DEBT_SUPPLIER dứt điểm (2026-05-17)**
  - Root cause xác nhận từ ADB device log: `debt_payments` có bản ghi corrupt (60M cho nợ 100k, 7M cho nợ 100k).
  - Giải pháp: tách biệt cash flow (dùng `debt_payments.amount`) và debt balance (dùng `debts.paidAmount`).
  - Main loop `debtSupplierChange=0`, Category B dùng full `paidAmount`, `_loadOpeningDebtBalances` đơn giản hóa.
  - Kết quả: debtSupplierClosing = 33,190,500 = payableTotal → **TOTAL_DEBT_SUPPLIER PASS** ✓

- [x] **Reconciliation Patch v5 — TOTAL_DEBT_SUPPLIER dứt điểm** (2026-05-16)
  - Root cause: payments link tới deleted debts (`deleted=1`) vẫn bị tính vào `debtSupplierChange` do LEFT JOIN không phân biệt deleted.
  - Fix: thêm `linkedDebtDeleted` column; chỉ set `debtSupplierChange` khi `linkedDebtIsActive` (debt còn tồn tại và không bị xóa).
  - Expected: TOTAL_DEBT_SUPPLIER PASS — closing = 12,020,500 + 21,170,000 = 33,190,500 ✓

- [x] **Reconciliation Patch v4 + sửa nền popup xuất file** (2026-05-16)
  - Audit 2 file mới người dùng gửi xác nhận:
    - `TOTAL_OUT` PASS
    - `NET` PASS
    - còn `TOTAL_DEBT_SUPPLIER` FAIL
  - Sửa reconciliation:
    - `db_helper.dart`: query debt payments trả thêm `linkedDebtType`
    - `finance_v2_view.dart`: `DEBT_PAY` chỉ trừ `debtSupplierChange` khi linked debt là loại NCC thật sự
  - Sửa UI popup xuất file thành công:
    - `finance_v2_excel_export.dart`: đổi block thông tin file từ nền xanh đậm sang nền xanh nhạt, tăng tương phản chữ/icon để không còn mảng xanh đặc.

- [x] **Reconciliation Patch v2 theo bộ Excel 16/05/2026** (2026-05-16)
  - Tái hiện chính xác FAIL từ file `nhat_ky_chi_tiet_16052026_16052026.xlsx`:
    - `TOTAL_OUT` lệch +200,000
    - `NET` lệch -200,000
    - `TOTAL_DEBT_SUPPLIER` lệch -66,800,000
  - Root cause 1: dedup import theo amount trong `finance_v2_data_service.dart` gây skip nhầm khoản nhập trùng số tiền.
  - Root cause 2: `DEBT_PAY` không linked vào bảng `debts` vẫn trừ `debtSupplierChange`, làm flow công nợ NCC âm giả.
  - Đã sửa:
    - dedup import theo canonical reference key.
    - SQL debt payments trả thêm `linkedDebtId`.
    - audit log chỉ ghi `debtSupplierChange` cho `DEBT_PAY` khi có `linkedDebtId`.
  - Validation: `flutter build apk --debug` thành công; analyze không có error mới.

- [x] **Reconciliation Patch v3: opening debt supplier âm giả** (2026-05-16)
  - Audit bộ Excel tải lại xác nhận:
    - `TOTAL_OUT` đã PASS
    - `NET` đã PASS
    - còn duy nhất `TOTAL_DEBT_SUPPLIER` FAIL
  - Sửa `_loadOpeningDebtBalances()` trong `finance_v2_view.dart`:
    - skip debt `totalAmount <= 0`
    - skip debt `openingRemaining <= 0`
  - Mục tiêu: loại ảnh hưởng các debt record âm/không hợp lệ khỏi opening balance công nợ NCC.
- [x] **Reconciliation Fix TOTAL_OUT + TOTAL_DEBT_SUPPLIER** (2026-05-16)
  - Audit tiếp theo sau 4 bug fixes trước: phát hiện 2 lỗi còn lại trong RECONCILIATION sheet
  - LỖI 1: TOTAL_OUT lệch 200K (log > report) — data service thiếu query `supplier_import_history`
    - Sửa `finance_v2_data_service.dart`: thêm import_history processing với dedup theo amount
  - LỖI 2: TOTAL_DEBT_SUPPLIER lệch 50.38M (log < report) — 2 nguyên nhân:
    - (a) `_loadOpeningDebtBalances()` dùng pre-period payments (debt_payments table) → lệch với snap.payableTotal (dùng stored paidAmount) khi có sync lag
      - Sửa `finance_v2_view.dart`: đổi sang `paidBeforeStart = storedPaid - inPeriodPaid` — algebraically nhất quán với snap.payableTotal
    - (b) Reconciliation engine cộng IMPORT debtSupplierChange (CÔNG NỢ imports qua purchase_orders) vào flow → không có trong snap.payableTotal (chỉ track debts table)
      - Sửa `finance_v2_reconciliation.dart`: skip debtSupplierChange cho IMPORT action
  - Git commit `c9822f44` — build debug thành công

- [x] **Financial Reconciliation Audit — 4 Bugs Fixed** (2026-05-16)
  - Audit 6 file Excel ngày 16/05/2026, xác định 4 nguyên nhân chênh lệch số liệu
  - BUG 1: KẾT HỢP sales dùng `finalPrice` thay vì `cashAmount + transferAmount` → thiếu 5M TOTAL_IN
    - Sửa `finance_v2_data_service.dart` (current + previous sales loops) + `daily_financial_analysis_service.dart`
    - recognizedCost denominator = actualPaid cho KẾT HỢP (ratio = 1, 100% vốn)
  - BUG 2: bao_cao_ngay "CHI — Nhập hàng" luôn 0 vì filter `type=IMPORT` không bao giờ match
    - Sửa `finance_v2_view.dart`: derive `importOut = totalOut - debtRepayOut - operatingExpenseOut`
  - BUG 3: Section 3 danh sách đơn bán hiển thị `finalPrice` thay vì `cashAmount+transferAmount` cho KẾT HỢP
  - BUG 4: so_quy duplicate partner payments (ĐỐI TÁC SỬA CHỮA + Trả đối tác SC = 2×)
    - Track `partnerExpenseAmounts`; skip `_repairPartnerPayments` nếu đã có entry trùng từ `_expenses`
  - Git commit `2b2f3966` — build debug thành công

- [x] **Fix Finance Tab Crash + Audit Financial Display** (2026-05-16)
   - Sửa `getSalesByDateRange()` crash `no such column: createdAt` — xóa `COALESCE(soldAt, createdAt)` dùng `soldAt` trực tiếp
   - Sửa Home `_loadStats` catch block không reset về 0 khi lỗi — giữ số liệu cũ
   - Audit xác nhận: Home và Finance tab dùng cùng `FinanceV2DataService.loadSnapshot()` → nhất quán
   - Công thức tài chính đúng: cash-basis, CÔNG NỢ = 0, trả góp chỉ tính phần đã thu, trả hàng trừ net

- [x] **Fix lỗi tab Nhật ký tài chính bị trống theo ảnh người dùng** (2026-05-16)
   - Triển khai fallback timeline trong `finance_v2_view.dart`: nếu `transactions + financial_activity_log` rỗng theo kỳ lọc thì lấy dữ liệu từ `audit_logs` liên quan tài chính.
   - Áp dụng lọc action tài chính: sale/repair/expense/debt/payment/purchase/import/cash_closing.
   - Mapping action kỹ thuật sang nhãn tiếng Việt để dễ đọc trên UI Nhật ký.
   - Thêm banner thông báo nguồn dữ liệu fallback để người dùng biết trạng thái hiển thị.
   - Validation: `flutter analyze` không có lỗi mới trong file sửa; `flutter build apk --debug` thành công.

- [x] **Financial Audit Home vs Finance + Consistency Fix** (2026-05-16)
   - Audit theo phản hồi xuất Excel rỗng ở tab Giao dịch/Công nợ/Nhật ký
   - Xác định và sửa lỗi query `getSalesByDateRange()` chưa lọc shopId (nguy cơ kéo số liệu chéo shop)
   - Bổ sung filter dữ liệu sales theo `shopId` + `deleted` + `COALESCE(soldAt, createdAt)`
   - Sửa Home không giữ số tài chính cũ khi `_loadStats` lỗi (reset về 0 trong catch)
   - Build/debug thành công sau khi vá

- [x] **Fix hiển thị mục 2 trên OPPO (NCC/Đối tác topbar)** (2026-05-16)
   - Xác định root cause: luồng OPPO đang dùng `supplier_list_view.dart`, không phải `partner_management_view.dart`
   - Chuyển tìm kiếm và bộ lọc lên AppBar cho cả 2 tab trong `supplier_list_view.dart`
   - Đồng bộ menu lọc theo tab:
      - NCC: Còn nợ, Đã tất toán, Quá hạn, Giao dịch gần đây
      - Đối tác: Hoạt động, Ngừng HĐ, Còn nợ, Theo tên
   - Loại bỏ cụm search/filter trong body để tránh trùng thao tác
   - Validation: `flutter build apk --debug` thành công

- [x] **Topbar Actions for Customer, Partner/NCC, and Inventory** (2026-05-16)
   - customer_profile_view: đưa Lưu/Xóa lên AppBar, đổi bộ lọc lịch sử sang dropdown topbar
   - customer_profile_view: xóa ô Email, thu gọn Địa chỉ/Ghi chú 1 dòng, giảm 1/2 chiều cao khung ảnh đại diện
   - partner_management_view: thêm tìm kiếm (icon kính lúp) và dropdown lọc trên topbar cho cả 2 tab NCC/đối tác
   - partner_management_view: thêm các chế độ lọc theo tab (còn nợ/tất toán/quá hạn/giao dịch gần đây và hoạt động/ngừng HĐ/theo tên)
   - inventory_view: chuyển tìm kiếm + toggle hiển thị hàng hết lên topbar, ẩn block “Tải cuộn 20 mục/lần”
   - Validation: build debug thành công; analyze còn warnings/info pre-existing ở inventory/partner

- [x] **Partner Navigation + Font Sync + Parts Financial Fix** (2026-05-16)
  - partner_management_view: onTap NCC/đối tác → RepairPartnerDetailView / SupplierDetailView
  - sale_detail_view: sửa lỗi PKX/NO_IMEI truyền sai vào IMEI lookup → "không tìm thấy sản phẩm"
  - deep_link_navigator: fallback strip quantity suffix (x2) khi tìm sản phẩm theo tên
  - Font size đồng bộ: parts_inventory_view, partner_management_view, create_repair_order_view dùng AppTextStyles
  - parts_inventory_view: gradient nhất quán [1A237E → 2962FF] với 2 tab còn lại
  - repair_detail_view: fix 2 bug tài chính — parts cash dùng sai PaymentIntentType + _showCostFundRecordingPopup thiếu FinancialActivity log

- [x] **Compact Listview + KiotViet Credentials UI + Clickable Navigation** (2026-05-16)
  - Khôi phục giao diện về `3185ff9f` sau khi revert broken color commit
  - Tái tích hợp: clickable customer header (phiếu sửa/đơn bán), clickable product (đơn bán), order navigation (hồ sơ KH)
  - KiotViet: nhập Client ID/Secret trực tiếp trong app (SharedPreferences), không cần dart-define
  - Compact listview: search box 42px, dense tiles, borderRadius 12 trên order_list, customer, inventory
  - Thêm Backup & KiotViet tiles trong Cài đặt cửa hàng

- [x] **Restore Legacy Color Palette** (2026-05-15)
  - Truy vết palette gốc từ commit `3d6b3109` bằng `git show`
  - Khôi phục primary `#4D8EE9` (soft blue, mềm mại hơn iOS/Zalo blue)
  - AppBar gradient: #0068FF → #0084FF (Zalo Blue gốc)
  - Grey scale: Material Design grey (gốc, không Tailwind)
  - finance_v2_theme.dart: khôi phục navy original
  - Toàn bộ ứng dụng tự kế thừa qua shared tokens

- [x] **Documentation Process Setup** (2026-05-15)
  - Tạo CLAUDE.md, documentation index
  - Setup quy trình tài liệu hóa bắt buộc
  - Tạo templates cho all documentation files

---

## Pending Tasks

### High Priority
- [ ] **Review & Update DOCS/FULL_DOCUMENTATION.md**
  - Đảm bảo đầy đủ tất cả services, models, views
  - Thêm chi tiết schema database
  - Thêm API documentation (Firestore, Firebase)

- [ ] **Complete docs/KNOWN_ISSUES.md**
  - Danh sách tất cả known issues
  - Workarounds nếu có
  - Priority levels

- [ ] **Complete docs/TODO.md**
  - Danh sách tasks pending
  - Priority, assignee, due dates
  - Link đến relevant code/docs

- [ ] **Complete docs/ROADMAP.md**
  - Milestones
  - Features planned
  - Timeline

### Medium Priority
- [ ] **Verify All Specialized Reports**
  - PERMISSION_AUDIT_REPORT.md
  - FINANCE_V2_MIGRATION.md
  - KIOTVIET_INTEGRATION_REPORT.md
  - IMAGE_UPLOAD_AUDIT_REPORT.md
  - UI_STANDARDIZATION_REPORT.md

- [ ] **Consolidate Legacy Documentation**
  - Clean up legacy files
  - Archive old reports
  - Link từ legacy files tới mới

### Low Priority
- [ ] **Create Automated Documentation Update Tool**
  - Script kiểm tra file changes
  - Auto-update CHANGELOG
  - Auto-validate documentation

---

## Known Issues

### Build & Compilation
1. **Android NDK Version Mismatch**
   - Issue: integration_test requires NDK 28.2.13676358
   - Status: ⚠ Pending fix in build.gradle.kts
   - Workaround: Add `ndkVersion = "28.2.13676358"` to android/app/build.gradle.kts

2. **Impeller Opt-out Deprecated**
   - Issue: Warning từ Flutter về Impeller opt-out
   - Status: ⚠ Pending removal
   - Workaround: Remove `io.flutter.embedding.android.EnableImpeller=false` từ AndroidManifest.xml

### Runtime
3. **Image Decoder Failures**
   - Issue: Some images fail to decode ("unimplemented")
   - Status: ⚠ Device-specific (Android 12+)
   - Workaround: Validate image format trước upload

4. **FCM Token Save**
   - Issue: "Cannot save FCM token: no authenticated user"
   - Status: ℹ Expected (happens at login screen)
   - Workaround: None needed, automatic retry after auth

### Known Limitations
5. **Geolocation**
   - Status: Active (connected)
   - Note: Requires permission từ user

6. **Crash `_dependents.isEmpty` / disposed TextEditingController trong bottom sheet có TextField — CHƯA fix**
   - Issue: Focus vào TextField trong 1 bottom sheet (bàn phím mở) → bấm Back hệ thống → bấm Back lần nữa hoặc bấm nút Lưu/xác nhận → có thể crash. Tái hiện trên `_editTechnicianNotes` (`repair_detail_view.dart`) ngày 2026-08-15, dù đã áp đủ 2 fix đã biết trước đó (outer context cho MediaQuery, `FocusManager.instance` cho unfocus).
   - Status: ⚠ Intermittent, chưa fix — đã thử `PopScope` chặn pop nhưng lại sinh crash khác ("TextEditingController used after disposed", lỗi nằm trong nội bộ Flutter's `_ModalBottomSheetRoute`), nên đã revert
   - Rủi ro: nghi có mặt ở MỌI bottom sheet có TextField trong app (không riêng 1 màn), vì đường crash đi qua nút Back hệ thống — nằm ngoài `onPressed` của các nút Hủy/Lưu vốn đã có bảo vệ
   - Chi tiết kỹ thuật + cách tái hiện: memory `feedback_modal_sheet_dependents_crash.md` mục "Cause 3"; `docs/CHANGELOG.md` mục `[2026-08-15]`
   - Next step: cần phiên điều tra riêng, có thể cần nâng cấp `android:enableOnBackInvokedCallback` (log cảnh báo hiện tại: "OnBackInvokedCallback is not enabled for the application") hoặc tìm hiểu sâu hơn Flutter's predictive-back handling

7. ~~22 điểm popup MEDIUM risk còn thiếu xử lý thanh điều hướng~~ — **✅ Đã fix xong 2026-08-16** (xem `docs/CHANGELOG.md` mục `[2026-08-16]`). Toàn bộ 42 điểm popup từ audit gốc (20 HIGH + 22 MEDIUM, gồm cả 6 điểm context-safety liên quan) nay đã xử lý hết.

---

## Recommended Next Steps

### Immediate (This Sprint)
1. **Complete Pending Documentation**
   - Finish KNOWN_ISSUES.md
   - Finish TODO.md
   - Finish ROADMAP.md

2. **Consolidate Full Documentation**
   - Review DOCS/FULL_DOCUMENTATION.md
   - Add missing details
   - Update all links

3. **Fix Build Issues**
   - Update Android NDK version
   - Remove Impeller opt-out

### Short-term (Next Sprint)
4. **Verify All Services**
   - Run comprehensive tests
   - Validate all Firestore operations
   - Check sync reliability

5. **UI/UX Review**
   - Check design consistency
   - Verify all screens
   - Test on multiple devices

### Long-term (Roadmap)
6. **Performance Optimization**
   - Analyze app startup time
   - Optimize Firestore queries
   - Reduce app bundle size

7. **Feature Expansion**
   - Multi-language support
   - Advanced reporting
   - Mobile payment integration

---

## System Architecture (Quick Reference)

```
┌─────────────────────┐
│  Views (UI)         │
├─────────────────────┤
│  Services           │
│  (Firestore, Auth)  │
├─────────────────────┤
│  Models & Database  │
│  (SQLite, Firestore)│
├─────────────────────┤
│  External APIs      │
│  (Firebase, etc.)   │
└─────────────────────┘
```

---

## Key Files to Know

| File | Purpose | Status |
|------|---------|--------|
| `lib/main.dart` | Entry point | ✓ Stable |
| `lib/services/firestore_service.dart` | Firestore CRUD | ✓ Stable |
| `lib/services/user_service.dart` | Auth & roles | ✓ Stable |
| `lib/services/sync_service.dart` | Real-time sync | ✓ Active |
| `lib/data/db_helper.dart` | SQLite | ✓ v17 |
| `.github/copilot-instructions.md` | AI guidelines | ✓ Updated |
| `CLAUDE.md` | Developer guide | ✓ Updated |
| `docs/DOCUMENTATION_INDEX.md` | Doc index | ✓ Updated |

---

## Documentation Files Status

| File | Status | Last Updated |
|------|--------|--------------|
| CLAUDE.md | ✓ Created | 2026-05-15 |
| .github/copilot-instructions.md | ⚠ Partial | 2026-05-15 |
| docs/DOCUMENTATION_INDEX.md | ✓ Created | 2026-05-15 |
| docs/CHANGELOG.md | ✓ Created | 2026-05-15 |
| docs/HANDOVER.md | ✓ Created (this file) | 2026-05-15 |
| docs/KNOWN_ISSUES.md | ⏳ Pending | - |
| docs/TODO.md | ⏳ Pending | - |
| docs/ROADMAP.md | ⏳ Pending | - |
| docs/ARCHITECTURE.md | ⏳ Pending | - |
| docs/DESIGN_SYSTEM.md | ⏳ Pending | - |
| docs/DESIGN_TOKENS_REFERENCE.md | ⏳ Pending | - |
| docs/UI_GUIDELINES.md | ⏳ Pending | - |
| docs/CODING_STANDARDS.md | ⏳ Pending | - |
| docs/IMPLEMENTATION_REPORT.md | ⏳ Pending | - |
| docs/PAYMENT_AUDIT.md | ⏳ Pending | - |
| DOCS/FULL_DOCUMENTATION.md | ⚠ Needs review | - |

---

## Quick Stats

- **Total Source Files:** 150+ (lib/)
- **Total Views:** 10+
- **Total Services:** 8+
- **Total Models:** 15+
- **Database Tables:** 8+
- **Firebase Collections:** 10+
- **External Integrations:** 4+ (Firebase, KiotViet, etc.)

---

## Communication

- **Documentation Owner:** GitHub Copilot
- **Last Updated:** 2026-05-16
- **Next Review:** Before next major task
- **Questions?** Check CLAUDE.md or docs/DOCUMENTATION_INDEX.md

---

**Note:** Tài liệu này được cập nhật tự động sau mỗi task. Nếu thông tin không chính xác, vui lòng báo cáo.
