import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SpecialtyModel extends Equatable {
  final String id;
  final String name;
  final String iconCode;
  final bool isActive;

  const SpecialtyModel({
    required this.id,
    required this.name,
    this.iconCode = '',
    this.isActive = true,
  });

  factory SpecialtyModel.fromMap(Map<String, dynamic> map, String id) {
    return SpecialtyModel(
      id: id,
      name: map['name'] ?? '',
      iconCode: map['iconCode'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  factory SpecialtyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return SpecialtyModel(id: doc.id, name: '');
    return SpecialtyModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconCode': iconCode,
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [id, name, iconCode, isActive];
}
