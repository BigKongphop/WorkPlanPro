import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'note_page.dart';
import 'account_page.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'create_group_screen.dart';

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
        groups = groupsSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading groups: $e');
      setState(() => isLoading = false);
    }
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
                      child: CircularProgressIndicator(
                      color: Color(0xFF0C5217),
                    ))
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            backgroundImage: group['imageUrl'] != null &&
                                    group['imageUrl'].isNotEmpty
                                ? NetworkImage(group['imageUrl'])
                                : null,
                            child: group['imageUrl'] == null ||
                                    group['imageUrl'].isEmpty
                                ? Icon(Icons.group,
                                    color: Colors.grey[600])
                                : null,
                          ),
                          title: Text(
                            group['name'] ?? 'Unnamed Group',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              Text('Created by: ${group['creatorName'] ?? 'Unknown'}'),
                          trailing: const Icon(Icons.more_vert),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CreateGroupScreen(currentUsername: widget.username),
              ),
            );
            if (result == true) {
              _loadGroups(); // Reload groups after creation
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0C5217),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "New Group",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        switch (index) {
          case 0:
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => HomePage(username: widget.username)));
          case 1:
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        AccountPage(username: widget.username)));
          case 2:
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => NotePage(username: widget.username)));
          case 3:
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        CalendarPage(username: widget.username)));
          case 4:
            break; // อยู่ที่หน้า Group อยู่แล้ว
        }
      },
      selectedItemColor: Colors.white,
      unselectedItemColor: const Color(0xFF0C5217),
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: _buildNavBarItem(Icons.home, 'Home', 0),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: _buildNavBarItem(Icons.person, 'Account', 1),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: _buildNavBarItem(Icons.book, 'Note', 2),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: _buildNavBarItem(Icons.calendar_today, 'Calendar', 3),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: _buildNavBarItem(Icons.group, 'Group', 4),
          label: '',
        ),
      ],
    );
  }

  Widget _buildNavBarItem(IconData icon, String label, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: _currentIndex == index
            ? const Color(0xFF0C5217)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: _currentIndex == index
                  ? Colors.white
                  : const Color(0xFF0C5217)),
          Text(
            label,
            style: TextStyle(
                color: _currentIndex == index
                    ? Colors.white
                    : const Color(0xFF0C5217)),
          )
        ],
      ),
    );
  }
}