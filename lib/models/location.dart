class Location {
  final String id;
  final String name;
  final String type; // Added location type
  final String? assignedAgentId;

  Location({
    required this.id,
    required this.name,
    required this.type,
    this.assignedAgentId,
  });

  factory Location.fromFirestore(Map<String, dynamic> data) {
    return Location(
      id: data['id'],
      name: data['name'],
      type: data['type'] ?? 'van', // Default type
      assignedAgentId: data['assignedAgentId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'assignedAgentId': assignedAgentId,
  };
}