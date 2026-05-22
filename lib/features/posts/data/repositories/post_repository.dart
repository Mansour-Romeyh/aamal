import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../requests/data/models/service_request_model.dart';
import '../models/post_model.dart';
import '../models/offer_model.dart';

class PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // إرسال عرض سعر
  Future<void> sendOffer(OfferModel offer) async {
    final postRef = _firestore
        .collection(FirebaseConstants.postsCollection)
        .doc(offer.postId);
    final offerRef = postRef
        .collection(FirebaseConstants.offersSubcollection)
        .doc(offer.id);

    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) throw Exception('الطلب غير موجود');

      // إضافة العرض
      transaction.set(offerRef, offer.toMap());

      // تحديث عداد العروض في البوست
      transaction.update(postRef, {'offersCount': FieldValue.increment(1)});
    });
  }

  // جلب العروض لطلب معين
  Stream<List<OfferModel>> getOffersForPost(String postId) {
    return _firestore
        .collection(FirebaseConstants.postsCollection)
        .doc(postId)
        .collection(FirebaseConstants.offersSubcollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OfferModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // قبول عرض سعر
  Future<void> acceptOffer(
    String postId,
    String offerId,
    String artisanId,
    double price,
  ) async {
    final postRef = _firestore
        .collection(FirebaseConstants.postsCollection)
        .doc(postId);
    final offersRef = postRef.collection(FirebaseConstants.offersSubcollection);

    await _firestore.runTransaction((transaction) async {
      // 1. تحديث البوست
      transaction.update(postRef, {
        'status': FirebaseConstants.statusAccepted,
        'acceptedArtisanId': artisanId,
        'acceptedOfferId': offerId,
        'acceptedPrice': price,
      });

      // 2. تحديث العرض المقبول
      transaction.update(offersRef.doc(offerId), {'status': 'accepted'});

      // 3. (اختياري) رفض العروض الأخرى - يمكن عملها هنا أو تركها pending
      // لتسريع العملية، سنكتفي بالخطوتين السابقتين حالياً
    });
  }

  // إنشاء بوست جديد
  Future<void> createPost(PostModel post, List<File> imageFiles) async {
    List<String> imageUrls = [];

    // رفع الصور بالتوازي (Parallel Upload) لتسريع العملية بشكل كبير
    final cloudinaryService = CloudinaryService();

    if (imageFiles.isNotEmpty) {
      try {
        final uploadFutures = imageFiles.map(
          (file) => cloudinaryService.uploadImage(file),
        );
        final results = await Future.wait(uploadFutures);

        for (var secureUrl in results) {
          if (secureUrl != null) {
            imageUrls.add(secureUrl);
          }
        }
      } catch (e) {
        print('خطأ في رفع الصور بالتوازي: $e');
        throw Exception('فشل في رفع بعض الصور، يرجى المحاولة مرة أخرى.');
      }
    }

    final postWithImages = PostModel(
      id: post.id,
      clientId: post.clientId,
      clientName: post.clientName,
      title: post.title,
      description: post.description,
      specialty: post.specialty,
      location: post.location,
      status: post.status,
      createdAt: post.createdAt,
      images: imageUrls,
      latitude: post.latitude,
      longitude: post.longitude,
    );

    try {
      await _firestore
          .collection(FirebaseConstants.postsCollection)
          .doc(post.id)
          .set(postWithImages.toMap())
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      print('Firestore Error in createPost: $e');
      throw Exception(
        'فشل في حفظ الطلب في قاعدة البيانات: تأكد من جودة اتصالك بالإنترنت.',
      );
    }
  }

  // جلب طلبات العميل
  Stream<List<PostModel>> getClientPosts(String clientId) {
    return _firestore
        .collection(FirebaseConstants.postsCollection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
        );
  }

  // جلب الطلبات المفتوحة لحرفي معين (حسب التخصص)
  Stream<List<PostModel>> getOpenPostsBySpecialty(String specialty) {
    return _firestore
        .collection(FirebaseConstants.postsCollection)
        .where('specialty', isEqualTo: specialty)
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
        );
  }

  // جلب الطلبات اللي الحرفي وافق عليها (أو اكتملت)
  Stream<List<PostModel>> getArtisanPosts(String artisanId) {
    return _firestore
        .collection(FirebaseConstants.postsCollection)
        .where('acceptedArtisanId', isEqualTo: artisanId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
        );
  }

  // ── جلب كل الأنشطة الموحدة للعميل ───────────────────────────────
  Stream<List<PostModel>> getUnifiedClientJobs(String clientId) {
    final postsStream = getClientPosts(clientId);
    final requestsStream = _firestore
        .collection(FirebaseConstants.serviceRequestsCollection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ServiceRequestModel.fromFirestore(doc).toPostModel(),
              )
              .toList(),
        );

    return _combineStreams(postsStream, requestsStream);
  }

  // ── جلب كل الأنشطة الموحدة للحرفي (المهام المقبولة) ──────────────
  Stream<List<PostModel>> getUnifiedArtisanJobs(String artisanId) {
    final postsStream = getArtisanPosts(artisanId);
    final requestsStream = _firestore
        .collection(FirebaseConstants.serviceRequestsCollection)
        .where('artisanId', isEqualTo: artisanId)
        .where('status', whereIn: ['accepted', 'completed'])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ServiceRequestModel.fromFirestore(doc).toPostModel(),
              )
              .toList(),
        );

    return _combineStreams(postsStream, requestsStream);
  }

  // جلب طلب محدد
  Future<PostModel?> getPostById(String postId) async {
    final doc = await _firestore
        .collection(FirebaseConstants.postsCollection)
        .doc(postId)
        .get();
    if (doc.exists) {
      return PostModel.fromFirestore(doc);
    }
    return null;
  }

  // مساعد لدمج الـ Streams وترتيبها
  Stream<List<PostModel>> _combineStreams(
    Stream<List<PostModel>> s1,
    Stream<List<PostModel>> s2,
  ) {
    // سنستخدم StreamController لدمج التدفقين يدوياً لعدم وجود rxdart في المشروع حالياً
    final controller = StreamController<List<PostModel>>();
    List<PostModel> lastS1 = [];
    List<PostModel> lastS2 = [];

    void emitLatest() {
      final combined = [...lastS1, ...lastS2];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) controller.add(combined);
    }

    final sub1 = s1.listen(
      (data) {
        lastS1 = data;
        emitLatest();
      },
      onError: (e) {
        if (!controller.isClosed) controller.addError(e);
      },
    );
    final sub2 = s2.listen(
      (data) {
        lastS2 = data;
        emitLatest();
      },
      onError: (e) {
        if (!controller.isClosed) controller.addError(e);
      },
    );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  // جلب كل الطلبات (للأدمن)
  Stream<List<PostModel>> getAllPosts() {
    return _firestore
        .collection(FirebaseConstants.postsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
        );
  }

  // تغيير حالة الطلب
  Future<void> updatePostStatus(
    String postId,
    String status, {
    String? artisanId,
    bool isDirectRequest = false,
  }) async {
    final Map<String, dynamic> data = {'status': status};
    if (artisanId != null) {
      data['acceptedArtisanId'] = artisanId;
    }

    final collection = isDirectRequest
        ? FirebaseConstants.serviceRequestsCollection
        : FirebaseConstants.postsCollection;

    await _firestore.collection(collection).doc(postId).update(data);
  }

  // تحديث بيانات الطلب (النصوص فقط)
  Future<void> updatePostDetails(
    String postId,
    Map<String, dynamic> data, {
    bool isDirectRequest = false,
  }) async {
    final collection = isDirectRequest
        ? FirebaseConstants.serviceRequestsCollection
        : FirebaseConstants.postsCollection;

    await _firestore.collection(collection).doc(postId).update(data);
  }

  // حذف الطلب

  Future<void> deletePost(String postId) async {
    try {
      // 1. جلب بيانات البوست لمعرفة روابط الصور
      final doc = await _firestore
          .collection(FirebaseConstants.postsCollection)
          .doc(postId)
          .get();

      if (doc.exists) {
        final post = PostModel.fromFirestore(doc);
        final cloudinaryService = CloudinaryService();

        // 2. حذف كل صورة من Cloudinary إذا وجدت
        if (post.images.isNotEmpty) {
          final deleteFutures = post.images.map(
            (url) => cloudinaryService.deleteImage(url),
          );
          await Future.wait(deleteFutures);
        }
      }
    } catch (e) {
      print('خطأ أثناء محاولة حذف الصور من Cloudinary: $e');
    }

    // 3. حذف البوست من فايربيز (Firestore)
    await _firestore
        .collection(FirebaseConstants.postsCollection)
        .doc(postId)
        .delete();
  }

  // التحقق من وجود عرض سابق من هذا الحرفي لهذا العميل
  Future<bool> checkIfArtisanHasOfferedToClient(
    String artisanId,
    String clientId,
  ) async {
    try {
      final posts = await _firestore
          .collection(FirebaseConstants.postsCollection)
          .where('clientId', isEqualTo: clientId)
          .where('status', isEqualTo: 'open')
          .get();

      for (var postDoc in posts.docs) {
        final offers = await postDoc.reference
            .collection(FirebaseConstants.offersSubcollection)
            .where('artisanId', isEqualTo: artisanId)
            .limit(1)
            .get();
        if (offers.docs.isNotEmpty) return true;
      }
      return false;
    } catch (e) {
      print('Error checking for existing offer: $e');
      return false;
    }
  }
}
