# Kịch bản test TOÀN BỘ số liệu tài chính — 1 ngày, 1 shop

> File test tự động tương ứng: `test/finance_full_scenario_test.dart`
> (chạy `flutter test test/finance_full_scenario_test.dart`).
> Mọi con số kỳ vọng dưới đây được **tính tay** rồi ghi cứng vào test — test
> không tự suy ra từ công thức của app, nhờ vậy mới bắt được lỗi công thức.

## 0. Bối cảnh

| Mục | Giá trị |
|---|---|
| Ngày test **D** | 10/09/2026 (mọi giao dịch trong ngày, trừ khi ghi khác) |
| Quỹ đầu ngày | Tiền mặt **10.000.000** · Ngân hàng **20.000.000** |
| Khách hàng | KH A (0901111111), KH B (0902222222) |
| Nhà cung cấp | NCC X (linh kiện, điện thoại), NCC Y (phụ kiện) |
| Đối tác sửa chữa | Đối tác Z |
| Nợ tồn kỳ trước | D6: KH B nợ **2.000.000** từ 01/08 (chưa trả) |

Ký hiệu: TM = tiền mặt, CK = chuyển khoản, CN = công nợ.

---

## 1. Các bước thao tác

### A. Bán hàng (`sales`)

| # | Thao tác trên app | Dữ liệu ghi | Tiền vào TM | Tiền vào CK | Ghi nhận nợ |
|---|---|---|---|---|---|
| S1 | Bán **ốp lưng** 200.000 (vốn 120.000) — TM | sale TIỀN MẶT | +200.000 | | |
| S2 | Bán **iPhone** 12.000.000, giảm 200.000 (vốn 10.000.000) — CK | sale CHUYỂN KHOẢN, discount 200.000 | | +11.800.000 | |
| S3 | Bán **Samsung** 5.000.000 (vốn 4.000.000) — **KẾT HỢP** 3tr TM + 2tr CK | sale KẾT HỢP cashAmount/transferAmount | +3.000.000 | +2.000.000 | |
| S4 | Bán **Xiaomi** 3.000.000 (vốn 2.400.000) — **CÔNG NỢ** KH A, trả trước 1.000.000 TM | sale CÔNG NỢ + debt **D1** CUSTOMER_OWES 3tr + phiếu thu **dp1** 1tr TM | +1.000.000 (qua dp1) | | D1 còn 2.000.000 |
| S5 | Bán **Oppo** 15.000.000 (vốn 12.500.000) — **TRẢ GÓP 1 NH** HD SAISON: cọc 5tr TM, vay 10tr, **chưa** tất toán | sale isInstallment, downPayment 5tr TM, loanAmount 10tr | +5.000.000 | | (NH chưa trả) |
| S6 | Bán **Vivo** 20.000.000 (vốn 17.000.000) — **TRẢ GÓP 2 NH**: cọc 4tr CK, FE 10tr + HOME 6tr; NH **tất toán trong ngày 15.500.000** (phí 500.000) | sale isInstallment, bankName/bankName2, settlementReceivedAt = D, settlementAmount 15,5tr | | +4.000.000 cọc +15.500.000 tất toán | |
| S7 | Đơn góp **Realme** bán **15/08** 10.000.000 (vốn 8.000.000), cọc 2tr TM (kỳ trước), vay 8tr — NH tất toán **hôm nay** 7.800.000 (phí 200.000) | cập nhật settlementReceivedAt = D, settlementAmount 7,8tr | | +7.800.000 | |
| S8 | **Trả hàng**: KH B trả ốp lưng mua kỳ trước, hoàn 150.000 TM (vốn 90.000) | sales_returns refundMethod TIỀN MẶT | −150.000 (tiền ra) | | |
| S9 | **Xoá** một đơn bán 999.999 (deleted = 1) | sale deleted=1 | không được tính | | |

### B. Sửa chữa (`repairs`) — trạng thái **Đã giao** (status 4) trong ngày D

