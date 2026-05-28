import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// نموذج الرسالة
class MessageModel extends Equatable {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final bool isLocation;
  final double? latitude;
  final double? longitude;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.isLocation = false,
    this.latitude,
    this.longitude,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      isLocation: data['isLocation'] ?? false,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'isLocation': isLocation,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  @override
  List<Object?> get props => [id, senderId, text, timestamp, isRead, isLocation, latitude, longitude];
}

/// نموذج المحادثة
class ConversationModel extends Equatable {
  final String id;
  final List<String> participants;
  final String postId;
  final String postTitle;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime lastMessageTime;
  final Map<String, String> participantNames;
  final Map<String, String> participantRoles; // client | artisan | admin
  final Map<String, String> participantImages;
  final Map<String, String> participantSpecialties; // خاص بالحرفيين
  final Map<String, bool> typingStatus;
  final bool isClosed;
  final bool isLastMessageRead;

  const ConversationModel({
    required this.id,
    required this.participants,
    required this.postId,
    this.postTitle = '',
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    required this.lastMessageTime,
    this.participantNames = const {},
    this.participantRoles = const {},
    this.participantImages = const {},
    this.participantSpecialties = const {},
    this.typingStatus = const {},
    this.isClosed = false,
    this.isLastMessageRead = true,
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      postId: data['postId'] ?? '',
      postTitle: data['postTitle'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantRoles: Map<String, String>.from(data['participantRoles'] ?? {}),
      participantImages:
          Map<String, String>.from(data['participantImages'] ?? {}),
      participantSpecialties:
          Map<String, String>.from(data['participantSpecialties'] ?? {}),
      typingStatus: Map<String, bool>.from(data['typingStatus'] ?? {}),
      isClosed: data['isClosed'] ?? false,
      isLastMessageRead: data['isLastMessageRead'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'postId': postId,
      'postTitle': postTitle,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'participantNames': participantNames,
      'participantRoles': participantRoles,
      'participantImages': participantImages,
      'participantSpecialties': participantSpecialties,
      'typingStatus': typingStatus,
      'isClosed': isClosed,
      'isLastMessageRead': isLastMessageRead,
    };
  }

  /// ايدي الطرف الآخر
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
  }

  /// اسم الطرف الآخر
  String getOtherParticipantName(String currentUserId) {
    final otherKey = participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
    return participantNames[otherKey] ?? 'مستخدم';
  }

  /// دور الطرف الآخر
  String getOtherParticipantRole(String currentUserId) {
    final otherKey = participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
    return participantRoles[otherKey] ?? 'client';
  }

  /// صورة الطرف الآخر
  String? getOtherParticipantImage(String currentUserId) {
    final otherKey = participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
    return participantImages[otherKey];
  }

  /// تخصص الطرف الآخر (للحرفيين)
  String? getOtherParticipantSpecialty(String currentUserId) {
    final otherKey = participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
    return participantSpecialties[otherKey];
  }

  @override
  List<Object?> get props => [
        id,
        participants,
        postId,
        postTitle,
        lastMessage,
        lastMessageSenderId,
        lastMessageTime,
        participantNames,
        participantRoles,
        participantImages,
        participantSpecialties,
        typingStatus,
        isClosed,
        isLastMessageRead,
      ];
}
