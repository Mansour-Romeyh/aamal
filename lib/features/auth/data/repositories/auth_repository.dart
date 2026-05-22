import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/notification_service.dart';

/// مستودع التوثيق – يتعامل مع Firebase Auth و Firestore
class AuthRepository {
  static const String _prefKeyLastKnownUid = 'auth_last_known_good_uid';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// آخر uid نجح تسجيل دخول/استعادة — لمساعدة الأندرويد على عدم قبول الخروج مبكرًا
  Future<void> persistLastKnownUid(String uid) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKeyLastKnownUid, uid);
  }

  Future<String?> readLastKnownUid() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefKeyLastKnownUid);
  }

  Future<void> clearLastKnownUid() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefKeyLastKnownUid);
  }

  /// المستخدم الحالي من Firebase Auth
  User? get currentFirebaseUser => _auth.currentUser;

  /// Stream لحالة التوثيق
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// يعيد مستخدم Firebase بعد تحمّل التخزين المحلي؛ يتجنّب اعتبار الجلسة مفقودة
  /// لو وصلنا لحديث "[غير مسجّل]" قبل أن يعبّئ التخزين المحلي الحساب.
  Future<User?> restorePersistedFirebaseUser({
    Duration timeout = NotificationConstants.authRestoreTimeout,
  }) async {
    User? u = currentFirebaseUser;
    if (u != null) return u;

    final completer = Completer<User?>();
    Timer? stabilizeNullTimer;
    Timer? watchdog;
    StreamSubscription<User?>? subscription;
    var disposed = false;

    void dispose() {
      if (disposed) return;
      disposed = true;
      stabilizeNullTimer?.cancel();
      watchdog?.cancel();
      subscription?.cancel();
    }

    void seal(User? value) {
      if (!completer.isCompleted) completer.complete(value);
      dispose();
    }

    subscription = authStateChanges.listen((User? authUser) {
      stabilizeNullTimer?.cancel();

      final synced = authUser ?? currentFirebaseUser;
      if (synced != null) {
        seal(synced);
        return;
      }

      // أطول قليلاً على أندرويد: استعادة المفتاح المحلي للجلسة قد تتجاوز ثانية واحدة
      stabilizeNullTimer = Timer(const Duration(milliseconds: 2400), () {
        seal(currentFirebaseUser);
      });
    });

    watchdog = Timer(timeout, () {
      seal(currentFirebaseUser);
    });

    User? resolved;
    try {
      resolved = await completer.future;
    } finally {
      dispose();
    }

    resolved ??= currentFirebaseUser;

    final tailEnd = DateTime.now().add(const Duration(milliseconds: 5500));
    while (resolved == null && DateTime.now().isBefore(tailEnd)) {
      await Future.delayed(const Duration(milliseconds: 120));
      resolved = currentFirebaseUser;
    }

    return resolved;
  }

  // ── التحقق من وجود الحساب ────────────────────────────────────
  Future<bool> checkUserExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── تسجيل حساب جديد ──────────────────────────────────────────
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    String specialty = '',
    String bio = '',
    String address = '',
    double? latitude,
    double? longitude,
    List<String> portfolioImages = const [],
    String profileImage = '',
    String idCardImage = '',
    String selfieImage = '',
  }) async {
    // إنشاء الحساب في Firebase Auth
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;

    // إنشاء نموذج المستخدم
    final userModel = UserModel(
      uid: user.uid,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      specialty: specialty,
      bio: bio,
      address: address,
      latitude: latitude,
      longitude: longitude,
      portfolioImages: portfolioImages,
      profileImage: profileImage,
      idCardImage: idCardImage,
      selfieImage: selfieImage,
      // الحرفي يبدأ بحالة "قيد الانتظار"، العميل يبدأ بـ "موافق عليه"
      approvalStatus: role == FirebaseConstants.roleArtisan ? 'pending' : 'approved',
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(user.uid)
        .set(userModel.toMap());

    // إخطار المسؤولين بطلب انضمام حرفي جديد
    if (role == FirebaseConstants.roleArtisan) {
      NotificationService.instance.sendNotificationToAdmins(
        title: 'طلب توثيق جديد',
        body: 'قام الحرفي $name بالتسجيل، يرجى مراجعة البيانات للتوثيق.',
        data: {
          'type': 'artisan_approval',
          'artisanId': user.uid,
          'artisanName': name,
        },
      );
    }

    // إرسال رسالة التفعيل للإيميلات الحقيقية فقط
    if (!email.trim().endsWith('@works.com')) {
      await user.sendEmailVerification();
    }

    return userModel;
  }

  // ── تسجيل الدخول ──────────────────────────────────────────────
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;

    // التحقق من تفعيل البريد الإلكتروني (للحسابات التي سجلت بإيميل حقيقي فقط)
    if (!user.emailVerified &&
        user.email != null &&
        !user.email!.endsWith('@works.com')) {
      await user.sendEmailVerification(); // إعادة الإرسال في حال لم يصله
      await _auth.signOut();
      throw Exception('email-not-verified');
    }

    return await getUserById(user.uid);
  }

  // ── تسجيل الخروج ─────────────────────────────────────────────
  Future<void> logout() async {
    await clearLastKnownUid();
    await _auth.signOut();
  }

  // ── جلب بيانات المستخدم ───────────────────────────────────────
  Future<UserModel> getUserById(String uid) async {
    Future<DocumentSnapshot<Map<String, dynamic>>> fetchDoc(GetOptions opts) {
      return _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(uid)
          .get(opts);
    }

    DocumentSnapshot<Map<String, dynamic>> doc;

    try {
      doc = await fetchDoc(const GetOptions(source: Source.server)).timeout(
        const Duration(seconds: 14),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        '⚠️ getUserById: Firebase على السيرفر (${e.code}) → محاولة كاش',
      );
      doc = await fetchDoc(const GetOptions(source: Source.cache));
      if ((!doc.exists || doc.data() == null) && e.code == 'permission-denied') {
        throw Exception('firestore-permission-denied');
      }
    } catch (e) {
      debugPrint(
        '⚠️ getUserById: السيرفر غير متاح أو مهلة الزمن انتهت ($e) → كاش محلي',
      );
      doc = await fetchDoc(const GetOptions(source: Source.cache));
    }

    if (doc.exists && doc.data() != null) {
      return UserModel.fromFirestore(doc);
    }

    final cacheDoc = await fetchDoc(const GetOptions(source: Source.cache));
    if (cacheDoc.exists && cacheDoc.data() != null) {
      return UserModel.fromFirestore(cacheDoc);
    }

    throw Exception('المستخدم غير موجود');
  }

  /// Stream لبيانات المستخدم من Firestore للتحديث اللحظي للـ Badge وغيره
  Stream<UserModel> getUserStream(String uid) {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .snapshots(includeMetadataChanges: false)
        .map((doc) {
          if (!doc.exists) throw Exception('المستخدم غير موجود');
          return UserModel.fromFirestore(doc);
        });
  }

  /// Stream مخصص للعدّاد فقط (يتجاهل بقية البيانات لتسريع الأداء ومنع الـ Freeze)
  Stream<int> getNotificationCountStream(String uid) {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .snapshots(includeMetadataChanges: false)
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          return (data?['unreadNotificationsCount'] ?? 0) as int;
        })
        .distinct(); // لا يبعث إشارة إلا إذا تغير الرقم فعلياً
  }

  /// Stream مجمع للأدمن يجمع بين عداد الإشعارات الشخصية وعداد الدعم المركزي
  Stream<int> getAdminCombinedNotificationCountStream(String uid) {
    if (uid == FirebaseConstants.supportId) {
      return getNotificationCountStream(uid);
    }

    final controller = StreamController<int>.broadcast();
    int personalCount = 0;
    int supportCount = 0;

    void updateSum() {
      if (!controller.isClosed) {
        controller.add(personalCount + supportCount);
      }
    }

    // جلب القيم الحالية فوراً لضمان تحميل الجرس لحظياً عند فتح التطبيق
    _firestore.collection(FirebaseConstants.usersCollection).doc(uid).get().then((doc) {
      if (doc.exists) {
        personalCount = (doc.data()?['unreadNotificationsCount'] ?? 0) as int;
        updateSum();
      }
    });
    
    _firestore.collection(FirebaseConstants.usersCollection).doc(FirebaseConstants.supportId).get().then((doc) {
      if (doc.exists) {
        supportCount = (doc.data()?['unreadNotificationsCount'] ?? 0) as int;
        updateSum();
      }
    });

    final s1 = getNotificationCountStream(uid).listen((c) {
      personalCount = c;
      updateSum();
    }, onError: (e) => debugPrint('❌ Error in combined stream (personal): $e'));

    final s2 = getNotificationCountStream(FirebaseConstants.supportId).listen((c) {
      supportCount = c;
      updateSum();
    }, onError: (e) => debugPrint('❌ Error in combined stream (support): $e'));

    controller.onCancel = () {
      s1.cancel();
      s2.cancel();
    };

    return controller.stream.distinct();
  }

  // ── تحديث بيانات المستخدم ─────────────────────────────────────
  Future<void> updateUser(UserModel user) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(user.uid)
        .update(user.toMap());
  }

  // ── تحديث الـ FCM Token ───────────────────────────────────────
  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .update({'fcmToken': token});
  }

  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  // ── جلب الحرفيين في نطاق جغرافي ──────────────────────────────
  Stream<List<UserModel>> getArtisansWithinRadius({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    String? specialty,
  }) {
    final collection = _firestore.collection(FirebaseConstants.usersCollection);
    final geoCenter = GeoFirePoint(GeoPoint(centerLat, centerLng));
    
    return GeoCollectionReference<Map<String, dynamic>>(collection).subscribeWithin(
      center: geoCenter,
      radiusInKm: radiusKm,
      field: 'geo',
      geopointFrom: (data) => (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
      queryBuilder: (query) {
        var q = query
            .where('role', isEqualTo: FirebaseConstants.roleArtisan)
            .where('isActive', isEqualTo: true)
            .where('approvalStatus', isEqualTo: 'approved');

        if (specialty != null && specialty.isNotEmpty && specialty != 'الكل') {
          q = q.where('specialty', isEqualTo: specialty);
        }
        return q;
      },
    ).map((list) {
      return list.map((doc) => UserModel.fromFirestore(doc)).toList();
    }).handleError((e) {
      debugPrint('❌ Error in getArtisansWithinRadius stream: $e');
    });
  }

  // ── جلب الحرفيين مع خيارات الفلترة والترتيب ──────────────────────
  Stream<List<UserModel>> getArtisansStream({
    String? specialty,
    bool sortByRating = false,
  }) {
    Query query = _firestore
        .collection(FirebaseConstants.usersCollection)
        .where('role', isEqualTo: FirebaseConstants.roleArtisan)
        .where('isActive', isEqualTo: true)
        .where('approvalStatus', isEqualTo: 'approved'); // فقط الحرفيين المقبولين

    if (specialty != null && specialty.isNotEmpty && specialty != 'الكل') {
      query = query.where('specialty', isEqualTo: specialty);
    }

    if (sortByRating) {
      query = query.orderBy('rating', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
    ).handleError((e) {
      debugPrint('❌ Error in getArtisansStream: $e');
    });
  }

  // ── جلب التخصصات المتوفرة للحرفيين النشطين ──────────────────────
  Stream<List<String>> getActiveArtisanSpecialtiesStream() {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .where('role', isEqualTo: FirebaseConstants.roleArtisan)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data()['specialty'] as String?)
              .where((s) => s != null && s.isNotEmpty)
              .cast<String>()
              .toSet()
              .toList();
        });
  }

  // ── تفعيل/تعطيل المستخدم (للأدمن) ────────────────────────────
  Future<void> toggleUserActive(String uid, bool isActive) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .update({'isActive': isActive});
  }

  // ── تحديث حالة الموافقة (للأدمن) ────────────────────────────
  Future<void> updateApprovalStatus(String uid, String status) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .update({
          'approvalStatus': status,
          'isVerified': status == 'approved' ? true : false,
        });

    // إرسال إشعار للحرفي
    final title = status == 'approved' ? 'تم قبول طلب توثيقك' : 'تم رفض طلب توثيقك';
    final body = status == 'approved'
        ? 'تهانينا! تم قبول طلب توثيقك كحرفي في منصة وركرز'
        : 'نأسف، تم رفض طلب توثيقك. يمكنك تقديم طلب جديد بعد مراجعة المستندات.';

    await NotificationService.instance.sendNotificationToUser(
      targetUserId: uid,
      title: title,
      body: body,
      data: {'type': 'artisan_approval'},
    );
  }

  // ── توثيق الحساب (للأدمن) ────────────────────────────
  Future<void> toggleUserVerified(String uid, bool isVerified) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .update({
          'isVerified': isVerified,
          'approvalStatus': isVerified ? 'approved' : 'pending',
        });
  }

  // ── تحديث دور المستخدم (للأدمن) ────────────────────────────
  Future<void> updateUserRole(String uid, String newRole) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .update({'role': newRole});
  }

  // ── إعادة تعيين كلمة المرور ───────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── تحديث حالة المتصل ──────────────────────────────────────────
  Future<void> updateUserOnlineStatus(String uid, bool isOnline) async {
    if (uid == FirebaseConstants.supportId) return;
    try {
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(uid)
          .update({
            'isOnline': isOnline,
            'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
          });
      debugPrint('🟢 User $uid Online Status Updated: $isOnline');
    } catch (e) {
      debugPrint('❌ Error updating online status: $e');
    }
  }

  // ── تصفير عداد الإشعارات ──────────────────────────────────────────
  Future<void> resetUnreadNotificationsCount(String uid, {String? conversationId}) async {
    try {
      if (conversationId == null) {
        // تفجير شامل: تصفير كل شيء (للحالات العامة)
        await _firestore
            .collection(FirebaseConstants.usersCollection)
            .doc(uid)
            .update({'unreadNotificationsCount': 0});
            
        // اختيارياً: مارك كل الإشعارات كمقروءة في قاعدة البيانات لإبقاء المزامنة
        final unreadNotifs = await _firestore.collection('notifications')
            .where('targetUserId', isEqualTo: uid)
            .where('isRead', isEqualTo: false)
            .get();
            
        if (unreadNotifs.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in unreadNotifs.docs) {
            batch.update(doc.reference, {'isRead': true, 'readAt': FieldValue.serverTimestamp()});
          }
          await batch.commit();
        }
      } else {
        // تصفير ذكي: فقط للمحادثة الحالية
        final unreadNotifs = await _firestore.collection('notifications')
            .where('targetUserId', isEqualTo: uid)
            .where('data.conversationId', isEqualTo: conversationId)
            .where('isRead', isEqualTo: false)
            .get();

        if (unreadNotifs.docs.isNotEmpty) {
          final countToDecrement = unreadNotifs.docs.length;
          final batch = _firestore.batch();
          
          // 1. تحديث الإشعارات الفردية
          for (var doc in unreadNotifs.docs) {
            batch.update(doc.reference, {'isRead': true, 'readAt': FieldValue.serverTimestamp()});
          }
          
          // 2. تحديث العداد الإجمالي للمستخدم
          final userRef = _firestore.collection(FirebaseConstants.usersCollection).doc(uid);
          batch.update(userRef, {
            'unreadNotificationsCount': FieldValue.increment(-countToDecrement)
          });
          
          await batch.commit();
          debugPrint('🧹 Cleaned up $countToDecrement notifications for conversation: $conversationId');
        }
      }
    } catch (e) {
      debugPrint('❌ Error in resetUnreadNotificationsCount: $e');
    }
  }

  /// تحديث معرف المحادثة النشطة حالياً (لكتم الجرس)
  Future<void> updateActiveChatId(String uid, String? chatId, {bool isSupport = false, String? sessionId}) async {
    try {
      final batch = _firestore.batch();
      
      // 1. تحديث المستخدم الشخصي (لكتم الجرس الشخصي)
      final userRef = _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(uid);
      batch.set(userRef, {'activeChatId': chatId}, SetOptions(merge: true));
      
      // 2. إذا كانت محادثة دعم، نحدث الحقل في حساب الدعم المركزي نفسه (ألية عمل الحرفي والعميل)
      if (isSupport) {
        final supportRef = _firestore
            .collection(FirebaseConstants.usersCollection)
            .doc(FirebaseConstants.supportId);
            
        // في النظام المبسط المشترك، نستخدم حقل واحد للدردشة النشطة للإدارة ككل
        batch.set(supportRef, {
          'activeChatId': chatId,
          'lastSeen': FieldValue.serverTimestamp(),
          'lastPresenceUpdate': FieldValue.serverTimestamp(), // ختم زمني مخصص للتواجد
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
      debugPrint('🔔 Admin Shared Presence ${chatId != null ? 'Updated to $chatId' : 'Cleared'}');
    } catch (e) {
      debugPrint('❌ Error updating active chat ID: $e');
    }
  }

  /// حذف محادثة معينة من قائمة النشط في الدعم (عند الخروج)
  Future<void> removeActiveSupportChat(String chatId, {String? adminUid}) async {
    try {
      final supportRef = _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(FirebaseConstants.supportId);
      
      // في النظام المبسط، يكفي تصفير المحادثة النشطة
      await supportRef.update({
        'activeChatId': null,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      debugPrint('🧹 Admin Shared Presence CLEARED from $chatId');
    } catch (e) {
      debugPrint('❌ Error removing active support chat: $e');
    }
  }

  // ── تهيئة حساب الدعم الفني المركزي ─────────────────────────────────────
  Future<void> setupSupportAccount(String? fcmToken) async {
    final doc = await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(FirebaseConstants.supportId)
        .get();

    if (!doc.exists) {
      // إنشاء الحساب لو مش موجود
      final supportUser = UserModel(
        uid: FirebaseConstants.supportId,
        name: 'الدعم الفني والادارة',
        email: 'support@works.com',
        role: 'admin',
        isActive: true,
        fcmToken: fcmToken ?? '',
        createdAt: DateTime.now(),
      );
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(FirebaseConstants.supportId)
          .set(supportUser.toMap());
      debugPrint('✅ Support account created for notifications.');
    } else if (fcmToken != null && fcmToken.isNotEmpty) {
      // تحديث الـ Token للجهاز الحالي عشان يستلم إشعارات (فقط لو الـ token حقيقي)
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(FirebaseConstants.supportId)
          .update({'fcmToken': fcmToken});
      debugPrint(
        '✅ Support account FCM token updated: ${fcmToken.substring(0, 8)}...',
      );
    }
  }

  // ── جلب حساب مدير للدعم الفني ──────────────────────────────
  Future<UserModel?> getSupportAdmin([String? excludeUserId]) async {
    try {
      // محاولة 1: البحث عن دور admin
      var query = _firestore
          .collection(FirebaseConstants.usersCollection)
          .where('role', isEqualTo: 'admin')
          .limit(5); // جلب أول 5 للمفاضلة

      var querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        // محاولة 2: البحث عن دور Admin (بجعل الحرف الأول كبيراً)
        querySnapshot = await _firestore
            .collection(FirebaseConstants.usersCollection)
            .where('role', isEqualTo: 'Admin')
            .limit(5)
            .get();
      }

      if (querySnapshot.docs.isNotEmpty) {
        final admins = querySnapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .where(
              (u) => u.uid != excludeUserId,
            ) // استبعاد المستخدم الحالي إذا كان أدمن
            .toList();

        if (admins.isNotEmpty) return admins.first;
      }

      // محاولة 3: البحث عن أي مستخدم بكلمة admin في الإيميل (حل أخير)
      final fallbackSnapshot = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where('email', isGreaterThanOrEqualTo: 'admin')
          .where('email', isLessThanOrEqualTo: 'admin')
          .limit(1)
          .get();

      if (fallbackSnapshot.docs.isNotEmpty) {
        final admin = UserModel.fromFirestore(fallbackSnapshot.docs.first);
        if (admin.uid != excludeUserId) return admin;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting support admin: $e');
      return null;
    }
  }

  // ── تحديث معرض أعمال الحرفي ──────────────────────────────────────────
  Future<void> updatePortfolioImages(String uid, List<String> images) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .update({'portfolioImages': images});
  }

  // ── تحديث رقم الهاتف ──────────────────────────────────────────────────
  Future<void> updateUserPhone(String uid, String newPhone, String newEmail) async {
    await _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(uid)
        .update({
          'phone': newPhone,
          'email': newEmail,
        });
  }

  /// تهيئة الحرفيين القدامى بـ GeoHash (للمرة الأولى فقط)
  Future<void> migrateGeoHashes() async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where('role', isEqualTo: FirebaseConstants.roleArtisan)
          .get();

      final batch = _firestore.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['latitude'] != null && data['longitude'] != null && data['geo'] == null) {
          final lat = (data['latitude'] as num).toDouble();
          final lng = (data['longitude'] as num).toDouble();
          final geo = GeoFirePoint(GeoPoint(lat, lng)).data;
          batch.update(doc.reference, {'geo': geo});
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
        debugPrint('✅ Migrated $count artisans to GeoHash.');
      }
    } catch (e) {
      debugPrint('❌ Error migrating GeoHashes: $e');
    }
  }
}
