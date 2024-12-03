import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleInvitation(
      String groupId, String memberId, bool accept) async {
    if (!mounted) return;

    try {
      Navigator.pop(context);

      WriteBatch batch = FirebaseFirestore.instance.batch();

      final groupRef =
          FirebaseFirestore.instance.collection('groups').doc(groupId);
      final memberRef = groupRef.collection('members').doc(memberId);

      if (accept) {
        batch.update(memberRef, {
          'status': 'accepted',
          'joinedAt': FieldValue.serverTimestamp(),
          'role': 'member'
        });

        batch.update(groupRef, {
          'memberCount': FieldValue.increment(1),
          'memberEmails': FieldValue.arrayUnion([widget.userEmail])
        });

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully joined the group'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await memberRef.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invitation declined'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      await _loadInvitations();
    } catch (e) {
      print('Error handling invitation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
          onPressed: (_invitations?.isEmpty ?? true)
              ? null
              : () async {
                  final groupsData =
                      await Future.wait(_invitations!.map((invitation) async {
                    final groupId = invitation.reference.parent.parent!.id;
                    final groupDoc = await FirebaseFirestore.instance
                        .collection('groups')
                        .doc(groupId)
                        .get();
                    return {'invitation': invitation, 'group': groupDoc};
                  }));

                  if (!mounted) return;

                  showModalBottomSheet(
                    context: context,
                    useRootNavigator: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
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
                                  'Group Invitations',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
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
                                  final groupDoc =
                                      data['group'] as DocumentSnapshot;
                                  final invitation =
                                      data['invitation'] as QueryDocumentSnapshot;
                                  final groupData =
                                      groupDoc.data() as Map<String, dynamic>;

                                  return Card(
                                    margin: const EdgeInsets.all(8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(8),
                                      leading: FutureBuilder(
                                        future: FirebaseFirestore.instance
                                            .collection('groups')
                                            .doc(groupDoc.id)
                                            .get(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData &&
                                              snapshot.data != null) {
                                            final Map<String, dynamic>?
                                                groupData = snapshot.data!.data()
                                                    as Map<String, dynamic>?;
                                            final String? imageUrl =
                                                groupData?['imageUrl'];

                                            return CircleAvatar(
                                              radius: 25,
                                              backgroundColor:
                                                  const Color(0xFF0C5217),
                                              backgroundImage: imageUrl != null &&
                                                      imageUrl.isNotEmpty
                                                  ? (imageUrl
                                                          .startsWith('assets/')
                                                      ? AssetImage(imageUrl)
                                                          as ImageProvider
                                                      : CachedNetworkImageProvider(
                                                          imageUrl))
                                                  : null,
                                              child: imageUrl == null ||
                                                      imageUrl.isEmpty
                                                  ? const Icon(Icons.group,
                                                      color: Colors.white)
                                                  : null,
                                            );
                                          }
                                          return const CircleAvatar(
                                            radius: 25,
                                            backgroundColor: Color(0xFF0C5217),
                                            child: Icon(Icons.group,
                                                color: Colors.white),
                                          );
                                        },
                                      ),
                                      title: Text(
                                        groupData['name']?.toString() ??
                                            'Unknown Group',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Text(
                                          'From: ${groupData['creatorName'] ?? 'Unknown'}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green.withOpacity(0.1),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            onPressed: () => _handleInvitation(
                                                groupDoc.id, invitation.id, true),
                                            child: const Text('Accept',
                                                style: TextStyle(
                                                    color: Colors.green)),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              backgroundColor:
                                                  Colors.red.withOpacity(0.1),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            onPressed: () => _handleInvitation(
                                                groupDoc.id,
                                                invitation.id,
                                                false),
                                            child: const Text('Decline',
                                                style:
                                                    TextStyle(color: Colors.red)),
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