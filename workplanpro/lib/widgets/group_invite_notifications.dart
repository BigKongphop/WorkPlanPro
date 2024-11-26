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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('members')
          .where('email', isEqualTo: widget.userEmail)
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _invitations = snapshot.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading invitations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleInvitation(String groupId, String memberId, bool accept) async {
    if (!mounted) return;

    try {
      // ปิด bottom sheet ก่อน
      Navigator.pop(context);

      // เริ่ม batch operation
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      final memberRef = groupRef.collection('members').doc(memberId);

      if (accept) {
        // อัพเดทสถานะสมาชิก
        batch.update(memberRef, {
          'status': 'accepted',
          'joinedAt': FieldValue.serverTimestamp(),
          'role': 'member'
        });

        // อัพเดทข้อมูลกลุ่ม
        batch.update(groupRef, {
          'memberCount': FieldValue.increment(1),
          'memberEmails': FieldValue.arrayUnion([widget.userEmail])
        });

        // ดำเนินการ batch
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เข้าร่วมกลุ่มเรียบร้อยแล้ว'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // กรณีปฏิเสธคำเชิญ
        await memberRef.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ปฏิเสธคำเชิญแล้ว'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // โหลดข้อมูลใหม่
      await _loadInvitations();

    } catch (e) {
      print('Error handling invitation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const IconButton(
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        onPressed: null,
      );
    }

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            _invitations?.isEmpty ?? true 
                ? Icons.notifications_none 
                : Icons.notifications_active,
            color: Colors.white,
          ),
          onPressed: (_invitations?.isEmpty ?? true) ? null : () async {
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
              useRootNavigator: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (BuildContext context) => StatefulBuilder(
                builder: (context, setState) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'คำเชิญเข้าร่วมกลุ่ม',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF0C5217),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: groupsData.length,
                          itemBuilder: (context, index) {
                            final data = groupsData[index];
                            final groupDoc = data['group'] as DocumentSnapshot;
                            final invitation = data['invitation'] as QueryDocumentSnapshot;
                            
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF0C5217),
                                  child: Icon(Icons.group, color: Colors.white),
                                ),
                                title: Text(
                                  groupDoc['name'] ?? 'Unknown Group',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('From: ${groupDoc['creatorName'] ?? 'Unknown'}'),
                                    Text(
                                      'Invited at: ${_formatDate(invitation['invitedAt'] as Timestamp)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      child: const Text(
                                        'รับ',
                                        style: TextStyle(color: Colors.green),
                                      ),
                                      onPressed: () => _handleInvitation(
                                        groupDoc.id,
                                        invitation.id,
                                        true,
                                      ),
                                    ),
                                    TextButton(
                                      child: const Text(
                                        'ปฏิเสธ',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () => _handleInvitation(
                                        groupDoc.id,
                                        invitation.id,
                                        false,
                                      ),
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
              ),
            );
          },
        ),
        if (_invitations?.isNotEmpty ?? false)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _invitations!.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }
}