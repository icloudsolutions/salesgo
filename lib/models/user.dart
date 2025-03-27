class AppUser {
  final String uid;
  final String email;
  final String role;
  final String? assignedCarId;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.assignedCarId, required String name,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'Utilisateur inconnu',
      email: data['email'] ?? '',
      role: data['role'] ?? 'agent',
      assignedCarId: data['assignedCarId'],
    );
  }
}