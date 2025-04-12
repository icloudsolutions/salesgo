class Coupon {
  final String id;
  final String code;
  final double value;
  final DateTime expiration;
  final bool isUsed;

  Coupon({
    required this.id,
    required this.code,
    required this.value,
    required this.expiration,
    required this.isUsed,
  });

  factory Coupon.fromFirestore(Map<String, dynamic> data) {
    return Coupon(
      id: data['id'],
      code: data['code'],
      value: data['value'].toDouble(),
      expiration: data['expiration'].toDate(),
      isUsed: data['isUsed'],
    );
  }
}