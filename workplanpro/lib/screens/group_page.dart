//group
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'note_page.dart';
import 'account_page.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import '../widgets/group_invite_notifications.dart';

class GroupPage extends StatefulWidget {
  final String username;
  final String userEmail;

  const GroupPage({
    Key? key,
    required this.username,
    required this.userEmail,
  }) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  int _currentIndex = 4;
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Stream<QuerySnapshot> _groupsStream;

  @override
  void initState() {
    super.initState();
    _initializeGroupOrder();
    _initGroupsStream();
  }

  Future<void> _initializeGroupOrder() async {
    try {
      final QuerySnapshot groups = await FirebaseFirestore.instance
          .collection('groups')
          .where('memberEmails', arrayContains: widget.userEmail)
          .get();

      int order = 0;
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in groups.docs) {
        if ((doc.data() as Map<String, dynamic>)['order'] == null) {
          batch.update(doc.reference, {'order': order});
          order++;
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error initializing group order: $e');
    }
  }

  void _initGroupsStream() {
    _groupsStream = FirebaseFirestore.instance
        .collection('groups')
        .where('memberEmails', arrayContains: widget.userEmail)
        .orderBy('order', descending: false)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterGroups(
      List<QueryDocumentSnapshot> groups) {
    if (_searchQuery.isEmpty) return groups;
    return groups.where((group) {
      final data = group.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final description = data['description']?.toString().toLowerCase() ?? '';
      final searchLower = _searchQuery.toLowerCase();
      return name.contains(searchLower) || description.contains(searchLower);
    }).toList();
  }

  Widget _buildGroupCard(QueryDocumentSnapshot group) {
    final data = group.data() as Map<String, dynamic>;
    final bool isCreator = data['creatorEmail'] == widget.userEmail;

    return Dismissible(
      key: Key(group.id),
      direction: DismissDirection.endToStart,
      background: Container(
        height: 85,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isCreator ? Colors.red : Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(isCreator ? Icons.delete : Icons.exit_to_app,
            color: Colors.white, size: 20),
      ),
      confirmDismiss: (direction) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
              isCreator ? 'Confirm Group Deletion' : 'Confirm Leave Group'),
          content: Text(isCreator
              ? 'Are you sure you want to delete this group?'
              : 'Are you sure you want to leave this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                isCreator ? 'Delete' : 'Leave',
                style: TextStyle(color: isCreator ? Colors.red : Colors.orange),
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) async {
        try {
          if (isCreator) {
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(group.id)
                .delete();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Group deleted successfully')),
            );
          } else {
            final List<String> memberEmails =
                List<String>.from(data['memberEmails'] ?? []);
            memberEmails.remove(widget.userEmail);

            await FirebaseFirestore.instance
                .collection('groups')
                .doc(group.id)
                .update({
              'memberEmails': memberEmails,
              'memberCount': FieldValue.increment(-1)
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Left group successfully')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  isCreator ? 'Error deleting group' : 'Error leaving group'),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          height: 85,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: data['imageUrl'] != null &&
                        data['imageUrl'].toString().isNotEmpty
                    ? (data['imageUrl'].toString().startsWith('assets/')
                        ? Image.asset(
                            data['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading asset image: $error');
                              return Icon(Icons.group, color: Colors.grey[400]);
                            },
                          )
                        : CachedNetworkImage(
                            imageUrl: data['imageUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0C5217),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              print('Error loading network image: $error');
                              return Icon(Icons.group, color: Colors.grey[400]);
                            },
                          ))
                    : Icon(Icons.group, color: Colors.grey[400]),
              ),
            ),
            title: Text(
              data['name']?.toString().replaceAll(RegExp(r'\s*\(\d+\)'), '') ??
                  'Unnamed Group',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${data['memberCount']?.toString() ?? '0'} members',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (isCreator) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    'Creator',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupDetailScreen(
                    groupId: group.id,
                    username: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm group deletion'),
        content: const Text('Do you want to delete this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // เปลี่ยนพื้นหลังเป็นขาว
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'My Groups',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: _buildGroupPageHeader(),
            ),
            actions: [
              NotificationWidget(userEmail: widget.userEmail),
            ],
          ),
        ],
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _buildGroupList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildCreateGroupButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget NotificationWidget({required String userEmail}) {
    return FutureBuilder<int>(
      future: _fetchPendingInvitations(userEmail),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return IconButton(
            icon: Icon(Icons.notifications_none, color: Colors.white),
            onPressed: null,
          );
        }

        int pendingInvitations = snapshot.data ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none, color: Colors.white),
              onPressed: () {
                // Navigation logic for notifications
              },
            ),
            if (pendingInvitations > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$pendingInvitations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<int> _fetchPendingInvitations(String userEmail) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('members')
          .where('email', isEqualTo: userEmail)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching pending invitations: $e');
      return 0;
    }
  }

  Widget _buildGroupPageHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C8C4B), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 80,
            color: Colors.white,
          ),
          SizedBox(height: 15),
          Text(
            'Collaborate & Connect',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade100,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Search groups...',
            prefixIcon: Icon(Icons.search, color: Color(0xFF0C5217)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.green.shade100),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _groupsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        final groups = snapshot.data?.docs ?? [];

        if (groups.isEmpty) {
          return _buildEmptyState();
        }

        return ReorderableListView.builder(
          itemCount: groups.length,
          onReorder: _reorderGroups,
          itemBuilder: (context, index) {
            return _buildGroupCard(groups[index]);
          },
        );
      },
    );
  }
