$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Location).Path
$root = Join-Path $repoRoot 'DOCS/BLUEPRINT'
$screensDir = Join-Path $root 'screens'
New-Item -ItemType Directory -Force -Path $screensDir | Out-Null

$viewFiles = Get-ChildItem -Path 'lib/views' -Recurse -File -Filter '*.dart' | Sort-Object FullName
$scanPath = Join-Path $repoRoot 'docs/_blueprint_view_scan.tsv'
$scanMap = @{}
if (Test-Path $scanPath) {
    foreach ($line in Get-Content $scanPath) {
        $parts = $line -split "`t"
        if ($parts.Length -ge 2) {
            $scanMap[$parts[0].Trim()] = $line
        }
    }
}

function Get-Domain([string]$name, [string]$rel) {
    $n = $name.ToLowerInvariant()
    $r = $rel.ToLowerInvariant()
    if ($n -match 'login|register|intro|splash|shop_selector|business_type_wizard') { return 'Xac thuc & Khoi tao' }
    if ($n -match 'repair|order_list|warranty|partner|salvage') { return 'Sua chua & Bao hanh' }
    if ($n -match 'sale|invoice|payment_request|bank_installment|sales_return') { return 'Ban hang & Thu tien' }
    if ($n -match 'inventory|stock|import|product|variant|category|label|imei|qr|storage|expiry') { return 'Kho & San pham' }
    if ($n -match 'debt|expense|cash_closing|financial|payroll|salary|adjustment') { return 'Tai chinh & Cong no' }
    if ($n -match 'attendance|staff|shift|hr') { return 'Nhan su' }
    if ($n -match 'customer|supplier|profile|community|chat') { return 'CRM & Giao tiep' }
    if ($n -match 'settings|guide|help|about|notification|dashboard|super_admin|audit|backup') { return 'Quan tri & Cai dat' }
    if ($r -match 'expansion') { return 'Expansion Modules' }
    return 'Tong hop van hanh'
}

function Get-Purpose([string]$base) {
    $b = $base.ToLowerInvariant()
    if ($b -eq 'home_view') { return 'Trung tam dieu phoi toan bo app voi truy cap nhanh cac module quan trong.' }
    if ($b -match 'login_view|register_view') { return 'Xac thuc nguoi dung, nap ngu canh shop va quyen.' }
    if ($b -match 'create_repair_order_view|repair_detail_view|order_list_view') { return 'Quan ly vong doi don sua tu tiep nhan den ban giao.' }
    if ($b -match 'create_sale_view|sale_list_view|sale_detail_view') { return 'Thuc thi POS va theo doi doanh thu/gia von theo giao dich.' }
    if ($b -match 'inventory_view|parts_inventory_view|smart_stock_in_view|fast_stock_in_view') { return 'Dieu pho i ton kho toc do cao: nhap hang, kiem ke, cap nhat trang thai.' }
    if ($b -match 'debt_view|expense_view|cash_closing_view|financial_activity_log_view') { return 'Kiem soat dong tien va cong no theo ngay.' }
    return 'Man hinh chuyen biet phuc vu chuoi van hanh cua cua hang.'
}

$screenIndex = New-Object System.Collections.Generic.List[string]

