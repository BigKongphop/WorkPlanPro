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

  @override
  void initState() {
    super.initState();
    _membersStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  Future<void> _inviteMember() async {
    final TextEditingController emailController = TextEditingController();
  
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
                final userQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .get();

                if (userQuery.docs.isEmpty) {
                  throw Exception('ไม่พบผู้ใช้นี้ในระบบ');
                }

                final existingMember = await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('members')
                    .where('email', isEqualTo: email)
                    .get();

                if (existingMember.docs.isNotEmpty) {
                  throw Exception('มีสมาชิกนี้อยู่ในกลุ่มแล้ว');
                }

                // เพิ่มสมาชิกใหม่เป็นสถานะ pending
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ส่งคำเชิญเรียบร้อยแล้ว')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: Text('เชิญ'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMemberRole(String memberId, String newRole) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(memberId)
          .update({'role': newRole});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตบทบาทสำเร็จ')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
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
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('members')
                    .doc(member.id)
                    .delete();

                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .update({
                      'memberCount': FieldValue.increment(-1),
                    });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ลบสมาชิกสำเร็จ')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                );
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
                  icon: Icon(Icons.person_add),
                  onPressed: _inviteMember,
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

              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isAdmin = member['role'] == 'admin';
                  
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
                      title: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where('email', isEqualTo: member['email'])
                            .get()
                            .then((value) => value.docs.first),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasData) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
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
                      trailing: widget.isAdmin && member['email'] != widget.currentEmail
                          ? PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'role') {
                                  _updateMemberRole(
                                    member.id,
                                    isAdmin ? 'member' : 'admin'
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