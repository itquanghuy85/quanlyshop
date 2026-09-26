# Báo cáo Audit Đồng bộ 2 máy — Quản Lý Shop

**Ngày:** 2026-09-18 (chiều)
**Người thực hiện:** QA tự động qua adb/uiautomator (không sửa code)
**Kết luận:** ✅ ĐỒNG BỘ ĐẠT — toàn bộ kịch bản CRUD 2 chiều, offline-first, live-push,
conflict đều hoạt động đúng; dữ liệu test đã dọn sạch và hội tụ hoàn toàn.

---

## 1. Môi trường

| Thiết bị | Serial | Vai trò | Tài khoản |
|---|---|---|---|
| CPH2203 | `NJR8W86LKRVW7DHQ` | A — chủ shop (owner) | firestoreId ghi đơn = `M` |
| CPH2239 | `WCE65565HMDYOB59` | B — nhân viên (employee) | — |

- Shop: `geqXPHQJ3nT6XkMbeh6JswTdGbr2`
- App: `com.huluca.shopmanager`, SQLite `repair_shop_v22.db` schema v111
- Toàn bộ dữ liệu test mang tiền tố `SYNC*` (SYNCX001, SYNC_TÉT_002/003, SYNCOFF1,
  SYNCCONFA/SYNCCONFB, repair `rep_1789699617453_617453` model `MAYTESTLIVE`).
- Kết nối: USB adb; kiểm tra offline bằng `svc wifi/data disable` (ping 100% loss).

## 2. Bảng kết quả kịch bản

| # | Kịch bản | Kết quả | Bằng chứng chính |
|---|---|---|---|
| RT-01 | A→B tạo khách | ✅ | `SYNCX001` A id23 `customer_1789696194647` → B id902, byte-identical |
| RT-02 | B→A tạo khách | ✅ | `SYNC_TÉT_003` B id903 `customer_1789696853314` → A id25 |
| RT-03 | A→B sửa | ✅ | `SYNCX001`→`SYNCEDIT1`, updatedAt 1789698016777, B id902 giống hệt |
| RT-04 | B→A sửa | ✅ | →`SYNCEDIT2`, updatedAt 1789698322689, A id23 giống hệt |
| RT-05 | A→B xoá (soft) | ✅ | `SYNC_TÉT_002` (A id24/B id904) `deleted=1`, updatedAt 1789698397233 khớp |
| RT-06 | B→A xoá (soft) | ✅ | `SYNC_TÉT_003` (A id25/B id903) `deleted=1`, updatedAt 1789698475665 khớp |
| RT-07 | Offline-first A→B | ✅ | A tạo `SYNCOFF1` khi mất mạng (isSynced=0, firestoreId='') → bật mạng push ~10s (`customer_1789698596267`, createdAt giữ nguyên 1789698596173) → B nhận đúng |
| RT-08 | Live-push repair | ✅ | A tạo repair `rep_1789699617453_617453` (status=1, model=MAYTESTLIVE, issue='TẺTTPUSH') → **B nhận trong <4s KHÔNG chạm máy B**; B còn hiện banner "🔧 ĐƠN SỬA MỚI 0904000001 MAYTESTLIVE" ngay trên màn hình |
| RT-09 | Conflict (last-write-wins) | ✅ | B (offline) sửa `SYNCCONFA`→`SYNCCONFB` → bật mạng push → **cả A & B = SYNCCONFB, updatedAt 1789700027098 khớp tuyệt đối**; không merge, không mất dữ liệu |

Khác biệt bổ sung ghi nhận được ở RT-08: repair tạo bằng form có cột bên phải nhập số
điện thoại → DB lưu `customerName='0904000001'`, `phone=''` (quirk của form, đồng bộ
vẫn nhất quán cả 2 máy).

## 3. Phát hiện kiến trúc (đối chiếu code + đo đạc thực tế)

1. **Khách hàng**: tạo/sửa/xoá — upsert theo `firestoreId`, không trùng lặp, byte-identical.
   Khi sync nhận doc có `deleted==true` → **hard-delete bản ghi LOCAL** (`sync_service.dart:2130-2131`),
   không giữ tombstone cục bộ lâu. Tombstone `deleted=1` cục bộ là trạng thái "chờ cycle kế".
2. **Repairs**: kênh LIVE — nhận push thực tế <4s khi máy khác ghi, kể cả máy đang ở màn hình khác.
   Xoá repair qua UI = soft-delete trên Firestore rồi **hard-delete local**
   (`order_list_view.dart:1516` `_executeDelete` → cần **reauth mật khẩu**).
3. **Offline**: tạo khi offline → isSynced=0, firestoreId rỗng, born-sync ~10s sau khi phục hồi,
   `createdAt` giữ đúng thời điểm tạo gốc.
4. **Conflict**: không có merge thông minh — **last-write-wins** sạch, cả 2 máy hội tụ đúng bản ghi sau nhất
   kèm cùng `updatedAt` (máy offline ghi sau → bản đó thắng khi push).
5. **Set toàn cục**: 2 máy không bao giờ lệch số bản ghi hoạt động; danh sách tránh trùng chéo.

## 4. Cleanup & trạng thái cuối

- Tất cả khách test: sync-xoá → hội tụ `deleted=1` (cùng updatedAt) → sau đó tự prune cục bộ.
- Repair test: xoá qua UI (mật khẩu quản lý `123123`) → A 22 đơn, B tự nhận tombstone live → 22 đơn.
- **Parity cuối (active-only):**
  - customers: A = 20, B = 20, set khác biệt = **0**
  - repairs:   A = 22, B = 22, set khác biệt = **0**
  - Không còn bản ghi `SYN*`/`SYNCX`/`SYNCOFF` nào sống trên cả 2 máy; test id repair = 0.
- Ghi chú dọn nhẹ: tombstone cục bộ (`deleted=1`) có thể đôi máy giữ lâu hơn (local housekeeping),
  KHÔNG ảnh hưởng tới dữ liệu hoạt động (thống kê active luôn khớp).

## 5. Lệnh lặp lại (cheat-sheet cho lần audit sau)

- Dump UI & đọc node: `Get-UiNodes <serial>`. **Quan trọng:** dòng danh sách đẩy nội dung vào
  `content-desc` (không vào `text`; còn `&#10;`→space). Chỉ EditText có `text`.
  **Bẫy encoding:** mẫu regex có dấu tiếng Việt trong PowerShell bị vỡ — luôn match theo số
  điện thoại ASCII trong desc, hoặc bấm theo toạ độ cố định.
- Vị trí chuẩn (A 1080px): QLKH = 'Bán hàng' (238,2124) → tile QLKH (540,1570);
  detail khách: tên (540,1502), sđt (540,1634), Lưu hồ sơ (852,176), Xóa (996,176) → xác nhận (807,1342).
  B (720px): Lưu (568,116), Xóa (664,116) → (538,894); field tên cy≈1000, sđt cy≈1088.
- Xoá repair: long-press row bằng `input touchscreen motionevent DOWN/UP` (900ms) → dialog
  'XÁC NHẬN XÓA ĐƠN' → nhập mật khẩu quản lý → XÓA (540,1587).
- Offline: `svc wifi disable; svc data disable` (kim loại USB adb không bị ảnh hưởng) → verify
  `ping -c 1 -W 2 8.8.8.8` → `svc wifi enable; svc data enable`.
- Trong lúc tạo đơn sửa lần đầu có overlay guide "Tạo Đơn Sửa Chữa 1/6" — bấm qua bằng 'Tiếp theo'.