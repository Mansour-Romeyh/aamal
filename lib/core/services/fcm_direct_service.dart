import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../../../core/constants/firebase_constants.dart';

/// ─── FCM Configuration ───────────────────────────────────────────────────────
/// يمكنك استخراج هذه القيم من Firebase Console:
/// Project Settings → Service Accounts → Generate new private key
/// ─────────────────────────────────────────────────────────────────────────────
class FcmConfig {
  // Project ID - موجود في إعدادات Firebase
  static const projectId = 'works-d4f07';

  // البريد الإلكتروني لحساب الخدمة - من ملف JSON المُحمَّل
  static const clientEmail =
      'firebase-adminsdk-fbsvc@works-d4f07.iam.gserviceaccount.com';

  static const privateKey = r'''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDOOHCFW+nYlPTg
JJK/nXI7hRMM3BTAMen6ycBVzJ7N6KgG/xoXP3qsMlU7m8V1XIlB6PwoYOhJsxEl
U0gYP8ZbqaCjNlrpd0gV8apYLEv3YJYssKMKFAtQeVGL9mxrOCsbzTjB9eXysxyB
ooyrttPwdT5d4nHe6YMSNro6aaXthC/o/GxS0TUG68cnrr8mTVKnBwNJMHfs2Wnc
6TmY7fw5p5DW8M7xINvDkrEYR5y1WK3vsoajkszFl3jBqtVI77ABu5HZd56KVuG3
YU8N+oImP0LXJ78uOHa/SHnbhmu1QBe0Xe8OqY1HsulU6sVTwcvOcpNiiqhYzdUb
LpXBVpzFAgMBAAECggEADeLyfn9RaaFZouCcvuAwdQvhks74Rr/MkSq6gXpJ8HTV
IFXFU27e390GGpPDT564vSbnPSVpbK0RqMpbdZ1spXeCttZOLqA2ywgRSQtJb/+h
nTQ3z4jI3IwhIRHy/DVaWu6gkPOo585iJr92RhwqM7VM3UIq9Wc3gEwykZavF264
3wFsIwkrrOZ0sZURnkzcNPVXRq9Lltc+Wb3vPeAylv9odIlOnWh650TZezGAVVsd
V26ylshs3aTgNKq+tXN9YRQxndYUTfkSD36VTIRb2aexbzGQ6r2zRNnJXuL7KVEb
945PTDkTvCSiC7JxYMX7Pv7YD/m33mTzbYhLNodHcQKBgQD2eeYw4I25zk+E0Xv5
pwCX49IqL0wjiWWx4bsTA/vY8+RmqaF2wAqTREB/2uveW7mMlkSaHcndIblWWqTL
CWzcB1mO0dxjvWa5jkkoHQuoae9FANviBchiLk2OZeEP5HHptof19yZIUjWVT3y7
6UuTTP3j+oED7N2EkarlwrBi2wKBgQDWMFZ0u3G7G/rNsAahxHfGjpxSWqVh/Nx2
dQxIb8lfSJA/l/oBUds6n30buWxPzWfQ4nW6nZvooBZYWACS3yfWy7gSn70ubvNn
RjGhPgE56bfc8+wPfdcemD6cdmvLeR0pnFDRmTs1aH2qUZuvZh+aw+UtTb9mfsCT
Wf8nGLmA3wKBgEMnc1Bd3j+Btqi5as3aco7vw5M6z8Pe65ZLqmzD6RpzWQefsB5q
tHbrYad0Pk+XLjbfulFDTHyzc4vTppKrPr20QvJmu2VxdUuZONV1FHgOZOKoGUC7
0pztgLQLjgaGd4L1+JVLgWKzA2ZrAdEw/yZjE8nJtt0a7D/ycF2pbeWBAoGBAMsT
r5Uj99QY1jXY1KDh/1JB+pLWoQGD1p91oLy5SGtQCHxTItXHf51YhC0aJEiRjwHt
BQR31M+9oRIH9htK+6HbK151F9CDn8HmOr4PZOg84XfbyZByltjKLmr4mIGmBnFi
ZPolV47u0F8A2yR1Jjf9zjejBHswaHQNGy89cPxvAoGAZm69OZZSmwf9qnlyV00W
c3xxls8S71f29Dtn1sxyUms15o8q+/qQpao2zFHBsDIRKxa7KP5jSb3EeWIHKHk5
SCbgNDud46DE4y2RqDrY533O3rHqhg/uswlSly7zC9qFHqqIjB1hvFOVpr7upvS2
SvoCckdp0q7Z6wRvVKbgh7s=
-----END PRIVATE KEY-----''';
}

