/// أسماء Collections في Firestore وثوابت Firebase
class FirebaseConstants {
  FirebaseConstants._();

  // ── Collections ───────────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String postsCollection = 'posts';
  static const String conversationsCollection = 'conversations';
  static const String messagesSubcollection = 'messages';
  static const String ratingsCollection = 'ratings';
  static const String offersSubcollection = 'offers';
  static const String reportsCollection = 'reports';
  static const String serviceRequestsCollection = 'service_requests';
  static const String specialtiesCollection = 'specialties';
  static const String supportPresenceCollection = 'support_presence';

  // ── Storage Paths ─────────────────────────────────────────────
  static const String profileImagesPath = 'profile_images';
  static const String postImagesPath = 'post_images';

  // ── أدوار المستخدمين ──────────────────────────────────────────
  static const String roleClient = 'client';
  static const String roleArtisan = 'artisan';
  static const String roleAdmin = 'admin';
  static const String supportId = 'technical_support';

  // ── حالات البوست ──────────────────────────────────────────────
  static const String statusOpen = 'open';
  static const String statusAccepted = 'accepted';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

}

/// ثوابت منطق الإشعارات (توحيد القيم المستخدمة بين الخدمات والمستودعات)
class NotificationConstants {
  NotificationConstants._();

  // التصنيفات
  static const String categoryAdmin = 'admin';
  static const String categoryOrder = 'order';
  static const String categoryChat = 'chat';

  // الأنواع (type)
  static const String typeChat = 'chat';
  static const String typeNewPost = 'new_post';
  static const String typeServiceRequest = 'service_request';
  static const String typeRequestStatus = 'request_status';
  static const String typePostAccepted = 'post_accepted';
  static const String typePostDeclined = 'post_declined';
  static const String typePostCompleted = 'post_completed';
  static const String typeNewOffer = 'new_offer';
  static const String typeOfferAccepted = 'offer_accepted';
  static const String typeReport = 'report';
  static const String typeSupport = 'support';
  static const String typeAdminAction = 'admin_action';
  static const String typeArtisanApproval = 'artisan_approval';

  // السلوك
  static const double artisanGeoRadiusKm = 20.0;
  /// مهلة انتظار جلسة Firebase بعد الإقلاع (توازن بين الأجهزة البطيئة ومدة الشاشة)
  static const Duration authRestoreTimeout = Duration(seconds: 12);
}
