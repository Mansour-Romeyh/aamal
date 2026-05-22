import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String clientId;
  final String clientName;
  final String title;
  final String description;
  final String specialty;
  final String location;
  final String status; // open, accepted, completed, cancelled
  final String? acceptedArtisanId;
  final String? acceptedOfferId;
  final double? acceptedPrice;
  final int offersCount;
  final DateTime createdAt;
  final List<String> images;
  final bool isDirectRequest;
  final double? latitude;
  final double? longitude;

  PostModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.title,
    required this.description,
    required this.specialty,
    required this.location,
    required this.status,
    this.acceptedArtisanId,
    this.acceptedOfferId,
    this.acceptedPrice,
    this.offersCount = 0,
    required this.createdAt,
    this.images = const [],
    this.isDirectRequest = false,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'title': title,
      'description': description,
      'specialty': specialty,
      'location': location,
      'status': status,
      'acceptedArtisanId': acceptedArtisanId,
      'acceptedOfferId': acceptedOfferId,
      'acceptedPrice': acceptedPrice,
      'offersCount': offersCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'images': images,
      'isDirectRequest': isDirectRequest,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return PostModel.empty();
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      specialty: data['specialty'] ?? '',
      location: data['location'] ?? '',
      status: data['status'] ?? 'open',
      acceptedArtisanId: data['acceptedArtisanId'],
      acceptedOfferId: data['acceptedOfferId'],
      acceptedPrice: (data['acceptedPrice'] ?? 0.0).toDouble(),
      offersCount: data['offersCount'] ?? 0,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      images: List<String>.from(data['images'] ?? []),
      isDirectRequest: data['isDirectRequest'] ?? false,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  static PostModel empty() {
    return PostModel(
      id: '',
      clientId: '',
      clientName: '',
      title: '',
      description: '',
      specialty: '',
      location: '',
      status: 'open',
      createdAt: DateTime.now(),
    );
  }

  PostModel copyWith({
    String? status,
    String? acceptedArtisanId,
    String? acceptedOfferId,
    double? acceptedPrice,
    int? offersCount,
    double? latitude,
    double? longitude,
  }) {
    return PostModel(
      id: id,
      clientId: clientId,
      clientName: clientName,
      title: title,
      description: description,
      specialty: specialty,
      location: location,
      status: status ?? this.status,
      acceptedArtisanId: acceptedArtisanId ?? this.acceptedArtisanId,
      acceptedOfferId: acceptedOfferId ?? this.acceptedOfferId,
      acceptedPrice: acceptedPrice ?? this.acceptedPrice,
      offersCount: offersCount ?? this.offersCount,
      createdAt: createdAt,
      images: images,
      isDirectRequest: this.isDirectRequest,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
