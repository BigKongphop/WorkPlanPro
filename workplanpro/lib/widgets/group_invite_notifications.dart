import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationWidget extends StatefulWidget {
  final String userEmail;

  const NotificationWidget({
    Key? key, 
    required this.userEmail,
  }) : super(key: key);

  @override
  State<NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget> {
  List<QueryDocumentSnapshot>? _invitations;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('members')
        .where('email', isEqualTo: widget.userEmail)
        .where('status', isEqualTo: 'pending')
        .get();

    if (mounted) {
      setState(() {
        _invitations = snapshot.docs;
      });
    }
  }

  Future<void> _handleInvitation(String groupId, String memberId, bool accept) async {
    try {
      if (accept) {
        // อัพเดทสถานะสมาชิก
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(memberId)
            .update({
              'status': 'accepted',
              'joinedAt': FieldValue.serverTimestamp()
            });

        // เพิ่ม email เข้าไปใน memberEmails array และอัพเดทจำนวนสมาชิก
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update({
              'memberCount': FieldValue.increment(1),
              'memberEmails': FieldValue.arrayUnion([widget.userEmail])
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เข้าร่วมกลุ่มเรียบร้อยแล้ว')),
        );
      } else {
        // ลบข้อมูลสมาชิก
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(memberId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ปฏิเสธคำเชิญแล้ว')),
        );
      }

      // โหลดข้อมูลใหม่
      await _loadInvitations();
    } catch (e) {
      print('Error handling invitation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_invitations == null) {
      return const IconButton(
        icon: Icon(Icons.notifications_none, color: Colors.white),
        onPressed: null,
      );
    }

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            _invitations!.isEmpty ? Icons.notifications_none : Icons.notifications_active,
            color: Colors.white,
          ),
          onPressed: _invitations!.isEmpty ? null : () async {
            // ดึงข้อมูลกลุ่มทั้งหมดที่เกี่ยวข้องกับคำเชิญ
            final groupsData = await Future.wait(
              _invitations!.map((invitation) async {
                final groupId = invitation.reference.parent.parent!.id;
                final groupDoc = await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .get();
                return {
                  'invitation': invitation,
                  'group': groupDoc
                };
              })
            );

            if (!mounted) return;

            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'คำเชิญเข้าร่วมกลุ่ม',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: groupsData.length,
                        itemBuilder: (context, index) {
                          final data = groupsData[index];
                          final groupData = data['group'] as DocumentSnapshot;
                          final invitation = data['invitation'] as QueryDocumentSnapshot;
                          
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF0C5217),
                                child: Icon(Icons.group, color: Colors.white),
                              ),
                              title: Text(groupData['name'] ?? 'Unknown Group'),
                              subtitle: Text('From: ${groupData['creatorName'] ?? 'Unknown'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    child: const Text('รับ', style: TextStyle(color: Colors.green)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _handleInvitation(groupData.id, invitation.id, true);
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _handleInvitation(groupData.id, invitation.id, false);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_invitations!.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _invitations!.length.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}