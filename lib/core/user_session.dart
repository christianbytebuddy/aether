import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserSession {
  UserSession._();
  static final instance = UserSession._();

  String? photoBase64;

  Future<void> load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      photoBase64 = doc.data()?['photoBase64'] as String?;
    } catch (e) {
      debugPrint('UserSession load error: $e');
    }
  }

  void clear() => photoBase64 = null;

  // Decodifica el base64 listo para Image.memory
  Uint8List? get photoBytes {
    if (photoBase64 == null) return null;
    try {
      final data = photoBase64!.contains(',')
          ? photoBase64!.split(',')[1]
          : photoBase64!;
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }
}
