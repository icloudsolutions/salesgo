class AppUser {
  final String uid;
  final String email;
  final String role;
  final String? assignedCarId;
  final String name;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.assignedCarId,
    required this.name,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'agent',
      assignedCarId: data['assignedCarId'],
      name: data['name'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'role': role,
    'assignedCarId': assignedCarId,
    'name': name,
  };

}