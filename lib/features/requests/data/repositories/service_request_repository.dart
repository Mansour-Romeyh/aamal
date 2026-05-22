import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../models/service_request_model.dart';
import '../../../../core/services/notification_service.dart';

class ServiceRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _requestsRef =>
      _firestore.collection(FirebaseConstants.serviceRequestsCollection);

  // ── إنشاء طلب جديد ──────────────────────────────────────────
  Future<void> createRequest(ServiceRequestModel request, List<File> imageFiles) async {
    List<String> imageUrls = [];

    // رفع الصور بالتوازي (Parallel Upload)
    final cloudinaryService = CloudinaryService();
    
    if (imageFiles.isNotEmpty) {
      try {
        final uploadFutures = imageFiles.map((file) => cloudinaryService.uploadImage(file));
        final results = await Future.wait(uploadFutures);
        
        for (var secureUrl in results) {
          if (secureUrl != null) {
            imageUrls.add(secureUrl);
          }
        }
      } catch (e) {
        throw Exception('فشل في رفع بعض الصور، يرجى المحاولة مرة أخرى.');
      }
    }

    final requestWithImages = ServiceRequestModel(
      id: request.id,
      clientId: request.clientId,
      clientName: request.clientName,
      artisanId: request.artisanId,
      artisanName: request.artisanName,
      specialty: request.specialty,
      status: request.status,
      title: request.title,
      location: request.location,
      images: imageUrls,
      message: request.message,
      createdAt: request.createdAt,
      latitude: request.latitude,
      longitude: request.longitude,
    );

    final docRef = await _requestsRef.add(requestWithImages.toMap());
    
    // إرسال إشعار للحرفي (نرسله في الخلفية لعدم تعطيل المستخدم)
    NotificationService.instance.sendNotificationToUser(
      targetUserId: request.artisanId,
      title: 'طلب خدمة جديد 🛠️',
      body: 'قام ${request.clientName} بإرسال طلب خدمة جديد لك: ${request.message}',
      data: {
        'type': 'service_request',
        'postId': docRef.id,
        'isDirectRequest': 'true',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    ).catchError((e) => print('Error sending notification: $e'));
  }

  // ── تحديث حالة الطلب ──────────────────────────────────────────
  Future<void> updateRequestStatus(String requestId, String status, ServiceRequestModel request) async {
    await _requestsRef.doc(requestId).update({'status': status});
    
    String title = '';
    String body = '';
    
    if (status == 'accepted') {
      title = 'تم قبول طلبك ✅';
      body = 'وافق الحرفي ${request.artisanName} على طلبك. يمكنك الآن التواصل معه.';
    } else if (status == 'declined') {
      title = 'تم رفض الطلب ❌';
      body = 'عذراً، قام الحرفي ${request.artisanName} بالاعتذار عن طلبك حالياً.';
    }

    if (title.isNotEmpty) {
      await _sendNotification(
        targetUserId: request.clientId,
        title: title,
        body: body,
        data: {
          'type': 'request_status',
          'postId': requestId,
          'isDirectRequest': 'true',
          'status': status,
        },
      );
    }
  }

  // ── مساعد لإرسال الإشعارات (تبسيط) ─────────────────────────────────────
  Future<void> _sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    await NotificationService.instance.sendNotificationToUser(
      targetUserId: targetUserId,
      title: title,
      body: body,
      data: data,
    );
  }

  // ── جلب طلب محدد ──────────────────────────────────────────
  Future<ServiceRequestModel?> getRequestById(String requestId) async {
    final doc = await _requestsRef.doc(requestId).get();
    if (doc.exists) {
      return ServiceRequestModel.fromFirestore(doc);
    }
    return null;
  }

  // ── جلب طلبات الحرفي (الطلبات المرسلة إليه) ─────────────────────
  Stream<List<ServiceRequestModel>> getArtisanRequests(String artisanId) {
    return _requestsRef
        .where('artisanId', isEqualTo: artisanId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceRequestModel.fromFirestore(doc))
            .toList());
  }

  // ── جلب طلبات العميل (الطلبات التي أرسلها) ─────────────────────
  Stream<List<ServiceRequestModel>> getClientRequests(String clientId) {
    return _requestsRef
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceRequestModel.fromFirestore(doc))
            .toList());
  }
}
