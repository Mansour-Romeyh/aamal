import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../posts/data/models/post_model.dart';

class ServiceRequestModel {
  final String id;
  final String clientId;
  final String clientName;
  final String artisanId;
  final String artisanName;
  final String specialty;
  final String status;
  final String title;
  final String location;
  final List<String> images;
  final String message;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  ServiceRequestModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.artisanId,
    required this.artisanName,
    required this.specialty,
    required this.status,
    required this.title,
    required this.location,
    this.images = const [],
    required this.message,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'artisanId': artisanId,
      'artisanName': artisanName,
      'specialty': specialty,
      'status': status,
      'title': title,
      'location': location,
      'images': images,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory ServiceRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceRequestModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      artisanId: data['artisanId'] ?? '',
      artisanName: data['artisanName'] ?? '',
      specialty: data['specialty'] ?? '',
      status: data['status'] ?? 'pending',
      title: data['title'] ?? 'طلب مباشر',
      location: data['location'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  PostModel toPostModel() {
    return PostModel(
      id: id,
      clientId: clientId,
      clientName: clientName,
      title: title,
      description: message,
      specialty: specialty,
      location: location,
      status: status == 'pending' ? 'open' : (status == 'accepted' ? 'accepted' : (status == 'declined' ? 'cancelled' : status)),
      createdAt: createdAt,
      images: images,
      acceptedArtisanId: artisanId,
      isDirectRequest: true,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
