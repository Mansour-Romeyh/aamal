const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotificationOnCreate = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const targetToken = data.targetToken;
        
        if (!targetToken) return null;

        const payload = {
            notification: {
                title: data.title,
                body: data.body,
            },
            data: data.data || {},
        };

        try {
            await admin.messaging().sendToDevice(targetToken, payload);
            return snapshot.ref.update({ isSent: true });
        } catch (error) {
            console.error('Error sending notification:', error);
            return null;
        }
    });
