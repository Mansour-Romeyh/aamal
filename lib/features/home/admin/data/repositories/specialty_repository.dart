import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/constants/firebase_constants.dart';
import '../models/specialty_model.dart';

class SpecialtyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SpecialtyModel>> getSpecialties() {
    return _firestore
        .collection(FirebaseConstants.specialtiesCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SpecialtyModel.fromFirestore(doc)).toList());
  }

  Stream<List<SpecialtyModel>> getActiveSpecialties() {
    return _firestore
        .collection(FirebaseConstants.specialtiesCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => SpecialtyModel.fromFirestore(doc)).toList();
          list.sort((a, b) => a.name.compareTo(b.name));
          return list;
        });
  }

  Future<void> addSpecialty(String name, {String iconCode = ''}) async {
    await _firestore.collection(FirebaseConstants.specialtiesCollection).add({
      'name': name,
      'iconCode': iconCode,
      'isActive': true,
    });
  }

  Future<void> toggleSpecialtyStatus(String id, bool isActive) async {
    await _firestore
        .collection(FirebaseConstants.specialtiesCollection)
        .doc(id)
        .update({'isActive': isActive});
  }

  Future<void> deleteSpecialty(String id) async {
    await _firestore.collection(FirebaseConstants.specialtiesCollection).doc(id).delete();
  }
}
