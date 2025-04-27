import 'package:cloud_firestore/cloud_firestore.dart';

class Location {
  final String id;
  final String name;
  final String type; // Added location type
  final String? assignedAgentId;
  final DateTime createdAt;

  Location({
    required this.id,
    required this.name,
    required this.type,
    this.assignedAgentId,
    required this.createdAt,
  });

  factory Location.fromFirestore(Map<String, dynamic> data) {
    return Location(
      id: data['id'],
      name: data['name'],
      type: data['type'] ?? 'van', // Default type
      assignedAgentId: data['assignedAgentId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'assignedAgentId': assignedAgentId,
    'createdAt': createdAt,

  };
}