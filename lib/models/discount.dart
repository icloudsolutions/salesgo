import 'package:cloud_firestore/cloud_firestore.dart';

class Discount {
  final String id;
  final DocumentReference categoryRef;
  final DateTime startDate;
  final DateTime endDate;
  final double value;
  final String type;
  final String name;
  final DocumentReference? reference;

  Discount({
    required this.id,
    required this.categoryRef,
    required this.startDate,
    required this.endDate,
    required this.value,
    required this.type,
    required this.name,
    this.reference,
  });

  /// Creates a Discount from a Firestore DocumentSnapshot
  factory Discount.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      return Discount(
        id: doc.id,
        categoryRef: data['categoryRef'] as DocumentReference,
        startDate: (data['startDate'] as Timestamp).toDate(),
        endDate: (data['endDate'] as Timestamp).toDate(),
        value: (data['value'] as num).toDouble(),
        type: data['type'] as String,
        name: data['name'] as String? ?? '',
        reference: doc.reference,
      );
    } catch (e) {
      throw FormatException('Failed to parse Discount: $e');
    }
  }



  /// Converts the Discount to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryRef': categoryRef,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'value': value,
      'type': type,
      if (name.isNotEmpty) 'name': name,
    };
  }

  /// Helper method to check if discount is currently active
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  @override
  String toString() {
    return 'Discount(id: $id, name: $name, value: $value$type, '
           'active: ${startDate.toIso8601String()} to ${endDate.toIso8601String()})';
  }
}