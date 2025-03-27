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
      id: data['id'],
      category: data['category'],
      startDate: data['startDate'].toDate(),
      endDate: data['endDate'].toDate(),
      value: data['value'].toDouble(),
      type: data['type'],
    );
  }
}