/// خدمة إرسال الإشعارات مباشرة عبر FCM HTTP v1 API
/// بدون Cloud Functions - مجانية 100%
class FcmDirectService {
  FcmDirectService._();
  static final FcmDirectService instance = FcmDirectService._();

  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _scope = 'https://www.googleapis.com/auth/firebase.messaging';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedToken;
  DateTime? _tokenExpiry;

  // ── الحصول على Access Token ──────────────────────────────────────
  Future<String> _getAccessToken() async {
    // استخدم الـ token المخزن إذا كان لا يزال صالحاً
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!;
    }

    final now = DateTime.now();
    final token = await compute(_signJwt, {
      'privateKey': FcmConfig.privateKey,
      'payload': {
        'iss': FcmConfig.clientEmail,
        'scope': _scope,
        'aud': _tokenEndpoint,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': (now.millisecondsSinceEpoch ~/ 1000) + 3600,
      },
    });

    final response = await http
        .post(
          Uri.parse(_tokenEndpoint),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': token,
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      debugPrint(
        '❌ FCM Token Request Failed: ${response.statusCode} - ${response.body}',
      );
      throw Exception('Failed to get FCM access token');
    }

    final data = jsonDecode(response.body);
    _cachedToken = data['access_token'] as String;
    _tokenExpiry = now.add(const Duration(minutes: 55));
    return _cachedToken!;
  }

  // ── إرسال إشعار مباشرة لـ Token معين ───────────────────────────
  Future<void> sendToToken({
    required String fcmToken,
    required String title,
    required String body,
    int? badge,
    Map<String, String>? data,
  }) async {
    try {
      final accessToken = await _getAccessToken();

      final payload = {
        'message': {
          'token': fcmToken,
          'notification': {'title': title, 'body': body},
          'data': {
            ...?data,
            'title': title,
            'body': body,
            if (badge != null) 'badge': badge.toString(),
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'android': {
            'priority': 'HIGH',
            'notification': {
              'channel_id': 'workers_channel',
              'notification_priority': 'PRIORITY_HIGH',
              'default_sound': true,
              'default_vibrate_timings': true,
              'visibility': 'PUBLIC',
              'icon': '@mipmap/ic_launcher',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'alert': {'title': title, 'body': body},
                'sound': 'default',
                'badge': badge ?? 0,
                'content-available': 1,
                'mutable-content': 1,
              },
            },
            'headers': {'apns-priority': '10'},
          },
        },
      };

      final res = await http
          .post(
            Uri.parse(
              'https://fcm.googleapis.com/v1/projects/${FcmConfig.projectId}/messages:send',
            ),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint('❌ FCM Send Failed [V1]: ${res.statusCode} - ${res.body}');
        
        // ── تنظيف التوكينات المنتهية (Auto-Cleanup) ────────────────────
        if (res.body.contains('UNREGISTERED') || res.statusCode == 404) {
          debugPrint('🧹 detected UNREGISTERED token. Cleaning up from Firestore...');
          _cleanupToken(fcmToken);
        }
        
        debugPrint('   Token: ${fcmToken.substring(0, 10)}...');
        debugPrint('   Project: ${FcmConfig.projectId}');
      } else {
        debugPrint(
          '✅ FCM Notification sent successfully to token: ${fcmToken.substring(0, 10)}...',
        );
      }
    } catch (e) {
      debugPrint('🚨 FCM Exception: $e');
    }
  }

  // ── إرسال إشعار لمستخدم عبر userId ─────────────────────────────
  Future<void> sendToUser({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (targetUserId.isEmpty) {
      debugPrint('⚠️ FcmDirectService: targetUserId is empty!');
      return;
    }
    try {
      debugPrint('🔍 FcmDirectService: Fetching user doc for $targetUserId');
      final userDoc = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(targetUserId)
          .get();

      if (!userDoc.exists) {
        debugPrint('⚠️ User doc not found: $targetUserId');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userRole = userData['role'] as String?;
      final type = data?['type'];
      final isChatType = type == NotificationConstants.typeChat;
      final category = _resolveNotificationCategory(type);
      // فحص هل المستخدم المستهدف فاتح نفس المحادثة حالياً؟
      final conversationId = data?['conversationId'];
      final isSupportFlag = data?['isSupport'] == 'true' || data?['isAdmin'] == 'true';
      final isSupportTarget = targetUserId == FirebaseConstants.supportId;
      final targetActiveChatId = userData['activeChatId'] as String?;
      bool isTargetInActiveChat = false;
      // ── فحص التواجد (Silence Logic) ──────────────────────────────────
      if (conversationId != null) {
        // الفحص الموحد (لصاحب الحساب المستهدف سواء كان مستخدم عادي أو أدمن مشترك)
        if (conversationId == targetActiveChatId) {
          // إضافة صمام أمان: لو الـ Presence قديم جداً (أكتر من 5 دقائق) نتجاهله
          // نفضل استخدام lastPresenceUpdate الجديد، ولو مش موجود نستخدم lastSeen كاحتياطي
          final lastPresenceUpdate = userData['lastPresenceUpdate'] as Timestamp?;
          final lastSeen = userData['lastSeen'] as Timestamp?;
          final targetTime = lastPresenceUpdate ?? lastSeen;
          
          bool isStale = false;
          if (targetTime != null) {
            final diff = DateTime.now().difference(targetTime.toDate());
            if (diff.inMinutes > 5) isStale = true;
          }

          if (!isStale) {
            isTargetInActiveChat = true;
            debugPrint('🎯 Silence: Target activeChatId matches current conversation: $conversationId');
          } else {
            debugPrint('⏰ Zombie Lock detected: Ignoring stale activeChatId for $targetUserId');
          }
        } 
      }


      // 🛑 استثناء حرج: لا نكتم الإشعارات الخارجية أبداً للهوية المشتركة (Support)
      // لأن دخول مسؤول واحد للمحادثة يجب ألا يحرم بقية المسؤولين من استلام التنبيه
      if (isSupportTarget) {
        isTargetInActiveChat = false; 
        debugPrint('🔓 Support Bypass: Shared identity will always receive push notification.');
      }

      // 1. زيادة عداد الإشعارات في Firestore لهذا المستخدم
      final isActuallyActive = isTargetInActiveChat;

      
      final batch = _firestore.batch();
      final userRef = _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(targetUserId);
          
      // زيادة العداد لكل الإشعارات ما عدا الشات (الشات يُعتمد على قراءة الرسائل مباشرة)
      // أو إذا كان المستخدم فاتح نفس المحادثة حالياً
      if (!isActuallyActive && !isChatType) {
        if (isSupportTarget) {
          // للأدمن: نستخدم set مع merge لضمان نجاح العملية حتى لو كان مستند الحساب مش موجود
          batch.set(userRef, {
            'unreadNotificationsCount': FieldValue.increment(1),
            'role': FirebaseConstants.roleAdmin,
          }, SetOptions(merge: true));
        } else {
          // للمستخدمين العاديين: نستخدم update لضمان التوافق مع قواعد الحماية (Security Rules)
          batch.update(userRef, {
            'unreadNotificationsCount': FieldValue.increment(1),
          });
        }
      }

      // 2. تحديث قائمة الـ Tokens والـ Badge للإرسال الخارجي
      final fcmToken = userData['fcmToken'] as String?;
      final rawTokens = userData['fcmTokens'] as List<dynamic>? ?? [];
      final List<String> fcmTokens = rawTokens
          .where((t) => t != null && t is String && t.isNotEmpty)
          .cast<String>()
          .toSet() // إزالة التكرار
          .toList();

      final Set<String> allTokens = {};
      if (fcmToken != null && fcmToken.isNotEmpty) allTokens.add(fcmToken);
      allTokens.addAll(fcmTokens);

      // 3. حفظ الإشعار في الفايرستور لتقوم الـ Cloud Function بإرساله
      // (حتى للشات، لأن Cloud Function تعتمد على هذا المستند للإرسال، ومركز الإشعارات سيتجاهله)
      if (!isActuallyActive) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'targetUserId': targetUserId,
          'targetToken': allTokens.isNotEmpty ? allTokens.first : null,
          'title': title,
          'body': body,
          'data': data ?? {},
          'category': category,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'isSent': false,
        });
      }

      // التحديث الداخلي (العداد وجرس التنبيهات) في Firestore
      try {
        await batch.commit();
        debugPrint('✅ Internal notification records committed to Firestore for $targetUserId');
      } catch (e) {
        debugPrint('⚠️ Warning: Firestore batch commit failed (Non-blocking): $e');
        // لا نتوقف، نكمل للإرسال الخارجي
      }

      // لو المستهدف فاتح الشات حالياً، نكتفي بالتحديث الداخلي ولا نرسل تنبيه خارجي (FCM)
      // ⚠️ هام: هذا الحجب يطبَّق فقط على رسائل الشات، أما الإشعارات الأخرى لا تُحجب
      if (isTargetInActiveChat && isChatType) {
        debugPrint('🔕 Active chat detected: Skipping external push for $targetUserId');
        return;
      }

      // ── فحص التصفية للأدمنز: السماح لكل ما يخص الدعم والتقارير ───────────────────
      if (userRole == FirebaseConstants.roleAdmin || isSupportTarget) {
        
        // إذا كان الإشعار موجهاً لحساب الدعم، فهو دائماً من نوع أدمن ويجب أن يمر (تجاوز كامل للفلاتر)
        bool isAdminType = isSupportTarget ||
            isSupportFlag ||
            type == 'report' ||
            type == 'support' ||
            type == 'admin_action' ||
            type == 'artisan_approval';

        // محاولة إضافية للتعرف على شات الدعم من الـ conversationId أو المحتوى
        if (!isAdminType && type == 'chat' && conversationId != null) {
          if (conversationId.contains(FirebaseConstants.supportId)) {
            isAdminType = true;
          }
        }

        if (!isAdminType) {
          // تحسين إضافي: أي رسائل تأتي لـ technical_support هي بالضرورة تخص الإدارة
          if (isSupportTarget) {
            isAdminType = true;
          } else {
            debugPrint('🚫 Silencing non-admin Push for Admin Identity: $targetUserId (Type: $type)');
            return;
          }
        }
        
        if (isAdminType) {
          debugPrint('🚀 Admin Push Approved for $targetUserId (Type: $type)');
        }
      }

      // جلب العدد المحدث للإرسال في البادج (بشكل مستقل عن الباتش السابق لضمان الدقة)
      int newCount = 0;
      try {
        final updatedUserDoc = await userRef.get();
        final num rawCount = updatedUserDoc.data()?['unreadNotificationsCount'] ?? 0;
        newCount = rawCount.toInt();
      } catch (e) {
         debugPrint('⚠️ Could not fetch updated count for badge: $e');
      }

      // ── بث الإشعارات (External Pushes) ──────────────────────────────
      if (allTokens.isEmpty) {
        debugPrint('⚠️ No valid FCM tokens found for $targetUserId - Skipping external push');
        return;
      }

      debugPrint('🚀 Starting FCM Broadcast to ${allTokens.length} tokens for $targetUserId');

      for (final String t in allTokens) {
        try {
          await sendToToken(
            fcmToken: t,
            title: title,
            body: body,
            badge: newCount,
            data: data,
          );
        } catch (e) {
          debugPrint('⚠️ Error sending to specific token in broadcast: $e');
        }
      }
    } catch (e) {
      print('sendToUser Error: $e');
    }
  }

  // ── إرسال لكل الحرفيين بتخصص معين (مع فلترة جغرافية) ──────────────────
  Future<void> sendToArtisansBySpecialty({
    required String specialty,
    required String title,
    required String body,
    double? clientLat,
    double? clientLng,
    Map<String, String>? data,
  }) async {
    // نطاق الإشعار: 10 كيلومتر
    const double maxDistanceKm = NotificationConstants.artisanGeoRadiusKm;

    try {
      final collection = _firestore.collection(FirebaseConstants.usersCollection);
      List<DocumentSnapshot> targetDocs = [];

      // ── الفلترة الجغرافية باستخدام GeoFlutterFire Plus ─────────────────────────────────
      if (clientLat != null && clientLng != null) {
        final geoCenter = GeoFirePoint(GeoPoint(clientLat, clientLng));
        final geoRef = GeoCollectionReference<Map<String, dynamic>>(collection);
        
        targetDocs = await geoRef.subscribeWithin(
          center: geoCenter,
          radiusInKm: maxDistanceKm,
          field: 'geo',
          geopointFrom: (data) => (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
          queryBuilder: (query) => query
              .where('role', isEqualTo: FirebaseConstants.roleArtisan)
              .where('specialty', isEqualTo: specialty)
              .where('isActive', isEqualTo: true),
        ).first;
      } else {
        final querySnapshot = await collection
            .where('role', isEqualTo: FirebaseConstants.roleArtisan)
            .where('specialty', isEqualTo: specialty)
            .where('isActive', isEqualTo: true)
            .get();
        targetDocs = querySnapshot.docs;
      }

      for (final doc in targetDocs) {
        final artisanData = doc.data() as Map<String, dynamic>?;
        if (artisanData == null) continue;

        // نمر عبر نفس مسار الإرسال الموحّد لضمان ظهور Push خارجي
        // مع حفظ Document في notifications (category=order, isRead=false).
        await sendToUser(
          targetUserId: doc.id,
          title: title,
          body: body,
          data: {
            ...?data,
            'type': data?['type'] ?? NotificationConstants.typeNewPost,
          },
        );
      }
    } catch (e) {
      debugPrint('🚨 sendToArtisansBySpecialty Error: $e');
    }
  }

  String _resolveNotificationCategory(String? type) {
    switch (type) {
      case NotificationConstants.typeChat:
        return NotificationConstants.categoryChat;
      case NotificationConstants.typeNewPost:
      case NotificationConstants.typeServiceRequest:
      case NotificationConstants.typeRequestStatus:
      case NotificationConstants.typePostAccepted:
      case NotificationConstants.typePostDeclined:
      case NotificationConstants.typePostCompleted:
      case NotificationConstants.typeNewOffer:
      case NotificationConstants.typeOfferAccepted:
        return NotificationConstants.categoryOrder;
      default:
        return NotificationConstants.categoryAdmin;
    }
  }


  // ── إرسال إشعار لكل الأدمنز (تم توجيهه لحساب الإدارة المركزي) ────────────────
  Future<void> sendToAdmins({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // توجيه الإشعار لحساب الدعم المركزي بدلاً من الأدمنز كأفراد بناءً على طلبك
      await sendToUser(
        targetUserId: FirebaseConstants.supportId,
        title: title,
        body: body,
        data: {...?data, 'isAdmin': 'true'},
      );
    } catch (e) {
      debugPrint('🚨 sendToAdmins Error: $e');
    }
  }
  /// تنظيف توكين منتهي الصلاحية من قاعدة البيانات
  void _cleanupToken(String token) async {
    try {
      final supportRef = _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(FirebaseConstants.supportId);

      final doc = await supportRef.get();
      if (!doc.exists) return;
      
      final data = doc.data();
      final updates = <String, dynamic>{
        'fcmTokens': FieldValue.arrayRemove([token]),
      };
      
      // إذا كان التوكين الميت هو التوكين الأساسي للمستند، نقوم بمسحه أيضاً
      if (data?['fcmToken'] == token) {
        updates['fcmToken'] = FieldValue.delete();
      }

      await supportRef.update(updates);
      debugPrint('✅ Token cleaned up from support identity registry.');
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup token: $e');
    }
  }
}

/// مساعد خارجي لـ compute لتجنب مشاكل الـ UI thread
String _signJwt(Map<String, dynamic> params) {
  final jwt = JWT(params['payload']);
  return jwt.sign(
    RSAPrivateKey(params['privateKey']),
    algorithm: JWTAlgorithm.RS256,
  );
}
