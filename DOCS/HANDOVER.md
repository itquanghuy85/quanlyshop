# HANDOVER - HULUCA Shop Manager

Trạng thái hiện tại dự án, tasks đã hoàn thành, tasks pending, known issues, next steps.

---

## ⚡ Trạng thái hiện tại

**Version:** 3.5.0+554 (đóng gói lên store — `[2026-08-29e..s]` + `[2026-08-30a..e]`; 3.4.0+545 đang live). Các build +546..+553 chưa upload store → bỏ, dùng +554.  
**Last Updated:** 2026-09-05  
**✅ NGHIỆM THU MÁY THẬT XONG (`[2026-09-05c]`) — Oppo CPH2203, `m@m.com`/shop "M".** Phát hiện + sửa **3 lỗi** mà `analyze`/unit test không bắt được: (1) **`firestore.rules` thiếu `price_catalog_items`** ⇒ `permission-denied`, danh mục giá KHÔNG BAO GIỜ đồng bộ được sang máy khác — đã thêm rule (READ mọi nhân viên trong shop vì họ cần tra Giá thu khách, GHI chỉ quản lý; nhánh update dùng `optNum` không `numGte0` để xoá mềm không làm kẹt hàng đợi) và **ĐÃ deploy production**; (2) **màn hướng dẫn trắng trơn** — `ResponsiveBody` bọc `Center` giãn hết chiều cao, đặt trong `bottomNavigationBar` làm thanh dưới chiếm trọn màn, ép thân màn còn 0 chiều cao (dùng `Center(heightFactor: 1)`); (3) mũi tên sơ đồ rơi lại cuối dòng khi `Wrap` xuống dòng. **ĐẠT:** migration v109→v110 sạch trên DB thật (dữ liệu cũ nguyên vẹn); cấu hình Trang chủ v3→v4 đúng 14 thẻ; "Hoạt động hôm nay" hiện thật; Tài chính 4 tab + nhãn "Toàn bộ công nợ"; **In/Xuất Excel đúng cả 4 đường** sau khi đổi chỉ số tab; file mẫu HD014650 tổng **3.120.000** khớp; nhập lần 1 ra 5 mặt hàng / 2 cần kiểm tra; **nhập lại cùng file → vẫn 5 mặt hàng, 5 dòng trùng, bình quân không đổi**; đặt giá thu khách 1.5tr lưu đúng; sau deploy rules `isSynced=1` cả 5. **✅ ĐÓNG món tồn đọng: crash `_dependents.isEmpty` (2026-09-05).** Bản vá ở `[2026-09-05?]` (commit `041a6034`) nay ĐÃ nghiệm thu máy thật Oppo CPH2203: (a) `order_list_view._addCustomerToRepair` — chạy đúng **đường barrier-dismiss** (gõ vào ô tìm khách rồi chạm ra ngoài) **6 vòng** với delay 80/150/250/310/400/600ms, quét cả hai phía ngưỡng timer 300ms → **không crash lần nào**; (b) `sale_detail_view._unlockManager` — sai mật khẩu thì **dialog VẪN MỞ + lỗi inline "Sai mật khẩu quản lý"** (trước đây đóng dialog rồi mới SnackBar, chính là kiểu gây crash), đúng mật khẩu thì mở được "SỬA ĐƠN BÁN"; không crash ở cả 2 đường. Ghi chú cũ dự đoán "cần phiên `flutter run` attach" — thực tế đọc thẳng assert trong Flutter SDK là đủ.  
**✅ ĐÓNG THÊM 3 MÓN TỒN ĐỌNG (2026-09-05, 2 máy Oppo CPH2203 + CPH2239):**
· **`[2026-08-30s]` nút ghi "Đối soát tiền về"** — món tồn đọng quan trọng nhất vì là luồng GHI TIỀN THẬT, phiên cũ kẹt IME không bấm được. Nay chạy trọn: chọn "Tiền ra", gõ 30.000 → tìm đúng "NCC TÉT A · Nhập giá vốn: TAI NGHE − 30.000đ · Khớp đúng" → **Xác nhận ghi** → log `Payment executed … 30000đ / SUPPLIER_DEBT`. **Đối chiếu DB trước–sau:** nợ #20 `paidAmount 0→30.000`, `status ACTIVE→PAID`; `debt_payments` +1 (#31, CHUYỂN KHOẢN); `payment_intents` +1; `financial_activity_log` +1 (`OUT 30.000 — "Trả nợ (đối soát): NCC TÉT A"`); **`debts` KHÔNG tăng** (không đẻ nợ trùng). ⇒ ĐẠT.
· **`[2026-08-31a]` "Đã giao" là trạng thái cuối (cần 2 máy)** — máy 1 duyệt giao đơn `rep_1788498641910` (`3→4`), máy 2 ép đồng bộ → nhận đúng `3→4`. Sau đó đối chiếu toàn bộ: **9 đơn, 2 máy khớp hoàn toàn, 0 đơn lệch trạng thái.** ⇒ ĐẠT.
· **`[2026-08-24f]`/`[2026-08-23a]` đồng bộ 2 thiết bị** — đã chứng minh qua 2 loại dữ liệu độc lập: danh mục giá NCC và trạng thái đơn sửa. ⇒ ĐẠT (riêng nhánh **phương thức Chuyển khoản** thì phiếu trả nợ vừa ghi đúng là `CHUYỂN KHOẢN`).

