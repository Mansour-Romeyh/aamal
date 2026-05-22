import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../../../../core/constants/firebase_constants.dart';
import 'package:flutter/foundation.dart';


class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<NotificationModel>> getUserNotifications(String userId, {bool isAdmin = false}) {
    // تحديد قائمة المعرفات المستهدفة (الشخصي + الدعم لو كان أدمن)
    final targetIds = [userId];
    if (isAdmin) {
      targetIds.add(FirebaseConstants.supportId);
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('notifications')
        .where('targetUserId', whereIn: targetIds);

    if (isAdmin) {
      // للأدمن نمنع الشات فقط على مستوى الاستعلام،
      // ثم نكمل فلترة منطقية في الذاكرة لدعم الإشعارات القديمة بدون category.
      query = query
          .where('category', isNotEqualTo: NotificationConstants.categoryChat)
          .orderBy('category');
    } else {
      // المستخدم العادي/الحرفي: نستبعد الشات من المركز
      query = query
          .where('category', isNotEqualTo: NotificationConstants.categoryChat)
          .orderBy('category');
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      
      // التنظيف التلقائي للإشعارات
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final isRead = data['isRead'] ?? false;
        
        if (createdAt != null) {
          final diffInHours = now.difference(createdAt).inHours;
          
          // القاعدة 1: حذف الإشعارات المقروءة بعد 7 ساعات
          // القاعدة 2: حذف أي إشعارات أخرى (غير مقروءة) بعد 10 ساعات كحد أمان
          final shouldDelete = (isRead && diffInHours >= 7) || (!isRead && diffInHours >= 10);

          if (shouldDelete) {
            final notificationId = doc.id;
            
            // حذف الإشعار
            _firestore.collection('notifications').doc(notificationId).delete().then((_) {
              // إذا كان غير مقروء، ننقص العداد الإجمالي للمستخدم
              if (!isRead) {
                _firestore.collection(FirebaseConstants.usersCollection).doc(userId).update({
                  'unreadNotificationsCount': FieldValue.increment(-1),
                }).catchError((e) {
                  debugPrint('❌ Error updating unread count for auto-deleted notification: $e');
                });
              }
            }).catchError((e) {
              debugPrint('❌ Error auto-deleting old notification: $e');
            });
          }
        }
      }

      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .where((notification) {
            final category = (notification.data['category'] ?? '').toString();
            final type = (notification.data['type'] ?? '').toString();
            if (isAdmin) {
              // مركز الأدمن: فقط الإداري (مع دعم الداتا القديمة التي لا تحمل category)
              const adminTypes = {
                NotificationConstants.typeReport,
                NotificationConstants.typeSupport,
                NotificationConstants.typeAdminAction,
                NotificationConstants.typeArtisanApproval,
              };
              if (category.isNotEmpty) {
                return category == NotificationConstants.categoryAdmin;
              }
              return adminTypes.contains(type);
            }
            return notification.data['type'] != NotificationConstants.typeChat;
          })
          .where((notification) {
        // فلترة للعرض الفوري لضمان عدم ظهور أي إشعار قديم قبل حذفه الفعلي من السيرفر
        final diffInHours = now.difference(notification.createdAt).inHours;
        if (notification.isRead) {
          return diffInHours < 7;
        }
        return diffInHours < 10;
      }).toList();
    });
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
    
    // نقص العداد للمستخدم (مع التأكد أنه لا يقل عن الصفر)
    final userDoc = await _firestore.collection(FirebaseConstants.usersCollection).doc(userId).get();
    final currentCount = (userDoc.data()?['unreadNotificationsCount'] ?? 0) as int;
    if (currentCount > 0) {
      await _firestore.collection(FirebaseConstants.usersCollection).doc(userId).update({
        'unreadNotificationsCount': FieldValue.increment(-1),
      });
    }
  }

  Future<void> deleteNotification(String userId, String notificationId, bool wasRead) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
    
    // إذا حذفت إشعاراً "غير مقروء"، ننقص العداد أيضاً (مع التأكد أنه لا يقل عن الصفر)
    if (!wasRead) {
      final userDoc = await _firestore.collection(FirebaseConstants.usersCollection).doc(userId).get();
      final currentCount = (userDoc.data()?['unreadNotificationsCount'] ?? 0) as int;
      if (currentCount > 0) {
        await _firestore.collection(FirebaseConstants.usersCollection).doc(userId).update({
          'unreadNotificationsCount': FieldValue.increment(-1),
        });
      }
    }
  }
}
