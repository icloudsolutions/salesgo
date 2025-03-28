import 'package:cloud_firestore/cloud_firestore.dart';

class Discount {
  final String id;
  final String category;
  final DateTime startDate;
  final DateTime endDate;
  final double value;
  final String type;

  Discount({
    required this.id,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.value,
    required this.type,
  });

  factory Discount.fromFirestore(Map<String, dynamic> data) {
    return Discount(
      id: data['id'] as String? ?? '', // Provide empty string as default
      category: data['category'] as String? ?? 'general', // Default category
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 30)),
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      type: data['type'] as String? ?? 'percentage', // Default to percentage
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'startDate': startDate,
    'endDate': endDate,
    'value': value,
    'type': type,
  };
}