| # | Thao tác | Dữ liệu ghi | Tiền vào | Tiền ra | Nợ |
|---|---|---|---|---|---|
| R1 | Sửa iPhone màn hình, giá 800.000, vốn linh kiện 300.000, **ghi sổ quỹ** TM — giao TM | repair price 800k cost 300k, costRecordedInFund=1 TM | +800.000 TM | −300.000 TM (vốn LK) | |
| R2 | Sửa Samsung **qua đối tác Z** 900.000 **CN**, giá 1.500.000 — giao CK | services [Z 900k CÔNG NỢ] → debt **D2** SHOP_OWES Z 900k | +1.500.000 CK | | D2 900.000 |
| R2b | Trả đối tác Z **1 phần** 400.000 CK | debt_payments **dp2** SHOP_OWES 400k CK | | −400.000 CK | D2 còn 500.000 |
| R3 | Sửa Oppo giá 600.000, vốn 200.000 ghi sổ quỹ CK — giao **CÔNG NỢ** KH B | repair CÔNG NỢ + debt **D3** CUSTOMER_OWES B 600k; costRecordedInFund CK 200k | | −200.000 CK | D3 600.000 |
| R3b | KH B trả **hết** 600.000 CK | **dp3** CUSTOMER_OWES 600k CK → D3 đóng | +600.000 CK | | D3 = 0 |
| R4 | Sửa Xiaomi, dịch vụ **nội bộ** "Vệ sinh" 50.000 (không đối tác), giá 250.000 — giao TM | repair price 250k, services [Vệ sinh 50k, partnerId null] | +250.000 TM | (mirror 50.000 — xem ghi chú §4) | |
| R5 | Sửa Huawei qua đối tác Z 700.000 **trả ngay TM**, giá 1.200.000 — giao TM | repair price 1.2tr, services [Z 700k TIỀN MẶT]; repair_partner_payments **rpp_p1** 700k + expense mirror **exp_partner_p1** | +1.200.000 TM | −700.000 TM | |

### C. Nhập hàng (`supplier_import_history` + `expenses` + `debts`)

| # | Thao tác | Dữ liệu ghi | Tiền ra | Nợ NCC |
|---|---|---|---|---|
| I1 | Nhập linh kiện NCC X **TM**: màn hình 5 × 400.000 + pin 10 × 100.000 = 3.000.000 | 2 dòng history ref `se1` + expense `exp_stock_se1_<ts>` NHẬP HÀNG 3tr TM | −3.000.000 TM | |
| I2 | Nhập phụ kiện NCC Y **CK**: 20 ốp × 50.000 = 1.000.000 | 1 dòng history `se2` + expense `exp_stock_se2_<ts>` 1tr CK | −1.000.000 CK | |
| I3 | Nhập điện thoại NCC X **CN**: 2 iPhone × 10.000.000 = 20.000.000 | history `se3` CÔNG NỢ + debt **D4** SHOP_OWES X 20tr (`debt_stock_se3`) | | D4 20.000.000 |
| I3b | Trả NCC X **1 phần** 5.000.000 CK | **dp4** SHOP_OWES 5tr CK | −5.000.000 CK | D4 còn 15.000.000 |
| I4 | Nhập phụ kiện NCC Y **CN** 500.000 | history `se4` CÔNG NỢ + debt **D5** SHOP_OWES Y 500k | | D5 500.000 |
| I4b | Trả NCC Y **toàn bộ** 500.000 TM | **dp5** SHOP_OWES 500k TM → D5 đóng | −500.000 TM | D5 = 0 |

### D. Thu chi phát sinh (`expenses`)

| # | Thao tác | Dữ liệu | Tiền |
|---|---|---|---|
| E1 | Chi **chủ động**: tiền điện 1.200.000 TM | expense CHI, category ĐIỆN NƯỚC | −1.200.000 TM |
| E2 | Chi mặt bằng 5.000.000 CK | expense CHI, MẶT BẰNG | −5.000.000 CK |
| E3 | **Thu phát sinh** 300.000 TM (bán ve chai) | expense **THU**, THU KHÁC | +300.000 TM |
| (tự động) | Chi phí **tự động** = các mirror `exp_stock_*` (I1, I2) và `exp_partner_*` (R5) — app tự sinh, không thao tác | | đã tính ở trên |

### E. Công nợ khách — trả thêm

| # | Thao tác | Dữ liệu | Tiền | Nợ |
|---|---|---|---|---|
| K1 | KH A trả thêm **1 phần** D1: 500.000 CK | **dp6** CUSTOMER_OWES 500k CK | +500.000 CK | D1 còn 1.500.000 |

