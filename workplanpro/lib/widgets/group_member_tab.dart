import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMembersTab extends StatefulWidget {
  final String groupId;
  final String currentUsername;
  final String currentEmail;
  final bool isAdmin;

  const GroupMembersTab({
    Key? key,
    required this.groupId,
    required this.currentUsername,
    required this.currentEmail,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _GroupMembersTabState createState() => _GroupMembersTabState();
}

class _GroupMembersTabState extends State<GroupMembersTab> {
  Stream<QuerySnapshot>? _membersStream;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ตรวจสอบสถานะสมาชิกเมื่อเปิดหน้า
    verifyMemberInGroup(widget.groupId, widget.currentEmail).then((isValid) {
      if (!isValid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('คุณไม่ได้เป็นสมาชิกของกลุ่มนี้')),
        );
        Navigator.pop(context);
      }
    });

    _membersStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  Future<bool> verifyMemberInGroup(String groupId, String email) async {
    try {
      final memberSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (memberSnapshot.docs.isEmpty) {
        // Check if there's a pending invitation
        final pendingSnapshot = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .where('email', isEqualTo: email)
            .where('status', isEqualTo: 'pending')
            .get();

        if (pendingSnapshot.docs.isNotEmpty) {
          // Handle pending invitation
          await _handleGroupMemberAcceptance(groupId, email);
          return true;
        }
        return false;
      }
      return true;
    } catch (e) {
      print('Error verifying member: $e');
      return false;
    }
  }

  Future<void> _handleGroupMemberAcceptance(String groupId, String email) async {
    try {
      // Start a batch write
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      // Get reference to the group
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      
      // Get reference to the member
      final memberQuerySnapshot = await groupRef
          .collection('members')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .get();

      if (memberQuerySnapshot.docs.isEmpty) {
        throw Exception('ไม่พบคำเชิญที่รอดำเนินการ');
      }

      final memberRef = memberQuerySnapshot.docs.first.reference;

      // Update member status and add necessary fields
      batch.update(memberRef, {
        'status': 'accepted',
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'member',
      });

      // Update group document
      batch.update(groupRef, {
        'memberEmails': FieldValue.arrayUnion([email]),
        'memberCount': FieldValue.increment(1),
      });

      // Commit the batch
      await batch.commit();

    } catch (e) {
      print('Error handling member acceptance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _inviteMember() async {
    if (_isLoading) return;
    
    final TextEditingController emailController = TextEditingController();
    setState(() => _isLoading = true);
  
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('เพิ่มสมาชิก'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  hintText: 'ระบุอีเมลที่ต้องการเชิญ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;

                try {
                  // ตรวจสอบว่ามีผู้ใช้นี้ในระบบหรือไม่
                  final userQuery = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .get();

                  if (userQuery.docs.isEmpty) {
                    throw Exception('ไม่พบผู้ใช้นี้ในระบบ');
                  }

                  // ตรวจสอบว่าเป็นสมาชิกอยู่แล้วหรือไม่
                  final existingMember = await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('members')
                      .where('email', isEqualTo: email)
                      .get();

                  if (existingMember.docs.isNotEmpty) {
                    throw Exception('มีสมาชิกนี้อยู่ในกลุ่มแล้ว');
                  }

                  // เพิ่มสมาชิกใหม่
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('members')
                      .add({
                        'email': email,
                        'role': 'member',
                        'status': 'pending',
                        'invitedBy': widget.currentEmail,
                        'invitedAt': FieldValue.serverTimestamp(),
                      });

                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ส่งคำเชิญเรียบร้อยแล้ว')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: Text('เชิญ'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMemberRole(String memberId, String newRole) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(memberId)
          .update({'role': newRole});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตบทบาทสำเร็จ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  void _showRemoveConfirmation(DocumentSnapshot member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('นำออกจากกลุ่ม'),
        content: Text('คุณต้องการนำ ${member['email']} ออกจากกลุ่มหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              try {
                WriteBatch batch = FirebaseFirestore.instance.batch();
                
                // Delete member document
                batch.delete(member.reference);

                // Update group document
                batch.update(
                  FirebaseFirestore.instance.collection('groups').doc(widget.groupId),
                  {
                    'memberCount': FieldValue.increment(-1),
                    'memberEmails': FieldValue.arrayRemove([member['email']]),
                  },
                );

                await batch.commit();

                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ลบสมาชิกสำเร็จ')),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                  );
                }
              }
            },
            child: Text('ยืนยัน'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'สมาชิก',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.isAdmin)
                IconButton(
                  icon: _isLoading 
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.person_add),
                  onPressed: _isLoading ? null : _inviteMember,
                  color: const Color(0xFF0C5217),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _membersStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data?.docs ?? [];

              if (members.isEmpty) {
                return Center(child: Text('ไม่มีสมาชิกในกลุ่ม'));
              }

              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isAdmin = member['role'] == 'admin';
                  final bool isCurrentUser = member['email'] == widget.currentEmail;
                  
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                        ),
                      ),
                      title: FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where('email', isEqualTo: member['email'])
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                            final userData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                            return Text(userData['username'] ?? 'ไม่ระบุชื่อ');
                          }
                          return Text(member['email']);
                        },
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member['email']),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAdmin ? Colors.green[100] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isAdmin ? 'Admin' : 'Member',
                              style: TextStyle(
                                fontSize: 12,
                                color: isAdmin ? const Color(0xFF0C5217) : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: widget.isAdmin && !isCurrentUser 
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'role') {
                                _updateMemberRole(
                                  member.id,
                                  isAdmin ? 'member' : 'admin',
                                );
                              } else if (value == 'remove') {
                                _showRemoveConfirmation(member);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'role',
                                child: Text(
                                  isAdmin ? 'ลดระดับเป็นสมาชิก' : 'เลื่อนระดับเป็นผู้ดูแล'
                                ),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  'นำออกจากกลุ่ม',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          )
                        : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}