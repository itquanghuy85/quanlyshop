# APNs Firebase Setup

Tai lieu nay dung de ban chuyen repo sang Mac build iOS ma khong commit APNs key vao Git.

## Ket luan ngan

- KHONG dua file .p8 vao thu muc ios/ hoac trong app bundle.
- KHONG commit file .p8 len GitHub.
- APNs Auth Key duoc cau hinh ben ngoai app, tren Apple Developer va Firebase Console.

## Trang thai repo hien tai

- Bundle ID iOS Release: com.huluca.shop
- Team ID: F7B6X2BZ6A
- Release entitlement: aps-environment = production
- Debug entitlement: aps-environment = development
- Firebase iOS plist dang map dung bundle id com.huluca.shop
- App da co code dang ky remote notifications va FCM tren iOS
- App da co man hinh kiem tra trong `Cai dat thong bao` hien:
   - Authorization status
   - APNs token preview
   - FCM token preview
   - Server token preview tren Firestore

## Ban can lam tren Apple Developer

1. Vao Certificates, Identifiers & Profiles.
2. Mo App ID cua com.huluca.shop.
3. Dam bao Push Notifications da bat.
4. Vao Keys va tao hoac chon APNs Auth Key.
5. Ghi lai:
   - Key ID
   - Team ID
   - File AuthKey_XXXXXXXXXX.p8

## Ban can lam tren Firebase Console

1. Mo project Firebase dang dung cho app nay.
2. Vao Project Settings -> Cloud Messaging.
3. Tim muc Apple app configuration.
4. Upload file .p8.
5. Nhap Key ID.
6. Nhap Team ID: F7B6X2BZ6A.
7. Xac nhan bundle id app iOS la com.huluca.shop.

## Nhung gi build tren Mac can kiem tra

1. flutter pub get
2. Open ios/Runner.xcworkspace bang Xcode
3. Runner -> Signing & Capabilities:
   - Team = F7B6X2BZ6A
   - Bundle Identifier = com.huluca.shop
   - Push Notifications = ON
   - Background Modes = Remote notifications, Background fetch
4. Chon Any iOS Device (arm64)
5. Product -> Archive
6. Organizer -> Distribute App -> App Store Connect -> Upload

## Test sau khi upload TestFlight

1. Cai build TestFlight tren iPhone that.
2. Dang nhap vao tai khoan test.
3. Cho app xin quyen thong bao.
4. Vao `Cai dat thong bao`.
5. Xac nhan tren man hinh:
   - Authorization = authorized hoac provisional
   - APNs = co gia tri
   - FCM = co gia tri
   - Server token = co gia tri
6. Neu APNs chua co:
   - Kiem tra lai Signing & Capabilities -> Push Notifications
   - Kiem tra build dung provisioning profile cua bundle id `com.huluca.shop`
   - Mo lai app va bam `LAM MOI FCM TOKEN`
7. Gui 1 push test tu Firebase/Cloud Function.
8. Test 3 trang thai:
   - foreground
   - background
   - app da bi tat hoan toan
9. Xac nhan khi foreground thi app hien banner/noi dung thong bao.
10. Xac nhan khi background/terminated thi iOS hien push system notification.

## Neu push van khong den tren TestFlight

1. Kiem tra APNs key da upload dung Firebase project chua.
2. Kiem tra app iOS tren Firebase co bundle id com.huluca.shop.
3. Kiem tra build dang dung RunnerRelease.entitlements voi aps-environment = production.
4. Kiem tra man `Cai dat thong bao` trong app co APNs token hay khong.
5. Kiem tra thiet bi da cho phep Notifications.
6. Kiem tra token FCM moi nhat da luu len Firestore.
7. Kiem tra server/Cloud Function dang gui notification message thay vi chi data-only khi can hien thong bao.
8. Neu co FCM token nhung khong co APNs token tren iPhone, uu tien sua capability/provisioning truoc khi debug Firebase.

## Bao mat

- Khong gui file .p8 vao repo nay.
- Khong luu file .p8 trong thu muc ios/.
- Neu can chuyen file .p8 sang Mac, dung kenh rieng va luu local tren may build.