**📌 TỒN ĐỌNG CÒN LẠI — CHƯA LÀM:** `[2026-08-31c]` badge sync ảo · `[2026-08-30w]` điều hướng Bảng giá/Đối soát · `[2026-08-30v]` Bảng giá P3 · `[2026-08-30u]` thẻ giá niêm yết trong form tạo đơn · `[2026-08-30b]`, `[2026-08-29g]` · `[2026-08-22a]` quét QR bằng app ngân hàng thật (cần app NH) · `[2026-08-16f]` luồng super admin (cần tài khoản super admin) · `[2026-08-08b]` Samsung A32 (không có máy) · **In** hoá đơn từng tab (không có máy in).
**🔴 LỖI CHẶN đã sửa (`[2026-09-05d]`): app KHÔNG đọc được file do ChatGPT tạo.** Cả tính năng dựng trên tiền đề "nhờ ChatGPT tạo file Excel", mà Code Interpreter dùng **openpyxl** — file openpyxl làm gói `excel` ném ở HAI chỗ: (1) Target tuyệt đối `/xl/worksheets/…` ⇒ *Null check operator*; (2) **ô inline string RỖNG** `<c t="inlineStr"/>` ⇒ *Bad state: No element* (parse.dart:630) — mà ô rỗng là **bắt buộc xảy ra** vì prompt của app yêu cầu để trống "Giá thu khách", nghĩa là **mọi file AI tạo đúng hướng dẫn đều hỏng**. Đã đổi `_normalizeOoxmlRelTargets` → `_repairOpenpyxlWorkbook` (vá cả rels lẫn worksheet). **Đã chạy nốt kịch bản còn thiếu trên máy thật, ĐẠT:** cùng mặt hàng 2 hoá đơn → BQ gia quyền **116.667** đúng công thức; khác model → 2 mục riêng; tiền `"310.000"/"310,000"/"310.000 đ"` → 310000, `"1.250.000đ"` → 1250000; thiếu tên/thiếu giá vốn/SL âm đếm đúng 1/1/1; file thiếu cột báo lỗi rõ + chặn nút Nhập; màn Tuỳ chỉnh hết `dailyReport` và có đủ 3 thẻ mới; xoay ngang thẻ giá xếp 2 cột. Test mới `openpyxl_compat_test.dart` (6 test) + fixture file openpyxl thật. `flutter test` **+550 −8**. **CÒN LẠI CHƯA TEST:** (a) **In** hoá đơn từng tab (không có máy in); (b) giữ bố cục người dùng đã tuỳ chỉnh qua nâng cấp — thử trên máy KHÔNG kết luận được vì `loadConfig` ưu tiên bản cloud (đã v4) đè bản local dựng tay; 11 unit test vẫn phủ logic gộp; (c) tắt "Lời chào" xem banner tiền còn không (không ép được điều kiện hiện banner). Chi tiết: `[2026-09-05d]`.  
**✅ ĐÃ TEST NỐT 2 MỤC CÒN LẠI (2026-09-05, máy thứ 2 Oppo CPH2239):**
**(a) Nhân viên `n@n.com` (role=employee) — che giá vốn ĐẠT triệt để:** Trang chủ không có "Dòng tiền hôm nay", không có "Truy cập nhanh tài chính", thẻ Hoạt động không có ô CÔNG NỢ. Bảng giá chỉ hiện `Thu`, **không có chữ "Vốn"/"Lãi" nào**; dòng danh mục NCC hiện "Chưa thiết lập giá thu khách" + loại/model (đủ để tra) nhưng **không lộ NCC lẫn ngày nhập**. **Xuất Excel cũng sạch:** sheet Sửa chữa/Bán hàng còn **8 cột** (bản đủ 10 — cắt "Giá vốn ĐX"/"Giá vốn NY"), sheet Bảng giá NCC còn **9 cột** (bản đủ 15 — cắt 6 cột vốn/NCC/ngày HĐ), giá thu khách 1.500.000 vẫn giữ.
**(b) Đồng bộ 2 máy ĐẠT:** mặt hàng tạo + đặt giá ở máy 1 hiện đúng trên máy 2.
**(c) Đổi vai trò trên CÙNG máy 2:** đăng xuất nhân viên → đăng nhập `m@m.com` → **cùng dòng đó hiện `Thu 1.500.000đ · Vốn 900.000đ · Lãi 600.000đ`** ⇒ chứng minh việc che là **theo vai trò**, không phải mất dữ liệu. Chi tiết: `[2026-09-05c]`.  
**🆕 Dọn bố cục Trang chủ + tab Tài chính theo audit UX (`[2026-09-05b]`): CHƯA NGHIỆM THU MÁY THẬT.** **Trang chủ — 3 lỗi thật:** (1) bật "Hoạt động hôm nay" trong Tuỳ chỉnh KHÔNG hiện gì (case rỗng, thẻ loé lên rồi mất); (2) ẩn "Lời chào" là mất luôn banner "Cần thanh toán" + "Giao dịch ngân hàng" (bị gắn cứng trong case greeting); (3) `dailyReport` đã bỏ vẫn là 1 công tắc chết trong màn Tuỳ chỉnh. **Bố cục:** 3 thẻ trước không tắt được (Khám phá/Mẹo/Cộng đồng) nay vào hệ thống Tuỳ chỉnh; bỏ nút "Tuỳ chỉnh dashboard" chiếm dòng đầu (lối vào đã có ở tab Cài đặt); thứ tự mặc định **v4** = việc gấp → việc hay làm → số liệu → xã giao (v3 đặt Chat/Hoạt động TRƯỚC Thao tác nhanh). **Cấu hình v3→v4, KHÔNG đạp lên bố cục người dùng đã tự sắp** — chỉ ai còn đúng y mẫu mặc định cũ mới được nâng lên mặc định mới. **Tài chính — lỗi số liệu:** tab Công nợ phớt lờ bộ lọc kỳ nhưng vẫn hiện thanh chip "Hôm nay" đang sáng ⇒ tưởng số của kỳ đó, thực ra là TOÀN BỘ mọi thời kỳ; nay thay bằng nhãn "Toàn bộ công nợ chưa tất toán — không theo kỳ đang chọn". **Gộp tab 5→4:** "Giao dịch"+"Nhật ký" → "Sổ giao dịch" (nút chuyển bên trong, KHÔNG trộn 2 nguồn dữ liệu); Tổng quan sắp lại theo dòng chảy tiền (Dòng tiền→Doanh thu→Chi phí→Lợi nhuận→So sánh, bản cũ đặt Lợi nhuận trước Doanh thu); bỏ khối Công nợ trùng. **Sửa bẫy chỉ số tab:** in/xuất Excel dùng số trần `index == 4`, sau khi gộp sẽ xuất nhầm hàm — nay dùng hằng có tên + đổi `_t0.._t5` thành tên có nghĩa. `flutter analyze` 0 lỗi; `flutter test` **+544 −8**; test mới migration **11/11 PASS**; build apk OK. Chi tiết: `[2026-09-05b]`.  
**⚠️ Kịch bản nghiệm thu thêm cho `[2026-09-05b]`:** (1) mở app bằng tài khoản ĐÃ từng tuỳ chỉnh Trang chủ → **thứ tự cũ phải giữ nguyên**, 3 thẻ mới nối ở cuối; (2) tài khoản chưa tuỳ chỉnh → thấy thứ tự mới (Cần xử lý → Thao tác nhanh → …); (3) Tuỳ chỉnh → bật "Hoạt động hôm nay" → phải hiện thật; (4) tắt "Lời chào" → 2 banner tiền vẫn còn; (5) màn Tuỳ chỉnh không còn dòng "Báo cáo hoạt động hôm nay"; (6) Tài chính: đúng 4 tab, tab Công nợ hiện nhãn "Toàn bộ…" thay cho chip kỳ; (7) tab Sổ giao dịch đổi qua lại 2 chế độ, **In và Xuất Excel ở từng tab/chế độ ra đúng nội dung** (đây là chỗ dễ sai nhất sau khi đổi chỉ số tab).  
**🆕 Bảng giá từ hoá đơn NCC — danh mục giá đồng bộ đám mây (`[2026-09-05a]`): CHƯA NGHIỆM THU MÁY THẬT.** Luồng: nhiều ảnh hoá đơn → GPT (prompt copy sẵn trong app) → 1 file Excel **4 sheet** ("Chi tiết nhập hàng"/"Tổng hợp giá vốn"/"Lỗi cần kiểm tra"/"Hướng dẫn nhập", 23 cột + `_khóa_import`) → chủ shop điền "Giá thu khách" → Bảng giá ⋮ → **"Nhập bảng giá từ hoá đơn NCC"** (màn RIÊNG, có xem trước + chọn Cập nhật/Bỏ qua + audit log). MỚI: `price_catalog_models.dart`, `price_catalog_service.dart`, `supplier_invoice_price_book_service.dart`, `supplier_invoice_price_import_view.dart`, bảng **`price_catalog_items` (DB v109→v110)** đồng bộ Firestore theo `shopId` — **hết cảnh giá chỉ nằm trên 1 máy** như cơ chế ghim SharedPreferences cũ (cơ chế cũ GIỮ NGUYÊN, dữ liệu cũ tra bình thường). **Phân quyền giá vốn — trước đây Bảng giá KHÔNG hề kiểm tra `allowViewCostPrice`, nhân viên thấy hết Vốn/Lãi:** nay chặn ở UI + tầng service (`buildRows`/`lookup` xoá sạch trường giá vốn) + **Xuất Excel** (file xuất ra không có cột giá vốn). **Chống trùng 2 lớp:** `firestoreId` tất định `pcat_sha1(shopId|khoá)` (2 máy nhập cùng file → cùng doc) + vân tay từng dòng hoá đơn trong `costHistoryJson` (nhập lại cùng file không cộng trùng bình quân gia quyền). `flutter analyze` **0 lỗi**; `flutter test` **+524 −8** (8 lỗi có sẵn từ trước, đã xác minh bằng `git stash` trên cây sạch); test mới **31/31 PASS** gồm đối chiếu hoá đơn mẫu HD014650 (tổng khớp 3.120.000); `flutter build apk --debug` OK. Chi tiết: `[2026-09-05a]`.  
**⚠️ Kịch bản cần nghiệm thu máy thật cho `[2026-09-05a]`** (máy Redmi M2101K7AG đang cắm bị MIUI chặn `adb install` — `INSTALL_FAILED_USER_RESTRICTED`; cần bật **Developer options → Install via USB** + **USB debugging (Security settings)**, hoặc cắm lại Oppo CPH2203): (1) mở app, **migration v110** chạy sạch không mất dữ liệu; (2) Bảng giá ⋮ → "Nhập bảng giá từ hoá đơn NCC" → tải file mẫu → nhập lại chính file đó → phải ra **5 mặt hàng mới**, 0 trùng, 2 mục "cần kiểm tra" (2 dòng nhiều model tương thích); (3) **nhập lại lần 2 cùng file** → phải là "5 cập nhật, 5 dòng trùng", giá bình quân KHÔNG đổi; (4) đặt Giá thu khách cho 1 mặt hàng → tab Sửa chữa hiện giá, các mặt hàng còn lại hiện **"Chưa thiết lập giá thu khách"**; (5) đăng nhập tài khoản **nhân viên** (không có `allowViewCostPrice`) → KHÔNG thấy Vốn/Lãi/NCC/ngày nhập, Xuất Excel ra file KHÔNG có cột giá vốn; (6) máy thứ 2 cùng shop → sau sync thấy đúng danh mục, không nhân đôi dòng. Tài khoản test: `m@m.com` / `123123` (shop "M").  
**✅ Fix không thể sửa/gán NCC cho linh kiện đã có (`[2026-09-04h]`):** dialog "SỬA linh kiện" và luồng "Nhập thêm" ở Kho phụ tùng hoàn toàn không có ô chọn nhà cung cấp — chỉ dialog "Thêm mới" mới có. Phụ tùng tạo trước không gán NCC (hoặc muốn đổi sau) luôn kẹt "Không xác định", không có cách sửa. Thêm ô "Nhà cung cấp" vào dialog Sửa (tái dùng widget picker sẵn có) + ghi `supplierId` khi lưu. **Máy thật Oppo — ĐẠT:** phụ tùng "Không xác định" → Sửa → chọn NCC → Lưu → hiện đúng ngay cả list lẫn chi tiết. Chi tiết: `[2026-09-04h]`.  
**✅ Fix Xuất/Nhập Excel bỏ sót phụ tùng tham khảo (`[2026-09-04g]`):** Xuất/Nhập Excel có sẵn của Bảng giá (`[2026-08-30v]`) chưa cập nhật theo dòng phụ tùng mới thêm ở `[2026-09-04f]` — xuất file bỏ sót hoàn toàn, nhập lại không nhận. Sửa: sheet "Sửa chữa" gộp cả dòng phụ tùng khi xuất; nhập nhận thêm khoá `p|`, ghim phụ tùng chỉ cần giá NIÊM YẾT HOẶC giá vốn NY > 0 (trước sẽ vô tình bỏ ghim phụ tùng chỉ có giá vốn); dòng mồ côi mới gõ thẳng vào Excel suy tên gốc từ cột "Tên". **Máy thật Oppo — ĐẠT:** xuất file → `adb pull` trực tiếp xác nhận đủ dữ liệu → nhập lại chính file đó → "ghim 3, bỏ ghim 0" khớp đúng, tên hiển thị + nhóm hãng của các dòng mồ côi giữ nguyên sau nhập. Chi tiết: `[2026-09-04g]`.  
**✅ Bảng giá — tích hợp giá vốn phụ tùng + tạo tay khi chưa có lịch sử (`[2026-09-04f]`):** tab Sửa chữa của Bảng giá nay gộp cả dòng phụ tùng/linh kiện (giá vốn LIVE từ Kho phụ tùng + mục nhập từ hoá đơn NCC chưa khớp tên) để nhân viên tra cứu khi nhận máy sửa. **Fix gộp nhóm hãng sai:** tên phụ tùng dạng "loại phụ tùng + hãng + model" (vd "Pin iPhone 13") khiến gộp nhóm cũ (chỉ xét từ đầu) gộp nhầm vào nhóm "PIN" thay vì "IPHONE" — nay quét toàn bộ từ trong tên để tìm đúng hãng. **Nút nổi "Thêm mục"** (chỉ tab Sửa chữa) → tạo tay 1 mục sửa chữa (model+lỗi) hoặc 1 phụ tùng tham khảo (tên+giá vốn, có Hãng máy tuỳ chọn) NGAY CẢ KHI CHƯA có lịch sử/chưa có trong Kho — dựng sẵn bảng giá trước khi khách mang máy đến. Nhập hoá đơn NCC (Excel) thêm cột "Hãng" tuỳ chọn để gộp nhóm chính xác hơn khi tên hàng không nêu rõ hãng. `PricePin` thêm 2 field mới (`displayExtra`, `brandHint`), không phá pin cũ. `flutter analyze` 0 lỗi mới. **Máy thật Oppo CPH2203 (shop "M") — ĐẠT cả 3 luồng mới:** phụ tùng test "TÉT PIN VIVO..." gộp đúng nhóm "VIVO" (trước fix sẽ vào "TÉT"); tạo tay "Oppo A74 · Thay màn hình" → xuất hiện đúng nhóm OPPO mới, "0 mẫu", NIÊM YẾT; tạo tay phụ tùng tên không rõ hãng kèm Hãng máy tự ghi → gộp đúng nhóm đó thay vì "Khác". Cột "Hãng" trong Excel nhập hoá đơn NCC chưa test qua file picker thật (logic dùng chung code path đã verify ở trên). Chi tiết: `[2026-09-04f]`.  
**✅ Cập nhật giá vốn phụ tùng từ hoá đơn NCC — cầu nối Excel + AI (`[2026-09-04e]`):** Kho phụ tùng → icon hoá đơn cạnh nút Sắp xếp → "Nhập giá vốn từ Excel" (chọn `.xlsx`) + "Hướng dẫn dùng AI đọc hoá đơn" (prompt mẫu copy được + tải file Excel mẫu). Khớp tên tự động (bỏ dấu/hoa-thường); dòng không khớp (thường do 1 linh kiện dùng chung nhiều model) có nút "Gán" chọn NHIỀU phụ tùng cùng lúc. **Fix quan trọng:** gói `excel` không đọc được file `.xlsx` do Python/openpyxl tạo (lỗi null-check do đường dẫn worksheet tuyệt đối trong `workbook.xml.rels`) — rất có thể ảnh hưởng cả file do AI (ChatGPT Code Interpreter…) tạo trực tiếp; đã fix bằng cách tự sửa lại zip trước khi đọc (gói `archive`). **Quyết định kiến trúc:** bản đầu định để app tự đọc ảnh bằng AI (`image_picker`) — gặp bug màn hình trắng trơn sau `Navigator.push` không giải thích được (xem memory dự án), nên đổi hẳn sang Excel. Máy thật Oppo: nhập 3 dòng (1 khớp tự động + 2 gán tay 2 phụ tùng khác nhau) → cập nhật đúng, danh sách refresh ngay. Chưa test file Excel thật do AI tạo (mới test bằng file mô phỏng). Chi tiết: `[2026-09-04e]`.  
**✅ Bảng giá — sửa lỗi hiển thị "Lãi âm" giả + tinh chỉnh (`[2026-09-04b]`):** audit UX phát hiện SP chưa có giá bán bị `buildSaleRows` hiện thành "Lãi -X đ" đỏ như đang lỗ (do lọc giá>0 khi tính trung vị nhưng không lọc khi tạo dòng). Sửa: trạng thái trung tính "Chưa có giá bán — chạm để đặt giá" + `sampleCount`/`confidenceLabel` hết mâu thuẫn nhau; thêm badge màu độ tin cậy; banner hệ số mùa vụ chạm được thẳng; tiêu đề nhóm hãng có số đếm. Máy thật Oppo xác nhận cả 2: dòng "17 128GB (MỚI)" hết hiện lỗ giả, hệ số mùa vụ +10% áp đúng qua banner chạm. Giai đoạn 2/3 của audit (chip lọc, ghim hàng loạt Sửa chữa, hoàn tác, đồng bộ pin cloud...) chưa làm, chờ duyệt riêng. Chi tiết: `[2026-09-04b]`.  
**✅ Chip phụ tùng/dịch vụ trong list + sửa dịch vụ khi đã giao (`[2026-09-04d]`):** `order_list_view` thẻ đơn nay hiện 🔩 phụ tùng + 🛠️ dịch vụ ngay trên list; `repair_detail_view` bỏ khóa `status!=4` cho nút "+Thêm"/✏️ sửa dịch vụ (khớp phụ tùng đã unlock từ `[2026-08-30t]`). Nghiệm thu máy thật ĐẠT (sửa giá dịch vụ đơn ĐÃ GIAO 250k→300k→trả lại 250k, không crash). **Phát hiện phụ chưa sửa:** crash `_dependents.isEmpty` tái hiện LẦN 3 ở `_addCustomerToRepair` (nút Hủy) dù đã có unfocus+delay — bẻ gãy giả thuyết "đừng pop sớm" là giải pháp triệt để; cần phiên `flutter run` attach riêng, xem memory. Chi tiết: `[2026-09-04d]`.  
**✅ Fix đơn sửa: NCC/link phụ tùng, dialog xoá đơn, xoá/đổi PT (`[2026-09-04c]`):** 3 bug user báo + 1 bug SQL phát hiện khi test sống (`repair_parts` query sai cột `name`→`partName` khiến xoá/đổi phụ tùng "Kho cũ" crash âm thầm, không lưu được) + suýt tái tạo crash `_dependents.isEmpty` đã biết (đã né đúng hướng: dialog mật khẩu KHÔNG pop trước khi await xác thực, lỗi hiện inline trong dialog qua `StatefulBuilder`). **Nghiệm thu máy thật ĐẠT** (Oppo CPH2203) — xem [[project_repair_parts_delete_swap_fix_2026-09-04]] (memory) để chi tiết đầy đủ, đặc biệt bài học crash cho `sale_detail_view.dart::_unlockManager` (vẫn CHƯA sửa). Chi tiết: `[2026-09-04c]`.  
**✅ Fix đối soát tiền về: bỏ QR thừa tab "Tiền vào" + ẩn bàn phím (`[2026-09-04b]`):** bỏ khối QR nhận tiền không cần thiết ở tab "Tiền vào (nhận)"; thêm chạm-ra-ngoài-để-ẩn-bàn-phím-số. Nghiệm thu máy thật ĐẠT. Chi tiết: `[2026-09-04b]`.  
**✅ Fix tìm kiếm không dấu/không phân biệt hoa-thường (`[2026-09-04a]`):** SQLite `LIKE` không tự bỏ dấu tiếng Việt → "Tìm kiếm toàn app" + ô "Chọn khách hàng" (dùng chung khi tạo đơn sửa/bán) không ra kết quả khi gõ không dấu/sai hoa-thường. Sửa 5 hàm `db_helper.dart` (`searchRepairs/searchSales/searchProducts/searchCustomers/searchCustomersRanked`) — bỏ SQL `LIKE`, lọc hoàn toàn bằng `VietnameseUtils` ở Dart, cùng cơ chế đã đúng sẵn ở `order_list_view.dart`. `flutter analyze` 0 error mới. Máy thật Oppo: tạo đơn "PHAM THI TEO" → tìm "teo" ra đúng kết quả ở cả 2 nơi. `adb` không gõ được dấu tiếng Việt nên phần bỏ dấu xác minh qua code, chưa gõ dấu thật trên máy — chủ shop nên tự gõ thử 1 lần. Chi tiết: `[2026-09-04a]`.  
**⚠️ CHƯA LÊN STORE:** từ `[2026-08-30a]` trở đi chưa build/upload store. **KHÔNG tự tăng version / build AAB** — user sẽ báo khi cần. `flutter analyze` + `flutter test` vẫn chạy để verify; debug APK cài máy test thì OK.  
**✅ Hướng dẫn trong app cho 2 tính năng NH (`[2026-08-31f]`):** thêm 2 mục KB `bank-transfer-qr` (QR + mở app NH ở mọi ô thanh toán) và `bank-notification` (đọc thông báo NH, kèm 7 lưu ý riêng tư/giới hạn) → tự có ở **AI Trợ Lý** + **Trung tâm trợ giúp**. `areaOf`/`_kbCategoryFor`: `bank-*` → nhóm Tài chính. Checklist "Khám phá Ứng Dụng" +2 nhiệm vụ. `flutter test` +490 −8 (+1 test AI truy hồi đúng 2 mục mới). Chi tiết: `[2026-08-31f]`.  
**✅ Đọc thông báo app ngân hàng tự động (`[2026-08-31e]`):** tính năng TÙY CHỌN, mặc định TẮT, chỉ Android. Bật (Cài đặt → "Đọc thông báo ngân hàng") + cấp quyền "Truy cập thông báo" → app đọc thông báo các app NH / SMS đầu số NH → parse số tiền +/− → bản ghi `bank_notifications` (cục bộ, KHÔNG sync) → Home banner + mục "Giao dịch ngân hàng gần đây" trong Đối soát tiền về → chạm dòng → tự điền số tiền + chiều → auto-match → Xác nhận (đi qua `MoneyReconcileService.apply` như cũ). KHÔNG tự ghi tiền. **DB v108→v109** (migration đã chạy OK máy thật). Plugin `notification_listener_service`. MỚI: `bank_directory.dart` (danh bạ NH), `bank_notification_parser.dart` (19 test), `bank_notification_service.dart`, `bank_notification_settings_view.dart`. `flutter test` +489 −8. **Nghiệm thu máy thật ĐẠT** (migration v109, cấp quyền, bắt thông báo VCB 690k → parse credit/690000/số dư 5.2tr → banner Home → mục "GD ngân hàng gần đây" → chạm tự điền số tiền + chiều). **⚠️ Khi lên store phải khai báo `BIND_NOTIFICATION_LISTENER_SERVICE` + Play Store Data safety.** Chi tiết: `[2026-08-31e]`.  
**✅ "Thanh toán qua ngân hàng" — QR VietQR + mở app NH (`[2026-08-31d]`):** khi chọn "Chuyển khoản" ở BẤT KỲ sheet thanh toán nào → hiện khối cố vấn: mã QR VietQR (số tiền + nội dung điền sẵn, tự cập nhật theo ô số tiền) + nút "Mở app ngân hàng" + sao chép STK/số tiền/nội dung. **KHÔNG đụng logic tiền** — nút Xác nhận vẫn gọi `executePaymentDirect` như cũ (đã verify máy thật: thu nợ CK → debt/debt_payments/financial_activity_log đúng, 0 regression). MỚI: `bank_accounts_service.dart` (đọc `settings/bank_qr` + prefs `bank_qr_*`), `bank_transfer_assist.dart` (`bankTransferAssistCard`, dùng `buildVietQrPayload`+`QrImageView`). Cắm 10 sheet: debt_payment_sheet, collect_customer_debt, money_reconcile, create_sale, create_repair_order, create_purchase_order, expense ×2, sale_detail (tất toán), repair_detail ×3, pending_payments. `AndroidManifest` +`<queries>` VIEW https. `flutter test` +470 −8. **Đợt 3 chưa làm:** đọc thông báo app NH tự động. Chi tiết: `[2026-08-31d]`.  
**✅ Fix badge "N cần đồng bộ" ảo (`[2026-08-31c]`):** `SyncHealthCheck` lệch số local↔cloud vì bản ghi local đã **xoá mềm** (`deleted=1`) mà Firestore còn `deleted:false`; auto-fix "tải lại" vô hiệu (model `Debt` không round-trip `deleted`) ⇒ kẹt vĩnh viễn. Sửa: vòng auto-fix `_checkCollection` phát hiện "cloud còn sống + local xoá mềm + đã synced" → **enqueue lệnh `delete`** (không hồi sinh) + `syncAll()` sau khi kiểm tra. `_entityTypeByCollection` / `_getLocalRowByFirestoreId` / `_enqueueCloudDelete` (mới). Máy test M: 2 công nợ `debt_partner_debt_rep_1787400740715…` (90k) + `debt_stock_vuLGqRt7…` (10tr, đã trả) — xoá 30/8 chưa đẩy lên cloud. `flutter test` +470 −8. Chưa nghiệm thu máy thật. Chi tiết: `[2026-08-31c]`.  
**✅ Chạm phụ tùng / dịch vụ trong đơn sửa (`[2026-08-31b]`):** mục Phụ tùng — mỗi dòng chạm được → `InventoryDetailView` đúng SP (tra `productId` → tên → fallback Kho Linh kiện); mục Dịch vụ — chạm dòng → `SimilarRepairHistoryView` các đơn khác dùng dịch vụ cùng tên (bỏ dấu). `repair_detail_view`: `_openPartInInventory`/`_openPartsWarehouse`/`_openServiceHistory`. `flutter test` +470 −8. Chi tiết: `[2026-08-31b]`.  
**✅ "Đã giao" là trạng thái cuối khi đồng bộ (`[2026-08-31a]`):** sửa lỗi "NV đã giao + chủ A đã duyệt (status 4) nhưng máy chủ B vẫn CHƯA GIAO". (1) `SyncService._shouldAcceptCloudData` — luật *trạng thái cuối*: cloud `status >= 4` & không `pendingDeliveryApproval` mà local `status < 4` → **LUÔN nhận cloud** (bỏ qua timestamp/`isSynced`/lệch giờ) + `_dropStaleRepairQueueEntry`. (2) `SyncOrchestrator._handleUpdate` — *guard đảo ngược*: trước khi push đơn sửa `status < 4`, đọc cloud; nếu cloud đã `status >= 4` & không chờ duyệt → bỏ field trạng thái giao (`status`/`deliveredAt`/`deliveredBy`/`deliveredByUid`/`pendingDeliveryApproval`) khỏi merge, vẫn sync ghi chú/linh kiện/giá vốn. `flutter analyze` 0 error mới; `flutter test` +470 −8. **Chưa nghiệm thu 2 máy thật.** Chi tiết: `[2026-08-31a]`.  
**✅ Điều hướng Bảng giá/Đối soát + xem đơn gốc (`[2026-08-30w]`):** (1) `PriceBookView`+`openPriceBook(initialTab:)` — lối tắt "Bảng giá sửa chữa" ở tab Sửa chữa (→ tab 0), "Bảng giá bán hàng"+"Đối soát tiền về" ở tab Bán hàng (→ tab 1). (2) Đối soát: mỗi kết quả có nút ↗ mở đơn/công nợ gốc (`_openSource`: trả góp→SaleDetail; công nợ theo `linkedType`/tiền tố fid→đơn bán/sửa; fallback→DebtView). (3) Dialog ghim giá thêm "Xem N đơn/SP" (`repairSourcesFor`/`saleSourcesFor`; repair→`SimilarRepairHistoryView` bấm mở chi tiết, sale→sheet SP). (4) `repair_detail_view._loadPartSuppliers` tra NCC theo `productId` cho phụ tùng đơn cũ. `PriceBookRow`+`src1..src4`. `flutter test` +470 −8. Chưa nghiệm thu adb. Chi tiết: `[2026-08-30w]`.  
**✅ Bảng giá P3 + đơn sửa NCC linh kiện (`[2026-08-30v]`):** (1) `PartUsedDetail`+`supplier` → `repair_detail_view` mục Phụ tùng liệt kê `Tên xSL · NCC: X`. (2) List giá làm gọn + thêm ô **Vốn** (Thu/Bán·Vốn·Lãi). (3) **Cảnh báo giá lệch >35%** khi tạo đơn sửa. (4) **Hệ số giá mùa vụ** (`PriceBookService.seasonPct`, SharedPrefs, chỉ áp giá ĐỀ XUẤT) — menu ⋮ + banner. (5) **Xuất/Nhập Excel** bảng giá (`exportToExcel`/`importFromExcel`, khớp theo cột `_khoá`); `ExcelExportHelper` thêm `writeSheet`+`saveAndShare` công khai. Chưa làm: giá lẻ/sỉ/khách quen. `flutter test` +470 −8. Chưa nghiệm thu adb (tiết kiệm token). Chi tiết: `[2026-08-30v]`.  
**✅ Bảng giá (`[2026-08-30u]`):** màn duyệt giá đề xuất (trung vị lịch sử) cho sửa chữa & bán hàng + **ghim giá niêm yết** + tự điền vào form. `price_book_models.dart` + `price_book_service.dart` + `price_book_view.dart` (MỚI, layer mỏng trên `PricingEngineService` + `ProductPricingService`). Ghim lưu SharedPreferences (`pricebook_pins_v1`, THEO MÁY — chưa đồng bộ). `resolveRepair/resolveSale` (GHIM → trung vị → không có) cho form. `proposeSalePrices/commitSalePrices` = áp giá hàng loạt cho SP chưa có giá. `create_repair_order_view` hiện thẻ "GIÁ NIÊM YẾT" + tự điền nếu ô giá trống. Lối tắt Home (thẻ TRUY CẬP NHANH TÀI CHÍNH) + KB `price-book` + nhiệm vụ checklist. `flutter analyze` 0 error mới; `flutter test` +469 −8 (9 test). Máy thật Oppo: màn render + ghim + badge NIÊM YẾT + áp-giá-hàng-loạt OK; thẻ trong form đã wire, chưa nghiệm thu trực quan qua adb. Chưa tăng version. Chi tiết: `[2026-08-30u]`.  
**✅ Đơn sửa ĐÃ GIAO vẫn sửa được (`[2026-08-30t]`):** bỏ khóa `status < 4` ở khối Quick actions của `repair_detail_view` — đơn Đã giao nay thêm/đổi/xóa linh kiện, ghi chú KTV, và **"Sửa KTV"** (nút mới → `_editTechnician()`: dialog chọn KTV từ danh sách nhân viên shop + bỏ gán + cảnh báo tính lại hoa hồng → `_saveData()` + audit `REPAIR_TECHNICIAN_CHANGED`). Có dòng nhắc "Đơn đã giao — thay đổi được ghi nhật ký". Handler linh kiện tái dùng nguyên bản (đã có audit + trả kho). KB `repair-status` cập nhật. `flutter analyze` 0 error mới; `flutter test` +460 −8. Máy thật Oppo: đơn "ĐÃ GIAO" hiện đủ nút; Sửa KTV → dialog + chọn → lưu OK, 0 exception. Chưa tăng version. Chi tiết: `[2026-08-30t]`.  
**✅ "Đối soát tiền về" (`[2026-08-30s]`):** nhập số tiền nhận/chuyển → app tự tìm đơn trả góp NH chưa tất toán hoặc khoản công nợ (khách/NCC) có số khớp → hiện danh sách → xác nhận → ghi nhận + cập nhật trạng thái. Màn mới `money_reconcile_view.dart` + `money_reconcile_service.dart` (MỚI). **Không viết lại logic tiền:** công nợ → `PaymentIntentService.executePaymentDirect` (y hệt `debt_payment_sheet`); trả góp → bản sao 1:1 khối tất toán của `sale_detail_view._openSettlementDialog`. `db.getPendingSettlementSales()` MỚI. Lối tắt: Home (thẻ TRUY CẬP NHANH TÀI CHÍNH), Sổ quỹ + Công nợ (icon AppBar), Tài chính (menu ⋯). Mục KB `money-reconcile` + nhiệm vụ checklist. `flutter analyze` 0 error mới; `flutter test` +460 −8. **Máy thật:** search + sort + nhãn + dialog xác nhận OK; nút Xác nhận-ghi (write) chưa kích được qua adb (kẹt IME) → **chủ shop nên ghi thử 1 khoản thật để nghiệm thu cuối.** Chưa tăng version. Chi tiết: `[2026-08-30s]`.  
**✅ Lớp khám phá tính năng (`[2026-08-30r]`):** để người dùng tự tìm hết ~40 tính năng. (1) Lối tắt "Hướng dẫn" ở Home nay mở `HelpCenterView` (KB, ~47 mục) thay `UserGuideView`; `HelpCenterView` thêm `initialTopicId` (deep-link). (2) **`feature_catalog_view.dart`** (MỚI) — "Tất cả tính năng" nhóm theo 8 khu, tìm kiếm, chi tiết + nút "Hỏi AI về mục này". (3) **Thẻ "Khám phá Ứng Dụng"** ở Home (`discovery_card.dart` + `discovery_service.dart` + `discovery_checklist.dart`, MỚI) — checklist 15 việc, tiến độ, lọc vai trò, tự tick từ dữ liệu (đơn sửa/bán/SP) + tick tay, nút Ẩn; + dòng **"Mẹo hôm nay"** xoay vòng. (4) AI chào bằng 3 câu hỏi mẫu xoay theo ngày + chip "📚 Tất cả tính năng"; `AiNavBridge.ask()` (MỚI) cho màn khác nhờ AI trả lời hộ. `AppKnowledgeBase` thêm `areas/areaOf/entriesByArea/sampleQuestionSpread/tipOfTheDay`. `flutter analyze` 0 error mới; `flutter test` +460 −8. **Nghiệm thu máy thật Oppo CPH2203: tất cả màn/luồng mới OK; phát hiện + sửa 4 lỗi hiển thị** (câu "…thế nào?" trả số liệu thay hướng dẫn → cổng `preferKb`; 2 overflow ở `help_center_view` Nổi bật/chi tiết; `offlineAnswer` chèn thuật ngữ kém liên quan) — đã build lại + xác minh. Chưa tăng version. Chi tiết: `[2026-08-30r]`.  
**✅ AI Trợ Lý — Knowledge Base (`[2026-08-30q]`):** để AI "hiểu toàn bộ app + trả lời mọi câu hỏi tính năng". (1) `lib/data/app_knowledge_base.dart` (MỚI) = nguồn sự thật DUY NHẤT: ~40 `KbEntry` (mọi màn/tính năng: menu path, làm gì, khi nào, các bước, lưu ý, câu hỏi mẫu, vai trò) + ~25 `KbTerm` (định nghĩa chuẩn: dòng tiền/dồn tích/chốt quỹ/giá vốn đơn sửa/nhập tạm…). (2) `lib/services/ai_knowledge_service.dart` (MỚI): `retrieve` (chấm điểm + lọc vai trò + chống khớp nhầm do bỏ dấu), `offlineAnswer` (trả lời how-to hoàn toàn offline, không tốn cloud, dùng được cho nhân viên), `buildCloudContext` (≤2600 ký tự gửi kèm). (3) `ai_chat_overlay._send` thêm bước KB trước khi lên cloud; `askAI(role:)` gửi kèm `knowledge`+`role`. (4) CF `chatAssistant`: nhận `knowledge`+`role`, prompt viết lại gọn + ghim thuật ngữ chuẩn, **phân quyền server-side** (finance/debt chỉ owner/manager) — **cần `firebase deploy --only functions`**. (5) `help_center_repository.topics` = curated + KB-sinh → Trung tâm trợ giúp ~47 mục, chung nguồn với AI. (6) log feedback thêm `matchedKb`. Quick-answer thêm "khách X nợ bao nhiêu". `flutter analyze` 0 error; `flutter test` +451 −8 (16 test KB mới). Chưa tăng version. **Sau này đổi tính năng PHẢI cập nhật `app_knowledge_base.dart`.** Chi tiết: `[2026-08-30q]`.  
**✅ Phân loại giá vốn đơn sửa (`[2026-08-30p]`):** đơn sửa `cost = 0` trước lẫn 2 nghĩa "chưa nhập" vs "không tốn linh kiện". Nay dùng `repairs.costRecordedAt` phân biệt: dialog "Tài chính đơn sửa" (`repair_detail_view`) thêm ô tích **"Đơn này KHÔNG tốn giá vốn (0đ)"** → set `costRecordedAt=now`, ẩn ô nhập, không popup ghi quỹ, hoàn nhập nếu lỡ ghi. Chi tiết đơn hiện dòng *"Không tốn giá vốn (0đ)"* (xám) vs *"Chưa ghi nhận giá vốn"* (cam) khi `cost=0`. Home CẦN XỬ LÝ (`dashboard_cards`) cảnh báo "đơn sửa tuần này chưa có giá vốn" lọc thêm `costRecordedAt IS NULL OR = 0` → đơn đã đánh dấu "không tốn" hết bị nhắc. `flutter analyze` 0 error; `flutter test` +435 −8. Chưa tăng version. Chi tiết: `[2026-08-30p]`.  
**✅ Dọn docs + fix "Không tìm thấy đơn gốc" (`[2026-08-30o]`):** (1) `debt_view._openSourceOrder` chỉ tra sales+repairs → nợ NHẬP KHO (`debt_stock_*`/`debt_cost_*`/`debt_part_*`, linkedId trỏ `stock_entries` không lưu local hoặc product) luôn báo "không tìm thấy" dù SP không xoá. Nay hiện bảng "Nguồn khoản nợ" (loại suy từ tiền tố fid + đối tượng/nội dung/số tiền/ngày). (2) Xoá 148 file docs lỗi thời: 14 báo cáo one-off ở gốc, `DOCS/BLUEPRINT/` (124, auto-gen tháng 5), `DOCS/UX_AUDIT/` (8), trùng lặp + `.firebase/` khỏi git. Giữ CHANGELOG/HANDOVER/INDEX/release_notes/vocabulary/test docs. Chưa tăng version. Chi tiết: `[2026-08-30o]`.  
**✅ Hoạt động hôm nay — đơn sửa chi tiết hơn (`[2026-08-30m]`):** `dashboard_cards` feed nay tách 3 mốc: "Nhận sửa" / **"Sửa xong"** (status 3, mốc `finishedAt`) / "Giao máy" (status 4) + phụ đề lỗi máy + KTV/người giao. Query `repairs` thêm cột `issue/finishedAt/repairedBy/deliveredBy` + WHERE `finishedAt >= đầu ngày`. Chưa tăng version. Chi tiết: `[2026-08-30m]`.  
**✅ Fix 4 điểm (`[2026-08-30l]`):** (1) công cụ dọn dữ liệu → CÔNG NỢ lọc bỏ nợ 0đ/đã trả hết/huỷ; (2) `generateProductName` trả '' khi thiếu model + bỏ brand "KHÁC" → hết đẻ tên "KHÁC MỚI" (hàng cũ cần sửa tay); (3) Sổ quỹ AppBar bọc `FittedBox` hết overflow ngày; (4) danh sách bảo hành thêm SĐT + thời hạn BH + nội dung sửa. Chưa tăng version. Chi tiết: `[2026-08-30l]`.  
**✅ CẦN XỬ LÝ giới hạn "tuần này" (`[2026-08-30k]`):** 2 cảnh báo "Tiền NH chưa tất toán" + "đơn sửa chưa có giá vốn" trong khung CẦN XỬ LÝ (home) trước đếm toàn thời gian, nay scope `soldAt`/`deliveredAt >= đầu tuần này` (Thứ 2 00:00) + đổi nhãn "tuần này". `dashboard_cards.dart`. Chưa tăng version. Chi tiết: `[2026-08-30k]`.  
**✅ Phân quyền thông báo tài chính (`[2026-08-30j]`):** thông báo `type:'finance'` + `type:'debt'` giờ chỉ tới **chủ shop + quản lý** (không còn tới nhân viên/kỹ thuật). Cổng chính: CF `getAllowedRolesForNotificationType` (`functions/index.js`) → `['admin','owner','manager']` — **cần `firebase deploy --only functions`**. Lớp 2: client `_isNotificationForCurrentContext` chốt theo `getCachedRole()`. `'payment'` (thanh toán đơn) giữ nguyên. Chưa tăng version. Chi tiết: `[2026-08-30j]`.  
**✅ Thông báo MỌI hoạt động tài chính (`[2026-08-30i]`):** `NotificationService.notifyFinancialActivity` (mới, `type:'finance'`) gọi tự động trong `PaymentIntentService.executePayment` cho mọi loại thanh toán (bán/sửa/chi phí/thu khác/lương/trả góp...); `createDebtRecord` thêm cờ `notify` → 7 điểm tạo nợ NCC khi nhập hàng bật `notify:true`; `cash_closing_view` báo "🔒 ĐÃ CHỐT QUỸ". Không báo trùng nợ (đã có `notifyDebtActivity`). Chưa gắn VOID/đảo bút toán + log sửa chữa nội bộ. Chưa tăng version. Chi tiết: `[2026-08-30i]`.  
**✅ Thông báo + Hoạt động cho công nợ (`[2026-08-30h]`):** `NotificationService.notifyDebtActivity` (mới, broadcast `type:'debt'` + FCM) gọi từ `debt_payment_sheet` (thu/trả nợ), `create_sale_view` (đơn CÔNG NỢ mới), `_writeOff` (miễn nợ). `dashboard_cards` thêm query `debts` tạo trong ngày → hiện ở "Hoạt động hôm nay". Chưa gắn cho công nợ nội bộ tự sinh (tránh spam). Chưa tăng version. Chi tiết: `[2026-08-30h]`.  
**✅ Hướng dẫn dễ dùng — Phase C (`[2026-08-30g]`):** 3 màn tài chính appbar tự vẽ (FinanceV2 5-tab, Báo cáo ngày, Sổ quỹ/Chốt quỹ) nay có ⓘ + hộp hướng dẫn "bản chất" (dòng tiền vs dồn tích, công thức chốt quỹ, lệch quỹ). `helpButton` thêm tham số `color`; key mới `keyFinanceDailyReport`, `keyCashClosing`; `keyFinanceTab` (trước chết) nay dùng. Guide trigger qua `addPostFrameCallback`. → **toàn bộ màn nghiệp vụ chính đã có ⓘ.** Chưa tăng version. Chi tiết: `[2026-08-30g]`.  
**✅ Hướng dẫn dễ dùng — Phase B (`[2026-08-30f]`):** thêm bước "🎯 Màn này để làm gì?" (khung ĐỂ LÀM GÌ/KHI NÀO DÙNG/VÍ DỤ) vào đầu hộp hướng dẫn 6 màn khó (Tạo đơn bán + viết lại step hình thức thanh toán, Công nợ, Nhập kho TM, Hàng chờ xác nhận, Chi phí, DS SP); empty state Công nợ "biết nói" + nút "Thêm khoản nợ"; thêm chủ đề "Thuật ngữ tài chính & công nợ" (9 mục: dòng tiền vs dồn tích, chốt quỹ, trả góp NH, giá vốn...) vào Trung tâm trợ giúp. Chưa tăng version. Phase C: ⓘ cho FinanceV2/Sổ quỹ (appbar tự vẽ). Chi tiết: `[2026-08-30f]`.  
**✅ Hướng dẫn dễ dùng — Phase A (`[2026-08-30e]`):** hộp `FirstTimeGuideService` trước chỉ hiện 1 lần rồi mất. Nay: `_cache` + `reopenGuide()` + `helpButton()`; `CustomAppBar.build`/`buildWithTabs` thêm `guideKey` → nút ⓘ trên thanh tiêu đề **18 màn** (Công nợ, Tạo đơn bán/sửa, DS bán/sửa, Kho, Nhập kho ×3, Kiểm kho, Xác nhận nhập kho, Đơn nhập hàng, NCC-Đối tác, Khách hàng, Chi phí, Lương, Chấm công, Bảo hành, Trang chủ) → bấm mở lại hướng dẫn bất cứ lúc nào. `flutter analyze` sạch, `flutter test` +435 −8. Máy thật Oppo: ⓘ ở Công nợ mở lại hộp OK. **Phase B (chưa làm):** nội dung 3 câu *Để làm gì/Khi nào dùng/Ví dụ* cho 4 nhóm khó + empty state + màn Cẩm nang. Chi tiết: `[2026-08-30e]`.  
**✅ FIX công nợ 2 lỗi (`[2026-08-30d]`):** (1) thanh toán xong không trừ nợ — echo cũ doc `debts` ghi đè `paidAmount`; (2) mỗi tài khoản một số công nợ khác nhau (NCC + đối tác SC) — nhận `debt_payments` từ cloud nhưng không tính lại `debts.paidAmount`. Gốc chung: `paidAmount` không tự khớp từ sổ cái `debt_payments` giữa các máy. Fix: `SyncService._reconcileDebtFromPaymentRow` gọi `updateDebtPaid(markUnsynced:false)` sau mỗi lần nhận phiếu từ cloud (realtime + batch) + `updateDebtPaid` thêm cờ `markUnsynced` + no-op khi không đổi + `_shouldAcceptCloudData` thêm `debts` vào chốt so-timestamp như `repairs`. **Test máy thật:** trả 500k nợ NCC → paidAmount 0→500k, giữ nguyên sau 15s chờ echo. Unit test mới 6 case. `flutter test` +435 −8. Chi tiết: `[2026-08-30d]`.  
**✅ FIX nút MIỄN NỢ (`[2026-08-30c]`):** Công cụ dọn dữ liệu → CÔNG NỢ → "Miễn nợ" — nút MIỄN NỢ xám bấm không được dù đã gõ lý do. `AlertDialog` thiếu `StatefulBuilder` → `onPressed` gate theo ô lý do chỉ tính 1 lần lúc build (rỗng → disabled) → nút chết vĩnh viễn. Fix: bọc `StatefulBuilder` + `onChanged→setLocal`. Kèm: 2 dialog "Sửa số lượng" (KHO & SP) nay báo snackbar khi thiếu lý do / số lượng sai thay vì im lặng thoát. `flutter analyze` sạch. Chi tiết: `[2026-08-30c]`.  
**✅ UI nhỏ (`[2026-08-30b]`):** (1) màn TẠO ĐƠN BÁN thêm thẻ "💡 GIÁ THAM KHẢO" (giá vốn/giá bán median lịch sử nhập cùng model, dùng chung `ProductPricingService` với màn nhập kho) vào bottom sheet Tặng/Giảm giá/💰 Sửa giá bán — kiểu THAM KHẢO không tự điền, có nút "DÙNG GIÁ BÁN"; ẩn Vốn/Lợi nhuận nếu thiếu quyền `allowViewCostPrice`; dòng SP chưa có giá đổi thành cảnh báo cam chạm được. (2) `sale_invoice_preview_view` QR chuyển khoản `size 180→150`. `flutter analyze` 0 error/warning; `flutter test` +429 −8. Chưa nghiệm thu trực quan máy thật (thuần UI). Chi tiết: `[2026-08-30b]`.  
**✅ E2E BÁN HÀNG — ĐỦ MỌI HÌNH THỨC THANH TOÁN (`[2026-08-30a]`):** test end-to-end trên máy thật (Oppo CPH2203, shop "M") 9 kịch bản, mỗi cái đối chiếu Giao dịch → DB (sales/debts/debt_payments/products/`financial_activity_log`) → tiền mặt/NH → doanh thu/vốn/lãi: **TIỀN MẶT · CHUYỂN KHOẢN · KẾT HỢP · CÔNG NỢ đủ · CÔNG NỢ trả trước 1 phần · TRẢ GÓP (NH) 1 ngân hàng · TRẢ GÓP (NH) 2 ngân hàng · Ghi chi phí · Thu nợ toàn bộ** — tất cả PASS từng đồng. **2 fix phát hiện qua test:** (1) nút **HOÀN TẤT ĐƠN HÀNG** gần như không bấm được — màn Tạo đơn bán thiếu `SafeArea` đáy → nút bị vùng chạm nav bar 3-nút nuốt → bọc `SafeArea(top:false)`; (2) **CÔNG NỢ trả trước 1 phần: TIỀN THỰC THU không được book** — nhánh CÔNG NỢ nhét số trả trước vào `debts.paidAmount` mà không tạo `debt_payments` / không ghi ledger / không cộng tiền (sổ quỹ + chốt quỹ thiếu, `paidAmount` lệch tổng phiếu) → `create_sale_view` gọi `executePaymentDirect(customerDebtCollection)` cho phần trả trước + `payment_intent_service` mở guard handler nợ chạy khi có `debtId` **HOẶC** `debtFirestoreId`. **Dọn dữ liệu test + đối chiếu cuối `recon16.py` = 16/16 PASS DIFFERENCE 0**, delta BASE→FINAL: mọi aggregate tiền = 0 (chỉ lệch −10tr kho do finding `deleteSaleWithReversal` không kích hoạt lại điện thoại serial — VỐN TỒN KHO đã lọc `status=0` nên không sai). `flutter test` +429 −8 (không hồi quy). Chi tiết: `[2026-08-30a]`.  
**✅ LÀM DỨT ĐIỂM AUDIT TÀI CHÍNH (`[2026-08-29s]`):** sửa nguồn L-1 (mirror đối tác khỏi expenseOut), L-2 (CÔNG NỢ parts fund không tiền ra ảo), L-3 (`partnerFirestoreId` khoá ổn định + backfill v108), L-4 (dọn payment_intent VOID), D-1 (`CashClosingNotifier` là NGUỒN thật của chốt quỹ ma — đã vá đi qua `upsertCashClosing` có định danh), D-2 (sync cascade xoá `sales_return_items` + cột `deleted` v108), D-3 (`executePayment` bù bút toán khi bước 6 lỗi + `_insertExpenseOnce` idempotent), D-3b (`SALE_VOID` = tiền THỰC thu), D-4 (SKU 2226 status=0/qty=3 — KHÔNG tự đổi, VỐN TỒN KHO đã lọc status=0). **Dọn dữ liệu tồn máy thật** qua Công cụ điều chỉnh dữ liệu → tab TÀI CHÍNH (cổng mật khẩu + audit): bù 3 VOID sai biên độ, đảo AUDITTESTCHI, xoá 6 item trả hàng mồ côi, hủy 14 payment_intent VOID. **Đối chiếu 16 nhóm Python `pre.db`→`post4.db`: DIFFERENCE = 0 cả 16.** `flutter test` +429 −8 (13 test mới, 3 test đỏ sẵn có đã sửa, 8 lỗi còn lại là môi trường). Chi tiết: `[2026-08-29s]`.  
**Bottom sheet bàn phím che ô nhập (`[2026-08-29r]`):** widget mới `KeyboardAwarePadding` (`lib/widgets/keyboard_aware_padding.dart`) đọc bàn phím từ `platformDispatcher.views.first.viewInsets` + `didChangeMetrics` — reactive nhưng zero InheritedWidget dep nên KHÔNG crash `_dependents.isEmpty` (kỹ thuật của `QuickActionBubble`). Thay `Padding(bottom: MediaQuery.viewInsetsOf(context)...)` ở ~26 bottom sheet có ô nhập trong 17 file (repair_detail, debt_view×4, expense_view×2, sale_detail, attendance×9, inventory×2, cash_closing, create_repair_order, category/community/missing_info/salvage/hr_salary/variant/pty_print, debt_payment_sheet, storage_location_selector). KHÔNG đụng sheet StatefulWidget riêng đã reactive + sheet picker không có ô nhập + `showDialog`. `flutter analyze` sạch, `flutter test` +410 −11.  
**Trả góp + Chốt quỹ (`[2026-08-29q]`):** hoàn tất reconciliation nhóm 11 (trả góp) + 12 (chốt quỹ) — trước NOT VERIFIED/BLOCKED. Sửa lỗi: đơn trả góp tất toán NH ở ngày ≠ ngày bán không được ghi `settlementIncome`/giá vốn ở Sổ quỹ offline + Báo cáo ngày (2 truy vấn mới trong `db_helper`, 2 call site). Test máy thật với đơn trả góp giả lập: `analyze()` `settlementIncome=15tr`/`saleCost` bù trừ đúng, chốt quỹ `expected = opening + in − out` khớp tuyệt đối (`cashEnd=4.010.000`, `bankEnd=17.000.000`). Dữ liệu test đã dọn sạch (soft-delete qua SyncOrchestrator). `HomeView`/`MonthlyProfitReportView`/Sổ quỹ online KHÔNG bị (đã có query riêng).  
**Release:** AAB `flutter build appbundle --release --obfuscate` (script `scripts/build_release.ps1`), ký upload-keystore (`CN=huy,O=huluca`) → `build/app/outputs/bundle/release/app-release.aab` (77 MB, versionCode 546, versionName 3.5.0, native symbols, minify+shrink) — **sẵn sàng upload Play Console**. Symbols de-obfuscate: `build/debug-info/`. Bước `--split-per-abi` APK của script báo lỗi exit 1 (do `build.gradle.kts` cố định `abi.isEnable=false` vs flag `--split-per-abi`) — KHÔNG ảnh hưởng store; APK universal vẫn OK ở `build/app/outputs/flutter-apk/app-release.apk` (122 MB). Release notes: `docs/release_notes_2026-08-29.md`. Store metadata What's New → v3.5.0. Xem `[2026-08-29p]`.  
**Build Status:** ✅ `flutter build apk --debug` OK, đã cài + test trên Oppo CPH2203 (`m@m.com`/shop "M") — xem `[2026-08-30a]`, `[2026-08-29o]`, `[2026-08-29n]`, `[2026-08-29m]`, `[2026-08-29l]`, `[2026-08-29k]`, `[2026-08-29j]`, `[2026-08-29i]`, `[2026-08-29h]`, `[2026-08-29g]`, `[2026-08-29f]`, `[2026-08-29e]`, `[2026-08-29d]`, `[2026-08-29c]`, `[2026-08-29b]`, `[2026-08-29a]`, `[2026-08-24q]`, `[2026-08-24p]`, `[2026-08-24o]`, `[2026-08-24n]`, `[2026-08-24m]`, `[2026-08-24l]`, `[2026-08-24k]`, `[2026-08-24j]`, `[2026-08-24i]`, `[2026-08-24h]`, `[2026-08-24g]`, `[2026-08-24f]`, `[2026-08-24e]`, `[2026-08-24d]`, `[2026-08-24c]`, `[2026-08-24b]`, `[2026-08-24a]`, `[2026-08-23d]`, `[2026-08-23c]`, `[2026-08-23b]`, `[2026-08-23a]`, `[2026-08-22a]`  
**Analyze Status:** ✅ 0 compile error (chỉ info/warning có sẵn từ trước)  
**Database Version:** SQLite v108 (v107 → v108 `[2026-08-29s]`: xoá `cash_closings` vô định danh + thêm `sales_return_items.deleted` + `repair_partner_payments.partnerFirestoreId` + backfill khoá đối tác thận trọng)  
**Branch:** master  
**✅ Đã TEST trên máy thật (2026-08-29, ADB automation) — refactor `createDebtRecord` (`[2026-08-24q]`):** chạy 7 nhóm test tạo công nợ CÔNG NỢ end-to-end trên Oppo CPH2203, xác minh qua SQLite `debts` + logcat. **6 luồng PASS** (debt #98–#104, tất cả `status=ACTIVE` + `isSynced=1` — đúng 2 fix của refactor): sửa giá vốn SP (`inventory_view:1753`), nút "+" NHẬP THÊM linh kiện (`parts_inventory_view:1474`), Thêm linh kiện mới (`parts_inventory_view:2477`), tạo đơn sửa + dịch vụ đối tác (`create_repair_order_view:848`), xác nhận vốn linh kiện "Nợ NCC" (`repair_detail_view:3635` — chỗ từng sai `UNPAID`, nay xác nhận ACTIVE), thêm dịch vụ đối tác vào đơn có sẵn (`repair_detail_view:6135`), Fast Stock In + xác nhận phiếu → `confirmEntry` (`stock_entry_service:811`). **3 luồng KHÔNG chạy được qua UI (không phải lỗi refactor):** (a) "Sửa" linh kiện đổi giá nhập + CÔNG NỢ — tab Linh kiện không có luồng này (giá vốn read-only, đổi qua NHẬP THÊM); (b) giao máy chọn CÔNG NỢ — tài khoản owner → `_approveDelivery():1966` không có ô chọn phương thức (chỉ luồng nhân viên `_submitForDeliveryApproval` có), call site `repair_detail_view:1138` là dead code trong block `/* */`; (c) tạo Purchase Order — `CreatePurchaseOrderView` không có entry point UI (chỉ mở từ reminder `pendingPurchase` cần sẵn 1 PO PENDING). Chi tiết: memory `project_congno_refactor_test_2026-08-29`.  
**🐛 Quan sát phụ (chưa sửa):** (1) `fast_stock_in_view.dart:1046` (`if (!isPending)`) nghi dead code — nút lưu luôn tạo phiếu draft, nợ tạo ở `confirmEntry`. (2) Logcat lặp lỗi vô hại khi load danh sách đơn sửa / xác nhận nhập kho: `Error saving shop settings locally: DatabaseException(UNIQUE constraint failed: shop_settings.firestoreId)` — INSERT thay vì upsert bảng `shop_settings`, không chặn gì, không liên quan công nợ.
**🔧 Đã làm 2026-08-29a (2 UI nhỏ):** (1) `create_repair_order_view.dart` — phần "Thêm chi tiết (bảo mật, ngoại quan, phụ kiện)" hiện sẵn khi tạo đơn sửa (cờ `_showAdvancedFields` mặc định `true`, vẫn thu gọn được). (2) `customer_debt_view.dart` + `collect_customer_debt_view.dart` — giảm đỏ chói (`#B91C1C→#EF4444` ⇒ `#A23B3B→#BE6A63`) + thu nhỏ thẻ "CÔNG NỢ HIỆN TẠI". `flutter analyze` sạch. Chi tiết: `[2026-08-29a]`.  
**✅ Đã làm 2026-08-29b (2b + 3) — user đã duyệt phương án:**  
&nbsp;&nbsp;• **(2b) Phiếu gửi khách** — `sale_invoice_preview_view.dart` + `repair_invoice_preview_view.dart`: thêm khối "Nợ cũ / Lần này / Tổng nợ" ngay dưới TỔNG TIỀN, ngay trên QR (chỉ hiện khi còn nợ thật); QR chuyển khoản đổi số tiền → **tổng nợ** (`_qrAmount`, VietQR hỗ trợ sẵn amount động). Mẫu in tùy biến có thêm `{customerTotalDebt}` `{oldDebt}`. Layout ESC/POS mặc định máy in nhiệt CHƯA đụng (cần plumbing data nợ riêng — ngoài phạm vi). **Test ADB OK**: đơn bán ABC nợ 12tr → `Nợ cũ 0 / Lần này 12.000.000 / Tổng nợ 12.000.000` + QR "Số tiền: 12.000.000 đ" đúng; phiếu sửa HUY trả tiền mặt → khối nợ không hiện (đúng). Chi tiết: `[2026-08-29b]`.  
&nbsp;&nbsp;• **(3) Home / CẦN XỬ LÝ** — `dashboard_cards.dart`: mục "trả góp NH" đổi nhãn → **"Tiền NH chưa tất toán: {tổng} đ · {N} đơn"** (query `SUM(loanAmount+loanAmount2)` cùng điều kiện query đếm đã có). **CODE ONLY — CHƯA XÁC MINH TRỰC QUAN**: shop test "M" có 0 đơn trả góp → mục không hiện (đúng logic); đã thử tạo 1 đơn trả góp qua UI để test nhưng luồng tạo đơn bán (định giá sản phẩm chưa có giá + chọn phương thức "TRẢ GÓP (NH)" + cọc + tiền vay + NH) nhiều bước, ô "Giá bán" trên thẻ SP đã chọn không lộ ra dạng field trong accessibility dump nên không tự động hoá tin cậy được — dừng theo nguyên tắc "không tạo dữ liệu test bằng mọi giá". Query là bản sao 1:1 query đếm đang chạy production (chỉ đổi `COUNT` → `SUM(loanAmount+loanAmount2)`), nhãn là chuỗi thuần → rủi ro rất thấp. **Cần xác nhận trực quan khi có đơn trả góp thật.** Chi tiết: `[2026-08-29b]`.  
**✅ (4) Lỗi layout top-inset — ĐÃ FIX + test máy thật PASS (2026-08-29c), hướng hẹp tại `CustomAppBar`:**  
&nbsp;&nbsp;**Nguyên nhân thật** (khác suy đoán ban đầu "padding.top=0"): `CustomTabBar.buildGradient/buildOnSub/build` khai `PreferredSize` cứng `Size.fromHeight(44)`, trong khi TabBar tab **icon+text** cao ~72px → `AppBar` chỉ chừa `44+44` → `Scaffold` ép `Flexible` bọc toolbar (nút Back) co còn ~16px → Back chui sau status bar. Tab **chỉ text** lệch ~2px (không thấy); tab **icon+text** lệch ~28px (thấy rõ, vd `FastInventoryInputView`, `label_designer_view`). AppBar không có TabBar: không ảnh hưởng.  
&nbsp;&nbsp;**Fix**: `lib/widgets/custom_app_bar.dart` — 3 hàm factory dựng `TabBar` 1 lần rồi lấy `tabBar.preferredSize` thật cho `PreferredSize`. KHÔNG đụng `main.dart` / observer / setState cấp app / padding từng màn.  
&nbsp;&nbsp;**Test ADB (cold start OK ~15s, không kẹt AuthGate)**: `FastInventoryInputView` Back y=131→176 ✅; `InventoryView` (không TabBar) y=176 giữ nguyên ✅; `DebtView` (buildWithTabs text) y=170→176 ✅; `PartnerManagementView` (build+buildGradient text) y=176 ✅; đổi tab qua lại + back không crash/overflow. Chi tiết: `[2026-08-29c]`.  
&nbsp;&nbsp;**(Đã thử trước đó ở `main.dart` + REVERT — không commit)**: `WidgetsBindingObserver`+`didChangeMetrics→setState`+`math.max` → app TREO ở "Đang kiểm tra phiên đăng nhập". Cô lập xác nhận đúng do fix đó. Nguyên nhân thật không liên quan `padding.top`.  
**✅ ĐÃ FIX 2026-08-29d — `shop_settings` INSERT → UPSERT idempotent:** `CategoryService._saveSettingsLocally` bỏ check-theo-`shopId`-rồi-insert (rơi nhánh INSERT khi bản ghi có sẵn nhưng shopId lệch → đụng UNIQUE trên `firestoreId` → lặp getShopSettings↔save, DB locked, cold-start ~45s). Thay bằng `db.insert(..., conflictAlgorithm: ConflictAlgorithm.replace)`. **Test máy thật:** cold-start ~45s→~6s; force-stop+mở lại ×5 đều ~5-6s; logcat 0 UNIQUE / 0 loop / 0 DB-locked. Không đổi schema, giữ dữ liệu cũ. Chi tiết: `[2026-08-29d]`.

**🔧 ĐANG LÀM — SỬA HỆ THỐNG TÀI CHÍNH (PHASE 1, sau đợt AUDIT):** kế hoạch 5 nhóm sửa các lỗi tài chính AUDIT xác nhận.
&nbsp;&nbsp;• **✅ PHASE 1.1 (`[2026-08-29e]`, commit fb9ff402, đã push)** — `analyze()` khử trùng thanh toán đối tác: Sổ quỹ/Chốt quỹ 09/08 −24 Tr → −12 Tr (khớp tab Chi + tab Tài chính). `flutter test` +410 −11 (0 hồi quy). Máy thật PASS + regression 08/08 giữ nguyên.
&nbsp;&nbsp;• **✅ PHASE 1.2 (`[2026-08-29f]`)** — VOID đơn bán/sửa dọn luôn `debt_payments` (hết phiếu thu nợ mồ côi tạo "tiền vào" ảo). `db_helper` +2 method + lọc `deleted` cho `getAllDebtPaymentsWithDetails` (nguồn Sổ quỹ). `sale_detail_view._deleteSale` + `data_reconciliation_service` (2 luồng WithReversal). `flutter test` +410 −11. Máy thật: build/cài OK, regression Sổ quỹ 15/08 +11.7 Tr giữ nguyên. **Luồng VOID end-to-end trên máy CHƯA test** (không tạo được đơn CÔNG NỢ mới qua ADB tin cậy; không xóa đơn thật để test) — logic review + tái dùng cơ chế sync-delete đã chạy prod cho `debts`.
&nbsp;&nbsp;• **✅ PHASE 1.3 (`[2026-08-29g]`)** — chặn đơn CÔNG NỢ có thành tiền ≤ 0 (`create_sale_view` + `sale_detail_view`) + không hạ công nợ thật về 0 khi sửa đơn (self-heal `totalAmount` về `finalPrice`). `flutter test` +410 −11. Máy thật build/chạy OK — 2 guard chưa nghiệm thu qua ADB (form bán hàng + edit dialog khóa PIN).
&nbsp;&nbsp;• **✅ PHASE 1.4 (`[2026-08-29h]`)** — `updateDebtPaid` định vị công nợ theo `firestoreId` + `paidAmount` = tổng phiếu `debt_payments` chưa xóa (idempotent, không cộng đôi, tự khớp lại) + `status` HOA `'PAID'/'UNPAID'` + không cap MIN (cảnh báo logcat khi vượt). `db_helper` + `payment_intent_service` (2 call site). `flutter test` +410 −11. **Máy thật PASS end-to-end**: thu 10.000đ công nợ ABC → UI/`debts.paidAmount`/`debt_payments`/`financial_activity_log`/Finance Công nợ đều khớp 11.99 Tr; `status='UNPAID'` HOA. Để lại 1 phiếu test 10.000đ trên công nợ ABC (tài khoản test). ⚠️ **Lưu ý kỹ thuật:** khi kéo DB máy thật phải kèm `repair_shop_v22.db-wal` (+ `-shm`) mới thấy write mới nhất — pull mỗi file `.db` sẽ thiếu WAL.
&nbsp;&nbsp;• **✅ PHASE 1.5 (`[2026-08-29i]`)** — tab "TÀI CHÍNH" trong Công cụ điều chỉnh dữ liệu (`data_reconciliation_view`): phát hiện + dọn (có `_confirmSummary` + `_confirmPassword`, không auto) 2 nhóm — phiếu `debt_payments` mồ côi, công nợ khách `totalAmount=0`. `data_reconciliation_service` +4 hàm. `flutter test` +410 −11. **Máy thật: phát hiện đúng** 3 phiếu mồ côi (12.8tr) + 1 công nợ `debt_1787034406889` (đặt về 10tr). **Fix chưa thực thi trên máy** — nút yêu cầu mật khẩu đăng nhập; **chủ shop cần tự vào Cài đặt → Dữ liệu & Hệ thống → Công cụ điều chỉnh dữ liệu → tab TÀI CHÍNH → bấm Xóa/Sửa từng dòng** để dọn 4 bản ghi hỏng hiện tại.
&nbsp;&nbsp;• **✅ PHASE 2 phân tích + PHASE 3.1 (`[2026-08-29j]`)** — user uỷ quyền "làm sao hợp lý nhất". Quyết định: FinanceV2 giữ vai trò **DÒNG TIỀN** (cash basis đúng chức năng), chỉ (1) bỏ 2 dòng cap `recognizedCost > actualPaid` → đơn bán dưới giá vốn hiện **lỗ âm đúng** (Lãi BH 3tr→2.95tr trên máy, −50k = đúng lỗ); (2) sửa nhãn 2 chỗ "Lợi nhuận (accrual)" → "Lãi gộp (phần đã thu)" + ghi rõ không phải lợi nhuận kế toán. `analyze()` / Báo cáo LN tháng KHÔNG đụng (đang đúng dồn tích cho CÔNG NỢ). `flutter test` +410 −11.
&nbsp;&nbsp;• **✅ PHASE 3 — mapping PHASE 2 user đã chốt (DÒNG TIỀN=cash / KẾT QUẢ KD=accrual, mỗi khái niệm 1 nguồn). Kế hoạch 3.2–3.5:**
&nbsp;&nbsp;&nbsp;&nbsp;- **✅ 3.2 (`[2026-08-29k]`)** — `finance_v2_daily_report_view` (tab "Báo cáo"): "Doanh thu/Giá vốn/Lợi nhuận" (màn hình + Excel `BaoCaoNgay_Audit`) đổi nguồn `FinanceV2` (cash) → `_analysis` (`DailyFinancialAnalysisService`, accrual); tách 2 nhóm có tiêu đề "KẾT QUẢ KINH DOANH (accrual)" / "DÒNG TIỀN (cash)". Máy thật: đơn CÔNG NỢ 200k/vốn 100k/chưa thu → Doanh thu 200k, Lợi nhuận 100k, Tiền vào 0. `flutter test` +410 −11.
&nbsp;&nbsp;&nbsp;&nbsp;- **✅ 3.3 (`[2026-08-29l]`)** — `finance_v2_view` Excel export: đổi NHÃN "Doanh thu/Vốn/Lợi nhuận" → "Tiền ... đã thu / Vốn (phần đã thu) / Lãi gộp (phần đã thu)" (số không đổi). KHÔNG đụng `_reportInputFromSnapshot` (cash-vs-cash reconciliation) + print-text ESC/POS (ngoài phạm vi). Máy thật: xuất `tong_quan.xlsx` đọc lại đúng nhãn mới. `flutter test` +410 −11.
&nbsp;&nbsp;&nbsp;&nbsp;- **✅ 3.4 (`[2026-08-29m]`)** — `monthly_profit_report_view` ô tổng kết năm: nhãn "Doanh thu/Lợi nhuận" → "(accrual)", "Tổng thu/Tổng chi" → "(dòng tiền)". Máy thật: CÔNG NỢ 200k → DThu(accrual) 200k / LN(accrual) 100k / Tổng thu(dòng tiền) 0. `flutter test` +410 −11.
&nbsp;&nbsp;&nbsp;&nbsp;- **✅ 3.5 (`[2026-08-29n]`)** — `home_view` thẻ dashboard: rename `netProfit`→`netCashToday`, chip "HÔM NAY"→"DÒNG TIỀN HÔM NAY", donut "Bán hàng/Sửa chữa"→"Tiền bán/Tiền sửa". dart analyze 0 err/warn, flutter test +410 −11, build OK. Thẻ chưa render qua ADB (opt-in dashboard card, tk test đang tắt) — thuần rename+chuỗi.
&nbsp;&nbsp;• **✅ PHASE 1 DỮ LIỆU CŨ XONG (`[2026-08-29o]`)** — đăng nhập lại `m@m.com` shop "M", dùng tab TÀI CHÍNH của Công cụ điều chỉnh dữ liệu (mật khẩu `123123`): xóa 3 phiếu mồ côi (12.8tr) + sửa debt #139 `totalAmount` 0→10tr. DB verify: orphan 69/70/71 `deleted=1 isSynced=1`, debt #139 `totalAmount=10.000.000 ACTIVE`, Nợ phải thu **21.990.000** (UI 21.99 Tr), Nợ phải trả 16.540.000 không đổi, Sổ quỹ 15/08 tab Thu "1 GD +100.000" (trước 3 GD +12.7 Tr), sync_queue=0. → 12.8tr tiền-vào ảo loại bỏ, 10tr nợ HUY hiện đúng.
&nbsp;&nbsp;• **✅ RECONCILIATION E2E (`reconF.py`) 13 nhóm:** 1-10 + 13 PASS; **11 trả góp NOT VERIFIED** (0 đơn trả góp; code review không double-count); **12 chốt quỹ BLOCKED** (`cash_closings`=0). Regression: cold-start 18s không exception, `flutter analyze` 0 err/warn, `flutter test` +410 −11 (0 lỗi mới).
&nbsp;&nbsp;• **FINANCIAL SYSTEM: PASS WITH ISSUES** (issues = 11 trả góp NOT VERIFIED, 12 chốt quỹ BLOCKED — cả 2 do thiếu dữ liệu test, không phải lỗi logic; + crash `_dependents.isEmpty` task riêng).
&nbsp;&nbsp;&nbsp;&nbsp;- **✅ PHASE 3 (3.2–3.5) XONG.** Còn **3.6 (report-only, KHÔNG code):** nhánh trả góp trong `analyze()` chỉ ghi cọc tới khi tất toán → chưa accrual thuần cho đơn trả góp (0 đơn trả góp trong data). Đề xuất fix riêng khi có đơn trả góp thật để test. Ngoài ra: crash `_dependents.isEmpty` (task riêng), 4 bản ghi hỏng tk `m@m.com` (user tự dọn tab TÀI CHÍNH).
&nbsp;&nbsp;• **✅ NGHIỆM THU LẠI trên TÀI KHOẢN TEST MỚI (2026-08-29, mật khẩu `123123`):**
&nbsp;&nbsp;&nbsp;&nbsp;- **1.3 (nhánh tạo đơn):** tạo đơn bán CÔNG NỢ 200.000đ → `debts.totalAmount = 200.000` (KHÔNG phải 0). ✅
&nbsp;&nbsp;&nbsp;&nbsp;- **1.4:** thu 50.000đ → `debts.paidAmount = 50.000` (= tổng phiếu), `status='UNPAID'` HOA, gọi lại không cộng đôi. ✅
&nbsp;&nbsp;&nbsp;&nbsp;- **1.2:** VOID đơn (Công cụ điều chỉnh dữ liệu → ĐƠN BÁN → "Xóa, hoàn tài chính") → `debt_payments` chuyển `deleted=1, isSynced=1`; `getAllDebtPaymentsWithDetails` trả **0 dòng** cho công nợ đó → Sổ quỹ/analyze/FinanceV2 hết cộng 50k vào "tiền vào". ✅
&nbsp;&nbsp;&nbsp;&nbsp;- **1.5 (empty-state):** tab TÀI CHÍNH sau VOID → "Không phát hiện dữ liệu tài chính cần dọn 👍" (VOID đã dọn đúng, không tạo mồ côi). ✅ *(detection với dữ liệu hỏng đã verify ở tài khoản `m@m.com`; fix execution chưa chạy — dùng đúng cơ chế `db.update deleted=1` + `SyncOrchestrator.enqueue(debtPayment, delete)` mà 1.2 đã verify end-to-end)*
&nbsp;&nbsp;• **🐛 BUG CÓ SẴN gặp lại (KHÔNG do PHASE 1):** `_dependents.isEmpty` màn đỏ khi đóng dialog "XÁC THỰC QUẢN LÝ" (`sale_detail_view._unlockManager`) — chặn luồng Sửa/Xóa đơn qua sale_detail (dialog reconciliation-tool `_confirmPassword` KHÔNG crash). Đã có trong memory `feedback_modal_sheet_dependents_crash`. Nên ưu tiên fix.
&nbsp;&nbsp;• **Dữ liệu test còn trên tài khoản mới:** sản phẩm TESTSP (tồn 1) + 1 chi phí nhập kho 100k. Vô hại.
&nbsp;&nbsp;• **Còn để lại (PHASE sau, cần dữ liệu / quyết định thêm):** nhánh trả góp trong `analyze()` (chia cọc/tất toán 2 kỳ thay vì dồn tích 1 lần — không có dữ liệu trả góp để test); `repair_partner_payments` mồ côi khi VOID repair (thiếu FK repair↔payment); `sale_detail_view._deleteSale` hard-delete local (cân nhắc soft-delete cho nhất quán `DataReconciliationService`); VOID đơn đã thu tiền thật có sinh bút toán hoàn tiền không; `financial_activity_log.balanceAfter*` toàn NULL (giữ audit-log); **fix `_dependents.isEmpty` crash ở `_unlockManager`**.
**✅ Đã làm (2026-08-24p):** thêm 2 mục nhắc vào khung "CẦN XỬ LÝ" ở Trang chủ — "Đã N ngày chưa chốt quỹ" (tính từ lần chốt gần nhất, hoặc từ ngày bán hàng đầu tiên nếu chưa từng chốt) và "N đơn sửa đã giao chưa có giá vốn", cả 2 bấm vào mở thẳng đúng màn hình liên quan. Thêm badge đỏ "Vốn 0đ — chưa có giá vốn" ngay trên thẻ đơn sửa trong danh sách. Đã test trên Oppo CPH2203: xác nhận cả 2 mục hiện đúng + điều hướng đúng + badge hiện đúng (chỉnh tạm 1 đơn về vốn 0đ để test, đã khôi phục lại sau). Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24p]`.
**✅ Đã fix (2026-08-24o):** Sổ quỹ đọc Firestore quá nhiều (phát hiện qua Firestore Audit Monitor: `sales` chiếm ~6.4K/8.3K lượt đọc/phiên) — do mỗi lần mở/đổi ngày đều tải TOÀN BỘ lịch sử `sales`/`expenses`/`sales_returns`, không giới hạn ngày. Đã giới hạn theo đúng khoảng ngày cần dùng (tận dụng index có sẵn, không cần deploy index mới); `sales` xử lý riêng đơn trả góp (không bound, vì tất toán NH có thể về rất lâu sau ngày bán). CỐ TÌNH chưa đụng `repairs`/`debt_payments`/... (rủi ro mất dữ liệu do nhiều mốc thời gian khác nhau, hoặc lượt đọc nhỏ không đáng ưu tiên). Test lại đúng kịch bản gộp 3 ngày ở `[2026-08-24n]` — số liệu giống hệt trước khi tối ưu. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24o]`.
**✅ Đã fix (2026-08-24n):** Sổ quỹ mất dấu tiền khi có ngày chưa chốt quỹ — trước đây "số dư đầu ngày" chỉ nhìn đúng "hôm qua", hôm qua chưa chốt thì về 0 luôn, mất hết dấu vết. Đã sửa để luôn tìm lần chốt quỹ GẦN NHẤT (dù cách đây mấy ngày) làm số dư đầu kỳ, tự gộp toàn bộ giao dịch từ sau lần chốt đó đến ngày đang xem vào cùng 1 lần tính — áp dụng đồng bộ ở Tổng quan/Thu/Chi/lúc xác nhận Chốt quỹ, kèm cảnh báo cam rõ ràng ghi rõ khoảng ngày đã gộp. Test bằng cách chèn 1 chốt quỹ giả lập 3 ngày trước vào DB thật trên máy — phát hiện thêm 1 lỗi liên quan (tab Chi ban đầu thiếu giao dịch do local DB vẫn giới hạn tải đúng 1 ngày) và đã sửa luôn. Đã dọn sạch dữ liệu test sau khi xác nhận đúng. Ngày ĐÃ chốt quỹ xem lại không đổi hành vi. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24n]`.
**✅ Đã fix (2026-08-24m):** audit toàn bộ luồng Nhập kho/Sản phẩm/Bán hàng theo yêu cầu user (vai trò người dùng thật, tối ưu cho người mới) — phát hiện + sửa 3 điểm: (1) ô "Tên điện thoại" ở NHẬP KHO MỚI bị ghi đè âm thầm bởi tên tự sinh từ Hãng/Model khi cả 2 cùng có giá trị — giờ tự đồng bộ + khóa sửa tay kèm giải thích rõ; (2) sản phẩm giá 0đ (do không bắt buộc giá bán lúc nhập kho) hiện mờ nhạt "Giá: 0" trong danh sách chọn khi bán, dễ bán nhầm — đổi thành cảnh báo đỏ đậm "⚠ Chưa định giá"; (3) khu vực chọn sản phẩm khi bán ghi cứng nhãn "ĐIỆN THOẠI" dù trộn cả phụ kiện — đổi sang "SẢN PHẨM" trung tính. Đã test cả 3 trên Oppo CPH2203: chọn Hãng "IPHONE" → tên tự đổi + khóa đúng; màn Bán hàng hiện đúng "SẢN PHẨM"/"⚠ Chưa định giá". Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24m]`.
**✅ Đã làm (2026-08-24l):** ảnh biên nhận đơn bán/phiếu sửa giờ kèm thêm ảnh sản phẩm (đơn bán, theo IMEI)/ảnh máy nhận (phiếu sửa, dùng `receiveImages` có sẵn) + QR tra cứu đơn quét được thật (trước đây chỉ là text ẩn, giờ render `QrImageView` — xác nhận `qr_router.dart` đã hỗ trợ sẵn mở đúng đơn khi quét, không phải trang trí). Gợi ý giá vốn/giá bán tham khảo (đã có ở màn Nhập kho) giờ có thêm ở màn Sửa sản phẩm — gõ Model tự hiện gợi ý median từ các sản phẩm cùng model. Đã test trên Oppo CPH2203: QR tra cứu hiện đúng trên đơn bán thật; thẻ gợi ý giá hiện đúng số liệu + áp dụng đúng vào ô giá vốn khi bấm nút. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24l]`.
**✅ Đã fix tận gốc (2026-08-24k):** lệch số "Còn nợ" NCC vs "Công nợ" (`[2026-08-24j]`) — user chọn sửa tận gốc thay vì chỉ vá số liệu. Đã sửa `PaymentIntentService` để mọi lần trả nợ NCC có liên kết phiếu nhập kho (`linkedId` = `stockEntryId`) tự đồng bộ ngược `paidAmount`/`paymentStatus` vào đúng phiếu đó; thêm hàm quét 1 lần tự sửa các phiếu đã lệch từ trước (chạy trong chu kỳ sync). **Đã test cả 2: (1)** phiếu NK-0075 cũ tự sửa đúng qua log + DB, tab Thống kê KHO TỔNG khớp tab Công nợ (còn nợ 0); **(2)** trả nợ MỚI 100.000đ cho NCC TÉT A qua "Thanh toán nhanh" thật trên máy → xác nhận qua DB cả `debts.paidAmount` và phiếu `NK-0040.paidAmount` cùng cập nhật khớp nhau ngay. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24k]`.
**✅ Đã fix (2026-08-24j):** tab Thống kê NCC đếm "Chưa thanh toán" luôn ra 0 dù có phiếu chưa trả thật — do so khớp cứng chuỗi `'UNPAID'` trong khi phiếu tạo từ luồng Nhập kho chính dùng `'DEBT'`. Đổi sang điều kiện "khác PAID". Đã test trên Oppo CPH2203, xác nhận 10+8=18 đúng tổng. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24j]`.
**✅ Đã fix (2026-08-24i):** avatar danh sách sản phẩm vẫn to dù đã đổi số 52→40px ở `[2026-08-24g]` — hoá ra thay đổi đó không có tác dụng, nguyên nhân thật là `Row` dùng `CrossAxisAlignment.stretch` (cho thanh accent trái) đã ép giãn luôn khối ảnh theo chiều cao thẻ, làm width/height khai báo cho ảnh vô tác dụng. Đã bọc `Align(alignment: Alignment.center)` quanh khối ảnh — giờ ảnh đúng là 1 ô nhỏ 30x30 canh giữa, không kéo giãn nữa. Đã test trên Oppo CPH2203, xác nhận qua ảnh chụp màn hình. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24i]`.
**✅ Đã fix (2026-08-24h):** ảnh header ở Chi tiết sản phẩm nhìn "hơi thô" (banner dẹt ngang cắt xén thô ảnh chụp dọc) — đổi sang khung vuông 1:1. Bấm vào ảnh giờ mở được trang xem ảnh toàn màn hình, phóng to/thu nhỏ bằng 2 ngón (tái dùng `FullScreenImageViewer` đã có sẵn trong bộ chọn ảnh, đổi từ private sang public). Cơ chế giảm dung lượng ảnh khi chọn ảnh đã có sẵn từ trước, đồng nhất ở cả 3 nơi thêm ảnh sản phẩm — đã xác nhận không cần sửa gì thêm. Đã test trên Oppo CPH2203. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24h]`.
**🔴 CẦN USER TỰ LÀM — Firebase Storage rules (2026-08-24g):** phát hiện qua log thật: upload ảnh sản phẩm mới (đường dẫn `uploads/products/{shopId}/{productId}/main.jpg`) bị Firebase Storage từ chối với `code=unauthorized`. File `storage.rules` KHÔNG có trong repo hiện tại (không rõ đang quản lý ở đâu — có thể chỉnh trực tiếp trên Firebase Console) nên không tự sửa/deploy được từ môi trường này. **Cần user tự vào Firebase Console > Storage > Rules kiểm tra và cho phép ghi vào đường dẫn `uploads/products/{shopId}/{productId}/**`** — trước mắt đã thêm cơ chế tự động thử lại upload (xem bên dưới) nên khi rules được sửa, các ảnh đang kẹt sẽ tự upload lại ở lần sync kế tiếp mà không cần thao tác gì thêm.
**✅ Đã fix (2026-08-24g):** 4 việc user báo ở màn Kho — (1) sửa phụ kiện (vd. "ốp") xong tên tự đổi thành "KHÁC MỚI" (bug thật: màn Sửa sản phẩm ghép tên kiểu điện thoại brand+model+tình trạng cho MỌI loại sản phẩm, kể cả phụ kiện không có model/brand — đã sửa chỉ ghép kiểu đó cho điện thoại); (2) avatar danh sách sản phẩm 52→40px cho gọn hơn; (3) ảnh đã chọn nhưng không hiện ở màn xem nhanh + Chi tiết sản phẩm (chỉ đọc `images` cloud, bỏ qua `localImagePath` — đã sửa ưu tiên hiện ảnh local trước, khớp đúng cách danh sách đã làm) — nhân tiện phát hiện + gọi luôn `retryPendingProductImages()` (viết sẵn từ trước nhưng chưa từng dùng) vào chu kỳ sync, để ảnh lỗi upload lần đầu tự thử lại thay vì kẹt vĩnh viễn; (4) audit lại trang Chi tiết sản phẩm — tách 3 khối có tiêu đề (Thông tin sản phẩm / Giá & lợi nhuận / Nhập hàng) thay vì 1 khối dài, thêm dòng Lợi nhuận tính tự động. Đã test trên Oppo CPH2203, xác nhận qua DB thật + ảnh hiện đúng ở cả 2 nơi. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24g]`.
**⚠️ Ghi chú máy test (2026-08-24):** máy Oppo CPH2203 test hiện đang ở trạng thái **"FRP lock"** (Factory Reset Protection) tầng hệ điều hành — xác nhận qua log `ChooserActivity: Sharing disabled due to active FRP lock`, khiến TẤT CẢ app trên máy này (không riêng HULUCA) không mở được share sheet hệ thống. Không phải lỗi code — cần gỡ khoá này ở Cài đặt máy (Bảo mật/chống trộm) mới test được nút "Chia sẻ ảnh cho khách" bằng thao tác tay thật.
**✅ Đã fix (2026-08-24f):** in/chia sẻ biên nhận (đơn bán + phiếu sửa) từng không báo kết quả thành công/thất bại gì — đã thêm banner xanh/đỏ rõ ràng cho cả 2 luồng. Đã test trên máy: in ra banner xanh "Đã gửi lệnh in" đúng; chia sẻ thì do máy bị khoá FRP (ghi chú trên) nên không thể tự tay xác nhận banner xanh "Đã chia sẻ..." nhưng đã xác nhận code KHÔNG báo nhầm thành công khi share sheet không mở được. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24f]`.
**🔴 Vừa fix khẩn (2026-08-24e):** nhánh `master` từng KHÔNG build được (thiếu file `lib/widgets/receipt_paper_view.dart` — bị sót, chưa commit từ phiên trước dù các file gọi hàm của nó đã push) — user báo lỗi khi build iOS trên Mac. Đã commit + push bổ sung ngay, `flutter analyze` xác nhận sạch. **User cần `git pull` lại trên Mac rồi build lại.**
**Active Initiative:** fix(kho) tab Lịch sử nhập của NCC — sản phẩm không bấm vào chi tiết được + phiếu trống không hiện gì 2026-08-24d + fix(sale,repair) bug share sheet không hiện + thêm nút chia sẻ nhanh ngoài đơn bán + đổi dialog NCC/thanh toán sang dropdown 2026-08-24c + polish(kho) bấm thẳng vào ô NCC/thanh toán để sửa, bỏ kiểu hiển thị khoá 2026-08-24b + feat(sale,repair,kho) chia sẻ ảnh gửi khách/nội bộ + đồng nhất sửa NCC/thanh toán ở màn Sửa sản phẩm + fix bug sửa lần 2 2026-08-24a + feat(kho,ncc) sửa NCC/phương thức thanh toán sau nhập kho, khớp công nợ+sổ quỹ 2026-08-23d + polish(sale,repair) thiết kế lại ảnh biên nhận/phiếu sửa giống giấy in thật, chuyên nghiệp hơn 2026-08-23c + feat(sale,repair) nút chia sẻ ảnh+QR ngay sau tạo đơn bán + đơn sửa dùng chung cơ chế ảnh+QR 2026-08-23b + feat(sale,kho) ảnh biên nhận + QR chuyển khoản VietQR qua Zalo + gợi ý giá vốn/giá bán khi nhập kho 2026-08-23a + feat(sale,debt) công nợ khách hàng gộp nhiều đơn + thu tiền phân bổ FIFO (bán sỉ) 2026-08-22 + Multi-fix session 2026-08-08/10 (audit tool, sync cost, double notification, hẹn giao máy, autocomplete khách hàng, backup đơn sửa kèm ảnh, fix sheet Thêm dịch vụ) + review/fix regression + fix danh sách bán còn nợ sai + fix 42 popup che nút (toàn bộ audit) 2026-08-15/16 + redesign Super Admin Console + broadcast có link + auto store-link theo nền tảng + fix 3 lỗi tab Cửa hàng + fix trùng tài khoản khi đăng ký + công cụ tìm/dọn trùng + deploy index thiếu + fix audit_logs retry vô hạn + fix đơn "Đã giao" hiện sai trạng thái + danh sách không bỏ sót đơn + cảnh báo quá hạn + mở khoá sửa đơn đã giao + xem đơn tương tự + ẩn giá vốn khỏi nhân viên ở "Giá tham khảo"/"Đơn tương tự" + Công cụ điều chỉnh dữ liệu (xóa đơn dư/miễn nợ/sửa kho) + dọn giao diện màn Công nợ + fix đơn sửa từ máy khác không cập nhật kịp thời + fix build iOS lỗi do thiếu file + cho phép bỏ qua yêu cầu SĐT khi giao máy + fix tab "Tất cả" trong Kho trống dữ liệu + fix overflow Firestore Audit Monitor + đổi nhãn menu Thao tác nhanh + gom mối công nợ/trả góp NH rải rác + buộc cập nhật bản cũ (version gate) 2026-08-16 + 🔴 fix đơn Duyệt giao/sửa giá vốn bị revert dữ liệu 2026-08-17
**✅ Đã fix + TEST ĐẦY ĐỦ trên máy thật (2026-08-22a):** feature lớn "Công nợ khách hàng gộp nhiều đơn" (bán sỉ) — schema mới (cột `debt_payments.paymentGroupId`, DB v105→v106), 2 màn hình mới (`CustomerDebtView`, `CollectCustomerDebtView`), service mới `CustomerDebtPaymentService` (thu tiền phân bổ FIFO nhiều đơn cùng lúc). Trong lúc test trên Oppo CPH2203 phát hiện + sửa ngay 1 bug thật: nút THU TIỀN làm cả banner phình to bất thường, nội dung biến mất — do style mặc định TOÀN APP của `ElevatedButton` (`Size(double.infinity, ...)`) xung đột với việc đặt nút trong `Row` cạnh 1 `Expanded` khác, đã sửa bằng cách ghi đè `minimumSize: Size.zero` riêng cho nút đó. Sau khi sửa: **xác nhận qua file DB kéo về từ máy** rằng migration v106 tự chạy đúng trên dữ liệu cũ thật; **chạy full luồng thật** trên khách có 2 đơn công nợ thật (1 đơn đã trả hết trước đó, 1 đơn còn nợ 2 triệu) — mở đơn → card công nợ đúng số → bấm Thu tiền → nhập 1 triệu → FIFO tự đề xuất đúng → thử sửa tay số vượt số dư bị chặn đúng → xác nhận thu → kết quả đúng "Còn 1 triệu" → quay lại màn chi tiết/màn công nợ khách/trang chủ đều cập nhật NGAY đúng số liệu → kiểm tra ngược DB xác nhận `debts.paidAmount` tăng đúng, doanh thu (`sales.totalPrice`) **không đổi**. **Chưa test:** đồng bộ 2 thiết bị cùng lúc (chỉ có 1 máy), phương thức Chuyển khoản (chỉ test Tiền mặt), phân bổ cắt ngang từ 2 đơn trở lên (dữ liệu test lúc đó chỉ còn đúng 1 đơn nợ). Chi tiết đầy đủ: `docs/CHANGELOG.md` mục `[2026-08-22a]`.
**🔴🔴 NGHIÊM TRỌNG — đã fix (2026-08-17a):** đơn "Duyệt giao máy" + "Sửa giá vốn" từng bị âm thầm mất dữ liệu — user báo màn hình hiện "thành công" (nhật ký, chat nội bộ đều xác nhận) nhưng vào lại app đơn hiện lại y như chưa làm gì. Nguyên nhân: (1) patch trạng thái lên cloud thiếu giá thu/vốn, (2) ghi cloud kiểu bắn-đi-không-đợi + nuốt lỗi im lặng vẫn báo "thành công". Đã sửa `repair_detail_view.dart`: gộp giá vào patch trạng thái, chờ xác nhận thật sự trước khi báo thành công, báo cam rõ ràng nếu mạng lỗi thay vì báo xanh gây hiểu lầm. **Đã test kỹ trên máy thật, xác nhận hết lỗi ở nhánh mạng bình thường** — nhánh mất mạng giữa chừng dựa trên suy luận code (không mô phỏng được qua adb). Chi tiết đầy đủ: `docs/CHANGELOG.md` mục `[2026-08-17a]`.
**⚠️ Lỗi TỰ GÂY RA rồi đã sửa ngay (2026-08-17b):** fix `[2026-08-17a]` ở trên có 1 lỗi logic khiến báo nhầm "mạng chập chờn" ở **MỌI đơn** dù mạng bình thường (do quên bật cờ `isSynced` trong DB khi bỏ qua bước gọi lại `syncAll()` để tối ưu) — user phát hiện ngay và báo lại trong vòng vài phút. Đã sửa + test lại ngay, xác nhận hết báo nhầm.
**✅ Đã fix triệt để, test kỹ trên máy thật (2026-08-17c):** phần "list không tự cập nhật" ở mục `[2026-08-17b]` chỉ mới sửa đúng 1 nửa — chỉ gọi `_refreshFromSQLite()` không đủ vì đơn CHƯA giao được hiển thị từ cache realtime Firestore riêng (ưu tiên hơn SQLite trong lúc gộp dữ liệu), user test lại vẫn thấy đơn Samsung hiện sai trạng thái trong list. Đã sửa đúng gốc: đồng bộ ngược bản ghi mới nhất thẳng vào cache realtime (không chỉ SQLite) ngay khi quay lại từ màn chi tiết. Test trực tiếp 2 lần trên 2 đơn khác nhau qua adb (không restart app) — cả 2 đơn đều biến mất khỏi danh sách "chờ xử lý" ngay lập tức sau khi đổi trạng thái + back, kèm toast xác nhận. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-17c]`.
**🔴 CẦN USER TỰ LÀM — build iOS (2026-08-17e):** đã lên bản **3.4.0+545** (`pubspec.yaml`) gồm toàn bộ fix trong ngày, và nâng `IPHONEOS_DEPLOYMENT_TARGET` iOS 14.0 → 15.0 (`ios/Podfile`, `Runner.xcodeproj`, `AppFrameworkInfo.plist`) theo đúng cảnh báo Apple mục `[2026-08-16]` bên dưới. Android đã build+cài+xác nhận version đúng, không crash trên Oppo CPH2203. **iOS KHÔNG build được ở đây** (máy Windows, không có Xcode) — user cần tự `git pull` trên Mac rồi `pod install` (sẽ tự áp dụng target 15.0 mới) + archive/submit App Store Connect bình thường.
**✅ Đã fix (2026-08-17d):** trong lúc test toàn diện module Sửa chữa, phát hiện + sửa 2 việc: (1) xóa đơn sửa (cả nút xóa gốc lẫn Công cụ điều chỉnh dữ liệu) mồ côi document trên Firestore vĩnh viễn khi mạng lỗi giữa chừng — nguyên nhân gây "Trung tâm đồng bộ" báo lệch Local/Cloud không tự hết (đã thấy thật: Local 59/Cloud 70, lệch 11) — đã sửa để xếp hàng đợi retry thay vì bỏ cuộc âm thầm. (2) `DebtPaymentSheet` từng âm thầm đoán "Thu nợ khách" khi thiếu field `type` thay vì báo lỗi — đã chặn lại, bắt báo lỗi rõ ràng. **Lưu ý minh bạch:** user báo 1 lần crash (màn đỏ) khi thanh toán nợ NCC dẫn tới ghi nhầm "Thu nợ KH" thay vì "Trả nợ NCC" — đã cố tái hiện và rà toàn bộ chuỗi code liên quan nhưng KHÔNG bắt được đúng nguyên nhân gốc (log đã trôi khỏi buffer), chỉ hardening được đường duy nhất code review tìm thấy có thể gây sai hướng. Nếu còn tái diễn, cần chụp lại đúng màn hình đỏ lúc crash (không chỉ kết quả sau khi thoát/vào lại) mới đủ dữ liệu để root-cause chính xác. Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-17d]`.
**🔴 Đã fix khẩn (2026-08-16p):** build iOS lỗi "No such file or directory" do `other_apps_view.dart` chưa từng được commit dù `home_view.dart` đã tham chiếu — đã commit đủ + push. **User cần tự pull code mới nhất và build lại trên Mac để xác nhận hết lỗi** (máy làm việc là Windows, không tự build iOS được).
**ℹ️ Cảnh báo Apple (không gấp):** email App Store Connect báo `MinimumOSVersion` hiện 14.0, từ mùa xuân 2027 Apple bắt buộc tối thiểu 15.0 mới cho gửi app — bản 3.3.0/541 đã gửi thành công, không phải lỗi. Cần nâng `IPHONEOS_DEPLOYMENT_TARGET` trong `ios/Podfile` + `Runner.xcodeproj` lên 15.0 trước mùa xuân 2027, chưa gấp.
**⚠️ Cần user tự xác nhận (2026-08-16r):** fix tab "Tất cả" trống dữ liệu trong Kho — không tái hiện được lỗi gốc trên dữ liệu test (quá ít sản phẩm), chỉ xác nhận qua code review + test cơ chế hoạt động đúng trên tập dữ liệu nhỏ. **Cần user tự mở app kiểm tra lại trên dữ liệu thật** sau khi cập nhật để chắc chắn 100%.
**✅ Đã fix + test đầy đủ (2026-08-16s):** overflow 6 thẻ ở Firestore Audit Monitor — đã xác nhận hết overflow trên máy thật (logcat sạch, không còn "OVERFLOWED"). Đổi nhãn menu "Thao tác nhanh" (thêm "Tạo" trước mỗi mục) — chỉ đổi chuỗi text, không kiểm tra trực tiếp trên UI được (nút nổi kéo thả, không có nhãn accessibility để tự động dò vị trí qua adb) nhưng an toàn vì chỉ là thay đổi text thuần.
**⚠️ Cần user tự xác nhận (2026-08-16t):** 2 mục mới ở khung "CẦN XỬ LÝ" trang chủ (công nợ quá hạn, đơn trả góp chờ NH tất toán) — đã xác nhận query DB không lỗi qua logcat nhưng KHÔNG tự thấy mục thực sự hiện trên UI (dữ liệu test hiện không có công nợ nào quá 30 ngày/đơn trả góp nào). Nút "Xem đơn gốc" trong lịch sử công nợ ĐÃ test xong trên đơn thật, hoạt động đúng.
**ℹ️ Tài khoản test riêng:** `m@m.com`/shop "M" trên máy Oppo CPH2203 là tài khoản test user chủ động tạo/đăng nhập để mình test thoải mái, tách biệt khỏi dữ liệu HULUCA STORE thật — không phải bất thường, không cần báo lại mỗi lần thấy.
**🔴 QUAN TRỌNG — Tính năng "Buộc cập nhật" (2026-08-16u):** đã build xong (Cài đặt Super Admin > Buộc cập nhật), Firestore rules đã deploy production. Chỉ xác nhận được nhánh AN TOÀN MẶC ĐỊNH (chưa cấu hình → app mở bình thường, không chặn) trên thiết bị thật — **CHƯA test được nhánh CHẶN thật** vì tài khoản test không có quyền Super Admin và không có Admin SDK credentials để tự tạo dữ liệu giả lập. Trước khi dùng thật: (1) LUÔN chỉ đặt số build của bản ĐÃ ĐƯỢC DUYỆT trên kho ứng dụng, KHÔNG BAO GIỜ đặt bằng bản đang chờ duyệt. (2) Khuyến nghị tự bật thử 1 lần với số build rất cao trên máy test trước khi áp dụng cho user thật, để tự mắt thấy màn chặn hoạt động đúng trước khi tin tưởng hoàn toàn.
**✅ Đã deploy Web (2026-08-16, 23:41):** `flutter build web --release` + `firebase deploy --only hosting` — live tại https://quanlyshop.web.app. Bản trước đó deploy từ 05/01/2026 (hơn 7 tháng trước) nên lần này đẩy MỘT LƯỢT rất nhiều thay đổi tích luỹ — chỉ xác nhận HTTP 200, chưa tự test được các luồng nghiệp vụ trên web (không có trình duyệt/Playwright trong môi trường này) — **user nên tự mở https://quanlyshop.web.app kiểm tra kỹ trước khi cho nhân viên dùng**, đặc biệt các tính năng mới nhất trong ngày.
**⚠️ Known issue chưa fix:** crash intermittent trong bottom sheet có TextField qua đường Back hệ thống — xem Known Issues bên dưới (mục "Crash `_dependents.isEmpty`"). Toàn bộ 42 điểm popup che nút từ audit ban đầu (20 HIGH + 22 MEDIUM) đã fix xong, KHÔNG còn mục nào tồn đọng.
**⚠️ Chưa test trực tiếp:** Toàn bộ thay đổi Super Admin Console (redesign + fix tab Cửa hàng + công cụ tìm trùng) chỉ verify qua `flutter analyze` + build + logcat, KHÔNG có tài khoản super admin thật trên máy test để tự vào xem UI/luồng vào-shop/xóa-shop/tìm-trùng — cần user tự mở app xác nhận qua tài khoản `admin@huluca.com` hoặc super admin thật.
**⚠️ Cần user tự làm (Công cụ điều chỉnh dữ liệu):** (1) xóa giúp 1 đơn sửa test vô hại còn sót lại trong danh sách thật: "SAMSUNG TÉTMODEL / TẼTOACC / 0900000000", giá 0đ, không nợ không phụ tùng — tạo ra trong lúc test, không xóa được vì cần mật khẩu chủ shop. (2) Tự thử thực hiện 1 lần thao tác xóa/miễn nợ/sửa kho thật trên tool mới (Cài đặt > Công cụ điều chỉnh dữ liệu) để xác nhận bước SAU KHI nhập mật khẩu chạy đúng — phần này chưa tự test được (không có mật khẩu để adb test tới cùng), chỉ mới xác nhận qua code review + logic mirror đúng luồng đã chạy thật nhiều năm.
**➡️ Việc cần user tự làm:** (1) vào Super Admin Console > Người dùng > bấm nút "Tìm tài khoản trùng email" (icon 📋 cạnh tiêu đề) để xem danh sách trùng thật + tự quyết định xoá dòng nào (bắt buộc nhập PIN cho từng dòng, không có xoá hàng loạt tự động). (2) Firebase Console > App Check > đăng ký app iOS `1:51200928212:ios:04c10eca3b61a3be910e41` (hoặc xác nhận enforcement đang tắt) — lỗi "App not registered" trong log iOS không sửa được bằng code.
**✅ Đã kết luận (không còn treo):** case "đơn hiện sai trạng thái" trên Máy A — kiểm tra trực tiếp Firestore Console xác nhận `status: 1` là dữ liệu THẬT (đơn chưa từng được cập nhật trong app, không phải bug đồng bộ). Đã fix xong phần liên quan thật (đơn CHƯA giao không còn bị `.limit()` cắt bớt khỏi danh sách + thêm cảnh báo quá 7 ngày chưa xử lý) ở `[2026-08-16j]`.
**⚠️ Cân nhắc nhưng chưa sửa:** `removeUserFromShop` (Cloud Function, "Xóa nhân viên khỏi shop") chỉ set `shopId: null` chứ không xoá hẳn document — cân nhắc dọn nhưng có rủi ro regression (có thể chặn mời lại đúng người vào shop sau này) nên tạm giữ nguyên, xem chi tiết ở `[2026-08-16f]`.

### ✅ Vừa hoàn thành (2026-08-24d): fix tab "Lịch sử nhập" của NCC — bấm sản phẩm không vào chi tiết + phiếu trống không hiện gì — đã test trên máy

- User phát hiện ở tab "Lịch sử nhập" của NCC: có phiếu hiện sản phẩm bên trong, có phiếu không hiện gì (nhìn như lỗi); bấm vào dòng sản phẩm không mở được trang chi tiết
- Kéo DB thật từ máy test ra kiểm tra trực tiếp: xác nhận các phiếu "trống" (NK-0080..0083) có `totalAmount=0` và bảng `import_order_items` thật sự không có dòng nào — tức các phiếu này được xác nhận với 0 sản phẩm từ trước (dữ liệu cũ, không phải lỗi hiển thị)
- Đã thêm dòng "Phiếu này chưa ghi nhận sản phẩm cụ thể nào." khi phiếu rỗng (thay vì im lặng), và thêm `onTap` cho dòng sản phẩm — tra theo IMEI trong danh sách sản phẩm đã tải sẵn, mở đúng `InventoryDetailView`
- Đã test trên Oppo CPH2203: bấm sản phẩm trong NK-0039 → vào đúng Chi tiết sản phẩm; mở NK-0083 (phiếu trống) → hiện đúng dòng thông báo mới
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24d]`

### ✅ Vừa hoàn thành (2026-08-24c): fix bug share sheet không hiện + thêm nút chia sẻ nhanh ngoài đơn bán + đổi dialog NCC/thanh toán sang dropdown — đã test trên máy

- User phản hồi 3 điểm sau `[2026-08-24b]`: (1) dialog "Sửa NCC/thanh toán" quá nhiều bước, muốn dropdown thay vì popup; (2) không thấy chỗ chia sẻ nhanh trong màn Chi tiết đơn bán (phải vào menu "⋮" tràn → "Xem trước" → mới thấy nút); (3) bug thật — bấm "Gửi cho khách" chỉ thấy icon xoay, share sheet hệ thống không hiện ra
- **Nguyên nhân bug (3):** sheet chọn "Gửi khách/Gửi nội bộ" (`share_receipt_sheet.dart`) đóng lại quá sát trước khi gọi tiếp share sheet hệ thống — 2 lớp overlay hệ thống chồng nhau gây xung đột focus/window, share sheet không hiện, `Future` treo im lặng. Đã xoá hẳn sheet trung gian này, tách lại thành 2 icon bấm thẳng (đúng pattern `repair_detail_view.dart` đã ổn định từ trước): "Chia sẻ" → ra thẳng share sheet hệ thống; "Chat" → gửi ảnh vào chat nội bộ ngay, không qua bước chọn nào
- Thêm thẳng 2 icon "Chia sẻ nhanh cho khách" + "Xem trước biên nhận" vào AppBar màn Chi tiết đơn bán (trước đây phải mở menu "⋮" 9 mục), đồng thời bỏ mục "Xem trước" khỏi menu đó (còn 8 mục, đỡ rối)
- Đổi dialog "Sửa NCC/thanh toán" (AlertDialog + Lưu/Huỷ) sang 2 tương tác trực tiếp: sửa NCC mở thẳng bộ chọn NCC; sửa thanh toán dùng `PopupMenuButton` (dropdown thật, neo đúng vị trí ô đang bấm) — chọn xong lưu luôn, không còn bước Lưu/Huỷ riêng
- **Đã test trên Oppo CPH2203:** bấm icon "Chia sẻ nhanh cho khách" ở cả đơn bán và đơn sửa → `dumpsys window` xác nhận `mFocusedApp` chuyển đúng sang `ChooserActivity` (share sheet hệ thống thật sự hiện) → icon trở về bình thường sau khi đóng, không kẹt xoay. 2 icon mới hiện đúng ngay trên AppBar, không cần mở menu "⋮"
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24c]`

### ✅ Vừa hoàn thành (2026-08-24b): polish(kho) bấm thẳng vào ô NCC/thanh toán để sửa — đã test trên máy

- User phản hồi lại `[2026-08-24a]`: 2 ô NCC/Thanh toán vẫn hiện icon ổ khoá + màu xám (nhìn như bị khoá/ẩn), dù nút "Sửa" riêng bên dưới đã sửa được — thiết kế 2 tầng (ô xem + nút sửa riêng) gây hiểu lầm
- Đã bỏ icon khoá + nền xám, đổi 2 ô NCC/Thanh toán thành `InkWell` màu indigo + icon bút — bấm thẳng vào ô là mở dialog sửa luôn, xoá nút thừa bên dưới. Ô "SL tồn kho" vẫn giữ khoá như cũ (không liên quan phản hồi này)
- Đã test trên Oppo CPH2203: bấm thẳng vào từng ô đều mở đúng dialog sửa
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24b]`

### ✅ Vừa hoàn thành (2026-08-24a): feat(sale,repair,kho) chia sẻ ảnh gửi khách/nội bộ + đồng nhất sửa NCC/thanh toán ở màn Sửa sản phẩm — đã test + tìm sửa thêm 1 bug thật (sửa lần 2 trở đi)

- Nối tiếp `[2026-08-23d]`: (1) user muốn nút "Chia sẻ ảnh" của đơn bán/phiếu sửa chuyên nghiệp hơn — thêm sheet chọn "Gửi cho khách" (giữ nguyên hành vi cũ) hoặc "Gửi nội bộ" (mới, đăng thẳng vào chat nội bộ shop kèm caption tóm tắt). (2) user phát hiện đúng 1 điểm KHÔNG đồng nhất còn sót: màn "Sửa sản phẩm" có ô NCC bị khoá cứng và thiếu hẳn ô "Phương thức thanh toán" — trong khi đây chính là 2 thứ vừa sửa được ở phiếu nhập kho
- Gom logic dialog "Sửa NCC/thanh toán" thành 1 hàm dùng chung (`showCorrectSupplierPaymentDialog`), dùng cả ở màn Chi tiết phiếu nhập kho lẫn màn Sửa sản phẩm — màn Sửa sản phẩm giờ tự tìm phiếu nhập kho gốc qua IMEI (bảng `supplier_import_history` có lưu liên kết ngược) rồi mở đúng dialog đó
- **Bug fix quan trọng phát hiện khi test sửa 1 phiếu LẦN THỨ HAI:** `correctSupplierAndPayment()` từng đọc trạng thái "đang công nợ hay không" từ `StockEntry` gốc (bản ghi bất biến lúc tạo) thay vì từ `ImportOrder` (bản ghi phản ánh đúng trạng thái hiện tại) — hậu quả: sửa lần 1 luôn đúng nhưng sửa lần 2 trở đi luôn báo "Không tìm thấy công nợ gốc của phiếu này" dù dữ liệu vẫn còn nguyên. Đã sửa đọc đúng từ `ImportOrder`
- **Đã test trên Oppo CPH2203:** từ màn Sửa sản phẩm, bấm "Sửa NCC/thanh toán" → tự tìm đúng phiếu gốc → đổi CHUYỂN KHOẢN→TIỀN MẶT → phát hiện bug (không lưu được) ngay trong lúc test → sửa code → build lại → test lại thành công, ô cập nhật ngay, `Lịch sử nhập kho` xác nhận đúng badge. Chia sẻ ảnh "Gửi nội bộ" từ phiếu sửa HUY → xác nhận tin nhắn ảnh + caption xuất hiện đúng trong Chat nội bộ (lần đầu tưởng lỗi do bấm sai toạ độ khi test tự động, không phải bug code)
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-24a]`

### ✅ Vừa hoàn thành (2026-08-23d): feat(kho,ncc) sửa NCC/phương thức thanh toán sau nhập kho — đã test + tìm sửa 3 bug thật trên máy

- Trước đây không có cách sửa lại NCC/phương thức thanh toán sau khi phiếu nhập kho đã xác nhận. Đã khảo sát kỹ trước khi code (xác nhận công nợ NCC + sổ quỹ tính từ đúng bảng `debts`/`expenses` local) rồi hỏi user xác nhận hướng sửa ở cấp phiếu nhập kho (không phải từng sản phẩm) mới khớp đúng số liệu tài chính
- `StockEntryService.correctSupplierAndPayment()` (mới): đổi tên NCC tại chỗ nếu cùng loại thanh toán; đổi loại (CÔNG NỢ↔TIỀN MẶT/CHUYỂN KHOẢN) thì soft-delete bản ghi cũ + tạo bản ghi mới đúng loại. **Chặn cứng** nếu công nợ đã trả một phần. Đồng bộ nhãn NCC/thanh toán cho sản phẩm khớp IMEI. Nút "Sửa" mới ở `import_order_detail_view.dart`, cảnh báo nếu ngày đó đã chốt quỹ. Thêm dòng hiển thị "Thanh toán" còn thiếu ở `inventory_detail_view.dart`
- **3 bug thật tìm thấy + sửa ngay trong lúc test:** (1) permission-denied khi cố sửa thẳng doc `stock_entries` đã confirmed (Firestore rules chỉ cho super-admin sửa sau khi confirmed — đã bỏ, chỉ sửa `import_orders`); (2) sync-race làm 1 debt đã xoá bị "hồi phục" lại active (đã sửa: ghi Firestore ngay lập tức thay vì chỉ qua hàng đợi, đúng pattern có sẵn ở `expense_view.dart`); (3) quên đồng bộ `paidAmount` theo `paymentStatus` làm tổng công nợ NCC hiện sai số
- **Đã test trên Oppo CPH2203:** tạo 2 phiếu CÔNG NỢ test (NCC TÉT A), sửa đổi cả NCC lẫn phương thức thanh toán — xác nhận UI cập nhật ngay tại chỗ, công nợ NCC đúng, khoản chi mới đúng trong Sổ quỹ, không còn báo lỗi quyền. **Chưa test:** chặn đổi loại khi công nợ đã trả một phần (chỉ code review — logic thuần, rủi ro thấp); vai trò STAFF thử sửa phiếu đụng `expenses` (rule Firestore yêu cầu Manager+, giống luồng gốc, không phải bug mới)
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-23d]`

### ✅ Vừa hoàn thành (2026-08-23c): polish(sale,repair) thiết kế lại ảnh biên nhận/phiếu sửa giống giấy in thật — đã test trên máy thật
- User phản hồi ảnh chia sẻ ở `[2026-08-23a/b]` chỉ là khối chữ thô, chưa đẹp/chuyên nghiệp — yêu cầu giống hệt biên nhận in ra nhưng gọn gàng dễ nhìn hơn. Đã hỏi lại user chọn hướng thiết kế (dạng thẻ hiện đại vs dải giấy giống hệt biên nhận in) — **user chọn giữ dải giấy giống biên nhận in**, chỉ làm sạch/đẹp hơn
- Widget mới dùng chung `receipt_paper_view.dart`: không đổi nội dung/công thức (vẫn đúng 100% dữ liệu + tôn trọng mẫu shop tự tùy biến) — chỉ trình bày lại: dòng gạch ngang thô → đường kẻ mảnh sạch; dòng tiêu đề `===...===` → chữ đậm căn giữa; tờ giấy bo góc nhẹ, đổ bóng, nổi trên nền xám nhạt thay vì phẳng lì như trước
- Khối QR chuyển khoản gộp vào cùng 1 tờ giấy với nội dung biên nhận (trước đây là 2 khối tách rời) — đọc liền mạch như 1 tờ biên nhận thật
- Áp dụng đồng bộ cho cả `sale_invoice_preview_view.dart` và `repair_invoice_preview_view.dart`
- **Đã test trên Oppo CPH2203:** mở lại đúng đơn ABC (còn nợ 12tr) đã test trước đó — xác nhận thiết kế mới hiện đúng, nút Chia sẻ ảnh vẫn hoạt động bình thường (logcat xác nhận share sheet mở đúng) với layout mới. Mở phiếu sửa HUY — xác nhận cùng thiết kế áp dụng nhất quán
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-23c]`

### ✅ Vừa hoàn thành (2026-08-23b): feat(sale,repair) nút chia sẻ ảnh+QR ngay sau tạo đơn bán + đơn sửa dùng chung cơ chế ảnh+QR — đã test đầy đủ máy thật
- Nối tiếp `[2026-08-23a]`: (1) thêm lối vào nhanh "Chia sẻ ảnh biên nhận" ngay trong sheet kết quả sau khi tạo đơn bán (trước đó phải tự mở lại đơn mới thấy nút); (2) đơn sửa trước đây share chỉ có text thuần — giờ dùng chung cơ chế ảnh+QR như đơn bán
- `payment_result_sheet.dart` (dùng chung cho cả tạo đơn bán và thu công nợ) thêm param tuỳ chọn `onShareReceipt` — mặc định `null` nên nơi gọi khác (thu công nợ) không đổi giao diện
- `sale_detail_view.dart` thêm `autoOpenPreview` — **cố tình chờ đủ cả `_loadShopInfo()` + `_loadCustomerDebt()` qua `Future.wait()`** trước khi tự mở xem trước, để tránh mở sớm lúc state rỗng làm QR/biên nhận hiện sai số tiền (đây là dữ liệu tiền, không chấp nhận race condition)
- Thêm `DebtSummaryService.remainingDebtFromLinkedDebt()` — tách từ công thức có sẵn, dùng chung được cho cả đơn sửa (đơn sửa cũng ghi nợ vào bảng `debts` qua `linkedId` giống hệt đơn bán, đã xác nhận qua code trước khi dùng)
- `repair_invoice_preview_view.dart` nâng cấp giống hệt kiến trúc bên đơn bán (ảnh+QR+share), thêm cờ `autoShare` để đơn sửa bấm 1 nút là tự chụp+chia sẻ luôn. `repair_detail_view.dart._shareToZalo()` viết lại nội dung hàm (giữ nguyên tên nên không cần sửa 2 nơi gọi) để mở màn xem trước mới thay vì gửi text
- **Đã test đầy đủ trên Oppo CPH2203:** tạo đơn CÔNG NỢ mới (khách ABC, 12tr) → bấm nút Chia sẻ mới trong sheet kết quả → tự chuyển sang xem trước, dữ liệu đúng ngay lập tức (Mã HD, khách, tổng tiền, còn nợ đơn, công nợ khách hiện tại, khối QR — tất cả khớp, không bị stale do race). Đơn sửa (HUY, IPHONE 8): bấm icon Chia sẻ trên AppBar → tự mở xem trước → icon hiện spinner đang tự chụp+chia sẻ → nội dung đúng, không còn lộ dòng `[QR]repair_check:...` thô → xác nhận qua logcat `ChooserActivity` (share sheet Android) mở thành công
- **Chưa test:** nhánh đơn sửa THỰC SỰ có nợ để QR hiện ra (đơn test dùng để verify có giá 0đ) — logic tính giống hệt bên bán đã test kỹ nên tự tin dùng lại; bước chọn app đích thật (Zalo) trong share sheet — không tự động hoá được từ môi trường adb
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-23b]`

### ✅ Vừa hoàn thành (2026-08-23a): feat(sale,kho) ảnh biên nhận + QR chuyển khoản VietQR qua Zalo + gợi ý giá vốn/giá bán khi nhập kho — test một phần trên máy thật
- 2 tính năng độc lập theo yêu cầu ngay sau `[2026-08-22a]`: (1) xuất ảnh biên nhận đơn bán kèm QR chuyển khoản thật (VietQR/napas) để gửi Zalo cho khách chuyển khoản, tham khảo kiểu KiotViet; (2) gợi ý giá vốn/giá bán khi nhập kho, tương tự "giá tham khảo" đã có ở đơn sửa
- `vietqr_builder.dart` (mới): tự viết bộ mã hoá EMVCo/VietQR chuẩn (GUID napas, CRC-16/CCITT-FALSE) — verify độc lập bằng test vector CRC + tự viết parser TLV round-trip, **nhưng chưa quét thử bằng app ngân hàng thật** (không tự động hoá được từ môi trường dev) — **cần user tự quét thử QR trước khi gửi cho khách thật**
- Thông tin NH lưu cloud (`shops/{shopId}/settings/bank_qr`, chỉ chủ shop sửa được) qua màn mới `bank_qr_settings_view.dart`, lối vào ở `home_view.dart` (phát hiện `settings_view.dart` là dead code — không sửa, chỉ ghi chú)
- `sale_invoice_preview_view.dart`: nút "Chia sẻ ảnh" mới (chụp `Screenshot` toàn bộ biên nhận → share qua `SharePlus` API v12) + khối QR chuyển khoản hiện có điều kiện (chỉ khi đơn còn nợ + đã cấu hình NH), số tiền QR = đúng số còn nợ đơn
- `product_pricing_service.dart` (mới) + `getProductsForPricing()`: cùng thuật toán thống kê với `PricingEngineService` (đơn sửa) nhưng khớp theo model đơn giản hơn. Nối vào cả `fast_stock_in_view.dart` và `smart_stock_in_view.dart`
- **Đã test trên Oppo CPH2203:** cấu hình NH thành công (ghi Firestore đúng quyền owner-only); khối QR trên biên nhận hiện đúng toàn bộ thông tin (tên NH, số TK, QR image, số tiền, nội dung); nút Chia sẻ ảnh xác nhận qua logcat mở đúng `ChooserActivity` (share sheet Android); card gợi ý giá ở Nhập nhanh chạy đúng luồng, hiện đúng "chưa đủ dữ liệu" (tài khoản test chưa có lịch sử nhập phù hợp)
- **Chưa test:** quét QR bằng app ngân hàng thật để xác nhận đọc đúng; bước chọn app đích thật trong share sheet (Zalo); nhánh card gợi ý giá THỰC SỰ hiện được số (cần dữ liệu nhập kho lặp lại cùng model); màn `smart_stock_in_view.dart` trực tiếp trên máy (cùng pattern, chỉ verify qua `flutter analyze`)
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-23a]`

### ✅ Vừa hoàn thành (2026-08-22a): feat(sale,debt) công nợ khách hàng gộp nhiều đơn (bán sỉ) + thu tiền phân bổ FIFO — đã test đầy đủ máy thật
- User chuyển hướng bán sỉ: 1 khách mua nhiều đơn, nợ cộng dồn, muốn trả gộp sau thay vì trả riêng từng đơn — yêu cầu chi tiết 17 mục kèm ảnh minh họa UI tham khảo (kiểu KiotViet). Đã `/plan` trước khi code, chốt với user: làm toàn bộ nhưng cẩn thận từng bước, "Nợ trước đơn" tính real-time, chặn thu vượt tổng công nợ
- Khảo sát kỹ trước khi sửa: `debts` vốn là 1 dòng nợ : 1 đơn (`linkedId`), `SaleOrder.remainingDebt` và bảng `debts` là 2 nguồn "còn nợ" độc lập đã biết lệch nhau (`sale_list_view.dart` phải tự dung hòa), `sale_detail_view.dart` không hiện số đã thu/còn nợ nào, công nợ tổng theo khách chỉ tồn tại dưới dạng SQL thô lặp lại y hệt ở 2 nơi. Phát hiện `DBMigrationService` (file `db_migration_service.dart`) là **dead code chưa từng được gọi ở đâu** — chuyển sang dùng đúng cơ chế `onUpgrade` version-bump đang thực sự chạy production (bump v105→v106)
- DB: thêm 1 cột nullable `debt_payments.paymentGroupId` (không đổi schema `sales`/`customers`/`debts`) — nhóm nhiều khoản thu (mỗi khoản vẫn 1 đơn như cũ) thành 1 phiếu thu gộp
- Service mới `CustomerDebtPaymentService` (FIFO đề xuất + sửa tay được, `collectPayment` lặp gọi đúng cơ chế `PaymentIntentService.executePaymentDirect` 1-đơn đã chạy production, không xây pipeline mới) + mở rộng `DebtSummaryService` (gom 3 chỗ SQL trùng lặp về 1 nguồn)
- 2 màn mới: `CustomerDebtView` (tổng nợ khách + danh sách đơn nợ + timeline lịch sử), `CollectCustomerDebtView` (luồng thu tiền gộp 3 bước). `sale_detail_view.dart` thêm card công nợ khách + banner Thu tiền + dòng "Tổng đã thu" (cộng thêm, không sửa UI cũ). Thêm token biên nhận `{customerTotalDebt}` tách riêng khỏi `{remainingDebt}`
- **Quyết định lệch khỏi plan ban đầu (chủ động, vì an toàn):** không tách `debt_view.dart._showDebtHistory()` thành widget dùng chung như dự tính — xây timeline độc lập trong `CustomerDebtView` để không đụng màn công nợ shop-wide đang chạy production hàng ngày
- **Bug tìm thấy + sửa ngay khi test:** nút THU TIỀN trong banner mới làm cả khối cha phình to bất thường, mất nội dung — do style `ElevatedButton` mặc định toàn app ép full-width, xung đột khi đặt trong `Row` cạnh `Expanded`. Đã sửa bằng ghi đè `minimumSize: Size.zero` riêng cho đúng nút đó, đã rà các `ElevatedButton` mới khác không dính lỗi tương tự
- **Đã test đầy đủ trên Oppo CPH2203 (`m@m.com`/shop "M"):** cài mới hoàn toàn, restart app nhiều lần — logcat sạch không FATAL. Kéo file DB thật về kiểm tra trực tiếp: migration v105→v106 tự chạy đúng, cột `paymentGroupId` đã có. Chạy full luồng trên khách thật (2 đơn CÔNG NỢ có sẵn) — card công nợ, banner Thu tiền, bước nhập tiền, bước phân bổ FIFO (kiểm cả chặn vượt số dư khi sửa tay), bước kết quả — đều đúng. Kiểm ngược DB sau khi thu: `debts.paidAmount` tăng đúng, `debt_payments` có `paymentGroupId`, **`sales.totalPrice` không đổi (doanh thu không tăng sai)**. Màn chi tiết/màn công nợ khách/trang chủ đều cập nhật số liệu ngay lập tức
- **Chưa test:** đồng bộ 2 thiết bị (chỉ 1 máy trong phiên), phương thức Chuyển khoản (chỉ test Tiền mặt), phân bổ cắt ngang ≥2 đơn cùng lúc (dữ liệu test lúc test chỉ còn 1 đơn nợ)
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-22a]`

### 🔴 Vừa hoàn thành (2026-08-17a): fix(repair) NGHIÊM TRỌNG — đơn Duyệt giao/sửa giá vốn bị revert dữ liệu
- User gửi 4 ảnh chụp: tự bấm DUYỆT giao máy + sửa giá vốn 3.500.000 cho đơn IPHONE 13 — nhật ký, chat nội bộ đều xác nhận đã làm — nhưng vào lại app đơn hiện lại y hệt như CHƯA làm gì (vẫn "CHỜ DUYỆT", giá vốn về 0). User nhấn mạnh nghiêm trọng, ảnh hưởng uy tín, dù không phải đơn nào cũng gặp
- Đọc kỹ toàn bộ luồng Duyệt giao (`_approveDelivery`) + Sửa giá vốn (`_editFinancials`/`_saveData`) trong `repair_detail_view.dart`, tìm ra 2 lỗ hổng thật: (1) patch trạng thái lên cloud lúc Duyệt giao KHÔNG gồm giá thu/vốn — giá được ghi bằng 1 lần riêng chạy sau, tạo khoảng hở nếu lần đó trễ/lỗi mạng; (2) cả 2 luồng ghi Firestore kiểu "bắn đi không đợi xác nhận" + lỗi bị nuốt im lặng, vẫn báo "Đã lưu thành công" bất kể cloud có thật sự nhận được không — nếu đúng lúc mạng chập chờn, cơ chế tự đồng bộ định kỳ (thêm hôm 16/08) sau đó vô tình lấy dữ liệu CŨ trên cloud đè lên local
- Fix: gộp giá vào patch trạng thái Duyệt giao (đóng khoảng hở #1); đổi cả 2 luồng ghi sang chờ xác nhận thật sự (có timeout) rồi đọc lại tình trạng đồng bộ từ DB — nếu chưa lên cloud được thì báo cam rõ ràng thay vì báo xanh "đã lưu" gây hiểu lầm
- **Đã test kỹ trên máy thật:** tạo đơn test → SỬA XONG → GIAO (giá 999.000đ) → DUYỆT → xác nhận đúng "ĐÃ GIAO"/"Đã sync"/giá đúng. Thoát vào lại (cả chi tiết lẫn danh sách reload mới hoàn toàn) — **dữ liệu giữ nguyên, không revert** — đúng như báo cáo lỗi cần sửa. Không crash
- `flutter analyze` sạch, build + cài Oppo CPH2203. **Giới hạn:** không mô phỏng được "mất mạng giữa chừng" qua adb nên chỉ xác nhận chắc chắn nhánh mạng bình thường, nhánh lỗi mạng dựa trên đọc code kỹ (tin cậy cao, chưa tận mắt thấy)
- Còn sót 1 đơn test vô hại: "SAMSUNG ETMODELSYNC / TESTSYNCFIX / 0900001111", đã giao, 999.000đ — user tự xóa qua Công cụ điều chỉnh dữ liệu
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-17a]`

### ✅ Vừa hoàn thành (2026-08-16u): feat: buộc cập nhật — chặn bản app cũ
- User hỏi có cách nào chặn hết bản app cũ, buộc cập nhật không — cũng hỏi bản 3.3.0/541 đang chờ Apple duyệt có bị ảnh hưởng không (đã giải thích: bản đã gửi là "đóng băng", không đụng gì; tính năng chỉ có hiệu lực từ bản MỚI sau này). User đồng ý làm
- Vì đây là tính năng rủi ro cao nhất phiên này (có thể khoá TOÀN BỘ user thật nếu sai), thiết kế bắt buộc theo nguyên tắc an toàn: fail-open tuyệt đối (lỗi/mất mạng/chưa cấu hình → KHÔNG BAO GIỜ chặn), cảnh báo rõ trong màn cấu hình về việc chỉ đặt build đã duyệt, dialog xác nhận trước khi bật gate
- File mới `version_gate_wrapper.dart` — đọc `app_config/version_gate` lúc mở app (bọc ở `MaterialApp.builder` nên áp dụng mọi màn hình), so build hiện tại (`AppInfo.getBuildNumber()`) với mức tối thiểu theo nền tảng, chặn bằng màn không đóng được nếu thấp hơn
- Thêm mục "Buộc cập nhật" trong Super Admin Console để cấu hình số build tối thiểu Android/iOS + thông báo tuỳ chỉnh
- `firestore.rules` thêm collection `app_config` (đọc công khai, chỉ Super Admin ghi) — đã deploy production
- **Đã test trên thiết bị thật:** xác nhận đúng hành vi fail-open quan trọng nhất — chưa cấu hình gì thì app mở bình thường, không chặn, không crash. **CHƯA test được nhánh chặn thật** (tài khoản test không có quyền Super Admin, không có Admin SDK để giả lập) — cần user tự bật thử trước khi dùng thật
- `flutter analyze` sạch, build + cài Oppo CPH2203
- Chi tiết: `docs/CHANGELOG.md` mục `[2026-08-16u]`

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
