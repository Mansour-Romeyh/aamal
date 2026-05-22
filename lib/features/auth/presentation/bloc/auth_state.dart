part of 'auth_cubit.dart';

/// حالات التوثيق
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// جاري التحميل
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// مستخدم مسجل الدخول
class AuthAuthenticated extends AuthState {
  final UserModel user;
  final DateTime lastUpdate;
  
  AuthAuthenticated({
    required this.user,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  @override
  List<Object?> get props => [user, lastUpdate];
}

/// مستخدم غير مسجل
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// تم إنشاء الحساب ويرجى التفعيل
class AuthRegistrationSuccess extends AuthState {
  const AuthRegistrationSuccess();
}

/// تم إرسال رابط إعادة تعيين كلمة المرور
class AuthPasswordResetSent extends AuthState {
  const AuthPasswordResetSent();
}

/// تم إرسال رمز التحقق
class AuthOtpSent extends AuthState {
  final String expectedOtp;
  final String phone;
  final String? pinId;
  final Map<String, dynamic> pendingUserData;
  final List<File> pendingPortfolioImages;
  final File? pendingProfileImage;
  final File? pendingIdCardImage;
  final File? pendingSelfieImage;

  const AuthOtpSent({
    required this.expectedOtp, 
    required this.phone,
    this.pinId,
    required this.pendingUserData,
    required this.pendingPortfolioImages,
    this.pendingProfileImage,
    this.pendingIdCardImage,
    this.pendingSelfieImage,
  });

  @override
  List<Object?> get props => [
    expectedOtp, 
    phone, 
    pinId,
    pendingUserData, 
    pendingPortfolioImages, 
    pendingProfileImage,
    pendingIdCardImage,
    pendingSelfieImage,
  ];
}

/// تم إرسال رمز التحقق لتغيير رقم الهاتف
class AuthPhoneChangeOtpSent extends AuthState {
  final String verificationId;
  final String newPhone;
  final UserModel currentUser;

  const AuthPhoneChangeOtpSent({
    required this.verificationId,
    required this.newPhone,
    required this.currentUser,
  });

  @override
  List<Object?> get props => [verificationId, newPhone, currentUser];
}

/// خطأ
class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
