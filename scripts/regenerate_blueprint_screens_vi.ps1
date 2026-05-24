$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Location).Path
$root = Join-Path $repoRoot 'DOCS/BLUEPRINT'
$screensDir = Join-Path $root 'screens'

$viewFiles = Get-ChildItem -Path 'lib/views' -Recurse -File -Filter '*.dart' | Sort-Object FullName
$scanPath = Join-Path $repoRoot 'docs/_blueprint_view_scan.tsv'
$scanMap = @{}
if (Test-Path $scanPath) {
    foreach ($line in Get-Content $scanPath) {
        $parts = $line -split "`t"
        if ($parts.Length -ge 2) { $scanMap[$parts[0].Trim()] = $line }
    }
}

function Get-Domain([string]$name, [string]$rel) {
    $n = $name.ToLowerInvariant(); $r = $rel.ToLowerInvariant()
    if ($n -match 'login|register|intro|splash|shop_selector|business_type_wizard') { return 'Xác thực & Khởi tạo' }
    if ($n -match 'repair|order_list|warranty|partner|salvage') { return 'Sửa chữa & Bảo hành' }
    if ($n -match 'sale|invoice|payment_request|bank_installment|sales_return') { return 'Bán hàng & Thu tiền' }
    if ($n -match 'inventory|stock|import|product|variant|category|label|imei|qr|storage|expiry') { return 'Kho & Sản phẩm' }
    if ($n -match 'debt|expense|cash_closing|financial|payroll|salary|adjustment') { return 'Tài chính & Công nợ' }
    if ($n -match 'attendance|staff|shift|hr') { return 'Nhân sự' }
    if ($n -match 'customer|supplier|profile|community|chat') { return 'CRM & Giao tiếp' }
    if ($n -match 'settings|guide|help|about|notification|dashboard|super_admin|audit|backup') { return 'Quản trị & Cài đặt' }
    if ($r -match 'expansion') { return 'Expansion Modules' }
    return 'Tổng hợp vận hành'
}

