import 'package:cloud_firestore/cloud_firestore.dart';

/// Typed access to the app's Firestore collections.
/// Documents store the same JSON the models already produce (`toJson`).
class Collections {
  Collections._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get students =>
      _db.collection('students');
  static CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');
  static CollectionReference<Map<String, dynamic>> get events =>
      _db.collection('events');
  static CollectionReference<Map<String, dynamic>> get requests =>
      _db.collection('requests');
  static CollectionReference<Map<String, dynamic>> get messMenu =>
      _db.collection('messMenu');
  static CollectionReference<Map<String, dynamic>> get messBookings =>
      _db.collection('messBookings');
  static CollectionReference<Map<String, dynamic>> get outpassBlocks =>
      _db.collection('outpassBlocks');

  /// Public phone -> {rollNo, kind} index, so the app can verify a number is
  /// registered before the user signs in. Written by the admin portal.
  static CollectionReference<Map<String, dynamic>> get phoneIndex =>
      _db.collection('phoneIndex');
}
