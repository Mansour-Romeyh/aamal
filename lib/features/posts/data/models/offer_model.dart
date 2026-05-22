import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String postId;
  final String artisanId;
  final String artisanName;
  final double artisanRating;
  final double price;
  final String comment;
  final DateTime createdAt;
  final String status; // pending, accepted, rejected

  OfferModel({
    required this.id,
    required this.postId,
    required this.artisanId,
    required this.artisanName,
    required this.artisanRating,
    required this.price,
    required this.comment,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'artisanId': artisanId,
      'artisanName': artisanName,
      'artisanRating': artisanRating,
      'price': price,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory OfferModel.fromMap(Map<String, dynamic> map) {
    return OfferModel(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      artisanId: map['artisanId'] ?? '',
      artisanName: map['artisanName'] ?? '',
      artisanRating: (map['artisanRating'] ?? 0.0).toDouble(),
      price: (map['price'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
    );
  }
}
