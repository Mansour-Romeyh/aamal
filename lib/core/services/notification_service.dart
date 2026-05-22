import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/router/app_router.dart';
import '../../app/di/injection_container.dart';
import '../../../features/auth/presentation/bloc/auth_cubit.dart';
import '../constants/firebase_constants.dart';
import 'fcm_direct_service.dart';

/// معالج الإشعارات في الخلفية (يجب أن يكون top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // في الخلفية لا يمكن استخدام الـ singleton مباشرة،
  // يتولى FCM عرض الإشعار تلقائياً لأن الـ notification payload موجود
  // لكن لو كانت الرسالة data-only نحتاج نعرض إشعار محلي يدوياً
  if (message.notification == null && message.data.isNotEmpty) {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    final badgeString = message.data['badge'];
    final badgeCount = int.tryParse(badgeString ?? '') ?? 0;

    await plugin.show(
      message.hashCode,
      message.data['title'] ?? 'إشعار جديد',
      message.data['body'] ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'workers_channel',
          'إشعارات وركرز',
          importance: Importance.high,
          priority: Priority.high,
          number: badgeCount > 0 ? badgeCount : null,
        ),
      ),
    );
  }
}

/// خدمة الإشعارات – FCM + إشعارات محلية
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// معرف المحادثة المفتوحة حالياً (لكتم إشعاراتها)
  String? currentOpenedChatId;

  bool _isInitialized = false;
  bool _isInitializing = false;

  // ── تهيئة الخدمة ──────────────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      // طلب إذن الإشعارات - مع قفل زمني لضمان عدم التعليق
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      ).timeout(const Duration(seconds: 2));

      await _completeSetup();
      _isInitialized = true;
      debugPrint('🔔 Notification Service: Initialization complete');
    } catch (e) {
      debugPrint('⚠️ Notification Service: Initialization timed out or failed: $e');
      // نفشل بصمت لضمان عدم تعليق التطبيق
    } finally {
      _isInitializing = false;
    }
  }

  // ── إكمال الإعداد بعد الموافقة ────────────────────────────────────
  Future<void> _completeSetup() async {
    try {
      // الحصول على الـ FCM Token - هذا هو المكان الأخطر للـ Hang
      _fcmToken = await _messaging.getToken().timeout(const Duration(seconds: 5));
      debugPrint('--- 🔔 NOTIFICATION SERVICE TOKEN FETCHED: $_fcmToken ---');

      // إعداد الإشعارات المحلية والطلب الصريح للأندرويد 13+
      await _setupLocalNotifications().timeout(const Duration(seconds: 2));

      // الاستماع للإشعارات
      _setupMessageListeners();

      // حفظ الـ Token لو المستخدم مسجل دخول بالفعل
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        saveTokenToFirestore(currentUserId); // لا نستخدم await هنا لسرعة الأداء
      }

      // الاستماع لتحديث الـ Token
      _messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          saveTokenToFirestore(userId);
        }
      });
    } catch (e) {
      debugPrint('⚠️ Notification Setup Trace: $e');
    }
  }

  // ── إعداد الإشعارات المحلية ───────────────────────────────────
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // طلب إذن الصريح للأندرويد 13+ (POST_NOTIFICATIONS)
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    // إنشاء قناة إشعارات للأندرويد
    const androidChannel = AndroidNotificationChannel(
      'workers_channel',
      'إشعارات وركرز',
      description: 'إشعارات تطبيق وركرز',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  // ── الاستماع للإشعارات ────────────────────────────────────────
  void _setupMessageListeners() {
    // إشعار أثناء فتح التطبيق (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(
        message,
      ); // استدعاء غير بّلوك (Non-blocking) لتجنب الـ UI Freeze
    });

    // الضغط على الإشعار وفتح التطبيق
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message);
    });
  }

  // ── عرض إشعار محلي ────────────────────────────────────────────
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // استخراج معلومات الرسالة من الـ data (لدعم الـ Data-only messages)
    final title = message.data['title'] ?? message.notification?.title;
    final body = message.data['body'] ?? message.notification?.body;

    if (title == null) return;

    // استخراج معلومات الدردشة
    final type = message.data['type'];
    final conversationId = message.data['conversationId'];

    // ── فلترة الإشعارات للمسؤولين ───────────────────────────────────
    final authState = sl<AuthCubit>().state;
    if (authState is AuthAuthenticated && authState.user.isAdmin) {
      final isAdminFlag =
          message.data['isSupport'] == 'true' ||
          message.data['isAdmin'] == 'true';
      bool isAdminType =
          type == 'report' ||
          type == 'support' ||
          type == 'admin_action' ||
          type == 'artisan_approval' ||
          isAdminFlag;
      if (type == 'chat' && conversationId != null) {
        if (conversationId.contains(FirebaseConstants.supportId) ||
            isAdminFlag) {
          isAdminType = true;
        }
      }

      if (!isAdminType) {
        debugPrint(
          '🔇 Muting local user-level notification for Admin (Type: $type)',
        );
        return;
      }
    }

    // إذا كانت رسالة شات والمحادثة مفتوحة حالياً، لا نعرض إشعاراً (هذا ما طلبه المستخدم بدقة)
    if (type == 'chat' &&
        conversationId != null &&
        conversationId == currentOpenedChatId) {
      debugPrint('🔇 Muting notification for active chat: $conversationId');
      return;
    }

    // استخراج عدد الإشعارات من الـ data لتحديث الـ Badge
    final badgeString = message.data['badge'];
    final badgeCount = int.tryParse(badgeString ?? '') ?? 0;

    final androidDetails = AndroidNotificationDetails(
      'workers_channel',
      'إشعارات وركرز',
      channelDescription: 'إشعارات تطبيق وركرز',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      number: badgeCount > 0 ? badgeCount : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode, // استخدام hashCode للرسالة كمعرف
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  // ── التعامل مع الضغط على الإشعار ─────────────────────────────
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleDataNavigation(data);
      } catch (e) {
        // Handle decode error
      }
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    _handleDataNavigation(message.data);
  }

  void _handleDataNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final postId = data['postId'] as String?;
    final conversationId = data['conversationId'] as String?;
    final isDirectRequest = data['isDirectRequest'] == 'true';

    if (type == 'chat') {
      if (conversationId != null) {
        // تحديد الوضع (أدمن أو دعم) بناءً على بيانات الإشعار أولاً ثم حالة التوثيق
        // هذا يضمن فتح الوضع الصحيح حتى لو لم تكن حالة التوثيق جاهزة بعد (Cold Start)
        final isAdminFlag = data['isAdmin'] == 'true' || data['isSupport'] == 'true';
        final isSupportFlag = data['isSupport'] == 'true' || conversationId.contains(FirebaseConstants.supportId);
        
        final user = sl<AuthCubit>().state is AuthAuthenticated
            ? (sl<AuthCubit>().state as AuthAuthenticated).user
            : null;

        AppRouter.router.push(
          '/chat-room/$conversationId',
          extra: {
            'name': data['senderName'] ?? 'محادثة',
            'id': data['senderId'] ?? '',
            'isAdminView': isAdminFlag || (user?.isAdmin ?? false),
            'isSupportView': isSupportFlag || ((user?.isAdmin ?? false) && conversationId.contains(FirebaseConstants.supportId)),
          },
        );
      }
    } else if (type == 'artisan_approval') {
      // التوجيه لتبويب "طلبات التوثيق" (الاندكس رقم 8)
      AppRouter.router.push('/admin?tab=8');
    } else if (type == 'report' || type == 'admin_action') {
      // التوجيه لتبويب "البلاغات" (الاندكس رقم 6)
      AppRouter.router.push('/admin?tab=6');
    } else if (postId != null) {
      // Navigate to post details with ID via query parameter
      String path = '/post-details?postId=$postId';
      if (isDirectRequest) {
        path += '&isDirectRequest=true';
      }
      AppRouter.router.push(path);
    } else {
      // Fallback to notifications list
      AppRouter.router.push('/notifications');
    }
  }

  // ── حفظ الـ Token في Firestore ────────────────────────────────
  Future<void> saveTokenToFirestore(String userId) async {
    if (_fcmToken == null) return;

    final batch = _firestore.batch();

    // 1. تحديث توكن المستخدم الشخصي (استخدام set مع merge أضمن من update)
    final userRef = _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userId);
    batch.set(userRef, {'fcmToken': _fcmToken}, SetOptions(merge: true));

    // 2. إذا كان المستخدم أدمن، نربط جهازه بالحساب المركزي لاستقبال التنبيهات الإدارية
    try {
      final userDoc = await userRef.get();
      // لو الحساب نفسه هو حساب الدعم المركزي، نحدث قائمة التوكنز مباشرة
      if (userId == FirebaseConstants.supportId) {
        batch.set(userRef, {
          'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
          'role': FirebaseConstants.roleAdmin, // تأمين وجود الرتبة
        }, SetOptions(merge: true));
      } else if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final role = (userData['role'] ?? '').toString().toLowerCase();
        if (role == FirebaseConstants.roleAdmin) {
          final supportRef = _firestore
              .collection(FirebaseConstants.usersCollection)
              .doc(FirebaseConstants.supportId);
          batch.set(supportRef, {
            'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
            'role': FirebaseConstants.roleAdmin, // تأمين وجود الرتبة دائماً
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint(
        '⚠️ Non-critical: Failed to sync token with support identity: $e',
      );
    }

    await batch.commit();
  }

  // ── إزالة التوكن عند تسجيل الخروج (للأدمن) ─────────────────────────
  Future<void> removeTokenFollowingLogout(String userId) async {
    if (_fcmToken == null) return;
    try {
      final userRef = _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['role'] == FirebaseConstants.roleAdmin) {
          await _firestore
              .collection(FirebaseConstants.usersCollection)
              .doc(FirebaseConstants.supportId)
              .update({
                'fcmTokens': FieldValue.arrayRemove([_fcmToken]),
              });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to remove token from support: $e');
    }
  }

  // ── إرسال إشعار لمستخدم ──────────────────────────────────────────
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // إرسال مباشر عبر FCM HTTP v1 API - بدون Cloud Functions
    await FcmDirectService.instance.sendToUser(
      targetUserId: targetUserId,
      title: title,
      body: body,
      data: data?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  // ── إرسال إشعار لكل الأدمنز ──────────────────────────────────────────
  Future<void> sendNotificationToAdmins({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await FcmDirectService.instance.sendToAdmins(
      title: title,
      body: body,
      data: data?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  // ── إرسال إشعار لمجموعة حرفيين بنفس التخصص ──────────────────
  Future<void> notifyArtisansBySpecialty({
    required String specialty,
    required String title,
    required String body,
    double? clientLat,
    double? clientLng,
    Map<String, dynamic>? data,
  }) async {
    await FcmDirectService.instance.sendToArtisansBySpecialty(
      specialty: specialty,
      title: title,
      body: body,
      clientLat: clientLat,
      clientLng: clientLng,
      data: data?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  // ── الاشتراك في topic حسب التخصص ─────────────────────────────
  Future<void> subscribeToSpecialty(String specialty) async {
    final cleanSpecialty = specialty.replaceAll(' ', '_');
    final topicName = Uri.encodeComponent(cleanSpecialty);
    await _messaging.subscribeToTopic(topicName);
  }

  Future<void> unsubscribeFromSpecialty(String specialty) async {
    final cleanSpecialty = specialty.replaceAll(' ', '_');
    final topicName = Uri.encodeComponent(cleanSpecialty);
    await _messaging.unsubscribeFromTopic(topicName);
  }

  // ── تسيفر الـ Badge ─────────────────────────────────────────────
  Future<void> resetBadgeCount(String userId) async {
    // تصفير في الفايرستور (الـ Badge الخارجي يتم تصفيره تلقائياً عند قراءة الإشعارات في معظم الأنظمة)
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userId)
        .update({'unreadNotificationsCount': 0});
  }
}
