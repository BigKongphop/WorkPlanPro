import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import './choose_group_image_screen.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  final String currentUserEmail;
  final bool isOwner;

  const GroupSettingsScreen({
    Key? key,
    required this.groupId,
    required this.currentUserEmail,
    required this.isOwner,
  }) : super(key: key);

  @override
  _GroupSettingsScreenState createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  String? currentGroupImage;
  String? currentGroupName;
  String? currentGroupDescription;
  bool isLoading = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (mounted && doc.exists) {
        final data = doc.data()!;
        setState(() {
          currentGroupImage = data['imageUrl'];
          currentGroupName = data['name'];
          currentGroupDescription = data['description'];
          _nameController.text = currentGroupName ?? '';
          _descriptionController.text = currentGroupDescription ?? '';
        });
      }
    } catch (e) {
      print('Error loading group data: $e');
    }
  }

  Future<void> _changeGroupImage() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChooseGroupImageScreen(
            currentImage: currentGroupImage,
            onImageSelected: (image) async {
              if (image != null) {
                setState(() {
                  isLoading = true;
                });

                String? imageUrl;
                if (image is File) {
                  imageUrl = await _uploadImage(image);
                } else if (image is String) {
                  imageUrl = image;
                }

                if (imageUrl != null) {
                  await _updateGroupImage(imageUrl);
                }

                setState(() {
                  currentGroupImage = imageUrl;
                  isLoading = false;
                });
              }
            },
          ),
        ),
      );

      if (result != null) {
        setState(() {
          currentGroupImage = result;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Error updating group image: $e');
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('group_images')
        .child(
            '${widget.groupId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = storageRef.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _updateGroupImage(String imageUrl) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'imageUrl': imageUrl,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _editGroupInfo() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showErrorSnackBar('Group name cannot be empty');
      return;
    }
    if (name.length > 25) {
      _showErrorSnackBar('Group name cannot exceed 25 characters');
      return;
    }

    try {
      setState(() => isLoading = true);

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        currentGroupName = _nameController.text.trim();
        currentGroupDescription = _descriptionController.text.trim();
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group information updated successfully')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error updating group info: $e');
    }
  }

// ใน group_settings_screen.dart
  Future<void> _leaveGroup() async {
    try {
      setState(() => isLoading = true);

      final batch = FirebaseFirestore.instance.batch();

      // 1. หา document ของ member ที่จะลบ
      final memberQuery = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .where('email', isEqualTo: widget.currentUserEmail)
          .get();

      // 2. ตรวจสอบและลบ member
      if (memberQuery.docs.isNotEmpty) {
        batch.delete(memberQuery.docs.first.reference);
      }

      // 3. อัปเดตข้อมูลกลุ่ม - ลบ email ออกจาก memberEmails array และลด memberCount
      final groupRef =
          FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
      batch.update(groupRef, {
        'memberCount': FieldValue.increment(-1),
        'memberEmails':
            FieldValue.arrayRemove([widget.currentUserEmail]) // เพิ่มบรรทัดนี้
      });

      await batch.commit();

      setState(() => isLoading = false);

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error leaving group: $e');
    }
  }

  Future<void> _deleteGroup() async {
    try {
      setState(() => isLoading = true);

      final membersSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in membersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(
          FirebaseFirestore.instance.collection('groups').doc(widget.groupId));

      await batch.commit();

      if (currentGroupImage != null &&
          !currentGroupImage!.startsWith('assets/')) {
        try {
          await FirebaseStorage.instance
              .refFromURL(currentGroupImage!)
              .delete();
        } catch (e) {
          print('Error deleting group image: $e');
        }
      }

      setState(() => isLoading = false);

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error deleting group: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF0C5217),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(16),
            children: [
              if (widget.isOwner) ...[
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (currentGroupImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: currentGroupImage!.startsWith('assets/')
                              ? Image.asset(
                                  currentGroupImage!,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: currentGroupImage!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF0C5217),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.group,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                ),
                        ),
                      ] else
                        Icon(
                          Icons.group,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF0C5217),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.photo_library,
                                color: Colors.white, size: 20),
                            onPressed: _changeGroupImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Group Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  maxLength: 25,
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _editGroupInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0C5217),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text('Save Changes',
                      style: TextStyle(color: Colors.white)),
                ),
                SizedBox(height: 32),
                Card(
                  color: Colors.red[50],
                  child: ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red),
                    title: Text(
                      'Delete Group',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: Text('This action cannot be undone'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete Group'),
                          content: Text(
                            'Are you sure you want to delete this group? '
                            'This action cannot be undone and all group data will be lost.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteGroup();
                              },
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                Card(
                  color: Colors.red[50],
                  child: ListTile(
                    leading: Icon(Icons.exit_to_app, color: Colors.red),
                    title: Text(
                      'Leave Group',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: Text('Remove yourself from this group'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Leave Group'),
                          content: Text(
                            'Are you sure you want to leave this group? '
                            'You will need to be invited again to rejoin.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _leaveGroup();
                              },
                              child: Text(
                                'Leave',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0C5217),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
