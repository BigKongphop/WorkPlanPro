import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    verifyMemberInGroup(widget.groupId, widget.currentEmail).then((isValid) {
      if (!isValid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not a member of this group')),
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

      return memberSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error verifying member: $e');
      return false;
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
          title: const Text('Add Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter email to invite',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _processInvitation(emailController.text.trim()),
              child: const Text('Invite'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processInvitation(String email) async {
    if (email.isEmpty) return;

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User not found in system');
      }

      final existingMember = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .where('email', isEqualTo: email)
          .get();

      if (existingMember.docs.isNotEmpty) {
        throw Exception('Member already exists in group');
      }

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
          const SnackBar(content: Text('Invitation sent successfully')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _updateMemberRole(String memberId, String newRole) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      final memberDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(memberId)
          .get();

      if (memberDoc.data()?['email'] == groupDoc.data()?['creatorEmail']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot change creator's role")),
          );
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(memberId)
          .update({'role': newRole});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildLeadingImage(DocumentSnapshot member) {
    return SizedBox(
      width: 40,
      height: 40,
      child: FutureBuilder<QuerySnapshot>(
        key: ValueKey('member_${member.id}'),
        future: FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: member['email'])
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final userData =
                snapshot.data!.docs.first.data() as Map<String, dynamic>;
            final accountImageUrl = userData['profileImageUrl'];

            return ClipOval(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: accountImageUrl != null && accountImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: accountImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF0C5217)),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: Colors.grey[600],
                        size: 24,
                      ),
              ),
            );
          }
          return ClipOval(
            child: Container(
              color: Colors.grey[200],
              child: Icon(
                Icons.person,
                color: Colors.grey[600],
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle(DocumentSnapshot member) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: member['email'])
          .limit(1)
          .get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
          final userData =
              userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
          return Text(userData['username'] ?? 'Not specified');
        }
        return const Text('Loading...');
      },
    );
  }

  Widget _buildTrailingMenu(DocumentSnapshot member, bool isAdmin) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.hasData) {
          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
          final bool isCreator = member['email'] == groupData['creatorEmail'];

          if (isCreator) {
            return const SizedBox.shrink();
          }

          return PopupMenuButton<String>(
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
                  isAdmin ? 'Demote to Member' : 'Promote to Admin',
                ),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text(
                  'Remove from Group',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showRemoveConfirmation(DocumentSnapshot member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Group'),
        content:
            Text('Do you want to remove ${member['email']} from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _removeMember(member),
            child: const Text('Confirm'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(DocumentSnapshot member) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (member['email'] == groupDoc.data()?['creatorEmail']) {
        Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot remove group creator')),
          );
        }
        return;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.delete(member.reference);
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
          const SnackBar(content: Text('Member removed successfully')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.isAdmin)
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.person_add),
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
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data?.docs ?? [];

              if (members.isEmpty) {
                return const Center(child: Text('No members in group'));
              }

              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isAdmin = member['role'] == 'admin';
                  final bool isCurrentUser =
                      member['email'] == widget.currentEmail;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: _buildLeadingImage(member),
                      title: _buildTitle(member),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member['email']),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? Colors.green[100]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isAdmin ? 'Admin' : 'Member',
                              style: TextStyle(
                                fontSize: 12,
                                color: isAdmin
                                    ? const Color(0xFF0C5217)
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: widget.isAdmin && !isCurrentUser
                          ? _buildTrailingMenu(member, isAdmin)
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
