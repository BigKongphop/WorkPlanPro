import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;
  dynamic _selectedImage;

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      if (_selectedImage is File) {
        final File imageFile = _selectedImage as File;
        final String fileName =
            DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('group_images')
            .child(fileName);

        final UploadTask uploadTask = storageRef.putFile(imageFile);
        final TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } else if (_selectedImage is String) {
        return _selectedImage;
      }
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      return null;
    }
    return null;
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ตรวจสอบชื่อกลุ่มซ้ำ
      final groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('name', isEqualTo: _nameController.text.trim())
          .get();

      if (groupSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group name already exists')),
        );
        return;
      }

      // อัพโหลดรูปภาพ (ถ้ามี)
      final String? imageUrl = await _uploadImage();

      // สร้างกลุ่มใหม่
      final docRef = await FirebaseFirestore.instance.collection('groups').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorEmail': widget.currentEmail,
        'creatorName': widget.currentUsername,
        'memberEmails': [widget.currentEmail], // เพิ่ม email ผู้สร้างเป็นสมาชิก
        'memberCount': 1,
        'imageUrl': imageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // เพิ่มผู้สร้างเป็นสมาชิกแบบ admin
      await docRef.collection('members').add({
        'email': widget.currentEmail,
        'role': 'admin',
        'status': 'accepted',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // อัพเดท id ของกลุ่ม
      await docRef.update({'id': docRef.id});

      // ปิดหน้าสร้างกลุ่มและกลับไปหน้า list
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group created successfully')),
        );
      }
    } catch (e) {
      print('Error creating group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showImagePicker() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChooseGroupImageScreen(
            currentImage: _selectedImage is String ? _selectedImage : null,
            onImageSelected: (image) {
              if (mounted) {
                setState(() => _selectedImage = image);
              }
            },
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _selectedImage = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
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
                Center(
                  child: GestureDetector(
                    onTap: _showImagePicker,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                        image: _selectedImage != null
                            ? DecorationImage(
                                fit: BoxFit.cover,
                                image: _selectedImage is File
                                    ? FileImage(_selectedImage as File)
                                    : AssetImage(_selectedImage as String)
                                        as ImageProvider,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? Icon(
                              Icons.add_photo_alternate,
                              size: 40,
                              color: Colors.grey,
                            )
                          : null,
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