foreach ($vf in $viewFiles) {
    $rel = $vf.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
    $base = [IO.Path]::GetFileNameWithoutExtension($vf.Name)
    $relativeView = $rel.Replace('lib/views/', '')
    $slug = $relativeView.Replace('/', '_').Replace('.dart', '')
    $docName = "$slug.md"
    $docPath = Join-Path $screensDir $docName

    $domain = Get-Domain -name $base -rel $rel
    $purpose = Get-Purpose -base $base
    $scan = $null
    if ($scanMap.ContainsKey($vf.FullName)) { $scan = $scanMap[$vf.FullName] }
    elseif ($scanMap.ContainsKey($rel)) { $scan = $scanMap[$rel] }

    $class = ''
    $navPush = '0'
    $fab = 'False'
    $dialog = 'False'
    $sheet = 'False'
    $list = 'False'

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

    $content = @"
# $base

Nguon code: $rel

## 1. Purpose
- Mien nghiep vu: $domain.
- Muc tieu chinh: $purpose
- Gia tri thuc te: rut ngan thao tac, giu nhat quan du lieu local/cloud.

## 2. Layout hierarchy
- Root: Scaffold theo tieu chuan app, AppBar xanh thuong hieu.
- Widget chinh: $class
- Cau truc hien thi: list/grid = $list, FAB = $fab, dialog = $dialog, bottom sheet = $sheet.
- To chuc section: header trang thai -> bo loc/tim kiem -> danh sach -> hanh dong xac nhan.

## 3. Visual design
- Nen: #F8FAFF; card trang vien mong.
- Typography: Roboto, title 16-22, body 12-16.
- Mau nhan: #0068FF (CTA), cam (warning), do (error), xanh la (success).
- Bo goc: 8-16, touch target toi thieu 44.

## 4. UX behavior
- Nhan vao item de mo chi tiet hoac thao tac nhanh.
- Dieu huong trong file co khoang $navPush lan Navigator.push.
- Tim kiem/loc uu tien cuc bo truoc khi goi cloud.
- Dialog/sheet dung de sua nhanh trong ngu canh hien tai.

## 5. Animation
- Material transition ngan (150-220ms).
- Dialog/sheet fade + slide ngan.
- Loading indicator dat gan vung du lieu.

## 6. Loading states
- Spinner/skeleton khi mo man hinh.
- Disable nut submit khi dang xu ly async.
- Danh sach dai uu tien lazy render.

## 7. Error states
- Loi mang: fallback local + thong bao ro hanh dong tiep theo.
- Loi validation: chan submit va thong bao sat field.
- Empty state: phan biet chua co du lieu, filter chat, hoac khong du quyen.

## 8. Offline behavior
- Doc/ghi local truoc, danh dau isSynced=0.
- Anh luu local truoc, upload nen khi online.
- Conflict rule: local unsynced duoc uu tien giu.

## 9. Navigation
- Thuong vao tu Home shortcut, danh sach nghiep vu, hoac deep link noi bo.
- Thuong roi toi detail/create/payment/print.
- Thuoc cum nghiep vu: $domain.

## 10. Business meaning
- Day la diem cham trong chuoi van hanh don hang - ton kho - tai chinh - cham soc khach.
- KPI anh huong: toc do thao tac, ty le loi nhap lieu, do chinh xac so lieu cuoi ngay.
- Rui ro: race condition khi nhieu thiet bi, timeout cloud, sai lech role cache.

## Tin hieu ky thuat quan sat duoc
- navPush=$navPush, FAB=$fab, Dialog=$dialog, BottomSheet=$sheet, ListOrGrid=$list.
- Can test runtime bo sung cho gesture/animation hiem.
"@

    Set-Content -Path $docPath -Value $content -Encoding UTF8
    $screenIndex.Add("- [$base](screens/$docName)")
}

$indexPath = Join-Path $root 'index.md'
if (Test-Path $indexPath) {
    $index = Get-Content $indexPath -Raw
    $screenBlock = "## Screen Documentation`nTong so man hinh/views da lap ho so: $($viewFiles.Count)`n`n$($screenIndex -join "`n")`n"
    if ($index -match '## Screen Documentation[\s\S]*?## Blueprint Coverage') {
        $index = [regex]::Replace($index, '## Screen Documentation[\s\S]*?## Blueprint Coverage', "$screenBlock`n## Blueprint Coverage")
    }
    else {
        $index += "`n$screenBlock"
    }
    Set-Content -Path $indexPath -Value $index -Encoding UTF8
}

Write-Host "Generated $($viewFiles.Count) screen docs in DOCS/BLUEPRINT/screens"