import 'package:cloud_firestore/cloud_firestore.dart';

class Discount {
  final String id;
  final DocumentReference categoryRef;
  final DateTime? startDate;
  final DateTime? endDate;
  final double value;
  final String type;
  final bool hasDateRange;
  final String name;
  final DocumentReference? reference;

  Discount({
    required this.id,
    required this.categoryRef,
    this.startDate,
    this.endDate,
    required this.value,
    required this.hasDateRange,
    required this.type,
    required this.name,
    this.reference,
  });

  factory Discount.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      return Discount(
        id: doc.id,
        categoryRef: data['categoryRef'] as DocumentReference,
        startDate: data['hasDateRange'] ? (data['startDate'] as Timestamp).toDate() : null,
        endDate: data['hasDateRange'] ? (data['endDate'] as Timestamp).toDate() : null,
        value: (data['value'] as num).toDouble(),
        type: data['type'] as String,
        hasDateRange: data['hasDateRange'] as bool? ?? false,
        name: data['name'] as String? ?? '',
        reference: doc.reference,
      );
    } catch (e) {
      throw FormatException('Failed to parse Discount: $e');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryRef': categoryRef,
      if (hasDateRange && startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (hasDateRange && endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'value': value,
      'type': type,
      'hasDateRange': hasDateRange,
      'name': name,
    };
  }

  bool get isActive {
    if (!hasDateRange) return true;
    if (startDate == null || endDate == null) return false;
    final now = DateTime.now();
    return now.isAfter(startDate!) && now.isBefore(endDate!);
  }

  @override
  String toString() {
    return 'Discount(id: $id, name: $name, value: $value$type, '
           'active: ${hasDateRange ? '${startDate?.toIso8601String()} to ${endDate?.toIso8601String()}' : 'Always active'})';
  }
}