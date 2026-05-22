import 'dart:async';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/cloudinary_service.dart';

import '../../../../core/constants/firebase_constants.dart';

part 'auth_state.dart';

/// Cubit لإدارة حالة التوثيق
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final CloudinaryService _cloudinaryService;
  StreamSubscription<UserModel>? _userSubscription;
  late final String sessionId; // معرف فريد لهذه الجلسة

  /// اكتمال أول تشغيل لـ checkAuthStatus (يشمل كل المسارات وحتى الخطأ)
  bool _authBootstrapComplete = false;
  bool get hasCompletedAuthBootstrap => _authBootstrapComplete;

  AuthCubit({
    required AuthRepository authRepository,
    required CloudinaryService cloudinaryService,
  }) : _authRepository = authRepository,
       _cloudinaryService = cloudinaryService,
       super(const AuthInitial()) {
    sessionId =
        'session_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(this)}';
  }

  // ── الاستماع لتغييرات بيانات المستخدم ────────────────────────────
  void _startUserSubscription(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _authRepository
        .getUserStream(uid)
        .listen(
          (user) {
            // فحص ذكي: هل فيه تغيير حقيقي في البيانات يستدعي تحديث الواجهة؟
            // نتجاوز التحديث لو التغيير في الـ isOnline أو الـ lastSeen أو الـ activeChatId
            final currentState = state;
            if (currentState is AuthAuthenticated) {
              final oldUser = currentState.user;
              final hasRealChange =
                  oldUser.name != user.name ||
                  oldUser.email != user.email ||
                  oldUser.role != user.role ||
                  oldUser.unreadNotificationsCount !=
                      user.unreadNotificationsCount ||
                  oldUser.profileImage != user.profileImage ||
                  oldUser.isActive != user.isActive ||
                  oldUser.phone != user.phone ||
                  oldUser.portfolioImages.length != user.portfolioImages.length;

              if (!hasRealChange) return;
            }

            debugPrint('🔔 Valid UI state update for UID=${user.uid}');
            emit(AuthAuthenticated(user: user, lastUpdate: DateTime.now()));
          },
          onError: (e) {
            debugPrint('❌ User Stream Error: $e');
          },
        );
  }

  // ── تسجيل حساب جديد - خطوة 1: إرسال الـ OTP ──────────────────
  Future<void> sendOtpForRegistration({
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
    List<File> portfolioImages = const [],
    File? profileImage,
    File? idCardImage,
    File? selfieImage,
  }) async {
    emit(const AuthLoading());
    try {
      // 1. التحقق من أن الحساب غير مسجل مسبقاً
      final exists = await _authRepository.checkUserExists(email);
      if (exists) {
        emit(
          const AuthError(
            message: 'البريد الإلكتروني أو رقم الهاتف مسجل مسبقاً لحساب آخر.',
          ),
        );
        return;
      }

      // تجهيز البيانات المؤقتة
      final pendingData = {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
        'specialty': specialty,
        'bio': bio,
        'address': address,
        'latitude': latitude?.toString() ?? '',
        'longitude': longitude?.toString() ?? '',
      };

      if (phone.isEmpty) {
        // تسجيل مباشر للإيميل (بدون OTP لهاتف)
        String profileImageUrl = '';
        if (profileImage != null) {
          profileImageUrl = await _cloudinaryService.uploadImage(profileImage) ?? '';
        }

        String idCardUrl = '';
        if (idCardImage != null) {
          idCardUrl = await _cloudinaryService.uploadImage(idCardImage) ?? '';
        }

        String selfieUrl = '';
        if (selfieImage != null) {
          selfieUrl = await _cloudinaryService.uploadImage(selfieImage) ?? '';
        }

        List<String> portfolioUrls = [];
        if (role == 'artisan' && portfolioImages.isNotEmpty) {
          portfolioUrls = await _uploadPortfolio(portfolioImages);
        }

        final user = await _authRepository.register(
          name: name,
          email: email,
          password: password,
          phone: '',
          role: role,
          specialty: specialty,
          bio: bio,
          address: address,
          latitude: latitude,
          longitude: longitude,
          portfolioImages: portfolioUrls,
          profileImage: profileImageUrl,
          idCardImage: idCardUrl,
          selfieImage: selfieUrl,
        );

        final fcmToken = NotificationService.instance.fcmToken;
        if (fcmToken != null) {
          await _authRepository.updateFcmToken(user.uid, fcmToken);
        }

        if (role == 'artisan' && specialty.isNotEmpty) {
          await NotificationService.instance.subscribeToSpecialty(specialty);
        }
        await _authRepository.logout();

        emit(const AuthRegistrationSuccess());
        return;
      }

      // ── التجاوز لغرض التجربة (Bypass for testing) ──
      if (phone == '+201234567890') {
        debugPrint('🧪 Bypass triggered for number: $phone');
        
        String profileImageUrl = '';
        if (profileImage != null) {
          profileImageUrl = await _cloudinaryService.uploadImage(profileImage) ?? '';
        }

        String idCardUrl = '';
        if (idCardImage != null) {
          idCardUrl = await _cloudinaryService.uploadImage(idCardImage) ?? '';
        }

        String selfieUrl = '';
        if (selfieImage != null) {
          selfieUrl = await _cloudinaryService.uploadImage(selfieImage) ?? '';
        }

        // تسجيل مباشر بدون OTP
        final user = await _authRepository.register(
          name: name,
          email: email,
          password: password,
          phone: phone,
          role: role,
          specialty: specialty,
          bio: bio,
          address: address,
          latitude: latitude,
          longitude: longitude,
          portfolioImages: role == 'artisan'
              ? await _uploadPortfolio(portfolioImages)
              : [],
          profileImage: profileImageUrl,
          idCardImage: idCardUrl,
          selfieImage: selfieUrl,
        );

        final fcmToken = NotificationService.instance.fcmToken;
        if (fcmToken != null)
          await _authRepository.updateFcmToken(user.uid, fcmToken);
        if (role == 'artisan' && specialty.isNotEmpty)
          await NotificationService.instance.subscribeToSpecialty(specialty);

        await _authRepository.logout();
        emit(const AuthRegistrationSuccess());
        return;
      }

      // إرسال طلب التحقق عبر Firebase
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          emit(AuthError(message: _mapPhoneAuthError(e.code, e.message)));
        },
        codeSent: (String verificationId, int? resendToken) {
          emit(
            AuthOtpSent(
              expectedOtp: '',
              phone: phone,
              pinId: verificationId,
              pendingUserData: pendingData,
              pendingPortfolioImages: portfolioImages,
              pendingProfileImage: profileImage,
              pendingIdCardImage: idCardImage,
              pendingSelfieImage: selfieImage,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      debugPrint('❌ Registration Error: $e');
      emit(AuthError(message: 'حدث خطأ أثناء الاتصال: ${e.toString()}'));
    }
  }

  // ── تسجيل حساب جديد - خطوة 2: تأكيد الـ OTP وإنشاء الحساب ─────
  Future<void> verifyOtpAndRegister(
    String enteredOtp,
    String expectedOtp,
    Map<String, dynamic> pendingData,
    List<File> portfolioImages,
    File? profileImage,
  ) async {
    final authOtpSentState = state is AuthOtpSent ? state as AuthOtpSent : null;
    final pinId = authOtpSentState?.pinId;
    final idCardImage = authOtpSentState?.pendingIdCardImage;
    final selfieImage = authOtpSentState?.pendingSelfieImage;

    emit(const AuthLoading());
    try {
      // التحقق من صحة الرمز المدخل عبر خوادم Infobip
      if (pinId == null) {
        emit(const AuthError(message: 'معرف التحقق مفقود، يرجى إعادة طلب الرمز.'));
        return;
      }

      bool isApproved = false;
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: pinId,
          smsCode: enteredOtp,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        isApproved = true;
      } catch (e) {
        isApproved = false;
      }

      if (!isApproved) {
        emit(
          const AuthError(message: 'رمز التحقق غير صحيح أو منتهي الصلاحية.'),
        );
        emit(
          AuthOtpSent(
            expectedOtp: '',
            phone: pendingData['phone'],
            pinId: pinId,
            pendingUserData: pendingData,
            pendingPortfolioImages: portfolioImages,
            pendingProfileImage: profileImage,
            pendingIdCardImage: idCardImage,
            pendingSelfieImage: selfieImage,
          ),
        );
        return;
      }
      List<String> portfolioUrls = [];
      if (pendingData['role'] == 'artisan' && portfolioImages.isNotEmpty) {
        // رفع الصور أولاً
        portfolioUrls = await _uploadPortfolio(portfolioImages);
      }

      String profileImageUrl = '';
      if (profileImage != null) {
        profileImageUrl = await _cloudinaryService.uploadImage(profileImage) ?? '';
      }

      String idCardUrl = '';
      if (idCardImage != null) {
        idCardUrl = await _cloudinaryService.uploadImage(idCardImage) ?? '';
      }

      String selfieUrl = '';
      if (selfieImage != null) {
        selfieUrl = await _cloudinaryService.uploadImage(selfieImage) ?? '';
      }

      final user = await _authRepository.register(
        name: pendingData['name']!,
        email: pendingData['email']!,
        password: pendingData['password']!,
        phone: pendingData['phone']!,
        role: pendingData['role']!,
        specialty: pendingData['specialty']!,
        bio: pendingData['bio']!,
        address: pendingData['address']!,
        latitude: pendingData['latitude'] != null && pendingData['latitude']!.isNotEmpty
            ? double.tryParse(pendingData['latitude']!)
            : null,
        longitude: pendingData['longitude'] != null && pendingData['longitude']!.isNotEmpty
            ? double.tryParse(pendingData['longitude']!)
            : null,
        portfolioImages: portfolioUrls,
        profileImage: profileImageUrl,
        idCardImage: idCardUrl,
        selfieImage: selfieUrl,
      );

      // حفظ الـ Token
      final userId = user.uid;
      await NotificationService.instance.saveTokenToFirestore(userId);

      // الاشتراك في topic التخصص لو حرفي

      // الاشتراك في topic التخصص لو حرفي
      if (pendingData['role'] == 'artisan' &&
          pendingData['specialty'].isNotEmpty) {
        await NotificationService.instance.subscribeToSpecialty(
          pendingData['specialty'],
        );
      }

      // تسجيل الخروج محلياً بعد إكمال كل العمليات
      await _authRepository.logout();

      emit(const AuthRegistrationSuccess());
    } catch (e) {
      emit(AuthError(message: _mapErrorMessage(e.toString())));
    }
  }

  // ── تسجيل الدخول ──────────────────────────────────────────────
  Future<void> login({required String email, required String password}) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.login(
        email: email,
        password: password,
      );

      await _authRepository.persistLastKnownUid(user.uid);

      // تحديث الـ FCM Token وحالة المتصل
      await NotificationService.instance.saveTokenToFirestore(user.uid);

      // بدء الاستماع لبيانات المستخدم وتحديث حالة المتصل
      _startUserSubscription(user.uid);
      await _authRepository.updateUserOnlineStatus(user.uid, true);

      emit(AuthAuthenticated(user: user, lastUpdate: DateTime.now()));
    } catch (e) {
      emit(AuthError(message: _mapErrorMessage(e.toString())));
    }
  }

  // ── التحقق من حال التوثيق ────────────────────────────────────
  Future<void> checkAuthStatus() async {
    emit(const AuthLoading());
    try {
      // 1) محاولة فورية من الكاش
      User? firebaseUser = _authRepository.currentFirebaseUser;

      // 2) fallback أكثر اعتمادية: ننتظر أول event من authStateChanges
      // بدل الاعتماد فقط على polling (الذي قد يفشل في بعض الإقلاعات الباردة).
      if (firebaseUser == null) {
        debugPrint('⏳ Auth: Recovering persisted Firebase session...');
        firebaseUser = await _authRepository.restorePersistedFirebaseUser();
      }

      // 3) إن وُجد uid محفوظ من آخر جلسة ناجحة وFirebase لسه فاضي — أندرويد أحيانًا يؤخر الهيدريشن
      if (firebaseUser == null) {
        final remembered = await _authRepository.readLastKnownUid();
        if (remembered != null && remembered.isNotEmpty) {
          debugPrint(
            '🔑 Auth: انتظار موسّع (~10–12 ث)؛ uid محفوظ محلياً: $remembered',
          );
          for (var i = 0; i < 72; i++) {
            await Future.delayed(const Duration(milliseconds: 170));
            firebaseUser = _authRepository.currentFirebaseUser;
            if (firebaseUser != null) break;
          }
        }
      }

      if (firebaseUser != null) {
        debugPrint('✅ Auth: User found UID=${firebaseUser.uid}');

        // تجنّب User.reload على أندرويد: بعض الأجهزة تعيد لحظياً currentUser = null؛
        // تحديث التوكن يكفي لمزامنة الجلسة دون لفّة حساسة بالشبكة.
        try {
          await firebaseUser
              .getIdToken(true)
              .timeout(const Duration(seconds: 12));
        } catch (e) {
          debugPrint(
            '⚠️ Auth: Could not refresh id token, continuing locally: $e',
          );
        }

        firebaseUser = _authRepository.currentFirebaseUser;
        if (firebaseUser == null) {
          debugPrint(
            '⚠️ Auth: currentUser null بعد reload — استطلاع قصير (أندرويد أحياناً يتأخر)',
          );
          for (var i = 0; i < 24; i++) {
            await Future.delayed(const Duration(milliseconds: 120));
            firebaseUser = _authRepository.currentFirebaseUser;
            if (firebaseUser != null) break;
          }
        }
        if (firebaseUser == null) {
          debugPrint('❌ Auth: لا يوجد مستخدم Firebase بعد الاستطلاع');
          emit(const AuthUnauthenticated());
          return;
        }

        // التحقق من البريد يُفرض عند login() فقط، لا نمسح الجلسة المحفوظة هنا؛
        // بعض الأجهزة ترجع emailVerified متأخراً بعد الإقلاع فتبدو الجلسة "مقطوعة".

        const delaysMs = [500, 900, 1500, 2200];
        UserModel? userResolved;
        Object? fatal;

        for (var attempt = 0; attempt <= delaysMs.length; attempt++) {
          try {
            userResolved = await _authRepository.getUserById(firebaseUser.uid);
            fatal = null;
            break;
          } catch (e) {
            fatal = e;
            final msg = e.toString();
            if (msg.contains('المستخدم غير موجود')) break;
            if (msg.contains('firestore-permission-denied')) continue;
            debugPrint('⚠️ Auth: getUserById attempt ${attempt + 1} failed: $e');
            if (attempt < delaysMs.length) {
              await Future.delayed(Duration(milliseconds: delaysMs[attempt]));
            }
          }
        }

        // لا نستدعي signOut لو فشل جلب مستند users: ذلك كان يمسح الجلسة من الجهاز
        // ويُرجِع المستخدم لشاشة اللوجين بعد إغلاق التطبيق وهو لا يزال مسجلاً منطقياً.
        late final UserModel user;
        if (userResolved != null) {
          user = userResolved;
        } else if (fatal != null &&
            fatal.toString().contains('المستخدم غير موجود')) {
          debugPrint(
            '⚠️ Auth: الوثيقة غير ظاهرة للـ SDK الآن — جسر من Firebase Auth (بدون logout).',
          );
          user = UserModel.fromFirebaseUserBridge(firebaseUser);
        } else if (fatal != null) {
          debugPrint(
            '⚠️ Auth: Firestore خطأ عمومي ($fatal) — جسر حتى تصحّح التيارات.',
          );
          user = UserModel.fromFirebaseUserBridge(firebaseUser);
        } else {
          user = UserModel.fromFirebaseUserBridge(firebaseUser);
        }

        await _authRepository.persistLastKnownUid(user.uid);

        NotificationService.instance.saveTokenToFirestore(user.uid);
        _startUserSubscription(user.uid);
        await _authRepository.updateUserOnlineStatus(user.uid, true);

        emit(AuthAuthenticated(user: user, lastUpdate: DateTime.now()));
      } else {
        debugPrint('ℹ️ Auth: No active session found after deep polling.');
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      debugPrint('⚠️ Auth: Fatal error during status check: $e');
      final u = _authRepository.currentFirebaseUser;
      if (u != null) {
        try {
          final recovered = await _authRepository.getUserById(u.uid);
          await _authRepository.persistLastKnownUid(recovered.uid);
          NotificationService.instance.saveTokenToFirestore(recovered.uid);
          _startUserSubscription(recovered.uid);
          await _authRepository.updateUserOnlineStatus(recovered.uid, true);
          emit(AuthAuthenticated(user: recovered, lastUpdate: DateTime.now()));
        } catch (_) {
          final bridge = UserModel.fromFirebaseUserBridge(u);
          await _authRepository.persistLastKnownUid(bridge.uid);
          NotificationService.instance.saveTokenToFirestore(bridge.uid);
          _startUserSubscription(bridge.uid);
          await _authRepository.updateUserOnlineStatus(bridge.uid, true);
          emit(AuthAuthenticated(user: bridge, lastUpdate: DateTime.now()));
        }
        return;
      }
      emit(const AuthUnauthenticated());
    } finally {
      _authBootstrapComplete = true;
    }
  }

  // ── تسجيل الخروج ─────────────────────────────────────────────
  Future<void> logout() async {
    final currentState = state;
    emit(const AuthLoading());
    try {
      if (currentState is AuthAuthenticated) {
        // إزالة التوكن من السجل المركزي للأدمنز
        await NotificationService.instance.removeTokenFollowingLogout(
          currentState.user.uid,
        );

        // تحديث الحالة ليكون غير متصل
        await _authRepository.updateUserOnlineStatus(
          currentState.user.uid,
          false,
        );
      }
      _userSubscription?.cancel();
      await _authRepository.logout();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: _mapErrorMessage(e.toString())));
    }
  }

  // ── تصفير عداد الإشعارات (للمستخدم الحالي أو حساب معين مثل الإدارة) ──────────────
  Future<void> resetUnreadCount([
    String? targetUid,
    String? conversationId,
  ]) async {
    final uid =
        targetUid ??
        (state is AuthAuthenticated
            ? (state as AuthAuthenticated).user.uid
            : null);
    if (uid != null) {
      try {
        await _authRepository.resetUnreadNotificationsCount(
          uid,
          conversationId: conversationId,
        );
      } catch (e) {
        debugPrint('❌ Error resetting unread count: $e');
      }
    }
  }

  // ── تحديث معرف المحادثة النشطة حالياً (لكتم الجرس) ─────────────────────────
  Future<void> updateActiveChatId(
    String? chatId, {
    bool isSupport = false,
  }) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      // للأدمن الموثق، نستخدم كلاً من الـ UID والـ sessionId لضمان عزل تمام
      await _authRepository.updateActiveChatId(
        currentState.user.uid,
        chatId,
        isSupport: isSupport,
        sessionId: sessionId,
      );
    } else if (isSupport) {
      // للأدمن الداخل بالبريد الخلفي، نستخدم الـ sessionId لتمييز هذه الجلسة
      await _authRepository.updateActiveChatId(
        FirebaseConstants.supportId,
        chatId,
        isSupport: true,
        sessionId: sessionId,
      );
    }
  }

  // ── إزالة شات دعم من القائمة (عند الخروج) ─────────────────────────
  Future<void> removeActiveSupportChat(String chatId) async {
    await _authRepository.removeActiveSupportChat(chatId, adminUid: sessionId);
  }

  // ── إعادة تعيين كلمة المرور ───────────────────────────────────
  Future<void> resetPassword(String email) async {
    emit(const AuthLoading());
    try {
      await _authRepository.resetPassword(email);
      emit(const AuthPasswordResetSent());
    } catch (e) {
      emit(AuthError(message: _mapErrorMessage(e.toString())));
    }
  }

  // ── رفع صور الأعمال ──────────────────────────────────────────
  Future<void> updateProfileImage(File newImage) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    try {
      final oldImageUrl = currentState.user.profileImage;
      
      // 1. Upload new image
      final newImageUrl = await _cloudinaryService.uploadImage(newImage);
      if (newImageUrl == null) throw Exception('فشل رفع الصورة');

      // 2. Delete old image if exists
      if (oldImageUrl.isNotEmpty) {
        await _cloudinaryService.deleteImage(oldImageUrl);
      }

      // 3. Update Firestore
      final updatedUser = currentState.user.copyWith(profileImage: newImageUrl);
      await _authRepository.updateUser(updatedUser);
      
      // Local state update is handled by the user stream subscription automatically
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      throw Exception('فشل تغيير الصورة: ${e.toString()}');
    }
  }

  Future<void> updateBio(String newBio) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;
    try {
      final updatedUser = currentState.user.copyWith(bio: newBio);
      emit(AuthAuthenticated(user: updatedUser, lastUpdate: DateTime.now()));
      await _authRepository.updateUser(updatedUser);
    } catch (e) {
      debugPrint('Error updating bio: $e');
      throw Exception('فشل تحديث النبذة: ${e.toString()}');
    }
  }

  Future<List<String>> _uploadPortfolio(List<File> files) async {
    List<String> urls = [];
    for (var file in files) {
      final url = await _cloudinaryService.uploadImage(file);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  // ── إدارة معرض الأعمال (إضافة / حذف) ────────────────────────────
  Future<void> addPortfolioImage(File imageFile) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;
    final user = currentState.user;

    if (user.portfolioImages.length >= 10) {
      throw Exception('لا يمكن إضافة أكثر من 10 صور في معرض الأعمال');
    }

    final url = await _cloudinaryService.uploadImage(imageFile);
    if (url == null) throw Exception('فشل رفع الصورة');

    final updatedImages = [...user.portfolioImages, url];
    final updatedUser = user.copyWith(portfolioImages: updatedImages);
    emit(AuthAuthenticated(user: updatedUser, lastUpdate: DateTime.now()));
    await _authRepository.updatePortfolioImages(user.uid, updatedImages);
  }

  Future<void> deletePortfolioImage(String imageUrl) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;
    final user = currentState.user;

    final updatedImages = user.portfolioImages.where((img) => img != imageUrl).toList();
    final updatedUser = user.copyWith(portfolioImages: updatedImages);
    emit(AuthAuthenticated(user: updatedUser, lastUpdate: DateTime.now()));

    try {
      await _cloudinaryService.deleteImage(imageUrl);
    } catch (e) {
      debugPrint('Cloudinary deletion failed, but removed from DB: $e');
    }
    await _authRepository.updatePortfolioImages(user.uid, updatedImages);
  }

  // ── تغيير رقم الهاتف مع كود تحقق ──────────────────────────────
  Future<void> sendPhoneChangeOtp(String newPhone) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    if (currentState.user.phone == newPhone) {
      emit(const AuthError(message: 'رقم الهاتف الجديد يطابق الرقم الحالي. الرجاء إدخال رقم مختلف.'));
      emit(AuthAuthenticated(user: currentState.user, lastUpdate: DateTime.now()));
      return;
    }

    emit(const AuthLoading());
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: newPhone,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          emit(AuthError(message: _mapPhoneAuthError(e.code, e.message)));
          emit(AuthAuthenticated(user: currentState.user, lastUpdate: DateTime.now()));
        },
        codeSent: (String verificationId, int? resendToken) {
          emit(AuthPhoneChangeOtpSent(
            verificationId: verificationId,
            newPhone: newPhone,
            currentUser: currentState.user,
          ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      emit(AuthError(message: _mapPhoneAuthError('', e.toString())));
      emit(AuthAuthenticated(user: currentState.user, lastUpdate: DateTime.now()));
    }
  }

  Future<void> verifyPhoneChangeOtp(String otp, String verificationId, String newPhone) async {
    final currentState = state;
    UserModel currentUser;
    if (currentState is AuthPhoneChangeOtpSent) {
      currentUser = currentState.currentUser;
    } else if (currentState is AuthAuthenticated) {
      currentUser = currentState.user;
    } else {
      return;
    }

    emit(const AuthLoading());
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      // ربط/تحديث رقم الهاتف للمستخدم الحالي بدلاً من تسجيل دخول جديد
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.updatePhoneNumber(credential);
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      
      // تحديث الرقم في Firestore
      final newEmail = '$newPhone@works.com';
      await _authRepository.updateUserPhone(currentUser.uid, newPhone, newEmail);
      
      // Fallback: نعيد جلب البيانات
      final updatedUser = await _authRepository.getUserById(currentUser.uid);
      _startUserSubscription(updatedUser.uid);
      emit(AuthAuthenticated(user: updatedUser, lastUpdate: DateTime.now()));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _mapPhoneAuthError(e.code, e.message)));
      emit(AuthPhoneChangeOtpSent(
        verificationId: verificationId,
        newPhone: newPhone,
        currentUser: currentUser,
      ));
    } catch (e) {
      emit(AuthError(message: 'رمز التحقق غير صحيح أو منتهي الصلاحية.'));
      emit(AuthPhoneChangeOtpSent(
        verificationId: verificationId,
        newPhone: newPhone,
        currentUser: currentUser,
      ));
    }
  }

  /// ترجمة أخطاء Firebase Phone Auth للعربية
  String _mapPhoneAuthError(String code, String? message) {
    switch (code) {
      case 'invalid-phone-number':
        return 'رقم الهاتف المدخل غير صالح. تأكد من كتابة الرقم بشكل صحيح مع كود الدولة.';
      case 'too-many-requests':
        return 'تم إرسال عدد كبير من الطلبات. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.';
      case 'quota-exceeded':
        return 'تم تجاوز الحد المسموح من الرسائل. يرجى المحاولة لاحقاً.';
      case 'app-not-authorized':
        return 'التطبيق غير مصرح له بإرسال رسائل SMS. يرجى التواصل مع الدعم الفني.';
      case 'captcha-check-failed':
        return 'فشل التحقق الأمني. يرجى المحاولة مرة أخرى.';
      case 'missing-phone-number':
        return 'يرجى إدخال رقم الهاتف.';
      case 'user-disabled':
        return 'هذا الحساب معطّل. تواصل مع الدعم الفني.';
      case 'invalid-verification-code':
        return 'رمز التحقق المدخل غير صحيح. تأكد من إدخال الرمز الصحيح.';
      case 'invalid-verification-id':
        return 'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.';
      case 'session-expired':
        return 'انتهت صلاحية الجلسة. يرجى إعادة طلب رمز التحقق.';
      case 'network-request-failed':
        return 'خطأ في الاتصال بالإنترنت. تأكد من اتصالك وحاول مرة أخرى.';
      case 'credential-already-in-use':
        return 'رقم الهاتف مرتبط بحساب آخر بالفعل.';
      default:
        if (message != null && message.contains('blocked')) {
          return 'تم حظر هذا الجهاز مؤقتاً بسبب نشاط غير عادي. حاول لاحقاً.';
        }
        if (message != null && message.contains('network')) {
          return 'خطأ في الاتصال بالإنترنت. تأكد من اتصالك وحاول مرة أخرى.';
        }
        return 'حدث خطأ أثناء إرسال رمز التحقق. يرجى المحاولة مرة أخرى.';
    }
  }

  String _mapErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'البريد الإلكتروني أو رقم الهاتف غير مسجل لدينا';
    } else if (error.contains('wrong-password')) {
      return 'كلمة المرور غير صحيحة';
    } else if (error.contains('invalid-credential')) {
      return 'البريد الإلكتروني/رقم الهاتف أو كلمة المرور غير صحيحة';
    } else if (error.contains('email-not-verified')) {
      return 'يرجى تفعيل بريدك الرلكتروني أولاً (تفقد صندوق الوارد أو المهملات)';
    } else if (error.contains('email-already-in-use')) {
      return 'البريد الإلكتروني أو رقم الهاتف مسجل مسبقاً في حساب آخر';
    } else if (error.contains('weak-password')) {
      return 'كلمة المرور ضعيفة جداً';
    } else if (error.contains('invalid-email')) {
      return 'الصيغة المدخلة للبريد الإلكتروني أو الرقم غير صالحة';
    } else if (error.contains('network-request-failed')) {
      return 'خطأ في الاتصال بالإنترنت';
    } else if (error.contains('too-many-requests')) {
      return 'محاولات كثيرة جداً، نرجو المحاولة لاحقاً';
    }
    return 'حدث خطأ غير متوقع، حاول مرة أخرى';
  }
}