---

## 2. Số kỳ vọng — Tài chính V2 (tab Tiền / Lãi / Nợ, cash basis)

### Tiền vào
| Nguồn | Tính | Kết quả |
|---|---|---|
| Bán hàng thực thu | S1 200.000 + S2 11.800.000 + S3 5.000.000 + S4 **0** + S5 5.000.000 + S6 19.500.000 + S7 7.800.000 − S8 150.000 | **49.150.000** |
| Sửa chữa thực thu | R1 800.000 + R2 1.500.000 + R3 **0** (CN) + R4 250.000 + R5 1.200.000 | **3.750.000** |
| Thu nợ khách | dp1 1.000.000 + dp3 600.000 + dp6 500.000 | **2.100.000** |
| Thu khác | E3 | **300.000** |
| **TỔNG TIỀN VÀO** | | **55.300.000** |

### Tiền ra
| Nguồn | Tính | Kết quả |
|---|---|---|
| Chi vận hành thuần | E1 1.200.000 + E2 5.000.000 | **6.200.000** |
| Nhập hàng (TM/CK) | I1 3.000.000 + I2 1.000.000 | **4.000.000** |
| Trả đối tác trực tiếp | R5 700.000 | **700.000** |
| Trả nợ NCC / đối tác | dp2 400.000 + dp4 5.000.000 + dp5 500.000 | **5.900.000** |
| Vốn SC đã ghi sổ quỹ (mirror) | R1 300.000 + R3 200.000 + R4 50.000 | **550.000** |
| **TỔNG TIỀN RA** | | **17.350.000** |
| **Dòng tiền ròng** | 55.300.000 − 17.350.000 | **37.950.000** |

### Vốn & Lãi gộp (cash basis — vốn ghi theo tỉ lệ tiền thực thu)
| Đơn | Vốn ghi nhận |
|---|---|
| S1 | 120.000 |
| S2 | 10.000.000 |
| S3 (KẾT HỢP, thu đủ) | 4.000.000 |
| S5 (thu 5/15) | 12.500.000 × 5/15 = **4.166.667** |
| S6 (thu 19,5/20) | 17.000.000 × 19,5/20 = **16.575.000** |
| S7 (thu 7,8/10) | 8.000.000 × 7,8/10 = **6.240.000** |
| S8 trả hàng | −90.000 |
| **Vốn bán hàng** | **41.011.667** |
| **Vốn sửa chữa** | R1 300.000 + R2 900.000 + R4 50.000 + R5 700.000 = **1.950.000** |
| **Lãi gộp bán hàng** | 49.150.000 − 41.011.667 = **8.138.333** |
| **Lãi gộp sửa chữa** | 3.750.000 − 1.950.000 = **1.800.000** |
| **Lãi gộp tổng** | **9.938.333** |
| **Lãi sau chi vận hành** | 9.938.333 − 6.200.000 = **3.738.333** |

### Công nợ cuối ngày
| Loại | Chi tiết | Tổng |
|---|---|---|
| **Phải thu** | D1 1.500.000 + D6 2.000.000 (D3 đã đóng) | **3.500.000** |
| **Phải trả** | D2 500.000 + D4 15.000.000 (D5 đã đóng) | **15.500.000** |

Bất biến: với mọi khoản nợ, `paidAmount == Σ debt_payments` (D1 = 1.500.000, D2 = 400.000, D3 = 600.000, D4 = 5.000.000, D5 = 500.000).

---

## 3. Số kỳ vọng — Chốt quỹ / Báo cáo ngày (`DailyFinancialAnalysisService`)

### Tiền mặt
| Vào | | Ra | |
|---|---|---|---|
| S1 | 200.000 | S8 hoàn trả | 150.000 |
| S3 phần TM | 3.000.000 | R1 vốn LK | 300.000 |
| S5 cọc | 5.000.000 | R5 trả đối tác | 700.000 |
| R1 | 800.000 | I1 nhập | 3.000.000 |
| R4 | 250.000 | dp5 trả NCC Y | 500.000 |
| R5 | 1.200.000 | E1 điện | 1.200.000 |
| dp1 | 1.000.000 | | |
| E3 | 300.000 | | |
| **Tổng TM vào** | **11.750.000** | **Tổng TM ra** | **5.850.000** |

