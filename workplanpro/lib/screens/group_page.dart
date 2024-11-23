import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
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
    _initGroupsStream();
  }

  void _initGroupsStream() {
    _groupsStream = FirebaseFirestore.instance
        .collection('groups')
        .where('memberEmails', arrayContains: widget.userEmail)
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(25),
          ),
          child:
              data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.network(
                        data['imageUrl'].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.group, color: Colors.grey[400]),
                      ),
                    )
                  : Icon(Icons.group, color: Colors.grey[400], size: 30),
        ),
        title: Text(
          data['name']?.toString() ?? 'Unnamed Group',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['description']?.toString().isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  data['description']?.toString() ?? '',
                  style: TextStyle(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  '${data['memberCount']?.toString() ?? '0'} members',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (isCreator) ...[
                  SizedBox(width: 8),
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  SizedBox(width: 4),
                  Text(
                    'Creator',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
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
    );
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบกลุ่ม'),
        content: Text('คุณต้องการลบกลุ่มนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C5217),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C5217),
        title: const Text('Group List', style: TextStyle(color: Colors.white)),
        elevation: 0,
        actions: [
          NotificationWidget(userEmail: widget.userEmail), // เปลี่ยนชื่อ class
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                hintText: 'Search groups...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _groupsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final groups = _filterGroups(snapshot.data?.docs ?? []);

                  if (groups.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No groups found\nTap + to create a new group',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      return Dismissible(
                        key: Key(groups[index].id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          color: Colors.red,
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) =>
                            _showDeleteConfirmDialog(),
                        onDismissed: (direction) async {
                          try {
                            final data =
                                groups[index].data() as Map<String, dynamic>;
                            if (data['creatorEmail'] == widget.userEmail) {
                              await FirebaseFirestore.instance
                                  .collection('groups')
                                  .doc(groups[index].id)
                                  .delete();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('ลบกลุ่มเรียบร้อยแล้ว')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('คุณไม่มีสิทธิ์ลบกลุ่มนี้')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('เกิดข้อผิดพลาดในการลบกลุ่ม')),
                            );
                          }
                        },
                        child: _buildGroupCard(groups[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
        backgroundColor: const Color(0xFF0C5217),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "New Group",
          style: TextStyle(color: Colors.white),
        ),
      ),
      bottomNavigationBar: MotionTabBar(
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
              // Already in Group page
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
