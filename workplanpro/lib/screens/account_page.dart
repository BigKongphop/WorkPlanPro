import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workplanpro/screens/calendar_page.dart';
import 'package:workplanpro/screens/group_page.dart';
import 'package:workplanpro/screens/home_page.dart';
import 'package:workplanpro/screens/note_page.dart';
import 'login_page.dart';

class AccountDetailRow extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onEdit;

  const AccountDetailRow({
    Key? key,
    required this.title,
    required this.controller,
    required this.onEdit,
    this.obscureText = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter $title',
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _currentIndex = 1; // กำหนดให้ AccountPage เป็นหน้าเริ่มต้น

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // ดึงข้อมูล userData จาก arguments ที่ส่งมา
      await Future.delayed(Duration.zero);
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        // ใช้ username จาก arguments เพื่อดึงข้อมูลล่าสุดจาก Firestore
        final username = args['username'];
        final userDoc = await FirebaseFirestore.instance
            .collection('user')
            .where('username', isEqualTo: username)
            .get();

        if (userDoc.docs.isNotEmpty) {
          setState(() {
            userData = userDoc.docs.first.data();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0C5217),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0C5217)),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Profile Image
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0C5217),
                          width: 3,
                        ),
                      ),
                      child: const CircleAvatar(
                        backgroundColor: Color(0xFF0C5217),
                        child: Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // User Information
                    if (userData != null) ...[
                      _buildInfoCard(
                        'ชื่อผู้ใช้',
                        userData!['username'] ?? 'N/A',
                        Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        'อีเมล',
                        userData!['email'] ?? 'N/A',
                        Icons.email,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        'เบอร์โทรศัพท์',
                        userData!['phone'] ?? 'N/A',
                        Icons.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        'ที่อยู่',
                        userData!['address'] ?? 'N/A',
                        Icons.location_on,
                      ),
                    ],
                  ],
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
              MaterialPageRoute(builder: (context) => HomePage()),
            );
            break;
          case 1:
            // ไม่ต้องทำอะไร เพราะอยู่ในหน้า AccountPage
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => NotePage()),
            );
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CalendarPage()),
            );
            break;
          case 4:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => GroupPage()),
            );
            break;
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
          Icon(
            icon,
            color:
                _currentIndex == index ? Colors.white : const Color(0xFF0C5217),
          ),
          Text(
            label,
            style: TextStyle(
              color: _currentIndex == index
                  ? Colors.white
                  : const Color(0xFF0C5217),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildInfoCard(String label, String value, IconData icon) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0C5217), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
