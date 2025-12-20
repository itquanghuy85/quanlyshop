const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// 🔔 Thông báo khi CÓ ĐƠN SỬA MỚI
exports.notifyNewRepair = functions.firestore
  .document("repairs/{repairId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    const payload = {
      notification: {
        title: "🔧 Có đơn sửa mới",
        body: `${data.customerName} - ${data.model}`,
      },
      data: {
        repairId: context.params.repairId,
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
exports.notifyStatusChange = functions.firestore
  .document("repairs/{repairId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return null;

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
