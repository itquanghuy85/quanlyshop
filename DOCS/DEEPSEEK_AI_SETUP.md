# DeepSeek AI — Hướng Dẫn Cài Đặt & Deploy

## Kiến Trúc

```
Flutter App
  └─► Firebase Cloud Function  (asia-southeast1)
        └─► DeepSeek API       (api.deepseek.com)
```

API key **không bao giờ** rời khỏi backend. Flutter chỉ gọi Cloud Function qua SDK.

---

## 1. Đặt Secret Key (một lần duy nhất)

```bash
# Từ thư mục gốc project hoặc functions/
firebase secrets:set DEEPSEEK_API_KEY
# Paste key khi được hỏi → Enter
```

Key được lưu trong **Google Secret Manager** của project `huyaka-1809`.  
Không commit vào git, không xuất hiện trong code, không lộ trong logs.

Kiểm tra secret đã tồn tại:
```bash
firebase secrets:get DEEPSEEK_API_KEY
```

> File key local ở `D:\android-keys` — **chỉ dùng để chạy lệnh trên**, không copy vào project.

---

## 2. Deploy Function

```bash
cd d:\FlutterProjects\quanlyshop

# Deploy riêng function AI (nhanh hơn deploy all)
firebase deploy --only functions:createRepairOrderAI

# Hoặc deploy toàn bộ functions
firebase deploy --only functions
```

Sau deploy, function có địa chỉ:
```
https://asia-southeast1-huyaka-1809.cloudfunctions.net/createRepairOrderAI
```
*(Flutter không dùng URL này — gọi qua SDK `cloud_functions` thay thế)*

---

## 3. Test Local với Emulator

```bash
cd d:\FlutterProjects\quanlyshop\functions

# Cài dependencies nếu chưa có
npm install

# Đặt secret cho emulator (chỉ cần 1 lần)
firebase functions:secrets:access DEEPSEEK_API_KEY > .secret.local
# → Tạo file .secret.local chứa key (đã có trong .gitignore)

# Chạy emulator
firebase emulators:start --only functions
```

Emulator chạy tại `http://localhost:5001/huyaka-1809/asia-southeast1/createRepairOrderAI`.

**Flutter kết nối emulator** (trong `main.dart` khi debug):
```dart
// Thêm vào initState() hoặc trước runApp() khi test local
if (kDebugMode) {
  FirebaseFunctions.instanceFor(region: 'asia-southeast1')
      .useFunctionsEmulator('localhost', 5001);
}
```

Test bằng curl:
```bash
curl -X POST \
  "http://localhost:5001/huyaka-1809/asia-southeast1/createRepairOrderAI" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "text": "iphone 13 mất face khách tên Hùng giá 500"
    }
  }'
```

---

## 4. Dùng trong Flutter

```dart
import 'package:quanlyshop/services/ai_service.dart';

// Trong widget hoặc controller:
final (result, error) = await AiService.instance.tryParseRepairText(
  'iphone 13 mất face khách tên Hùng giá 500',
);

if (error != null) {
  // Hiện snackbar lỗi
  NotificationService.showSnackBar(error, color: Colors.red);
  return;
}

if (result!.isRepairOrder) {
  // Điền vào form
  setState(() {
    nameCtrl.text = result.customerName;
    phoneCtrl.text = result.customerPhone;
    modelCtrl.text = result.device;
    issueCtrl.text = result.issue;
    depositAmount = result.deposit;
  });
}
```

---

## 5. Tích Hợp với Nút "Nhập Nhanh"

Trong `create_repair_order_view.dart`, thay thế hoặc bổ sung sau khi local parser không đủ:

```dart
Future<void> _showNaturalRepairInputDialog() async {
  // ... (bottom sheet hiện tại)
  
  // Sau khi user nhấn "Áp dụng":
  final input = await showModalBottomSheet<String>(...);
  if (!mounted || input == null || input.trim().isEmpty) return;

  // 1. Thử local parser trước (nhanh, offline)
  final localParsed = NaturalOrderParserService.parse(input);
  
  // 2. Nếu local parser không đủ field → dùng AI
  final needsAI = localParsed.repair?.customerName?.isEmpty == true
      || localParsed.repair?.issue?.isEmpty == true;

  if (needsAI) {
    setState(() => _isAiParsing = true);
    final (aiResult, aiError) = await AiService.instance.tryParseRepairText(input);
    setState(() => _isAiParsing = false);
    
    if (aiResult != null && aiResult.isRepairOrder) {
      // Điền từ AI result
      if (aiResult.customerName.isNotEmpty) nameCtrl.text = aiResult.customerName;
      if (aiResult.customerPhone.isNotEmpty) phoneCtrl.text = aiResult.customerPhone;
      if (aiResult.device.isNotEmpty) modelCtrl.text = aiResult.device;
      if (aiResult.issue.isNotEmpty) issueCtrl.text = aiResult.issue;
    }
  }
}
```

---

## 6. Rate Limit & Security

| Rule | Giá trị |
|------|---------|
| Requests / user / phút | 30 |
| Max text length | 500 ký tự |
| Timeout DeepSeek | 22 giây |
| Timeout Function | 30 giây |
| Retry | 1 lần khi 429 / 5xx |
| Auth | Bắt buộc Firebase Auth |

Rate limit lưu trong Firestore collection `_ai_rate_limit/{uid}` — tự reset sau 1 phút.

---

## 7. Mở Rộng AI Actions

Thêm function mới trong `functions/index.js` theo cùng pattern:

```js
exports.searchRepairOrdersAI = onCall(
  { secrets: [deepseekApiKey], timeoutSeconds: 30 },
  async (request) => { /* ... */ }
);
```

Thêm method mới trong `lib/services/ai_service.dart`:

```dart
Future<AiSearchResult> searchRepairOrders(String query) async {
  final callable = _functions.httpsCallable('searchRepairOrdersAI', ...);
  // ...
}
```

Các action dự kiến mở rộng:
- `searchRepairOrdersAI` — Tìm đơn bằng ngôn ngữ tự nhiên
- `summarizeFinanceAI` — Tổng kết tài chính tháng  
- `parseVoiceInputAI` — Phân tích audio → text → đơn hàng

---

## 8. Giám Sát & Logs

```bash
# Xem logs function AI
firebase functions:log --only createRepairOrderAI

# Xem toàn bộ logs
firebase functions:log
```

Logs format:
```
🤖 createRepairOrderAI uid=xxx text="iphone 13..."
✅ createRepairOrderAI result: {"intent":"create_repair_order",...}
❌ callDeepSeek exception: ...
⚠️ DeepSeek 429 — retry 1
```
