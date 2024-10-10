import 'package:flutter/material.dart';
import 'home_page.dart';
import 'notification_page.dart';
import 'calendar_page.dart';
import 'group_page.dart';
import 'login_page.dart';
import '../models/user_database.dart'; // Import UserDatabase
import '../models/personal.dart';

class AccountPage extends StatefulWidget {
  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  int _currentIndex = 1;
  User? user;
  final UserDatabase _userDatabase = UserDatabase();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load user data on init
  }

  Future<void> _loadUserData() async {
    user = await _userDatabase.fetchUser();
    if (user != null) {
      _usernameController.text = user!.username; // Pre-fill the text fields
      _emailController.text = user!.email;
    }
    setState(() {});
  }

  Future<void> _editUser() async {
    if (user != null) {
      final updatedUser = User(
        username: _usernameController.text,
        email: _emailController.text,
        password: user!.password, // Retain the existing password
      );
      await _userDatabase.updateUser(updatedUser); // Update user in database
      _loadUserData(); // Reload user data to reflect changes
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        foregroundColor: Colors.white,
        title: Text('ACCOUNT'),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        color: Color(0xFFEFEFEF),
        child: user == null
            ? Center(
                child: CircularProgressIndicator()) // Show loading indicator
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF0C5217),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 45,
                            backgroundImage:
                                AssetImage('assets/profile_placeholder.png'),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 10,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    user!.username,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  AccountDetailRow(
                    title: 'Username',
                    detail: user!.username,
                    controller: _usernameController,
                    onEdit: _editUser,
                  ),
                  AccountDetailRow(
                    title: 'Email',
                    detail: user!.email,
                    controller: _emailController,
                    onEdit: _editUser,
                  ),
                  AccountDetailRow(
                    title: 'Phone number',
                    detail: '06-2589-6377', // Static for now
                    controller: TextEditingController(),
                    onEdit: () {}, // No edit functionality for phone
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text('Log out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5A5A5A),
                      padding:
                          EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                      textStyle: TextStyle(fontSize: 18),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => NotificationPage()),
              );
              break;
            case 1:
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
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
        unselectedItemColor: Color(0xFF0C5217),
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
      ),
    );
  }

  Widget _buildNavBarItem(IconData icon, String label, int index) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: _currentIndex == index ? Color(0xFF0C5217) : Colors.transparent,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: _currentIndex == index ? Colors.white : Color(0xFF0C5217)),
          Text(
            label,
            style: TextStyle(
                color:
                    _currentIndex == index ? Colors.white : Color(0xFF0C5217)),
          )
        ],
      ),
    );
  }
}

class AccountDetailRow extends StatelessWidget {
  final String title;
  final String detail;
  final TextEditingController controller;
  final VoidCallback onEdit;

  AccountDetailRow({
    required this.title,
    required this.detail,
    required this.controller,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 5,
            child: TextField(
              controller: controller,
              readOnly: detail == 'Phone number', // Make phone read-only
              decoration: InputDecoration(
                hintText: detail,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onEdit,
            child: Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5A5A5A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
