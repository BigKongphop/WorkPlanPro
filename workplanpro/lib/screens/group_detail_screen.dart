import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import './group_settings_screen.dart';
import './group_calendar_page.dart';
import '../widgets/group_member_tab.dart';

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
  bool isLoading = true;
  bool _isAdmin = false;
  Map<String, dynamic>? groupData;
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
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'content': _messageController.text.trim(),
        'sender': widget.username,
        'senderEmail': widget.userEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

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

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isMyMessage = message['senderEmail'] == widget.userEmail;
              final date = (message['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();

              return Align(
                alignment:
                    isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: 8,
                    left: isMyMessage ? 50 : 0,
                    right: isMyMessage ? 0 : 50,
                  ),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMyMessage ? Color(0xFF0C5217) : Colors.grey[200],
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
                      Text(
                        message['content'],
                        style: TextStyle(
                          color: isMyMessage ? Colors.white : Colors.black,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('HH:mm').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isMyMessage ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
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
              CircleAvatar(
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
        backgroundColor: const Color(0xFF0C5217),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${data['name']} (${data['memberCount'] ?? 0})',
                          style: TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (data['description']?.isNotEmpty ?? false)
                    Text(
                      data['description'],
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
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
            color: const Color(0xFF0C5217),
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}