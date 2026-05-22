import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../models/rating_model.dart';

/// مستودع التقييمات
class RatingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ratingsRef =>
      _firestore.collection(FirebaseConstants.ratingsCollection);

  // ── إضافة تقييم ──────────────────────────────────────────────
  Future<void> addRating(RatingModel rating) async {
    // حفظ التقييم
    await _ratingsRef.add(rating.toMap());

    // تحديث متوسط تقييم الحرفي
    final artisanRef = _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(rating.artisanId);

    await _firestore.runTransaction((transaction) async {
      final artisanDoc = await transaction.get(artisanRef);
      final oldRating = (artisanDoc.data()?['rating'] ?? 0.0).toDouble();
      final oldCount = (artisanDoc.data()?['ratingCount'] ?? 0).toInt();

      final newCount = oldCount + 1;
      final newRating =
          ((oldRating * oldCount) + rating.rating) / newCount;

      transaction.update(artisanRef, {
        'rating': newRating,
        'ratingCount': newCount,
      });
    });
  }

  // ── جلب تقييمات حرفي ─────────────────────────────────────────
  Stream<List<RatingModel>> getArtisanRatings(String artisanId) {
    return _ratingsRef
        .where('artisanId', isEqualTo: artisanId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromFirestore(doc))
            .toList());
  }

  // ── هل العميل قيّم هذا البوست؟ ───────────────────────────────
  Future<bool> hasRated(String clientId, String postId) async {
    final query = await _ratingsRef
        .where('clientId', isEqualTo: clientId)
        .where('postId', isEqualTo: postId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // ── جلب جميع التقييمات (للأدمن) ─────────────────────────────
  Stream<List<RatingModel>> getAllRatings() {
    return _ratingsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromFirestore(doc))
            .toList());
  }

  // ── إخفاء/إظهار التقييم (للأدمن) ───────────────────────────
  Future<void> toggleRatingVisibility(String ratingId, bool isHidden) async {
    await _ratingsRef.doc(ratingId).update({'isHidden': isHidden});
  }
}