// Add these methods to the _GroupPageState class

// Create Group Button
  Widget _buildCreateGroupButton() {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateGroupScreen(
              currentUsername: widget.username,
              currentEmail: widget.userEmail,
            ),
          ),
        );

        if (result == true) {
          setState(() {});
        }
      },
      backgroundColor: Color(0xFF0C5217),
      icon: Icon(Icons.add, color: Colors.white),
      label: Text(
        "Create Group",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

// Error State
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'Failed to load groups',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          Text(
            'Please check your connection',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

// Loading State
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C5217)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading Groups...',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

// Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off_outlined,
            size: 80,
            color: Colors.green.shade200,
          ),
          SizedBox(height: 16),
          Text(
            'No Groups Yet',
            style: TextStyle(
              color: Color(0xFF0C5217),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first group and start collaborating!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateGroupScreen(
                    currentUsername: widget.username,
                    currentEmail: widget.userEmail,
                  ),
                ),
              );

              if (result == true) {
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0C5217),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Create First Group',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

// Reorder Groups Method
  void _reorderGroups(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    try {
      final QuerySnapshot? querySnapshot = await _groupsStream.first;
      final groups = querySnapshot?.docs ?? [];

      final batch = FirebaseFirestore.instance.batch();
      final item = groups.removeAt(oldIndex);
      groups.insert(newIndex, item);

      for (var i = 0; i < groups.length; i++) {
        batch.update(groups[i].reference, {'order': i});
      }

      await batch.commit();
    } catch (e) {
      print('Error reordering groups: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating group order')),
      );
    }
  }

// Group Avatar Builder
  Widget _buildGroupAvatar(Map<String, dynamic> data) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(25),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child:
            data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                ? Image.network(
                    data['imageUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.group,
                        color: Colors.green.shade700,
                      );
                    },
                  )
                : Icon(
                    Icons.group,
                    color: Colors.green.shade700,
                  ),
      ),
    );
  }

// Navigation to Group Detail
  void _navigateToGroupDetail(QueryDocumentSnapshot group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(
          groupId: group.id,
          username: widget.username,
          userEmail: widget.userEmail,
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return SafeArea(
      // เพิ่ม SafeArea เพื่อป้องกัน overflow
      child: MotionTabBar(
        labels: const ["Home", "Account", "Notes", "Calendar", "Groups"],
        icons: const [
          Icons.home,
          Icons.person,
          Icons.book,
          Icons.calendar_today,
          Icons.group
        ],
        initialSelectedTab: "Groups",
        tabIconColor: const Color(0xFF0C5217),
        tabSelectedColor: Colors.green,
        onTabItemSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    username: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountPage(
                    initialUsername: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => NotePage(
                    username: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarPage(
                    username: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
              break;
            case 4:
              break;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
