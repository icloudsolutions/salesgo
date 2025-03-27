import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:salesgo/models/car.dart';
import 'package:salesgo/models/user.dart';

class CarManagement extends StatefulWidget {
  const CarManagement({super.key});

  @override
  _CarManagementState createState() => _CarManagementState();
}

class _CarManagementState extends State<CarManagement> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  String? _selectedAgentId;

  Future<void> _addCar() async {
    if (_formKey.currentState!.validate()) {
      try {
        final car = Car(
          id: FirebaseFirestore.instance.collection('cars').doc().id,
          name: _nameController.text,
          plateNumber: _plateController.text,
          assignedAgentId: _selectedAgentId,
        );

        await FirebaseFirestore.instance
            .collection('cars')
            .doc(car.id)
            .set(car.toMap());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Car added successfully')),
        );

        // Clear form
        _formKey.currentState!.reset();
        setState(() => _selectedAgentId = null);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding car: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Car Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Car Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Plate Number'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              const Text('Assign to Agent (optional)'),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'agent')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final agents = snapshot.data!.docs
                      .map((doc) => AppUser.fromFirestore(doc.data() as Map<String, dynamic>))
                      .toList();
                  
                  return DropdownButton<String>(
                    value: _selectedAgentId,
                    hint: const Text('Select Agent'),
                    items: agents.map((agent) {
                      return DropdownMenuItem<String>(
                        value: agent.uid,
                        child: Text(agent.email),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedAgentId = value),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addCar,
                child: const Text('Add Car'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text('Existing Cars', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('cars').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final car = Car.fromFirestore(doc.data() as Map<String, dynamic>);
                      return ListTile(
                        title: Text(car.name),
                        subtitle: Text('Plate: ${car.plateNumber}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteCar(doc.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCar(String carId) async {
    try {
      await FirebaseFirestore.instance.collection('cars').doc(carId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Car deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting car: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }
}