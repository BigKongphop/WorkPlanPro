//group page
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'note_page.dart';
import 'account_page.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';

class GroupPage extends StatefulWidget {
  final String username;

  const GroupPage({Key? key, required this.username}) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  int _currentIndex = 4;
  List<Map<String, dynamic>> groups = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => isLoading = true);
    try {
      final QuerySnapshot groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        groups = groupsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {...data, 'docId': doc.id};
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading groups: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading groups: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get filteredGroups {
    if (_searchQuery.isEmpty) return groups;
    return groups.where((group) {
      final name = group['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _deleteGroup(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('groups').doc(docId).delete();
      await _loadGroups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting group: $e')),
      );
    }
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> group) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Group'),
          content: Text('Are you sure you want to delete this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteGroup(group['docId']);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C5217),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C5217),
        title: const Text('Group List', style: TextStyle(color: Colors.white)),
        elevation: 0,
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
                hintText: 'Search...',
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
              child: isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF0C5217)))
                  : ListView.builder(
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        return Dismissible(
                          key: Key(group['docId']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade700,
                              size: 24,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            await _showDeleteConfirmation(group);
                            return false;
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                child:
                                    Icon(Icons.group, color: Colors.grey[600]),
                              ),
                              title: Text(
                                group['name'] ?? 'Unnamed Group',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                  'Created by: ${group['creatorName'] ?? 'Unknown'}'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GroupDetailScreen(
                                      groupId: group['docId'],
                                      username: widget.username,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
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
              builder: (context) =>
                  CreateGroupScreen(currentUsername: widget.username),
            ),
          );
          if (result == true) {
            _loadGroups();
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
          Icons.group,
        ],
        initialSelectedTab: "Groups",
        tabIconColor: const Color(0xFF0C5217),
        tabSelectedColor:
            Colors.green, // เปลี่ยนสีพื้นหลังของไอเทมที่เลือกเป็นสีเขียว
        onTabItemSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          HomePage(username: widget.username)));
              break;
            case 1:
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          AccountPage(initialUsername: widget.username)));
              break;
            case 2:
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          NotePage(username: widget.username)));
              break;
            case 3:
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          CalendarPage(username: widget.username)));
              break;
            case 4:
              break;
          }
        },
      ),
    );
  }
}
