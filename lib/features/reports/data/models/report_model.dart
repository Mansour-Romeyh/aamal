import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterId;
  final String reportedId; // User being reported
  final String? postId;
  final String? chatId;
  final String reason;
  final String details;
  final DateTime createdAt;
  final String status; // pending, reviewed, resolved

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    this.postId,
    this.chatId,
    required this.reason,
    required this.details,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reportedId': reportedId,
      'postId': postId,
      'chatId': chatId,
      'reason': reason,
      'details': details,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reportedId: data['reportedId'] ?? '',
      postId: data['postId'],
      chatId: data['chatId'],
      reason: data['reason'] ?? '',
      details: data['details'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
    );
  }
}
