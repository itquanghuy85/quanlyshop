const admin = require("firebase-admin");
const crypto = require("crypto");
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();
// Giới hạn region & timeout mặc định
setGlobalOptions({ region: "asia-southeast1", timeoutSeconds: 30 });

// ============================================================
// DEEPSEEK AI SECRET
// ============================================================
// Đặt secret bằng lệnh:
//   firebase secrets:set DEEPSEEK_API_KEY
// Key KHÔNG commit vào git — chỉ tồn tại trong Google Secret Manager.
// ============================================================
const deepseekApiKey = defineSecret("DEEPSEEK_API_KEY");

// ============================================================
// CUSTOM CLAIMS MANAGEMENT
// ============================================================
// Purpose: Auto-sync Custom Claims when user data changes
// Claims: shopId, role, isSuperAdmin
// ============================================================

const VALID_ROLES = ["owner", "manager", "employee", "technician", "user", "super_admin"];

/**
 * Build custom claims object from user data
 */
function buildCustomClaims(userData, email) {
  const roleFromDoc = (userData?.role || "user").toString().trim().toLowerCase();
  const isSuperAdmin = roleFromDoc === "super_admin";
  return {
    shopId: userData?.shopId || null,
    role: isSuperAdmin ? "super_admin" : roleFromDoc,
    isSuperAdmin: isSuperAdmin,
  };
}

/**
 * 🔑 AUTO-SYNC CUSTOM CLAIMS
 * Triggered when user document is created or updated
 * Sets: shopId, role, isSuperAdmin in JWT token
 */
exports.syncUserClaims = onDocumentWritten("users/{userId}", async (event) => {
  const userId = event.params.userId;
  const afterData = event.data?.after?.data();
  
  // Skip if document was deleted
  if (!afterData) {
    console.log(`User ${userId} deleted, skipping claims sync`);
    return;
  }

  try {
    // Get user's email from Auth
    let userEmail = afterData.email;
    if (!userEmail) {
      try {
        const userRecord = await admin.auth().getUser(userId);
        userEmail = userRecord.email;
      } catch (e) {
        console.warn(`Cannot get email for user ${userId}:`, e.message);
      }
    }

    // Build and set claims
    const claims = buildCustomClaims(afterData, userEmail);
    
    // Check if claims actually changed
    const beforeData = event.data?.before?.data();
    const oldClaims = beforeData ? buildCustomClaims(beforeData, userEmail) : null;
    
    if (oldClaims && 
        oldClaims.shopId === claims.shopId && 
        oldClaims.role === claims.role && 
        oldClaims.isSuperAdmin === claims.isSuperAdmin) {
      console.log(`Claims unchanged for user ${userId}, skipping`);
      return;
    }

    await admin.auth().setCustomUserClaims(userId, claims);
    
    // Mark claims as synced in Firestore (for client to know when to refresh token)
    await event.data.after.ref.update({
      claimsSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
      _claimsVersion: admin.firestore.FieldValue.increment(1),
    });

    console.log(`✅ Claims synced for ${userId}:`, claims);
  } catch (error) {
    console.error(`❌ Error syncing claims for ${userId}:`, error);
  }
});

/**
 * 🔄 MANUAL REFRESH CLAIMS
 * Callable function to force refresh user's claims
 * Client should call this after joining shop or role change
 */
