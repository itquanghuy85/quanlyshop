const admin = require("firebase-admin");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2/options");

admin.initializeApp();
// Giới hạn region & timeout mặc định
setGlobalOptions({ region: "asia-southeast1", timeoutSeconds: 30 });

// 🔔 Thông báo khi CÓ ĐƠN SỬA MỚI
exports.notifyNewRepair = onDocumentCreated("repairs/{repairId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const payload = {
    notification: {
      title: "🔧 Có đơn sửa mới",
      body: `${data.customerName} - ${data.model}`,
    },
    data: {
      repairId: event.params.repairId,
    },
  };

  try {
    await admin.messaging().sendToTopic("staff", payload);
    console.log("Đã gửi thông báo đơn mới");
  } catch (e) {
    console.error("Lỗi gửi thông báo:", e);
  }
});

// 🔔 Thông báo khi ĐỔI TRẠNG THÁI (đã sửa / đã giao)
exports.notifyStatusChange = onDocumentUpdated("repairs/{repairId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status === after.status) return;

  let statusText = "Cập nhật đơn sửa";
  if (after.status === 2) statusText = "🛠️ Đã sửa xong";
  if (after.status === 3) statusText = "✅ Đã giao máy";

  const payload = {
    notification: {
      title: statusText,
      body: `${after.customerName} - ${after.model}`,
    },
  };

  try {
    await admin.messaging().sendToTopic("staff", payload);
    console.log("Đã gửi thông báo đổi trạng thái");
  } catch (e) {
    console.error("Lỗi gửi thông báo:", e);
  }
});

// ✅ Chỉ quản lý/super admin được tạo tài khoản nhân viên qua callable
exports.createStaffAccount = onCall(async (request) => {
  const data = request.data || {};
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập để tạo tài khoản");
  }

  const requesterUid = auth.uid;
  const requesterEmail = auth.token.email || "";
  const isSuperAdmin = requesterEmail === "admin@huluca.com";

  const requesterDoc = await admin.firestore().collection("users").doc(requesterUid).get();
  const requesterData = requesterDoc.data() || {};
  const requesterRole = isSuperAdmin ? "admin" : requesterData.role || "user";
  const requesterShopId = requesterData.shopId || requesterUid;

  // Allow owner and admin to create staff accounts
  if (!isSuperAdmin && requesterRole !== "admin" && requesterRole !== "owner") {
    throw new HttpsError("permission-denied", "Chỉ chủ shop hoặc quản lý mới được tạo tài khoản nhân viên");
  }

  const email = (data.email || "").toString().trim().toLowerCase();
  const password = (data.password || "").toString();
  const displayName = (data.displayName || "").toString().trim();
  const phone = (data.phone || "").toString().trim();
  const address = (data.address || "").toString().trim();
  let role = (data.role || "user").toString();
  let shopId = (data.shopId || "").toString().trim();

  if (!email || !password || password.length < 6 || !displayName) {
    throw new HttpsError("invalid-argument", "Thiếu email/mật khẩu/tên hoặc mật khẩu quá ngắn");
  }

  // Admin bình thường chỉ tạo được trong shop của mình; super admin có thể chỉ định shopId khác
  if (!isSuperAdmin || shopId === "") {
    shopId = requesterShopId;
  }

  // Chỉ cho phép nâng lên admin khi chính caller là admin/super admin
  if (role !== "admin" || (!isSuperAdmin && requesterRole !== "admin")) {
    role = "user";
  }

  try {
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName,
    });

    const basePermissions = {
      allowViewSales: true,
      allowViewRepairs: true,
      allowViewInventory: true,
      allowViewParts: true,
      allowViewSuppliers: true,
      allowViewCustomers: true,
      allowViewWarranty: true,
      allowViewChat: true,
      allowViewPrinter: true,
      allowViewRevenue: role === "admin",
      allowViewExpenses: role === "admin",
      allowViewDebts: role === "admin",
    };

    await admin.firestore().collection("users").doc(userRecord.uid).set({
      email,
      displayName: displayName.toUpperCase(),
      phone,
      address: address.toUpperCase(),
      role,
      shopId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: requesterUid,
      ...basePermissions,
    }, { merge: true });

    await admin.firestore().collection("shops").doc(shopId).set({
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastStaffCreatedBy: requesterUid,
    }, { merge: true });

    return {
      uid: userRecord.uid,
      role,
      shopId,
    };
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Email đã tồn tại");
    }
    console.error("Lỗi tạo tài khoản nhân viên:", e);
    throw new HttpsError("internal", "Không thể tạo tài khoản mới");
  }
});

// --- CLEANUP (OPT-IN): XÓA HOÀN TOÀN NHỮNG REPAIR ĐÃ ĐÁNH DẤU deleted=true SAU N NGÀY ---
// Tính năng này là 'opt-in' — chỉ chạy nếu doc `settings/cleanup` tồn tại và có `enabled: true`.
// Để bật: tạo doc `settings/cleanup` với { enabled: true, repairRetentionDays: 30 }
exports.cleanupDeletedRepairs = onSchedule("every 24 hours", async (event) => {
  try {
    const cfgDoc = await admin.firestore().doc('settings/cleanup').get();
    const cfg = cfgDoc.exists ? (cfgDoc.data() || {}) : {};
    if (!cfg.enabled) {
      console.log('cleanupDeletedRepairs is disabled via settings/cleanup (or doc missing). Skipping.');
      return;
    }

    const days = Number(cfg.repairRetentionDays ?? 30);
    if (!(days > 0)) {
      console.log('cleanupDeletedRepairs: invalid repairRetentionDays, skipping.');
      return;
    }

    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

    const q = admin.firestore().collection('repairs')
      .where('deleted', '==', true)
      .where('deletedAt', '<=', cutoffTs)
      .limit(500);

    const snaps = await q.get();
    console.log(`Found ${snaps.size} deleted repairs older than ${days} days`);
    for (const doc of snaps.docs) {
      try {
        await doc.ref.delete();
        console.log(`Permanently deleted repair ${doc.id}`);
      } catch (e) {
        console.error(`Failed to delete repair ${doc.id}:`, e);
      }
    }
  } catch (e) {
    console.error('Cleanup job failed:', e);
  }
});