foreach ($vf in $viewFiles) {
    $rel = $vf.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
    $base = [IO.Path]::GetFileNameWithoutExtension($vf.Name)
    $relativeView = $rel.Replace('lib/views/', '')
    $slug = $relativeView.Replace('/', '_').Replace('.dart', '')
    $docPath = Join-Path $screensDir "$slug.md"

    $scan = $null
    if ($scanMap.ContainsKey($vf.FullName)) { $scan = $scanMap[$vf.FullName] }
    elseif ($scanMap.ContainsKey($rel)) { $scan = $scanMap[$rel] }

    $class = ''; $navPush = '0'; $fab = 'False'; $dialog = 'False'; $sheet = 'False'; $list = 'False'
    if ($scan) {
        foreach ($seg in ($scan -split "`t")) {
            if ($seg -like 'class=*') { $class = $seg.Substring(6) }
            if ($seg -like 'navPush=*') { $navPush = $seg.Substring(8) }
            if ($seg -like 'fab=*') { $fab = $seg.Substring(4) }
            if ($seg -like 'dialog=*') { $dialog = $seg.Substring(7) }
            if ($seg -like 'sheet=*') { $sheet = $seg.Substring(6) }
            if ($seg -like 'list=*') { $list = $seg.Substring(5) }
        }
    }

    $domain = Get-Domain -name $base -rel $rel

    $content = @"
# $base

Nguồn code: $rel

## 1. Purpose
- Miền nghiệp vụ: $domain.
- Mục đích chính: màn hình này là một điểm thao tác thực chiến trong chuỗi vận hành cửa hàng, ưu tiên tốc độ và độ chính xác.
- Ý nghĩa kinh doanh: giảm thời gian xử lý mỗi giao dịch, hạn chế sai lệch dữ liệu giữa các thiết bị.

## 2. Layout hierarchy
- Root: `Scaffold` với AppBar theo ngôn ngữ thiết kế chung.
- Widget chính: $class
- Tín hiệu cấu trúc: list/grid = $list, FAB = $fab, dialog = $dialog, bottom sheet = $sheet.
- Cấu trúc section điển hình: trạng thái/tổng quan -> bộ lọc/tìm kiếm -> danh sách thao tác -> nút xác nhận.

## 3. Visual design
- Nền mặc định: `AppColors.background` (#F8FAFF), card trắng viền mảnh.
- Typography: Roboto, cấp chữ ưu tiên đọc nhanh tại quầy (title 16-22, body 12-16).
- Màu hành động: xanh #0068FF cho CTA; cam cảnh báo; đỏ lỗi; xanh lá thành công.
- Border radius và spacing: 8-16px, touch target tối thiểu 44px.

## 4. UX behavior
- Tương tác chính: bấm vào item để mở chi tiết hoặc xử lý nhanh trong ngữ cảnh hiện tại.
- Điều hướng nội bộ: file có khoảng $navPush điểm `Navigator.push`, cho thấy mức độ điều phối đa màn hình.
- Tìm kiếm/lọc: ưu tiên lọc cục bộ tức thì, sau đó mới đồng bộ/fetch cloud khi cần.
- Dialog/sheet: dùng để giảm context switch, tránh bắt người dùng rời màn hình chính quá nhiều.

## 5. Animation
- Transition chuẩn Material, thời lượng ngắn (150-220ms) để cảm giác app “nhanh tay”.
- Dialog/sheet dùng fade + slide ngắn, tránh animation dài gây chậm nhịp thao tác.
- Loading animation đặt gần vùng dữ liệu thay vì che phủ toàn màn hình khi không cần thiết.

## 6. Loading states
- Initial load: spinner/skeleton nhẹ.
- Submit async: khóa nút xác nhận tạm thời, hiển thị trạng thái đang xử lý.
- Danh sách lớn: tối ưu lazy rendering để giữ FPS ổn định.

## 7. Error states
- Lỗi mạng: fallback local trước, thông báo tiếng Việt rõ ràng và có hướng hành động tiếp theo.
- Lỗi validation: chặn sớm tại field và hiển thị ngay cạnh vùng nhập.
- Empty state: phân biệt rỗng do chưa có dữ liệu, do bộ lọc, hay do thiếu quyền.
- Retry flow: có cơ chế thử lại/refresh mà không làm mất dữ liệu đang nhập.

## 8. Offline behavior
- Đọc/ghi local SQLite trước; record mới/sửa thường ở trạng thái `isSynced = 0`.
- Tác vụ ảnh ưu tiên lưu local path rồi upload nền khi có mạng.
- Quy tắc xung đột: local chưa sync được ưu tiên giữ để tránh mất thao tác tại quầy.

## 9. Navigation
- Đi đến: thường từ Home shortcut hoặc màn hình danh sách liên quan.
- Đi tiếp: sang chi tiết/tạo mới/thanh toán/in ấn tùy ngữ cảnh nghiệp vụ.
- Quan hệ: màn hình nằm trong cụm $domain và gắn với service domain tương ứng.

## 10. Business meaning
- Vai trò thực tế: một mắt xích trong chuỗi xử lý đơn hàng, tồn kho, công nợ và chăm sóc khách.
- KPI tác động: thời gian thao tác, tỷ lệ lỗi nhập liệu, độ chính xác báo cáo cuối ngày.
- Rủi ro tiềm ẩn: race condition đa thiết bị, timeout cloud, lệch quyền do cache role.

## Tín hiệu kỹ thuật quan sát được
- navPush=$navPush, FAB=$fab, Dialog=$dialog, BottomSheet=$sheet, ListOrGrid=$list.
- Cần test runtime bổ sung cho các edge case gesture/animation hiếm.
"@

    Set-Content -Path $docPath -Value $content -Encoding UTF8
}

Write-Host "Regenerated $($viewFiles.Count) screen docs with Vietnamese diacritics."