→ **Tiền mặt cuối ngày = 10.000.000 + 11.750.000 − 5.850.000 = 15.900.000**

### Ngân hàng
| Vào | | Ra | |
|---|---|---|---|
| S2 | 11.800.000 | R3 vốn LK | 200.000 |
| S3 phần CK | 2.000.000 | dp2 trả Z | 400.000 |
| S6 cọc | 4.000.000 | I2 nhập | 1.000.000 |
| S6 tất toán | 15.500.000 | dp4 trả NCC X | 5.000.000 |
| S7 tất toán | 7.800.000 | E2 mặt bằng | 5.000.000 |
| R2 | 1.500.000 | | |
| dp3 | 600.000 | | |
| dp6 | 500.000 | | |
| **Tổng CK vào** | **43.700.000** | **Tổng CK ra** | **11.600.000** |

→ **Ngân hàng cuối ngày = 20.000.000 + 43.700.000 − 11.600.000 = 52.100.000**

**Kiểm tra chéo:** (11.750.000 + 43.700.000) − (5.850.000 + 11.600.000) = **37.950.000** = dòng tiền ròng Tài chính V2 ✔

### Lợi nhuận ngày (accrual — tính cả đơn CÔNG NỢ)
| | |
|---|---|
| Doanh thu bán (S1..S6 kể cả S4 CN, trừ S8) | 200.000 + 11.800.000 + 5.000.000 + 3.000.000 + 5.000.000 + 4.000.000 − 150.000 = **28.850.000** |
| Tất toán NH | 15.500.000 + 7.800.000 = **23.300.000** |
| Doanh thu sửa (kể cả R3 CN) | 800.000 + 1.500.000 + 600.000 + 250.000 + 1.200.000 = **4.350.000** |
| Thu khác | **300.000** |
| Chi vận hành | **6.200.000** |
| Vốn bán | 120.000 + 10.000.000 + 4.000.000 + 2.400.000 + 4.166.667 + 3.400.000 + 13.600.000 + 6.400.000 − 90.000 = **43.996.667** |
| Vốn sửa | 300.000 + 900.000 + 200.000 + 50.000 + 700.000 = **2.150.000** |
| **Lợi nhuận ròng** | 28.850.000 + 23.300.000 + 4.350.000 + 300.000 − 6.200.000 − 43.996.667 − 2.150.000 = **4.453.333** |

---

## 4. Điểm hai engine cố ý KHÁC nhau (không phải lỗi)

| Chủ đề | Tài chính V2 | Chốt quỹ / Báo cáo ngày |
|---|---|---|
| Đơn CÔNG NỢ (S4, R3) | không tính doanh thu/vốn cho tới khi thu tiền (cash basis) | tính đủ doanh thu + vốn ngay (accrual), tiền chỉ vào khi có phiếu thu |
| Trả hàng S8 | trừ thẳng vào doanh thu bán (net) — không nằm trong "tiền ra" | ghi tiền ra 150.000 + trừ doanh thu |
| Dịch vụ nội bộ R4 (50.000) | hiện 1 dòng chi mirror `repair_cost_*` trong sổ (nằm trong tiền ra, **loại** khỏi chi vận hành) | chỉ tính vào vốn sửa, **không** tính tiền ra |

## 5. Nghi vấn cần đối chiếu khi chạy test (xem kết quả test để xác nhận)

1. **Vốn đơn trả góp đã tất toán** (S6, S7): V2 ghi vốn theo tỉ lệ tiền nhận
   (16.575.000 / 6.240.000) trong khi vốn thật là 17.000.000 / 8.000.000 — phần phí
   NH không bao giờ về nhưng vốn vẫn bị "khấu" theo → lãi gộp cao hơn thực
   425.000 + 160.000. Báo cáo ngày ghi đủ vốn (3.400.000 + 13.600.000 = 17.000.000).
2. **Nhập kho nhiều dòng trả TM/CK** (I1): `analyze()` khớp từng dòng history với
   expense theo số tiền (±1.000). Expense là tổng phiếu 3.000.000, dòng là
   2.000.000 / 1.000.000 → dòng 2.000.000 không khớp ⇒ nghi tiền ra TM bị cộng
   thêm 2.000.000 (và dòng 1.000.000 khớp nhầm với expense của I2).
