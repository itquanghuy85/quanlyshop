# Kiểm thử firestore.rules bằng emulator (không đụng production)

Dùng khi một thao tác bị `PERMISSION_DENIED` mà đọc rules thấy "đáng lẽ phải qua".
Cách này tìm ra lỗi 2026-09-11: `data.deleted != true` **lỗi đánh giá → false**
khi doc `shops/{id}` không có field `deleted` ⇒ chủ shop không tạo được danh mục.

```bash
cd tools/firestore_rules_test
npm install
cp ../../firestore.rules .
# firebase-tools cần JDK ≥ 21 — máy dev có sẵn JBR của Android Studio:
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"; export PATH="$JAVA_HOME/bin:$PATH"
firebase emulators:exec --only firestore --project huyaka-1809 "node shop_deleted_field_test.js"
```

Kết quả mong đợi: `PASS s_nofield allowed`, `PASS s_deleted blocked`, `PASS s_false allowed`.

Viết test mới: copy file `.js`, seed dữ liệu trong `withSecurityRulesDisabled`,
tạo context bằng `authenticatedContext(uid, claims)` rồi `assertSucceeds` /
`assertFails`. Bisect từng field/claim khi chưa rõ điều kiện nào rớt.
