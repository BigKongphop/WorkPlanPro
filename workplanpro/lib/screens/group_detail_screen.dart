import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import './group_settings_screen.dart';
import './group_calendar_page.dart';
import '../widgets/group_member_tab.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';

extension FileExtension on File {
  String get mimeType {
    final ext = path.extension(this.path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.mp4':
        return 'video/mp4';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }
}

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String username;
  final String userEmail;

  const GroupDetailScreen({
    Key? key,
    required this.groupId,
    required this.username,
    required this.userEmail,
  }) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool isLoading = true;
  bool _isUploading = false;
  bool _isAdmin = false;

  Map<String, dynamic>? groupData;
  String? _editingMessageId;

  List<Map<String, dynamic>> messages = [];
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
    _loadMessages();
    _checkAdminStatus();
  }

  Future<void> _loadGroupData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (mounted) {
        setState(() {
          groupData = doc.data() as Map<String, dynamic>;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading group data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateMessage(String messageId, String newContent) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': newContent,
        'isEdited': true,
      });

      setState(() {
        _editingMessageId = null;
        _messageController.clear();
      });

      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating message: $e')),
        );
      }
    }
  }

  Future<void> _checkAdminStatus() async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .where('email', isEqualTo: widget.userEmail)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (memberDoc.docs.isNotEmpty && mounted) {
        setState(() {
          _isAdmin = memberDoc.docs.first['role'] == 'admin';
        });
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  Future<void> _uploadAndSendMedia(File file, String type) async {
    try {
      setState(() => _isUploading = true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(file.path);
      final fileName = 'file_${timestamp}${extension}';

      final storageRef =
          FirebaseStorage.instance.ref().child('chats').child(fileName);
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'sender': widget.username,
        'senderEmail': widget.userEmail,
        'content': '',
        'mediaUrl': downloadUrl,
        'mediaType': type,
        'fileName': fileName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isUploading = false);
    } catch (e) {
      print('Upload error: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          messages = snapshot.docs
              .map((doc) => {
                    ...doc.data() as Map<String, dynamic>,
                    'id': doc.id,
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      if (_editingMessageId != null) {
        await _updateMessage(
            _editingMessageId!, _messageController.text.trim());
      } else {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('messages')
            .add({
          'content': _messageController.text.trim(),
          'sender': widget.username,
          'senderEmail': widget.userEmail,
          'createdAt': FieldValue.serverTimestamp(),
          'isEdited': false,
        });
      }

      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  void _startEditing(Map<String, dynamic> message) {
    setState(() {
      _editingMessageId = message['id'];
      _messageController.text = message['content'];
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data?.docs.map((doc) {
                    return {
                      ...doc.data() as Map<String, dynamic>,
                      'id': doc.id,
                    };
                  }).toList() ??
                  [];

              return ListView.builder(
                reverse: true,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMyMessage =
                      message['senderEmail'] == widget.userEmail;
                  final date = (message['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now();

                  return _buildMessageItem(message, isMyMessage, date);
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.attach_file),
                onPressed: _showAttachmentOptions,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              SizedBox(width: 8),
              _isUploading
                  ? CircularProgressIndicator()
                  : CircleAvatar(
                      backgroundColor: Color(0xFF0C5217),
                      child: IconButton(
                        icon: Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C8C4B), // Changed
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data?.data() != null) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['name']} (${data['memberCount'] ?? 0})',
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data['description']?.isNotEmpty ?? false)
                    Text(
                      data['description'],
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              );
            }
            return Text('Loading...', style: TextStyle(color: Colors.white));
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              final groupDoc = await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .get();

              if (!mounted) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupSettingsScreen(
                    groupId: widget.groupId,
                    currentUserEmail: widget.userEmail,
                    isOwner:
                        groupDoc.data()?['creatorEmail'] == widget.userEmail,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2C8C4B), Color(0xFF4CAF50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _selectedTabIndex = 0),
                  icon: Icon(Icons.chat, color: Colors.white),
                  label: Text('Chat', style: TextStyle(color: Colors.white)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedTabIndex = 1),
                  icon: Icon(Icons.calendar_today, color: Colors.white),
                  label:
                      Text('Calendar', style: TextStyle(color: Colors.white)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedTabIndex = 2),
                  icon: Icon(Icons.group, color: Colors.white),
                  label: Text('Members', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildChatView()
                : _selectedTabIndex == 1
                    ? GroupCalendarPage(
                        groupId: widget.groupId,
                        currentUserEmail: widget.userEmail,
                      )
                    : GroupMembersTab(
                        groupId: widget.groupId,
                        currentUsername: widget.username,
                        currentEmail: widget.userEmail,
                        isAdmin: _isAdmin,
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadAndSendMedia(File(image.path), 'image');
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final file = File(video.path);
        final sizeInBytes = await file.length();
        final sizeInMb = sizeInBytes / (1024 * 1024);

        if (sizeInMb > 50) {
          throw 'Video size must be less than 50MB';
        }

        await _uploadAndSendMedia(file, 'video');
      }
    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);

        final sizeInBytes = await file.length();
        final sizeInMb = sizeInBytes / (1024 * 1024);

        if (sizeInMb > 10) {
          throw 'File size must be less than 10MB';
        }

        await _uploadAndSendMedia(file, 'file');
      }
    } catch (e) {
      print('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          if (_editingMessageId != null)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editing message',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: _cancelEditing,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.attach_file),
                onPressed:
                    _editingMessageId == null ? _showAttachmentOptions : null,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              SizedBox(width: 8),
              _isUploading
                  ? CircularProgressIndicator()
                  : CircleAvatar(
                      backgroundColor: Color(0xFF2C8C4B),
                      child: IconButton(
                        icon: Icon(
                          _editingMessageId != null ? Icons.check : Icons.send,
                          color: Colors.white,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo),
              title: Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam),
              title: Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: Icon(Icons.insert_drive_file),
              title: Text('File'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(
      Map<String, dynamic> message, bool isMyMessage, DateTime date) {
    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMyMessage ? () => _showMessageOptions(message) : null,
        child: Container(
          margin: EdgeInsets.only(
            bottom: 8,
            left: isMyMessage ? 50 : 0,
            right: isMyMessage ? 0 : 50,
          ),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMyMessage ? Color(0xFF2C8C4B) : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMyMessage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message['sender'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              if (message['mediaUrl'] != null) ...[
                _buildMediaPreview(message),
                SizedBox(height: 8),
              ],
              if (message['content'].isNotEmpty)
                Text(
                  message['content'],
                  style: TextStyle(
                    color: isMyMessage ? Colors.white : Colors.black,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(date),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMyMessage ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  if (message['isEdited'] == true) ...[
                    SizedBox(width: 4),
                    Text(
                      '(edited)',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isMyMessage ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Message'),
              onTap: () {
                Navigator.pop(context);
                _startEditing(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(Map<String, dynamic> message) {
    switch (message['mediaType']) {
      case 'image':
        return GestureDetector(
          onTap: () => _showFullScreenImage(message['mediaUrl']),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              message['mediaUrl'],
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        );
      case 'video':
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.play_circle_fill,
            size: 50,
            color: Colors.white,
          ),
        );
      case 'file':
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  message['fileName'] ?? 'File',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      default:
        return SizedBox.shrink();
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
          backgroundColor: Colors.black,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
