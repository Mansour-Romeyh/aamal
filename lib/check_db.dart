import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snapshot = await FirebaseFirestore.instance.collection('specialties').get();
  print('Total Specialties: ${snapshot.docs.length}');
  for (var doc in snapshot.docs) {
    print('Specialty: ${doc.data()}');
  }
}
