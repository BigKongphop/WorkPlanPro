import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'login_page.dart';
import 'note_page.dart';
import 'calendar_page.dart';
import 'group_page.dart';
import 'home_page.dart';
import 'EditProfilePage.dart';

class AccountPage extends StatefulWidget {
  final String initialUsername;
  final String userEmail;

  const AccountPage({
    Key? key,
    required this.initialUsername,
    required this.userEmail,
  }) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  int _currentIndex = 1;
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _showQuickActions = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (mounted) {
          setState(() {
            _userData = userData.data() ?? {};
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileImage() {
    String? profileImageUrl = _userData['profileImageUrl'];
    
    if (profileImageUrl == null || profileImageUrl.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: 60,
          color: Colors.white,
        ),
      );
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
      ),
      child: ClipOval(
        child: Image.asset(
          profileImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading profile image: $error');
            return Icon(
              Icons.person,
              size: 60,
              color: Colors.white,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        title: Text('My Account', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(userData: _userData),
                ),
              );
              if (result == true) {
                _loadUserData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section with Green Background
                  Container(
                    color: Color(0xFF0C5217),
                    padding: EdgeInsets.symmetric(vertical: 20),
                    width: double.infinity,
                    child: Column(
                      children: [
                        _buildProfileImage(),
                        SizedBox(height: 10),
                        Text(
                          _userData['username'] ?? widget.initialUsername,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.userEmail,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contact Information
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(
                          icon: Icons.phone,
                          title: 'Phone Number',
                          value: _userData['phone'] ?? '',
                        ),
                        SizedBox(height: 8),
                        _buildInfoCard(
                          icon: Icons.location_on,
                          title: 'Address',
                          value: _userData['address'] ?? '',
                        ),
                        
                        SizedBox(height: 16),
                        Text(
                          'Additional Information',
                          style: TextStyle(
                            color: Color(0xFF0C5217),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        
                        _buildInfoCard(
                          icon: Icons.calendar_today,
                          title: 'Registration Date',
                          value: _formatTimestamp(_userData['createdAt']),
                        ),
                        SizedBox(height: 8),
                        _buildInfoCard(
                          icon: Icons.access_time,
                          title: 'Last Updated',
                          value: _formatTimestamp(_userData['lastUpdated']),
                        ),

                        if (_showQuickActions) ...[
                          SizedBox(height: 16),
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              color: Color(0xFF0C5217),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to Edit Username
                            },
                            icon: Icon(Icons.edit),
                            label: Text('Edit Username'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0C5217),
                              minimumSize: Size(double.infinity, 45),
                            ),
                          ),
                        ],

                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[400],
                            minimumSize: Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Logout',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      if (timestamp is Timestamp) {
        DateTime dateTime = timestamp.toDate();
        return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} น.';
      }
    } catch (e) {
      print('Error formatting timestamp: $e');
    }
    return 'Unknown';
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
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

  Widget _buildBottomNavigationBar() {
    return MotionTabBar(
      labels: const ["Home", "Account", "Notes", "Calendar", "Groups"],
      icons: const [
        Icons.home,
        Icons.person,
        Icons.book,
        Icons.calendar_today,
        Icons.group
      ],
      initialSelectedTab: "Account",
      tabIconColor: const Color(0xFF0C5217),
      tabSelectedColor: Colors.green,
      onTabItemSelected: (int index) {
        setState(() => _currentIndex = index);
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  username: widget.initialUsername,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;
          case 1:
            // Already in Account page
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => NotePage(
                  username: widget.initialUsername,
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
                  username: widget.initialUsername,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;
          case 4:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GroupPage(
                  username: widget.initialUsername,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;
        }
      },
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }
}