import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './choose_group_image_screen.dart';

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
  String _selectedImage = 'assets/group_images/default1.png';

  void _showImagePicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChooseGroupImageScreen(
          currentImage: _selectedImage,
          onImageSelected: (imagePath) {
            setState(() => _selectedImage = imagePath);
          },
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _nameError = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

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
        'order': nextOrder,
        'imageUrl': _selectedImage,
      });

      await docRef.update({'id': docRef.id});

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating group: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C5217),
        title: const Text('Create New Group',
            style: TextStyle(color: Colors.white)),
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
                Center(
                  child: Container(
                    height: 200,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: _selectedImage != null
                                ? Image.asset(_selectedImage!,
                                    fit: BoxFit.cover)
                                : Icon(Icons.group,
                                    size: 64, color: Colors.grey[400]),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF0C5217),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.photo_library,
                                  color: Colors.white),
                              onPressed: _showImagePicker,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
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
                    if ((value?.length ?? 0) > 25) {
                      return 'Group name cannot exceed 25 characters';
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
                            style: TextStyle(fontSize: 16, color: Colors.white),
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
