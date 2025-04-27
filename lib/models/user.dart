import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String role;
  final String? assignedLocationId;
  final String name;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.assignedLocationId,
    required this.name,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'agent',
      assignedLocationId: data['assignedLocationId'],
      name: data['name'] ?? 'Agent Name',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'role': role,
    'assignedLocationId': assignedLocationId,
    'name': name,
    'createdAt': createdAt,
  };

}