exports.refreshMyClaims = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const userId = auth.uid;
  const userEmail = auth.token.email;

  try {
    // Get fresh user data from Firestore
    const userDoc = await admin.firestore().doc(`users/${userId}`).get();
    const userData = userDoc.data();

    if (!userData) {
      throw new HttpsError("not-found", "Không tìm thấy thông tin người dùng");
    }

    // Build and set claims
    const claims = buildCustomClaims(userData, userEmail);
    await admin.auth().setCustomUserClaims(userId, claims);

    // Update sync timestamp
    await userDoc.ref.update({
      claimsSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Claims refreshed for ${userId}:`, claims);

    return {
      success: true,
      claims: claims,
      message: "Claims đã được cập nhật. Vui lòng refresh token.",
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error(`Error refreshing claims for ${userId}:`, error);
    throw new HttpsError("internal", "Lỗi cập nhật claims: " + error.message);
  }
});

/**
 * 👑 ADMIN: UPDATE USER ROLE
 * Only owner/admin can change roles
 * Cannot self-assign higher role
 */
exports.updateUserRole = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const data = request.data || {};
  const targetUserId = (data.userId || "").toString().trim();
  const newRole = (data.role || "").toString().trim().toLowerCase();

  // === VALIDATION ===
  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "Thiếu userId");
  }

  if (!newRole || !VALID_ROLES.includes(newRole)) {
    throw new HttpsError("invalid-argument", `Role không hợp lệ. Chỉ chấp nhận: ${VALID_ROLES.join(", ")}`);
  }

  const callerUid = auth.uid;
  const callerEmail = auth.token.email || "";
  const callerIsSuperAdmin = checkIsSuperAdmin(callerEmail);

  // Get caller's data
  const callerDoc = await admin.firestore().doc(`users/${callerUid}`).get();
  const callerData = callerDoc.data() || {};
  const callerRole = callerIsSuperAdmin ? "admin" : (callerData.role || "user");
  const callerShopId = callerData.shopId;

  // Get target user's data
  const targetDoc = await admin.firestore().doc(`users/${targetUserId}`).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "Không tìm thấy người dùng");
  }
  const targetData = targetDoc.data() || {};
  const targetShopId = targetData.shopId;

  // === PERMISSION CHECKS ===
  
  // 1. Super admin can do anything
  if (!callerIsSuperAdmin) {
    // 2. Must be in same shop (unless super admin)
    if (callerShopId !== targetShopId) {
      throw new HttpsError("permission-denied", "Không thể thay đổi role người dùng khác shop");
    }

    // 3. Only owner can assign owner role
    if (newRole === "owner" && callerRole !== "owner") {
      throw new HttpsError("permission-denied", "Chỉ owner mới có thể chỉ định owner mới");
    }

    // 4. Manager can only assign employee/technician/user
    if (callerRole === "manager" && !["employee", "technician", "user"].includes(newRole)) {
      throw new HttpsError("permission-denied", "Manager chỉ có thể gán role: employee, technician, user");
    }

    // 5. Employee and below cannot change roles
    if (!["admin", "owner", "manager"].includes(callerRole)) {
      throw new HttpsError("permission-denied", "Bạn không có quyền thay đổi role");
    }

    // 6. Cannot demote yourself
    if (callerUid === targetUserId && getRolePriority(newRole) < getRolePriority(callerRole)) {
      throw new HttpsError("permission-denied", "Không thể tự hạ role của mình");
    }
  }

  // === UPDATE ROLE ===
  try {
    await targetDoc.ref.update({
      role: newRole,
      roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      roleUpdatedBy: callerUid,
    });

    // Claims will be auto-synced by syncUserClaims trigger
    console.log(`✅ Role updated: ${targetUserId} -> ${newRole} (by ${callerUid})`);

    return {
      success: true,
      userId: targetUserId,
      newRole: newRole,
      message: `Đã cập nhật role thành ${newRole}`,
    };
  } catch (error) {
    console.error(`Error updating role for ${targetUserId}:`, error);
    throw new HttpsError("internal", "Lỗi cập nhật role: " + error.message);
  }
});

/**
 * Helper: Get role priority for comparison
 */
function getRolePriority(role) {
  const priorities = {
    "admin": 100,
    "owner": 90,
    "manager": 70,
    "employee": 50,
    "technician": 40,
    "user": 10,
  };
  return priorities[role] || 0;
}

/**
 * 🏪 ADMIN: ADD USER TO SHOP
 * Assigns user to a shop and sets initial role
 */
exports.addUserToShop = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const data = request.data || {};
  const targetUserId = (data.userId || "").toString().trim();
  const targetShopId = (data.shopId || "").toString().trim();
  const initialRole = (data.role || "employee").toString().trim().toLowerCase();

  // === VALIDATION ===
  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "Thiếu userId");
  }
  if (!targetShopId) {
    throw new HttpsError("invalid-argument", "Thiếu shopId");
  }
  if (!VALID_ROLES.includes(initialRole)) {
    throw new HttpsError("invalid-argument", `Role không hợp lệ: ${initialRole}`);
  }

  const callerEmail = auth.token.email || "";
  const callerIsSuperAdmin = checkIsSuperAdmin(callerEmail);

  // Get caller's data
  const callerDoc = await admin.firestore().doc(`users/${auth.uid}`).get();
  const callerData = callerDoc.data() || {};
  const callerRole = callerIsSuperAdmin ? "admin" : (callerData.role || "user");
  const callerShopId = callerData.shopId;

  // === PERMISSION CHECKS ===
  if (!callerIsSuperAdmin) {
    // Must be owner/manager of the target shop
    if (callerShopId !== targetShopId) {
      throw new HttpsError("permission-denied", "Bạn không thuộc shop này");
    }
    if (!["owner", "manager"].includes(callerRole)) {
      throw new HttpsError("permission-denied", "Chỉ owner/manager mới có thể thêm nhân viên");
    }
    // Manager cannot add owner
    if (callerRole === "manager" && initialRole === "owner") {
      throw new HttpsError("permission-denied", "Manager không thể thêm owner");
    }
  }

  // Check if target user exists
  const targetDoc = await admin.firestore().doc(`users/${targetUserId}`).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "Không tìm thấy người dùng");
  }

  const targetData = targetDoc.data() || {};
  if (targetData.shopId && targetData.shopId !== targetShopId) {
    throw new HttpsError("failed-precondition", "Người dùng đã thuộc shop khác");
  }

  // === ADD TO SHOP ===
  try {
    await targetDoc.ref.update({
      shopId: targetShopId,
      role: initialRole,
      joinedShopAt: admin.firestore.FieldValue.serverTimestamp(),
      addedBy: auth.uid,
    });

    console.log(`✅ User ${targetUserId} added to shop ${targetShopId} as ${initialRole}`);

    return {
      success: true,
      userId: targetUserId,
      shopId: targetShopId,
      role: initialRole,
      message: `Đã thêm người dùng vào shop với role ${initialRole}`,
    };
  } catch (error) {
    console.error(`Error adding user to shop:`, error);
    throw new HttpsError("internal", "Lỗi thêm người dùng vào shop: " + error.message);
  }
});

/**
 * 🧩 SECURE: UPDATE USER PROFILE (fallback for permission-denied on client writes)
 * Allows owner/manager of same shop to update basic profile fields.
 * Role change is limited to owner/super admin.
 */
exports.updateUserProfileSecure = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const data = request.data || {};
  const targetUserId = (data.userId || "").toString().trim();
  const displayName = (data.displayName || "").toString().trim();
  const phone = (data.phone || "").toString().trim();
  const address = (data.address || "").toString().trim();
  const photoUrl = (data.photoUrl || "").toString().trim();
  const requestedRole = (data.role || "").toString().trim().toLowerCase();
  const requestedShopId = (data.shopId || "").toString().trim();

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "Thiếu userId");
  }

  if (!displayName) {
    throw new HttpsError("invalid-argument", "Tên nhân viên không được để trống");
  }

  if (phone && !/^\d{9,12}$/.test(phone.replace(/\D/g, ""))) {
    throw new HttpsError("invalid-argument", "Số điện thoại không hợp lệ");
  }

  if (requestedRole && !VALID_ROLES.includes(requestedRole)) {
    throw new HttpsError("invalid-argument", `Role không hợp lệ: ${requestedRole}`);
  }

  const callerEmail = auth.token.email || "";
  const callerIsSuperAdmin = checkIsSuperAdmin(callerEmail);

  const callerDoc = await admin.firestore().doc(`users/${auth.uid}`).get();
  const callerData = callerDoc.data() || {};
  const callerRole = callerIsSuperAdmin ? "admin" : (callerData.role || "user");
  const callerShopId = callerData.shopId || null;

  const targetDoc = await admin.firestore().doc(`users/${targetUserId}`).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "Không tìm thấy người dùng");
  }
  const targetData = targetDoc.data() || {};
  const targetShopId = targetData.shopId || null;

  // === PERMISSION CHECKS ===
  if (!callerIsSuperAdmin) {
    if (!["owner", "manager"].includes(callerRole)) {
      throw new HttpsError("permission-denied", "Chỉ owner/manager mới có thể cập nhật nhân viên");
    }

    if (!callerShopId) {
      throw new HttpsError("failed-precondition", "Không tìm thấy shop hiện tại của tài khoản");
    }

    // Không cho phép cập nhật nhân viên thuộc shop khác.
    if (targetShopId && targetShopId !== callerShopId) {
      throw new HttpsError("permission-denied", "Không thể cập nhật nhân viên khác shop");
    }

    // Manager không được đổi role.
    if (requestedRole && callerRole !== "owner") {
      throw new HttpsError("permission-denied", "Chỉ owner mới có thể đổi vai trò");
    }

    // Owner không được tự nâng/ngáng ngoài phạm vi trong hàm này.
    if (requestedRole === "owner" && callerRole !== "owner") {
      throw new HttpsError("permission-denied", "Không có quyền gán role owner");
    }
  }

  const updateData = {
    displayName: displayName.toUpperCase(),
    name: displayName.toUpperCase(),
    phone: phone,
    address: address.toUpperCase(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (photoUrl) {
    updateData.photoUrl = photoUrl;
  }

  if (requestedRole) {
    updateData.role = requestedRole;
  }

  // Tự healing shopId thiếu: gán cùng shop caller để các lần update sau đi thẳng rules.
  if (!targetShopId) {
    if (callerIsSuperAdmin && requestedShopId) {
      updateData.shopId = requestedShopId;
    } else if (callerShopId) {
      updateData.shopId = callerShopId;
    }
  }

  await targetDoc.ref.set(updateData, { merge: true });

  console.log(`✅ updateUserProfileSecure: updated ${targetUserId} by ${auth.uid}`);
  return {
    success: true,
    userId: targetUserId,
    message: "Đã cập nhật hồ sơ nhân viên",
  };
});

/**
 * 🏪 SECURE: UPDATE SHOP PROFILE
 * Fallback cho trường hợp client bị permission-denied khi cập nhật shops/{shopId}.
 * Cho phép owner/manager cùng shop (hoặc super admin) cập nhật profile shop.
 */
exports.updateShopProfileSecure = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const data = request.data || {};
  const shopId = (data.shopId || "").toString().trim();
  const profile = data.profile || {};

  if (!shopId) {
    throw new HttpsError("invalid-argument", "Thiếu shopId");
  }

  const callerEmail = auth.token.email || "";
  const callerIsSuperAdmin = checkIsSuperAdmin(callerEmail);

  const callerDoc = await admin.firestore().doc(`users/${auth.uid}`).get();
  const callerData = callerDoc.data() || {};
  const callerRole = callerIsSuperAdmin ? "admin" : (callerData.role || "user");
  const callerShopId = (callerData.shopId || "").toString().trim();

  if (!callerIsSuperAdmin) {
    if (!["owner", "manager"].includes(callerRole)) {
      throw new HttpsError(
        "permission-denied",
        "Chỉ owner/manager mới có thể cập nhật thông tin cửa hàng",
      );
    }
    if (!callerShopId || callerShopId !== shopId) {
      throw new HttpsError(
        "permission-denied",
        "Không thể cập nhật thông tin cửa hàng khác shop",
      );
    }
  }

  const toText = (value) => (value == null ? "" : value.toString().trim());
  const toNumOrNull = (value) => {
    if (value === null || value === undefined || value === "") return null;
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  };

  const safeProfile = {
    name: toText(profile.name),
    address: toText(profile.address),
    phone: toText(profile.phone),
    email: toText(profile.email),
    description: toText(profile.description),
    logoUrl: toText(profile.logoUrl),
    latitude: toNumOrNull(profile.latitude),
    longitude: toNumOrNull(profile.longitude),
  };

  if (!safeProfile.name) {
    throw new HttpsError("invalid-argument", "Tên cửa hàng không được để trống");
  }

  const shopRef = admin.firestore().collection("shops").doc(shopId);
  const shopSnap = await shopRef.get();
  const shopData = shopSnap.data() || {};
  const shouldBackfillOwner =
    !shopData.ownerUid && (callerIsSuperAdmin || callerRole === "owner");

  const topLevelPayload = {
    ...safeProfile,
    shopId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: auth.uid,
  };

  if (!shopSnap.exists) {
    topLevelPayload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  if (shouldBackfillOwner) {
    topLevelPayload.ownerUid = auth.uid;
    topLevelPayload.ownerEmail = callerEmail || callerData.email || "";
  }

  await shopRef.set(topLevelPayload, { merge: true });

  await shopRef
    .collection("settings")
    .doc("shop_profile")
    .set(
      {
        ...safeProfile,
        shopId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: auth.uid,
      },
      { merge: true },
    );

  console.log(
    `✅ updateShopProfileSecure: shop=${shopId}, by=${auth.uid}, ownerBackfilled=${shouldBackfillOwner}`,
  );

  return {
    success: true,
    shopId,
    ownerBackfilled: shouldBackfillOwner,
  };
});

/**
 * 🚪 ADMIN: REMOVE USER FROM SHOP
 * Removes user from shop (sets shopId to null)
 */
exports.removeUserFromShop = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const data = request.data || {};
  const targetUserId = (data.userId || "").toString().trim();

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "Thiếu userId");
  }

  const callerEmail = auth.token.email || "";
  const callerIsSuperAdmin = checkIsSuperAdmin(callerEmail);

  // Get target user's data
  const targetDoc = await admin.firestore().doc(`users/${targetUserId}`).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "Không tìm thấy người dùng");
  }
  const targetData = targetDoc.data() || {};
  const targetShopId = targetData.shopId;

  if (!targetShopId) {
    throw new HttpsError("failed-precondition", "Người dùng không thuộc shop nào");
  }

  // === PERMISSION CHECKS ===
  if (!callerIsSuperAdmin) {
    const callerDoc = await admin.firestore().doc(`users/${auth.uid}`).get();
    const callerData = callerDoc.data() || {};
    
    if (callerData.shopId !== targetShopId) {
      throw new HttpsError("permission-denied", "Không thể xóa người dùng khác shop");
    }
    if (!["owner", "manager"].includes(callerData.role)) {
      throw new HttpsError("permission-denied", "Chỉ owner/manager mới có thể xóa nhân viên");
    }
    // Cannot remove owner
    if (targetData.role === "owner") {
      throw new HttpsError("permission-denied", "Không thể xóa owner khỏi shop");
    }
    // Cannot remove yourself
    if (auth.uid === targetUserId) {
      throw new HttpsError("permission-denied", "Không thể tự xóa mình khỏi shop");
    }
  }

  // === REMOVE FROM SHOP ===
  try {
    await targetDoc.ref.update({
      shopId: null,
      role: "user",
      removedFromShopAt: admin.firestore.FieldValue.serverTimestamp(),
      removedBy: auth.uid,
    });

    console.log(`✅ User ${targetUserId} removed from shop ${targetShopId}`);

    return {
      success: true,
      userId: targetUserId,
      message: "Đã xóa người dùng khỏi shop",
    };
  } catch (error) {
    console.error(`Error removing user from shop:`, error);
    throw new HttpsError("internal", "Lỗi xóa người dùng: " + error.message);
  }
});

/**
 * 🔍 GET USER CLAIMS (for debugging)
 * Returns current claims of a user
 */
exports.getUserClaims = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const data = request.data || {};
  const targetUserId = data.userId || auth.uid;

  // Only super admin can view other users' claims
  if (targetUserId !== auth.uid && !checkIsSuperAdmin(auth.token.email)) {
    throw new HttpsError("permission-denied", "Không có quyền xem claims người khác");
  }

  try {
    const userRecord = await admin.auth().getUser(targetUserId);
    return {
      success: true,
      userId: targetUserId,
      email: userRecord.email,
      claims: userRecord.customClaims || {},
    };
  } catch (error) {
    console.error(`Error getting claims for ${targetUserId}:`, error);
    throw new HttpsError("internal", "Lỗi lấy thông tin claims");
  }
});

// ============================================================
// END CUSTOM CLAIMS MANAGEMENT
// ============================================================

// 🔔 Thông báo khi CÓ ĐƠN SỬA MỚI
exports.notifyNewRepair = onDocumentCreated("repairs/{repairId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const price = data.price ? Number(data.price).toLocaleString('vi-VN') : '0';
  const phone = data.phone || '';
  const time = data.createdAt ? new Date(data.createdAt.toDate()).toLocaleTimeString('vi-VN', {hour: '2-digit', minute: '2-digit'}) : '';
  let body = `👤 ${data.customerName || 'N/A'}`;
  if (phone) body += ` • 📞 ${phone}`;
  body += `\n📱 ${data.model || 'N/A'} • 💰 ${price}đ`;
  if (time) body += `\n🕐 ${time}`;

  const payload = {
    notification: {
      title: "🔧 ĐƠN SỬA MỚI",
      body: body,
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

// 🔔 Thông báo khi CÓ TIN NHẮN CHAT MỚI
exports.notifyNewChat = onDocumentCreated("chats/{chatId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const shopId = data.shopId;
  const senderId = data.senderId;
  const senderName = data.senderName;
  const message = data.message;

  try {
    // Get all users in the shop except sender
    const userDocs = await admin.firestore()
      .collection('users')
      .where('shopId', '==', shopId)
      .get();

    const tokens = [];
    for (const doc of userDocs.docs) {
      const userData = doc.data();
      // Don't send to sender
      if (doc.id !== senderId && userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    }

    if (tokens.length === 0) {
      console.log('No FCM tokens found for shop chat:', shopId);
      return;
    }

    const payload = {
      notification: {
        title: `💬 ${senderName}`,
        body: message.length > 100 ? message.substring(0, 100) + '...' : message,
      },
      data: {
        type: 'chat',
        chatId: event.params.chatId,
        shopId: shopId,
        senderId: senderId,
      },
      android: {
        notification: {
          channelId: 'system_channel',
          priority: 'default',
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendMulticast(payload);
    console.log(`Sent ${response.successCount} chat notifications for shop ${shopId}`);

  } catch (error) {
    console.error('Error sending chat FCM notification:', error);
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

  const price = after.price ? Number(after.price).toLocaleString('vi-VN') : '0';
  const body = `👤 ${after.customerName || 'N/A'} • 📱 ${after.model || 'N/A'}\n💰 ${price}đ`;

  const payload = {
    notification: {
      title: statusText,
      body: body,
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
  const requesterRoleClaim = (auth.token.role || "").toString().toLowerCase();
  const isSuperAdmin = auth.token.isSuperAdmin === true || requesterRoleClaim === "super_admin";

  const requesterDoc = await admin.firestore().collection("users").doc(requesterUid).get();
  const requesterData = requesterDoc.data() || {};
  const requesterRole = isSuperAdmin ? "super_admin" : requesterData.role || "user";
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
  // Cho phép owner tạo nhân viên với role: employee, manager, technician
  const allowedRoles = ["employee", "manager", "technician", "owner"];
  if (role === "admin" && !isSuperAdmin && requesterRole !== "admin") {
    role = "employee"; // Không phải admin/superAdmin → fallback to employee
  } else if (!allowedRoles.includes(role) && role !== "admin") {
    role = "employee"; // Role không hợp lệ → fallback to employee
  }

  try {
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName,
    });

    const isManagerOrAbove = ["admin", "owner", "manager"].includes(role);
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
      allowViewRevenue: isManagerOrAbove,
      allowViewExpenses: isManagerOrAbove,
      allowViewDebts: isManagerOrAbove,
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

    const shopRef = admin.firestore().collection("shops").doc(shopId);
    const shopSnap = await shopRef.get();

    if (shopSnap.exists) {
      await shopRef.set({
        lastStaffCreatedBy: requesterUid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } else if (isSuperAdmin || requesterRole === "owner") {
      await shopRef.set({
        shopId,
        ownerUid: requesterUid,
        ownerEmail: requesterData.email || auth.token.email || "",
        name: requesterData.shopName || "Cửa hàng mới",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStaffCreatedBy: requesterUid,
      }, { merge: true });
    } else {
      console.warn(
        `⚠️ createStaffAccount: shop ${shopId} missing and caller is ${requesterRole}, skip creating shop doc to avoid invalid ownerUid`,
      );
    }

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
  } catch (error) {
    console.error('Error in cleanupDeletedRepairs:', error);
  }
});


function getNotificationChannel(type) {
  switch (type) {
    case 'new_order':
      return 'new_order_channel';
    case 'payment':
      return 'payment_channel';
    case 'inventory':
      return 'inventory_channel';
    case 'staff':
      return 'staff_channel';
    case 'system':
    default:
      return 'system_channel';
  }
}

function getAndroidPriority(type) {
  switch (type) {
    case 'new_order':
    case 'payment':
    case 'chat':
      return 'high';
    case 'inventory':
    case 'staff':
      return 'default';
    case 'system':
    default:
      return 'default';
  }
}

function getChannelId(type) {
  switch (type) {
    case 'new_order':
      return 'new_order_channel';
    case 'payment':
      return 'payment_channel';
    case 'inventory':
      return 'inventory_channel';
    case 'staff':
      return 'staff_channel';
    case 'chat':
      return 'chat_channel';
    case 'system':
    default:
      return 'system_channel';
  }
}

// Role-based notification permissions
function getAllowedRolesForNotificationType(type) {
  switch (type) {
    case 'new_order':
      return ['admin', 'owner', 'manager', 'employee'];
    case 'payment':
      return ['admin', 'owner', 'manager', 'employee'];
    case 'inventory':
      return ['admin', 'owner', 'manager', 'technician'];
    case 'staff':
      return ['admin', 'owner', 'manager'];
    case 'chat':
      return ['admin', 'owner', 'manager', 'employee', 'technician', 'user'];
    case 'system':
    default:
      return ['admin', 'owner', 'manager', 'employee', 'technician', 'user'];
  }
}

// 📢 GỬI THÔNG BÁO PUSH CHO SHOP
exports.sendShopNotification = onCall(async (request) => {
  const data = request.data || {};
  
  // Re-enable auth - require authenticated users
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const title = (data.title || "Thông báo").toString();
  const body = (data.body || "").toString();
  const type = (data.type || "system").toString();
  const targetUserId = data.targetUserId; // optional, if null then broadcast to all shop users
  const extraData =
    data.data && typeof data.data === 'object' && !Array.isArray(data.data)
      ? data.data
      : {};

  // Get shopId from authenticated user's Firestore doc, fallback to data.shopId
  let shopId = data.shopId;
  if (!shopId) {
    const requesterDoc = await admin.firestore().collection("users").doc(auth.uid).get();
    const requesterData = requesterDoc.data() || {};
    shopId = requesterData.shopId;
  }

  if (!shopId) {
    throw new HttpsError("failed-precondition", "Không tìm thấy thông tin cửa hàng");
  }

  try {
    // Get FCM tokens for the shop with role-based filtering
    let query = admin.firestore()
      .collection('users')
      .where('shopId', '==', shopId);

    if (targetUserId) {
      query = query.where(admin.firestore.FieldPath.documentId(), '==', targetUserId);
    }

    const userDocs = await query.get();
    const tokens = [];
    const allowedRoles = getAllowedRolesForNotificationType(type);

    userDocs.forEach(doc => {
      const userData = doc.data();
      const userRole = userData.role || 'user';

      // Check if user has permission for this notification type
      if (allowedRoles.includes(userRole) || userRole === 'admin') { // Super admin always gets notifications
        if (userData.fcmToken && userData.fcmToken.trim() !== '') {
          tokens.push(userData.fcmToken);
        }
      }
    });

    if (tokens.length === 0) {
      console.log(`No FCM tokens found for shop ${shopId} with permission for notification type: ${type}`);
      return { success: true, sentCount: 0 };
    }

    const fcmData = {
      type: type,
      shopId: shopId.toString(),
      senderId: auth.uid,
    };
    Object.entries(extraData).forEach(([key, value]) => {
      if (value === null || value === undefined) return;
      fcmData[key] = typeof value === 'string' ? value : JSON.stringify(value);
    });

    // Send FCM messages
    const payload = {
      notification: {
        title: title,
        body: body,
      },
      data: fcmData,
      android: {
        priority: getAndroidPriority(type),
        notification: {
          channelId: getChannelId(type),
          priority: getAndroidPriority(type),
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            badge: 1,
            sound: 'default',
            'content-available': 1,
            'mutable-content': 1,
          },
        },
      },
    };

    const responses = await admin.messaging().sendEachForMulticast({
      tokens: tokens,
      ...payload,
    });

    console.log(`Sent ${responses.successCount} notifications, ${responses.failureCount} failed`);

    return {
      success: true,
      sentCount: responses.successCount,
      failedCount: responses.failureCount
    };

  } catch (error) {
    console.error('Error sending notification:', error);
    throw new HttpsError("internal", "Lỗi gửi thông báo: " + error.message);
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// 🔐 CUSTOM CLAIMS MANAGEMENT - Quản lý quyền người dùng
// ══════════════════════════════════════════════════════════════════════════════

/**
 * BATCH SYNC ALL CLAIMS - Đồng bộ Custom Claims cho TOÀN BỘ user cũ
 * 
 * Chỉ Super Admin (custom claims role=super_admin) được quyền gọi.
 * Đọc từ Firestore users/{uid} và set custom claims.
 * 
 * @returns {Object} Thống kê: total, success, skipped, failed, errors
 */
exports.batchSyncAllClaims = onCall({ 
  timeoutSeconds: 540,  // 9 phút cho batch lớn
  memory: "512MiB"
}, async (request) => {
  const auth = request.auth;
  
  // 1. Verify authentication
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }
  
  // 2. ONLY Super Admin can call this function
  const callerEmail = auth.token.email || "";
  const callerRole = (auth.token.role || "").toString().toLowerCase();
  const callerIsSuperAdmin = auth.token.isSuperAdmin === true || callerRole === "super_admin";
  if (!callerIsSuperAdmin) {
    console.log(`DENIED: ${callerEmail} tried to call batchSyncAllClaims`);
    throw new HttpsError("permission-denied", "Chỉ Super Admin mới có quyền sync claims toàn bộ");
  }
  
  console.log(`✅ Super Admin ${callerEmail} started batchSyncAllClaims`);
  
  // 3. Statistics
  const stats = {
    total: 0,
    success: 0,
    skipped: 0,
    failed: 0,
    errors: [],
    details: []
  };
  
  try {
    // 4. Get ALL users from Firestore
    const usersSnapshot = await admin.firestore().collection('users').get();
    stats.total = usersSnapshot.size;
    
    console.log(`Found ${stats.total} users to process`);
    
    // 5. Process each user
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      const userData = userDoc.data();
      
      try {
        // 5.1 Validate user data
        const email = (userData.email || "").toString().trim().toLowerCase();
        const role = (userData.role || "user").toString().trim();
        const shopId = (userData.shopId || "").toString().trim();
        
        // 5.2 Skip if no valid email (can't match with Auth)
        if (!email) {
          stats.skipped++;
          stats.details.push({ uid, status: 'skipped', reason: 'no_email' });
          continue;
        }
        
        // 5.3 Validate role
        const validRoles = ['owner', 'manager', 'employee', 'technician', 'user', 'super_admin'];
        const finalRole = validRoles.includes(role) ? role : 'user';
        
        // 5.4 Determine isSuperAdmin
        const isSuperAdmin = finalRole === 'super_admin';
        
        // 5.5 Build claims object
        const claims = {
          role: isSuperAdmin ? 'super_admin' : finalRole,
          shopId: shopId || uid, // Fallback to uid if no shopId
          isSuperAdmin: isSuperAdmin
        };
        
        // 5.6 Verify user exists in Firebase Auth
        try {
          await admin.auth().getUser(uid);
        } catch (authError) {
          // User doesn't exist in Auth, skip
          stats.skipped++;
          stats.details.push({ uid, email, status: 'skipped', reason: 'not_in_auth' });
          continue;
        }
        
        // 5.7 Set custom claims
        await admin.auth().setCustomUserClaims(uid, claims);
        
        // 5.8 Update Firestore with sync timestamp
        await admin.firestore().collection('users').doc(uid).update({
          claimsSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
          claimsSyncedBy: 'batchSyncAllClaims'
        });
        
        stats.success++;
        stats.details.push({
          uid,
          email,
          status: 'success',
          claims
        });
        
        console.log(`✓ Synced claims for ${email}: role=${finalRole}, shopId=${claims.shopId}, isSuperAdmin=${isSuperAdmin}`);
        
      } catch (userError) {
        stats.failed++;
        const errorMsg = userError.message || userError.toString();
        stats.errors.push({ uid, error: errorMsg });
        stats.details.push({ uid, status: 'failed', error: errorMsg });
        console.error(`✗ Failed to sync claims for ${uid}: ${errorMsg}`);
      }
    }
    
    console.log(`\n=== BATCH SYNC COMPLETED ===`);
    console.log(`Total: ${stats.total}`);
    console.log(`Success: ${stats.success}`);
    console.log(`Skipped: ${stats.skipped}`);
    console.log(`Failed: ${stats.failed}`);
    
    return {
      success: true,
      message: `Đã sync claims cho ${stats.success}/${stats.total} users`,
      stats: {
        total: stats.total,
        success: stats.success,
        skipped: stats.skipped,
        failed: stats.failed
      },
      errors: stats.errors.length > 0 ? stats.errors.slice(0, 10) : [], // Limit errors in response
      details: stats.details.slice(0, 50) // Limit details in response
    };
    
  } catch (error) {
    console.error('Error in batchSyncAllClaims:', error);
    throw new HttpsError("internal", `Lỗi sync claims: ${error.message}`);
  }
});

/**
 * SYNC SINGLE USER CLAIMS - Sync claims cho 1 user cụ thể (v2)
 * Chỉ Super Admin hoặc Owner của shop được gọi.
 */
exports.syncUserClaimsV2 = onCall(async (request) => {
  const auth = request.auth;
  const data = request.data || {};
  
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }
  
  const targetUid = data.uid;
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "Thiếu uid của user cần sync");
  }
  
  const callerEmail = auth.token.email || "";
  const callerTokenRole = (auth.token.role || "").toString().toLowerCase();
  const isSuperAdmin = auth.token.isSuperAdmin === true || callerTokenRole === "super_admin";

  // Get caller's data to check permissions
  const callerDoc = await admin.firestore().collection('users').doc(auth.uid).get();
  const callerData = callerDoc.data() || {};
  const callerRole = callerData.role || "user";
  const callerShopId = callerData.shopId;
  
  // Get target user's data
  const targetDoc = await admin.firestore().collection('users').doc(targetUid).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "User không tồn tại");
  }
  
  const targetData = targetDoc.data();
  const targetShopId = targetData.shopId;
  
  // Permission check: Super Admin OR Owner of same shop
  if (!isSuperAdmin && (callerRole !== 'owner' || callerShopId !== targetShopId)) {
    throw new HttpsError("permission-denied", "Bạn không có quyền sync claims cho user này");
  }
  
  // Build claims
  const email = (targetData.email || "").toString().trim().toLowerCase();
  const role = (targetData.role || "user").toString();
  const shopId = targetData.shopId || targetUid;
  const isSuperAdminByRole = role === 'super_admin';
  
  const claims = {
    role: isSuperAdminByRole ? 'super_admin' : role,
    shopId: shopId,
    isSuperAdmin: isSuperAdminByRole
  };
  
  // Set claims
  await admin.auth().setCustomUserClaims(targetUid, claims);
  
  // Update Firestore
  await admin.firestore().collection('users').doc(targetUid).update({
    claimsSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    claimsSyncedBy: auth.uid
  });
  
  console.log(`✓ syncUserClaims: ${email} synced by ${callerEmail}`);
  
  return {
    success: true,
    uid: targetUid,
    claims: claims
  };
});

/**
 * REFRESH MY CLAIMS - User tự refresh claims của mình (v2)
 * Dùng sau khi role/shopId được thay đổi bởi admin
 */
exports.refreshMyClaimsV2 = onCall(async (request) => {
  const auth = request.auth;
  
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }
  
  const uid = auth.uid;
  
  // Get user data from Firestore
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User không tồn tại trong Firestore");
  }
  
  const userData = userDoc.data();
  const email = (userData.email || auth.token.email || "").toString().trim().toLowerCase();
  const role = (userData.role || "user").toString();
  const shopId = userData.shopId || uid;
  const isSuperAdminByRole = role === 'super_admin';
  
  const claims = {
    role: isSuperAdminByRole ? 'super_admin' : role,
    shopId: shopId,
    isSuperAdmin: isSuperAdminByRole
  };
  
  // Set claims
  await admin.auth().setCustomUserClaims(uid, claims);
  
  // Update Firestore
  await admin.firestore().collection('users').doc(uid).update({
    claimsSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    claimsSyncedBy: 'self'
  });
  
  console.log(`✓ refreshMyClaims: ${email} refreshed own claims`);
  
  return {
    success: true,
    claims: claims,
    message: "Claims đã được refresh. Vui lòng logout và login lại để áp dụng."
  };
});

/**
 * GET MY CLAIMS - Xem claims hiện tại của user (v2)
 */
exports.getMyClaimsV2 = onCall(async (request) => {
  const auth = request.auth;
  
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }
  
  const uid = auth.uid;
  
  // Get current claims from Auth
  const userRecord = await admin.auth().getUser(uid);
  const currentClaims = userRecord.customClaims || {};
  
  // Get Firestore data for comparison
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  const firestoreData = userDoc.exists ? userDoc.data() : null;
  
  return {
    success: true,
    uid: uid,
    email: auth.token.email,
    currentClaims: currentClaims,
    firestoreData: firestoreData ? {
      role: firestoreData.role,
      shopId: firestoreData.shopId,
      claimsSyncedAt: firestoreData.claimsSyncedAt
    } : null,
    needsSync: firestoreData && (
      currentClaims.role !== firestoreData.role ||
      currentClaims.shopId !== firestoreData.shopId
    )
  };
});

// 🧹 CLEANUP FCM TOKENS - Xóa tokens cũ và không hợp lệ (mỗi Chủ nhật 3AM)
exports.cleanupFCMTokens = onSchedule("0 3 * * 0", async (event) => {
  try {
    console.log('Starting FCM token cleanup...');

    const batch = admin.firestore().batch();
    let cleanupCount = 0;
    const maxCleanup = 500; // Giới hạn số lượng cleanup mỗi lần

    // 1. Xóa tokens cũ hơn 30 ngày
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const oldTokensQuery = admin.firestore()
      .collection('users')
      .where('fcmTokenUpdatedAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .limit(maxCleanup);

    const oldTokensSnapshot = await oldTokensQuery.get();
    console.log(`Found ${oldTokensSnapshot.size} old FCM tokens to clean up`);

    oldTokensSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.fcmToken) {
        batch.update(doc.ref, {
          fcmToken: admin.firestore.FieldValue.delete(),
          fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        cleanupCount++;
      }
    });

    // 2. Xóa tokens trùng lặp (giữ lại token mới nhất cho mỗi user)
    if (cleanupCount < maxCleanup) {
      const allTokensQuery = admin.firestore()
        .collection('users')
        .where('fcmToken', '!=', null)
        .orderBy('fcmToken')
        .orderBy('fcmTokenUpdatedAt', 'desc')
        .limit(maxCleanup - cleanupCount);

      const allTokensSnapshot = await allTokensQuery.get();
      const seenTokens = new Set();

      allTokensSnapshot.forEach(doc => {
        const userData = doc.data();
        const token = userData.fcmToken;

        if (token && seenTokens.has(token)) {
          // Token này đã thấy trước đó, xóa
          batch.update(doc.ref, {
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          cleanupCount++;
        } else if (token) {
          seenTokens.add(token);
        }
      });
    }

    if (cleanupCount > 0) {
      await batch.commit();
      console.log(`Cleaned up ${cleanupCount} FCM tokens`);
    } else {
      console.log('No FCM tokens to clean up');
    }

  } catch (error) {
    console.error('Error in FCM token cleanup:', error);
  }
});

/**
 * 🗑️ DELETE USER DATA (Super Admin only)
 * Deletes user Firestore doc + Auth account + related data in all collections
 */
exports.deleteUserData = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  const callerEmail = (auth.token.email || "").toLowerCase().trim();
  if (!checkIsSuperAdmin(callerEmail)) {
    throw new HttpsError("permission-denied", "Chỉ Super Admin mới có quyền xóa dữ liệu");
  }

  const data = request.data || {};
  const targetUserId = (data.userId || "").toString().trim();
  const deleteAuth = data.deleteAuth !== false; // default true

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "Thiếu userId");
  }

  // Prevent deleting self
  if (auth.uid === targetUserId) {
    throw new HttpsError("permission-denied", "Không thể tự xóa tài khoản của mình");
  }

  const db = admin.firestore();
  const results = { deleted: [], errors: [] };

  // 1. Get user doc to find shopId
  const userDoc = await db.doc(`users/${targetUserId}`).get();
  const userData = userDoc.exists ? userDoc.data() : {};
  const shopId = userData.shopId || null;

  // 2. Delete related data in batched collections (filtered by shopId if available)
  const collectionsToClean = [
    { name: 'repairs', field: 'createdBy' },
    { name: 'sales', field: 'sellerId' },
    { name: 'expenses', field: 'createdBy' },
    { name: 'attendance', field: 'userId' },
    { name: 'notifications', field: 'userId' },
    { name: 'payment_requests', field: 'senderId' },
  ];

  for (const col of collectionsToClean) {
    try {
      const query = db.collection(col.name)
        .where(col.field, '==', targetUserId)
        .limit(500);
      const snap = await query.get();
      if (snap.size > 0) {
        const batch = db.batch();
        snap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        results.deleted.push(`${col.name}: ${snap.size} docs`);
      }
    } catch (err) {
      results.errors.push(`${col.name}: ${err.message}`);
    }
  }

  // 3. Delete user Firestore document
  try {
    if (userDoc.exists) {
      await db.doc(`users/${targetUserId}`).delete();
      results.deleted.push('users: 1 doc');
    }
  } catch (err) {
    results.errors.push(`users: ${err.message}`);
  }

  // 4. Delete Firebase Auth account
  if (deleteAuth) {
    try {
      await admin.auth().deleteUser(targetUserId);
      results.deleted.push('auth: account deleted');
    } catch (err) {
      // User may not exist in Auth
      if (err.code !== 'auth/user-not-found') {
        results.errors.push(`auth: ${err.message}`);
      }
    }
  }

  console.log(`🗑️ deleteUserData for ${targetUserId}:`, JSON.stringify(results));

  return {
    success: true,
    userId: targetUserId,
    results: results,
    message: `Đã xóa user ${userData.email || targetUserId} và dữ liệu liên quan`,
  };
});

// ══════════════════════════════════════════════════════════════════════════════
// 📢 BROADCAST NOTIFICATION (Super Admin → Toàn bộ người dùng)
// ══════════════════════════════════════════════════════════════════════════════
// Gửi thông báo hệ thống tới TẤT CẢ người dùng qua:
//   A. Firestore /broadcasts/{id} → client listener hiển thị dialog
//   B. FCM topic 'all_users'      → push notification kể cả khi app đóng
// ══════════════════════════════════════════════════════════════════════════════

exports.sendBroadcastNotification = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Vui lòng đăng nhập");
  }

  // Chỉ Super Admin mới được gửi broadcast
  const isSuperAdmin = auth.token.isSuperAdmin === true ||
    (auth.token.role || "").toString().toLowerCase() === "super_admin";
  if (!isSuperAdmin) {
    throw new HttpsError("permission-denied", "Chỉ Super Admin mới được gửi thông báo hệ thống");
  }

  const data = request.data || {};
  const title = (data.title || "").toString().trim();
  const body  = (data.body  || "").toString().trim();
  const type  = (data.type  || "info").toString(); // info | warning | update_required
  const expiresAfterDays = typeof data.expiresAfterDays === 'number' ? data.expiresAfterDays : 7;
  const url = (data.url || "").toString().trim();

  if (!title) throw new HttpsError("invalid-argument", "Thiếu tiêu đề thông báo");
  if (!body)  throw new HttpsError("invalid-argument", "Thiếu nội dung thông báo");
  if (url && !/^https?:\/\//i.test(url)) {
    throw new HttpsError("invalid-argument", "Link phải bắt đầu bằng http:// hoặc https://");
  }

  const db = admin.firestore();
  const expiresAt = new Date(Date.now() + expiresAfterDays * 24 * 60 * 60 * 1000);

  // A — Lưu vào Firestore (client listener sẽ hiển thị dialog)
  const broadcastRef = await db.collection('broadcasts').add({
    title,
    body,
    type,
    ...(url && { url }),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: auth.uid,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
  });

  console.log(`📢 Broadcast created: ${broadcastRef.id} by ${auth.uid} — "${title}"`);

  // B — Gửi FCM tới topic all_users (push kể cả khi app đóng)
  try {
    await admin.messaging().send({
      topic: 'all_users',
      notification: { title, body },
      data: {
        type,
        broadcastId: broadcastRef.id,
        source: 'broadcast',
        ...(url && { url }),
      },
      android: {
        priority: type === 'update_required' ? 'high' : 'normal',
        notification: {
          channelId: 'system',
          priority: type === 'update_required' ? 'max' : 'default',
        },
      },
      apns: {
        headers: { 'apns-priority': type === 'update_required' ? '10' : '5' },
        payload: {
          aps: {
            alert: { title, body },
            badge: 1,
            sound: 'default',
          },
        },
      },
    });
    console.log(`✅ FCM topic broadcast sent to all_users for broadcastId=${broadcastRef.id}`);
  } catch (fcmError) {
    console.error(`⚠️  FCM topic send failed (Firestore doc still saved): ${fcmError.message}`);
  }

  return { success: true, broadcastId: broadcastRef.id };
});

// ============================================================
// DEEPSEEK AI — REPAIR ORDER PARSER
// ============================================================
// Endpoint callable từ Flutter qua cloud_functions SDK.
// Flutter KHÔNG biết API key — key chỉ tồn tại trong Secret Manager.
//
// Rate limit: mỗi user tối đa 30 lần/phút (lưu trong Firestore).
// Timeout: 25 s để tránh Firebase hard-limit 30 s.
// Retry: 1 lần khi gặp 429 hoặc 5xx từ DeepSeek.
// ============================================================

const DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1/chat/completions";
const DEEPSEEK_MODEL = "deepseek-chat";

// ── Prompt hệ thống ────────────────────────────────────────────────────────
const REPAIR_SYSTEM_PROMPT = `Bạn là hệ thống phân tích ngôn ngữ tự nhiên cho phần mềm quản lý cửa hàng sửa chữa điện thoại Việt Nam.

NHIỆM VỤ:
Phân tích câu nhập của kỹ thuật viên/nhân viên và trả về JSON chuẩn.

SCHEMA (bắt buộc — không được thêm / bớt field):
{
  "intent": "create_repair_order" | "unknown",
  "customer_name": "<string — để rỗng nếu không có>",
  "customer_phone": "<string — để rỗng nếu không có>",
  "device": "<string — tên thiết bị, ví dụ 'iPhone 13 Pro Max' — để rỗng nếu không có>",
  "issue": "<string — mô tả lỗi ngắn gọn — để rỗng nếu không có>",
  "deposit": <number — giá sửa / tiền thu khách, đơn vị VNĐ, 0 nếu không có>
}

QUY TẮC CỨNG:
1. Chỉ trả JSON thuần — KHÔNG markdown, KHÔNG giải thích.
2. KHÔNG bịa dữ liệu. Thiếu field → để rỗng / 0.
3. Số tiền: "1tr2" = 1200000, "500k" = 500000, "800" nếu không có đơn vị thì = 800000 (giả định nghìn đồng nếu < 10000).
4. Tên khách: tìm sau từ khóa "khách", "tên", "cho", "của". Nếu ambiguous → để rỗng.
5. SĐT: chuỗi 10 số bắt đầu bằng 0, hoặc +84...
6. Thiết bị: nhận diện thương hiệu (iphone, samsung, oppo, vivo, xiaomi, realme, nokia, tecno) + model.
7. intent = "create_repair_order" khi có ít nhất thiết bị HOẶC lỗi cần sửa.
8. intent = "unknown" khi không thể xác định là đơn sửa chữa.`;

// ── Gọi DeepSeek với retry ─────────────────────────────────────────────────
async function callDeepSeek(apiKey, userText, attempt = 1) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 22000); // 22 s

  try {
    const res = await fetch(DEEPSEEK_BASE_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: DEEPSEEK_MODEL,
        messages: [
          { role: "system", content: REPAIR_SYSTEM_PROMPT },
          { role: "user", content: userText.trim() },
        ],
        temperature: 0.1,       // ổn định, không sáng tạo
        max_tokens: 256,         // JSON ngắn, không cần nhiều
        response_format: { type: "json_object" },
      }),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (res.status === 429 || res.status >= 500) {
      if (attempt < 2) {
        console.warn(`⚠️ DeepSeek ${res.status} — retry ${attempt}`);
        await new Promise((r) => setTimeout(r, 1500));
        return callDeepSeek(apiKey, userText, attempt + 1);
      }
      throw new HttpsError("resource-exhausted", `DeepSeek lỗi ${res.status}`);
    }

    if (!res.ok) {
      const errBody = await res.text();
      console.error("❌ DeepSeek error body:", errBody);
      throw new HttpsError("internal", `DeepSeek HTTP ${res.status}`);
    }

    const data = await res.json();
    return data.choices?.[0]?.message?.content ?? null;
  } catch (err) {
    clearTimeout(timeoutId);
    if (err.name === "AbortError") {
      throw new HttpsError("deadline-exceeded", "DeepSeek timeout sau 22 s");
    }
    if (err instanceof HttpsError) throw err;
    console.error("❌ callDeepSeek exception:", err);
    throw new HttpsError("internal", "Lỗi kết nối AI");
  }
}

// ── Rate limit: 30 req/phút/user ──────────────────────────────────────────
async function checkRateLimit(uid) {
  const db = admin.firestore();
  const now = Date.now();
  const windowMs = 60_000;       // 1 phút
  const maxRequests = 30;
  const ref = db.doc(`_ai_rate_limit/${uid}`);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? { count: 0, windowStart: now };

    if (now - data.windowStart > windowMs) {
      tx.set(ref, { count: 1, windowStart: now });
      return true;
    }
    if (data.count >= maxRequests) return false;
    tx.update(ref, { count: admin.firestore.FieldValue.increment(1) });
    return true;
  });
}

// ── Parse & validate JSON từ AI ───────────────────────────────────────────
function parseAiRepairResult(rawJson) {
  let parsed;
  try {
    parsed = typeof rawJson === "string" ? JSON.parse(rawJson) : rawJson;
  } catch {
    throw new HttpsError("internal", "AI trả về JSON không hợp lệ");
  }

  // Sanitise — chỉ giữ đúng các field trong schema
  return {
    intent: parsed.intent === "create_repair_order" ? "create_repair_order" : "unknown",
    customer_name: (parsed.customer_name ?? "").toString().trim(),
    customer_phone: (parsed.customer_phone ?? "").toString().trim(),
    device: (parsed.device ?? "").toString().trim(),
    issue: (parsed.issue ?? "").toString().trim(),
    deposit: Math.max(0, parseInt(parsed.deposit ?? 0, 10) || 0),
  };
}

// ── Callable function chính ────────────────────────────────────────────────
exports.createRepairOrderAI = onCall(
  {
    secrets: [deepseekApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "asia-southeast1",
  },
  async (request) => {
    // 1. Xác thực
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Yêu cầu đăng nhập");
    }
    const uid = request.auth.uid;

    // 2. Validate input
    const text = (request.data?.text ?? "").toString().trim();
    if (!text || text.length < 3) {
      throw new HttpsError("invalid-argument", "Văn bản quá ngắn");
    }
    if (text.length > 500) {
      throw new HttpsError("invalid-argument", "Văn bản quá dài (tối đa 500 ký tự)");
    }

    // 3. Rate limit
    const allowed = await checkRateLimit(uid);
    if (!allowed) {
      throw new HttpsError("resource-exhausted", "Quá nhiều yêu cầu. Thử lại sau 1 phút.");
    }

    // 4. Gọi DeepSeek
    const apiKey = deepseekApiKey.value();
    const requestId = createSafeRequestId(uid);
    const startedAt = Date.now();
    console.log(`🤖 createRepairOrderAI.start rid=${requestId} uid=${uid} text_len=${text.length}`);

    const rawContent = await callDeepSeek(apiKey, text);
    if (!rawContent) {
      throw new HttpsError("internal", "AI không trả về kết quả");
    }

    // 5. Parse & trả kết quả
    const result = parseAiRepairResult(rawContent);
    console.log(`✅ createRepairOrderAI.done rid=${requestId} uid=${uid} intent=${result.intent} latency_ms=${Date.now() - startedAt}`);

    return { success: true, data: result };
  }
);

// ============================================================
// DEEPSEEK AI — UNIVERSAL ORDER PARSER (repair / sale / stock)
// ============================================================
// Cải tiến so với createRepairOrderAI:
//   • Xử lý cả 3 loại đơn: sửa chữa, bán hàng, nhập kho
//   • Server-side Firestore cache (TTL 24h) — tiết kiệm token
//   • Prompt huấn luyện phong phú hơn với nhiều ví dụ thực tế
//   • hint_mode giúp AI ưu tiên loại đơn được chỉ định
// ============================================================

const UNIVERSAL_SYSTEM_PROMPT = `Bạn là AI phân tích lệnh nhanh cho phần mềm quản lý cửa hàng điện thoại Việt Nam.

NHIỆM VỤ: Phân tích câu nhập tự nhiên của nhân viên → trả về JSON chuẩn.

━━━ INTENT & SCHEMA ━━━

[1] create_repair_order — có từ: sửa, thay, fix, màn, pin, ep, nạp, nạp source, mất face id, vỡ màn:
{"intent":"create_repair_order","device":"<model máy, VD: iPhone 13 Pro Max>","issue":"<lỗi cần sửa ngắn gọn>","deposit":<giá sửa / tiền thu khách VNĐ, 0 nếu không có>,"customer_name":"<tên khách>","customer_phone":"<SĐT 10 số>"}

[2] create_sale_order — có từ: bán, xuất, bán cho, bán hàng:
{"intent":"create_sale_order","product_hint":"<tên/mô tả sản phẩm>","imei":"<IMEI nếu có>","payment_method":"<TIỀN MẶT|CHUYỂN KHOẢN|TRẢ GÓP (NH)|KẾT HỢP>","finance_partner":"<FE|HOME|MIRAE|HD|MB|F83|T86>","total_price":<giá bán VNĐ, 0 nếu không có>,"customer_name":"<tên khách>","customer_phone":"<SĐT 10 số>"}

[3] create_stock_entry — có từ: nhập kho, nhập hàng, nhận hàng, thêm kho:
{"intent":"create_stock_entry","product_name":"<tên sản phẩm>","quantity":<số lượng, mặc định 1>,"unit_price":<giá vốn/máy VNĐ, 0 nếu không>,"supplier_name":"<tên NCC nếu có>"}

[4] unknown — không xác định được:
{"intent":"unknown"}

━━━ QUY TẮC CỨNG ━━━
1. Chỉ trả JSON thuần — KHÔNG markdown, KHÔNG giải thích thêm.
2. KHÔNG bịa dữ liệu. Thiếu field → để rỗng "" / 0.
3. Tiền VNĐ: "1tr2"=1200000, "1.5tr"=1500000, "500k"=500000, "800" (không đơn vị, <10000)=800000.
4. Tên khách: tìm sau từ "khách","tên","cho","của". Nếu không chắc → để rỗng.
5. SĐT: chuỗi 10 số bắt đầu 0 (VD: 0901234567). Không dùng dấu cách.
6. Thương hiệu máy: iphone/samsung/oppo/vivo/xiaomi/realme/nokia/tecno/huawei/asus.
7. Thanh toán: "trả góp"→"TRẢ GÓP (NH)", "chuyển khoản"→"CHUYỂN KHOẢN", "tiền mặt"→"TIỀN MẶT", "kết hợp"→"KẾT HỢP".
8. Đối tác tài chính: nhận diện FE Credit, Home Credit, Mirae Asset, HD Saison, MB Shinsei, F88, T-Fintech.

━━━ VÍ DỤ ━━━
Input: "sửa iphone 13 mất face id khách Hùng 0901234567 thu 500k"
Output: {"intent":"create_repair_order","device":"iPhone 13","issue":"Mất Face ID","deposit":500000,"customer_name":"Hùng","customer_phone":"0901234567"}

Input: "thay màn samsung a55 khách Nam 0965111222 giá 1tr2"
Output: {"intent":"create_repair_order","device":"Samsung A55","issue":"Thay màn hình","deposit":1200000,"customer_name":"Nam","customer_phone":"0965111222"}

Input: "bán iphone 14 pro max imei 123456789 khách Linh 0912333444 chuyển khoản giá 25tr"
Output: {"intent":"create_sale_order","product_hint":"iPhone 14 Pro Max","imei":"123456789","payment_method":"CHUYỂN KHOẢN","finance_partner":"","total_price":25000000,"customer_name":"Linh","customer_phone":"0912333444"}

Input: "bán samsung a34 trả góp FE khách Minh 0987654321"
Output: {"intent":"create_sale_order","product_hint":"Samsung A34","imei":"","payment_method":"TRẢ GÓP (NH)","finance_partner":"FE","total_price":0,"customer_name":"Minh","customer_phone":"0987654321"}

Input: "nhập kho 5 iphone 14 giá vốn 18tr NCC Minh Đức"
Output: {"intent":"create_stock_entry","product_name":"iPhone 14","quantity":5,"unit_price":18000000,"supplier_name":"Minh Đức"}

Input: "nhập 3 samsung a55 giá 7tr5 mỗi máy"
Output: {"intent":"create_stock_entry","product_name":"Samsung A55","quantity":3,"unit_price":7500000,"supplier_name":""}`;

// ── Server-side result cache (Firestore, TTL 24h) ─────────────────────────
const AI_CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const AI_CACHE_COLLECTION = "_ai_cache";

function _cacheHash(text, hintMode) {
  const key = `${(hintMode || "").toLowerCase()}:${text.toLowerCase().replace(/\s+/g, " ").trim()}`;
  return crypto.createHash("md5").update(key).digest("hex");
}

async function _getCachedResult(hash) {
  try {
    const db = admin.firestore();
    const doc = await db.collection(AI_CACHE_COLLECTION).doc(hash).get();
    if (!doc.exists) return null;
    const data = doc.data();
    if (!data || Date.now() - data.cachedAt > AI_CACHE_TTL_MS) return null;
    console.log(`🔁 parseOrderAI: server cache hit hash=${hash}`);
    return data.result;
  } catch (err) {
    console.warn("⚠️ cache read error:", err.message);
    return null;
  }
}

async function _setCachedResult(hash, result) {
  try {
    const db = admin.firestore();
    await db.collection(AI_CACHE_COLLECTION).doc(hash).set({
      result,
      cachedAt: Date.now(),
    });
  } catch (err) {
    console.warn("⚠️ cache write error:", err.message);
  }
}

// ── Parse & validate universal JSON from AI ────────────────────────────────
function _parseUniversalResult(rawJson, hintMode) {
  let parsed;
  try {
    parsed = typeof rawJson === "string" ? JSON.parse(rawJson) : rawJson;
  } catch {
    throw new HttpsError("internal", "AI trả về JSON không hợp lệ");
  }

  const intent = (parsed.intent ?? "unknown").toString().trim();
  const validIntents = [
    "create_repair_order",
    "create_sale_order",
    "create_stock_entry",
    "unknown",
  ];
  const safeIntent = validIntents.includes(intent) ? intent : "unknown";

  const _str = (v) => (v ?? "").toString().trim();
  const _int = (v, def = 0) => {
    const n = parseInt(v ?? def, 10);
    return isNaN(n) || n < 0 ? def : n;
  };

  if (safeIntent === "create_repair_order") {
    return {
      intent: safeIntent,
      device: _str(parsed.device),
      issue: _str(parsed.issue),
      deposit: _int(parsed.deposit),
      customer_name: _str(parsed.customer_name),
      customer_phone: _str(parsed.customer_phone),
    };
  }

  if (safeIntent === "create_sale_order") {
    return {
      intent: safeIntent,
      product_hint: _str(parsed.product_hint),
      imei: _str(parsed.imei),
      payment_method: _str(parsed.payment_method),
      finance_partner: _str(parsed.finance_partner),
      total_price: _int(parsed.total_price),
      customer_name: _str(parsed.customer_name),
      customer_phone: _str(parsed.customer_phone),
    };
  }

  if (safeIntent === "create_stock_entry") {
    return {
      intent: safeIntent,
      product_name: _str(parsed.product_name),
      quantity: _int(parsed.quantity, 1),
      unit_price: _int(parsed.unit_price),
      supplier_name: _str(parsed.supplier_name),
    };
  }

  return { intent: "unknown" };
}

// ── Universal callable function ────────────────────────────────────────────
exports.parseOrderAI = onCall(
  {
    secrets: [deepseekApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "asia-southeast1",
  },
  async (request) => {
    // 1. Auth
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Yêu cầu đăng nhập");
    }
    const uid = request.auth.uid;

    // 2. Validate input
    const text = (request.data?.text ?? "").toString().trim();
    if (!text || text.length < 3) {
      throw new HttpsError("invalid-argument", "Văn bản quá ngắn (tối thiểu 3 ký tự)");
    }
    if (text.length > 600) {
      throw new HttpsError("invalid-argument", "Văn bản quá dài (tối đa 600 ký tự)");
    }
    const hintMode = (request.data?.hint_mode ?? "").toString().trim().toLowerCase();

    // 3. Server-side cache check (no rate-limit cost)
    const hash = _cacheHash(text, hintMode);
    const cached = await _getCachedResult(hash);
    if (cached) {
      return { success: true, data: cached, cached: true };
    }

    // 4. Rate limit (only on cache miss)
    const allowed = await checkRateLimit(uid);
    if (!allowed) {
      throw new HttpsError("resource-exhausted", "Quá nhiều yêu cầu. Thử lại sau 1 phút.");
    }

    // 5. Build prompt (hint_mode prepended for context)
    const hintPrefix = hintMode === "repair"
      ? "[Ưu tiên: đơn sửa chữa] "
      : hintMode === "sale"
      ? "[Ưu tiên: đơn bán hàng] "
      : hintMode === "stock"
      ? "[Ưu tiên: nhập kho] "
      : "";

    const userText = hintPrefix + text;
    const requestId = createSafeRequestId(uid);
    const startedAt = Date.now();
    console.log(`🤖 parseOrderAI.start rid=${requestId} uid=${uid} hint=${hintMode || "none"} text_len=${text.length}`);

    // 6. Call DeepSeek (reuse existing callDeepSeek with universal prompt)
    const apiKey = deepseekApiKey.value();
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 22000);

    let rawContent;
    try {
      const res = await fetch(DEEPSEEK_BASE_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: DEEPSEEK_MODEL,
          messages: [
            { role: "system", content: UNIVERSAL_SYSTEM_PROMPT },
            { role: "user", content: userText },
          ],
          temperature: 0.05,
          max_tokens: 300,
          response_format: { type: "json_object" },
        }),
        signal: controller.signal,
      });
      clearTimeout(timeoutId);

      if (res.status === 429 || res.status >= 500) {
        // 1 retry
        await new Promise((r) => setTimeout(r, 1500));
        const res2 = await fetch(DEEPSEEK_BASE_URL, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model: DEEPSEEK_MODEL,
            messages: [
              { role: "system", content: UNIVERSAL_SYSTEM_PROMPT },
              { role: "user", content: userText },
            ],
            temperature: 0.05,
            max_tokens: 300,
            response_format: { type: "json_object" },
          }),
        });
        if (!res2.ok) throw new HttpsError("resource-exhausted", `DeepSeek ${res2.status}`);
        const d2 = await res2.json();
        rawContent = d2.choices?.[0]?.message?.content ?? null;
      } else if (!res.ok) {
        const errBody = await res.text();
        console.error("❌ DeepSeek error:", errBody);
        throw new HttpsError("internal", `DeepSeek HTTP ${res.status}`);
      } else {
        const data = await res.json();
        rawContent = data.choices?.[0]?.message?.content ?? null;
      }
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === "AbortError") {
        throw new HttpsError("deadline-exceeded", "DeepSeek timeout sau 22 s");
      }
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "Lỗi kết nối AI");
    }

    if (!rawContent) {
      throw new HttpsError("internal", "AI không trả về kết quả");
    }

    // 7. Parse & sanitise
    const result = _parseUniversalResult(rawContent, hintMode);
    console.log(`✅ parseOrderAI.done rid=${requestId} uid=${uid} hint=${hintMode || "none"} intent=${result.intent} latency_ms=${Date.now() - startedAt}`);

    // 8. Store in server cache (fire-and-forget)
    _setCachedResult(hash, result);

    return { success: true, data: result, cached: false };
  }
);

// ============================================================
// DEEPSEEK AI — CHAT ASSISTANT (AI Trợ Lý Shop)
// ============================================================
// Flutter gọi qua cloud_functions SDK: FirebaseFunctions
//   .instanceFor(region:'asia-southeast1')
//   .httpsCallable('chatAssistant')
//   .call({ question, stats, history })
//
// API key: chỉ trong Google Secret Manager (DEEPSEEK_API_KEY).
// Rate limit: 20 câu hỏi / phút / user.
// Timeout: 20 s client-side, 25 s server-side abort.
// ============================================================

const CHAT_SYSTEM_PROMPT = `Bạn là AI Trợ Lý của phần mềm quản lý cửa hàng sửa chữa điện thoại HULUCA (tên app: Quản Lý Shop).

━━━ VAI TRÒ ━━━
Bạn hỗ trợ chủ shop và nhân viên tại các cửa hàng sửa chữa điện thoại Việt Nam. Bạn có thể:
• Tra cứu và giải thích số liệu kinh doanh hôm nay và tháng này.
• Tư vấn cách vận hành, quản lý kho, xử lý công nợ, theo dõi đơn sửa.
• Hướng dẫn sử dụng các tính năng trong app.
• Đưa ra lời khuyên thực tế phù hợp với shop điện thoại Việt Nam.

━━━ CÁC TÍNH NĂNG CHÍNH CỦA APP ━━━
• **Đơn sửa chữa**: Tạo, theo dõi trạng thái (Mới nhận → Đang sửa → Xong chờ lấy → Đã giao), in phiếu.
• **Bán hàng**: Tạo hoá đơn bán điện thoại, phụ kiện; hỗ trợ trả góp (FE, Home Credit, Mirae...).
• **Kho hàng**: Quản lý tồn kho, nhập hàng từ NCC, theo dõi giá vốn.
• **Công nợ**: Quản lý nợ phải thu (khách nợ shop) và nợ phải trả (shop nợ NCC).
• **Tài chính**: Báo cáo doanh thu, lợi nhuận, chi phí theo ngày/tháng.
• **Khách hàng**: Danh sách khách, lịch sử sửa chữa, lịch sử mua hàng.
• **Nhân viên**: Phân quyền theo vai trò (chủ shop, quản lý, kỹ thuật viên, nhân viên bán).
• **Nhập nhanh bằng giọng nói**: Tạo đơn sửa/bán hàng/nhập kho bằng giọng nói tự nhiên.
• **Thông báo**: Cảnh báo đơn mới, đổi trạng thái, công nợ qua push notification.
• **Đồng bộ đa thiết bị**: Dữ liệu đồng bộ realtime qua Firebase giữa các thiết bị trong shop.
• **Xuất Excel**: Xuất báo cáo tài chính, danh sách đơn sửa, tồn kho ra file Excel.

━━━ QUY TẮC PHẢN HỒI ━━━
1. **LUÔN dùng tiếng Việt CÓ DẤU đầy đủ** — không viết tắt thiếu dấu, không dùng tiếng Anh khi có từ tiếng Việt tương đương.
2. Chỉ trả lời dựa trên dữ liệu được cung cấp trong context. KHÔNG bịa số liệu.
3. Nếu hỏi số liệu ngoài phạm vi dữ liệu cung cấp, giải thích lịch sự rằng chỉ có dữ liệu hôm nay và tháng này.
4. Nếu câu hỏi không liên quan đến shop, từ chối nhẹ nhàng và gợi ý chủ đề phù hợp.
5. Dùng **bold** để nhấn mạnh số liệu quan trọng.
6. Không dùng markdown heading (#) — chỉ dùng gạch đầu dòng (•) nếu cần liệt kê.
7. Ngắn gọn, súc tích — không quá 250 từ mỗi câu trả lời.
8. Không lặp lại cùng một tiêu đề hoặc cùng một khối nội dung trong một câu trả lời.
9. Với kho hàng: "mặt hàng" là số bản ghi sản phẩm còn hàng, còn "sản phẩm tồn" là tổng quantity. Không được cộng gộp hai khái niệm này.`;

function dedupeConsecutiveBlocks(text) {
  const raw = String(text || '').trim();
  if (!raw) return raw;

  const paragraphs = raw.split(/\n{2,}/);
  const seen = new Set();
  const out = [];

  for (const paragraph of paragraphs) {
    const normalized = paragraph.replace(/\s+/g, ' ').trim().toLowerCase();
    if (!normalized) continue;
    if (seen.has(normalized)) continue;
    seen.add(normalized);
    out.push(paragraph.trim());
  }

  return out.join('\n\n').replace(/\n{3,}/g, '\n\n').trim();
}

async function callDeepSeekChat(apiKey, messages, attempt = 1) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 22000);

  try {
    const res = await fetch(DEEPSEEK_BASE_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: DEEPSEEK_MODEL,
        messages,
        temperature: 0.5,
        max_tokens: 400,
      }),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (res.status === 429 || res.status >= 500) {
      if (attempt < 2) {
        console.warn(`⚠️ DeepSeek chat ${res.status} — retry ${attempt}`);
        await new Promise((r) => setTimeout(r, 1500));
        return callDeepSeekChat(apiKey, messages, attempt + 1);
      }
      throw new HttpsError("resource-exhausted", "AI đang bận, vui lòng thử lại sau.");
    }

    if (!res.ok) {
      const errBody = await res.text();
      console.error("❌ DeepSeek chat error:", errBody);
      throw new HttpsError("internal", `DeepSeek HTTP ${res.status}`);
    }

    const data = await res.json();
    return data.choices?.[0]?.message?.content?.trim() ?? null;
  } catch (err) {
    clearTimeout(timeoutId);
    if (err.name === "AbortError") {
      throw new HttpsError("deadline-exceeded", "AI phản hồi quá chậm, hãy thử lại.");
    }
    if (err instanceof HttpsError) throw err;
    console.error("❌ callDeepSeekChat exception:", err);
    throw new HttpsError("internal", "Lỗi kết nối AI");
  }
}

function createSafeRequestId(uid) {
  const base = `${uid}-${Date.now()}-${Math.random()}`;
  return crypto.createHash("md5").update(base).digest("hex").slice(0, 12);
}

function normalizeForIntent(text) {
  return String(text || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function detectChatIntent(question) {
  const q = normalizeForIntent(question);

  if (/\b(kho|ton kho|linh kien|phu kien|gia von|hang ton)\b/.test(q)) return "stock";
  if (/\b(cong no|khach no|ncc no|no phai thu|no phai tra|doi soat no)\b/.test(q)) return "debt";
  if (/\b(doanh thu|loi nhuan|thu chi|tai chinh|bao cao|tong hop|thang nay|nam nay)\b/.test(q)) return "finance";
  if (/\b(don sua|sua chua|bao hanh|dang sua|cho giao|da giao may)\b/.test(q)) return "repair";
  if (/\b(ban hang|hoa don|don ban|tra gop|doanh so)\b/.test(q)) return "sales";
  return "general";
}

function maskPii(text) {
  if (!text) return "";
  return String(text)
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[EMAIL]")
    .replace(/(\+?84|0)\d{8,10}/g, "[PHONE]")
    .replace(/\b\d{8,}\b/g, "[NUMBER]")
    .replace(/\bkhach\s+[^\n,.;:]+/gi, "khach [MASKED]");
}

function sanitizeHistory(history) {
  if (!Array.isArray(history)) return [];
  const out = [];
  for (const turn of history.slice(-6)) {
    if (!turn || !turn.role || !turn.content) continue;
    const safeRole = ["user", "assistant", "system"].includes(turn.role) ? turn.role : "user";
    out.push({ role: safeRole, content: maskPii(String(turn.content).substring(0, 280)) });
  }
  return out;
}

function buildStatsContextByIntent(intent, s, fmt) {
  const compactToday = [
    `• Doanh thu hôm nay: ${fmt(s.revenueToday)}`,
    `• Lợi nhuận hôm nay: ${fmt(s.profitToday)}`,
    `• Bán hàng: ${s.salesToday ?? 0} đơn`,
    `• Sửa chữa đang chờ: ${s.repairsPending ?? 0} đơn`,
  ];

  const countFmt = (value) => Number(value || 0).toLocaleString('vi-VN');

  if (intent === "stock") {
    return [
      "=== KHO ===",
      `• Kho điện thoại: ${countFmt(s.phoneStockCount)} mặt hàng | Tồn: ${countFmt(s.phoneStockQuantity)} | Giá vốn: ${fmt(s.phoneStockCapital)}`,
      `• Kho phụ kiện: ${countFmt(s.accessoryStockCount)} mặt hàng | Tồn: ${countFmt(s.accessoryStockQuantity)} | Giá vốn: ${fmt(s.accessoryStockCapital)}`,
      `• Kho linh kiện: ${countFmt(s.partStockCount)} mặt hàng | Tồn: ${countFmt(s.partStockQuantity)} | Giá vốn: ${fmt(s.partStockCapital)}`,
      `• Tồn kho hiện tại: ${countFmt(s.stockCount)} mặt hàng | Tồn: ${countFmt(s.stockQuantity)} | Giá vốn: ${fmt(s.stockCapital)}`,
    ].join("\n");
  }

  if (intent === "debt") {
    return [
      "=== CÔNG NỢ ===",
      `• Phải thu: ${fmt(s.debtReceivable)}`,
      `• Phải trả: ${fmt(s.debtPayable)}`,
    ].join("\n");
  }

  if (intent === "repair") {
    return [
      "=== SỬA CHỮA ===",
      `• Đơn mới hôm nay: ${s.repairsToday ?? 0}`,
      `• Đã giao hôm nay: ${s.deliveredRepairsToday ?? 0}`,
      `• Đang chờ giao: ${s.repairsPending ?? 0}`,
      `• Doanh thu sửa hôm nay: ${fmt(s.repairRevenueToday)}`,
    ].join("\n");
  }

  if (intent === "sales") {
    return [
      "=== BÁN HÀNG ===",
      `• Đơn bán hôm nay: ${s.salesToday ?? 0}`,
      `• Doanh thu bán hôm nay: ${fmt(s.saleRevenueToday ?? s.revenueToday)}`,
      `• Đơn bán tháng này: ${s.salesThisMonth ?? 0}`,
      `• Doanh thu bán tháng này: ${fmt(s.saleRevenueThisMonth ?? 0)}`,
    ].join("\n");
  }

  if (intent === "finance") {
    return [
      "=== TÀI CHÍNH ===",
      ...compactToday,
      "\n=== THÁNG NÀY ===",
      `• Doanh thu tháng: ${fmt(s.revenueThisMonth)}`,
      `• Lợi nhuận tháng: ${fmt(s.profitThisMonth)}`,
      `• Bán hàng: ${s.salesThisMonth ?? 0} đơn (${fmt(s.saleRevenueThisMonth ?? 0)})`,
      `• Sửa chữa: ${s.repairsThisMonth ?? 0} đơn (${fmt(s.repairRevenueThisMonth ?? 0)})`,
      `• Công nợ phải thu: ${fmt(s.debtReceivable)} | Phải trả: ${fmt(s.debtPayable)}`,
    ].join("\n");
  }

  return ["=== TỔNG QUAN ===", ...compactToday].join("\n");
}

exports.chatAssistant = onCall(
  {
    secrets: [deepseekApiKey],
    timeoutSeconds: 25,
    region: "asia-southeast1",
  },
  async (request) => {
    // 1. Auth
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Cần đăng nhập để dùng AI.");
    }
    const uid = request.auth.uid;

    // 2. Rate limit — 20 câu/phút
    const db = admin.firestore();
    const now = Date.now();
    const rlRef = db.doc(`_ai_rate_limit_chat/${uid}`);
    const allowed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(rlRef);
      const d = snap.data() ?? { count: 0, windowStart: now };
      if (now - d.windowStart > 60_000) {
        tx.set(rlRef, { count: 1, windowStart: now });
        return true;
      }
      if (d.count >= 20) return false;
      tx.update(rlRef, { count: admin.firestore.FieldValue.increment(1) });
      return true;
    });
    if (!allowed) {
      throw new HttpsError("resource-exhausted", "Đã gửi quá 20 câu hỏi/phút. Hãy chờ chút.");
    }

    // 3. Validate input
    const { question, stats, history } = request.data ?? {};
    if (!question || typeof question !== "string" || question.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Câu hỏi không được để trống.");
    }
    const q = question.trim().substring(0, 500); // giới hạn độ dài
    const requestId = createSafeRequestId(uid);
    const intent = detectChatIntent(q);

    // 4. Build stats context string
    const fmt = (n) => {
      const num = Number(n) || 0;
      if (num === 0) return "0đ";
      if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1).replace(/\.0$/, "")}tr`;
      return `${num.toLocaleString("vi-VN")}đ`;
    };
    const s = stats ?? {};
    const statsContext = buildStatsContextByIntent(intent, s, fmt);

    // 5. Build messages array
    const systemWithContext = `${CHAT_SYSTEM_PROMPT}

━━━ DỮ LIỆU THỰC TẾ CỦA SHOP ━━━
${statsContext}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;

    const messages = [{ role: "system", content: systemWithContext }];

    const safeHistory = sanitizeHistory(history);

    // Append sanitized conversation history (max 6 turns)
    for (const turn of safeHistory) {
      messages.push(turn);
    }

    // Append current question
    messages.push({ role: "user", content: maskPii(q) });

    // 6. Call DeepSeek
    const startedAt = Date.now();
    console.log(`🤖 chatAssistant.start rid=${requestId} uid=${uid} intent=${intent} q_len=${q.length} hist=${safeHistory.length}`);
    const apiKey = deepseekApiKey.value();
    const answer = await callDeepSeekChat(apiKey, messages);

    if (!answer) {
      throw new HttpsError("internal", "AI không trả lời được. Hãy thử lại.");
    }

    const cleanedAnswer = dedupeConsecutiveBlocks(answer);

    console.log(`✅ chatAssistant.done rid=${requestId} uid=${uid} intent=${intent} answer_len=${cleanedAnswer.length} latency_ms=${Date.now() - startedAt}`);
    return { answer: cleanedAnswer };
  }
);
