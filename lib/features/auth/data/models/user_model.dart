import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../../../core/constants/firebase_constants.dart';

/// نموذج بيانات المستخدم
class UserModel extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // client | artisan | admin
  final String specialty; // للحرفي فقط
  final String profileImage;
  final double rating;
  final int ratingCount;
  final String fcmToken;
  final List<String> fcmTokens;
  final bool isActive;
  final bool isVerified;
  final int unreadNotificationsCount;
  final bool isOnline;
  final DateTime? lastSeen;
  final String bio; // للحرفي فقط
  final String address; // للحرفي فقط
  final List<String> portfolioImages; // للحرفي فقط
  final String? activeChatId; // معرف المحادثة النشطة حالياً
  final String idCardImage; // صورة البطاقة/الهوية (للحرفي)
  final String selfieImage; // صورة السيلفي (للحرفي)
  final String approvalStatus; // pending | approved | rejected | none (none for clients)
  final double? latitude; // خط العرض للحرفي
  final double? longitude; // خط الطول للحرفي
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.specialty = '',
    this.profileImage = '',
    this.rating = 0.0,
    this.ratingCount = 0,
    this.fcmToken = '',
    this.fcmTokens = const [],
    this.isActive = true,
    this.isVerified = false,
    this.unreadNotificationsCount = 0,
    this.isOnline = false,
    this.lastSeen,
    this.bio = '',
    this.address = '',
    this.portfolioImages = const [],
    this.activeChatId,
    this.idCardImage = '',
    this.selfieImage = '',
    this.approvalStatus = 'approved', // الافتراضي موافق عليه (للعملاء)
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  /// إنشاء من Firestore Document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'client',
      specialty: data['specialty'] ?? '',
      profileImage: data['profileImage'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingCount: (data['ratingCount'] ?? 0).toInt(),
      fcmToken: data['fcmToken'] ?? '',
      fcmTokens: List<String>.from(data['fcmTokens'] ?? const []),
      isActive: data['isActive'] ?? true,
      isVerified: data['isVerified'] ?? false,
      unreadNotificationsCount: (data['unreadNotificationsCount'] ?? 0).toInt(),
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
      bio: data['bio'] ?? '',
      address: data['address'] ?? '',
      portfolioImages: List<String>.from(data['portfolioImages'] ?? []),
      activeChatId: data['activeChatId'],
      idCardImage: data['idCardImage'] ?? '',
      selfieImage: data['selfieImage'] ?? '',
      approvalStatus: data['approvalStatus'] ?? (data['role'] == 'artisan' ? 'pending' : 'approved'),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// جسر وقت تعطل جلب مستند Firestore مع بقاء جلسة Auth؛ يُستبدل فورًا عبر getUserStream
  factory UserModel.fromFirebaseUserBridge(User firebaseUser) {
    final email = (firebaseUser.email ?? '').trim();
    final dn = firebaseUser.displayName?.trim();
    final name = () {
      if (dn != null && dn.isNotEmpty) return dn;
      final local = firebaseUser.email?.split('@').first;
      if (local != null && local.isNotEmpty) return local;
      return 'مستخدم';
    }();

    return UserModel(
      uid: firebaseUser.uid,
      name: name,
      email: email,
      phone: '',
      role: FirebaseConstants.roleClient,
      specialty: '',
      profileImage: firebaseUser.photoURL ?? '',
      createdAt: DateTime.now(),
    );
  }

  /// إنشاء من Map
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'client',
      specialty: map['specialty'] ?? '',
      profileImage: map['profileImage'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      ratingCount: (map['ratingCount'] ?? 0).toInt(),
      fcmToken: map['fcmToken'] ?? '',
      fcmTokens: List<String>.from(map['fcmTokens'] ?? const []),
      isActive: map['isActive'] ?? true,
      isVerified: map['isVerified'] ?? false,
      unreadNotificationsCount: (map['unreadNotificationsCount'] ?? 0).toInt(),
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : null,
      bio: map['bio'] ?? '',
      address: map['address'] ?? '',
      portfolioImages: List<String>.from(map['portfolioImages'] ?? []),
      activeChatId: map['activeChatId'],
      idCardImage: map['idCardImage'] ?? '',
      selfieImage: map['selfieImage'] ?? '',
      approvalStatus: map['approvalStatus'] ?? (map['role'] == 'artisan' ? 'pending' : 'approved'),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'specialty': specialty,
      'profileImage': profileImage,
      'rating': rating,
      'ratingCount': ratingCount,
      'fcmToken': fcmToken,
      'fcmTokens': fcmTokens,
      'isActive': isActive,
      'isVerified': isVerified,
      'unreadNotificationsCount': unreadNotificationsCount,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'bio': bio,
      'address': address,
      'portfolioImages': portfolioImages,
      'activeChatId': activeChatId,
      'idCardImage': idCardImage,
      'selfieImage': selfieImage,
      'approvalStatus': approvalStatus,
      'latitude': latitude,
      'longitude': longitude,
      if (latitude != null && longitude != null)
        'geo': GeoFirePoint(GeoPoint(latitude!, longitude!)).data,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// نسخة معدلة
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? specialty,
    String? profileImage,
    double? rating,
    int? ratingCount,
    String? fcmToken,
    List<String>? fcmTokens,
    bool? isActive,
    bool? isVerified,
    int? unreadNotificationsCount,
    bool? isOnline,
    DateTime? lastSeen,
    String? bio,
    String? address,
    List<String>? portfolioImages,
    String? activeChatId,
    String? idCardImage,
    String? selfieImage,
    String? approvalStatus,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      specialty: specialty ?? this.specialty,
      profileImage: profileImage ?? this.profileImage,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      unreadNotificationsCount: unreadNotificationsCount ?? this.unreadNotificationsCount,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      bio: bio ?? this.bio,
      address: address ?? this.address,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      activeChatId: activeChatId ?? this.activeChatId,
      idCardImage: idCardImage ?? this.idCardImage,
      selfieImage: selfieImage ?? this.selfieImage,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// هل المستخدم عميل؟
  bool get isClient => role == 'client';

  /// هل المستخدم حرفي؟
  bool get isArtisan => role == 'artisan';

  /// هل المستخدم أدمن؟
  bool get isAdmin => role == 'admin';

  @override
  List<Object?> get props => [
        uid,
        name,
        email,
        phone,
        role,
        specialty,
        profileImage,
        rating,
        ratingCount,
        fcmToken,
        fcmTokens,
        isActive,
        isVerified,
        unreadNotificationsCount,
        isOnline,
        lastSeen,
        bio,
        address,
        portfolioImages,
        activeChatId,
        idCardImage,
        selfieImage,
        approvalStatus,
        latitude,
        longitude,
        createdAt,
      ];
}
