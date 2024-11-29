import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateGroupScreen extends StatefulWidget {
  final String currentUsername;
  final String currentEmail;

  const CreateGroupScreen({
    Key? key,
    required this.currentUsername,
    required this.currentEmail,
  }) : super(key: key);

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _nameError = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // ดึงลำดับสูงสุดที่มีอยู่
      final highestOrderDoc = await firestore
          .collection('groups')
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      int nextOrder = 0;
      if (highestOrderDoc.docs.isNotEmpty) {
        nextOrder = (highestOrderDoc.docs.first.data()['order'] ?? -1) + 1;
      }
      
      final groupSnapshot = await firestore
          .collection('groups')
          .where('name', isEqualTo: _nameController.text)
          .get();

      if (groupSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group name already exists')),
        );
        return;
      }

      final docRef = await firestore.collection('groups').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorEmail': widget.currentEmail,
        'creatorName': widget.currentUsername,
        'createdAt': FieldValue.serverTimestamp(),
        'memberCount': 1,
        'memberEmails': [widget.currentEmail],
        'order': nextOrder, // เพิ่ม order field
      });

      await docRef.update({'id': docRef.id});

      // Add creator as admin member
      final memberRef = docRef.collection('members').doc();
      await memberRef.set({
        'email': widget.currentEmail,
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'accepted'
      });

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group created successfully')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating group: $e')),
      );
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C5217),
        title: const Text(
          'Create New Group',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    errorText: _nameError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.group),
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Please enter a group name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C5217),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Create Group',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}