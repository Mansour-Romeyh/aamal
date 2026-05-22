const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

/**
 * Cloud Function: تُراقب إضافة أي إشعار جديد في مجموعة notifications
 * وتقوم بإرساله عبر FCM للجهاز المستهدف
 */
exports.sendPushNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const data = snapshot.data();
    const { targetToken, title, body, data: notifData, isSent } = data;

    // تجاهل إذا كان تم الإرسال مسبقاً أو لا يوجد token
    if (isSent || !targetToken) return null;

    const message = {
      notification: {
        title: title || "إشعار جديد",
        body: body || "",
      },
      data: {
        type: notifData?.type || "general",
        postId: notifData?.postId || "",
        conversationId: notifData?.conversationId || "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "workers_channel",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
      token: targetToken,
    };

    try {
      await getMessaging().send(message);
      // تعيين حالة الإرسال
      await getFirestore()
        .collection("notifications")
        .doc(event.params.notificationId)
        .update({ isSent: true, sentAt: new Date() });

      console.log("✅ Notification sent successfully to:", targetToken);
      return null;
    } catch (error) {
      console.error("❌ Error sending notification:", error);
      // تعيين حالة الفشل
      await getFirestore()
        .collection("notifications")
        .doc(event.params.notificationId)
        .update({ isSent: false, error: error.message });
      return null;
    }
  }
);

/**
 * Cloud Function: إعادة تعيين كلمة المرور باستخدام رقم الهاتف (بعد التحقق من الـ OTP من جهة العميل)
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");

exports.resetUserPassword = onCall(async (request) => {
  const { uid, newPassword } = request.data;
  
  if (!uid || !newPassword) {
    throw new HttpsError('invalid-argument', 'Missing uid or newPassword');
  }

  try {
    // تحديث الباسورد في Firebase Auth
    await getAuth().updateUser(uid, {
      password: newPassword,
    });
    console.log(`✅ Password updated successfully for user: ${uid}`);
    return { success: true };
  } catch (error) {
    console.error("❌ Error updating password:", error);
    throw new HttpsError('internal', error.message);
  }
});
