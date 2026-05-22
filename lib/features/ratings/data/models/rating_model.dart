import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// نموذج التقييم
class RatingModel extends Equatable {
  final String id;
  final String artisanId;
  final String clientId;
  final String clientName;
  final String postId;
  final double rating;
  final String comment;
  final bool isHidden;
  final DateTime createdAt;

  const RatingModel({
    required this.id,
    required this.artisanId,
    required this.clientId,
    required this.clientName,
    required this.postId,
    required this.rating,
    this.comment = '',
    this.isHidden = false,
    required this.createdAt,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RatingModel(
      id: doc.id,
      artisanId: data['artisanId'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      postId: data['postId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      isHidden: data['isHidden'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'artisanId': artisanId,
      'clientId': clientId,
      'clientName': clientName,
      'postId': postId,
      'rating': rating,
      'comment': comment,
      'isHidden': isHidden,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props =>
      [id, artisanId, clientId, postId, rating, comment, isHidden, createdAt];
}
