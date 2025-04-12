import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:salesgo/models/location.dart';
import 'package:salesgo/models/user.dart';

class LocationManagement extends StatefulWidget {
  const LocationManagement({super.key});

  @override
  _LocationManagementState createState() => _LocationManagementState();
}

class _LocationManagementState extends State<LocationManagement> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedType = 'van';
  String? _selectedAgentId;

  Future<void> _addLocation() async {
    if (_formKey.currentState!.validate()) {
      try {
        final location = Location(
          id: FirebaseFirestore.instance.collection('locations').doc().id,
          name: _nameController.text,
          type: _selectedType,
          assignedAgentId: _selectedAgentId,
        );

        await FirebaseFirestore.instance
            .collection('locations')
            .doc(location.id)
            .set(location.toMap());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location added successfully')),
        );

        // Clear form
        _formKey.currentState!.reset();
        setState(() => _selectedAgentId = null);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Location Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
                  DropdownMenuItem(value: 'store', child: Text('Store')),
                  DropdownMenuItem(value: 'van', child: Text('Mobile Van')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
                decoration: const InputDecoration(labelText: 'Location Type'),
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
                onPressed: _addLocation,
                child: const Text('Add Location'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text('Existing Locations', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('locations').snapshots(),
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
                      final location = Location.fromFirestore(doc.data() as Map<String, dynamic>);
                      return ListTile(
                        title: Text(location.name),
                        subtitle: Text('Type: ${location.type}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteLocation(doc.id),
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

  Future<void> _deleteLocation(String locationId) async {
    try {
      await FirebaseFirestore.instance.collection('locations').doc(locationId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting location: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}