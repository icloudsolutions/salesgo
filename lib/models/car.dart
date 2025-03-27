class Car {
  final String id;
  final String name;
  final String plateNumber;
  final String? assignedAgentId;

  Car({
    required this.id,
    required this.name,
    required this.plateNumber,
    this.assignedAgentId,
  });

  factory Car.fromFirestore(Map<String, dynamic> data) {
    return Car(
      id: data['id'],
      name: data['name'],
      plateNumber: data['plateNumber'],
      assignedAgentId: data['assignedAgentId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'plateNumber': plateNumber,
    'assignedAgentId': assignedAgentId,
  };
}