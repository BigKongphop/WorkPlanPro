import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shimmer/shimmer.dart';
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

class _AccountPageState extends State<AccountPage>
    with SingleTickerProviderStateMixin {
  int _pendingInvitations = 0;
  int _currentIndex = 1;
  Map<String, dynamic> _userData = {};
  List<Map<String, dynamic>> _userActivities = [];
  List<Map<String, dynamic>> _userNotifications = [];
  List<Map<String, dynamic>> _userGroups = [];
  bool _isLoading = true;
  int _totalActivitiesCount = 0;

  bool _isTimeoutOccurred = false;
  Timer? _loadingTimer;
  static const int MINIMUM_LOADING_TIME = 2; // วินาที
  static const int MAXIMUM_LOADING_TIME = 10; // วินาที

  final ThemeData appTheme = ThemeData(
    primarySwatch: Colors.green,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.green.shade700,
      primary: Colors.green.shade700,
      secondary: Colors.greenAccent.shade400,
      background: Colors.green.shade50,
    ),
    fontFamily: 'Prompt',
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadingTimer = Timer(Duration(seconds: MINIMUM_LOADING_TIME), () {
      if (mounted && _isLoading) {
        _loadAllUserData();
      }
    });

    _loadAllUserData();
    _loadUserData();
    _fetchUserActivities();
    _fetchUserNotifications();
    _fetchUserGroups();
    _fetchPendingInvitations();
  }

  Future<void> _fetchPendingInvitations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('members')
          .where('email', isEqualTo: widget.userEmail)
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _pendingInvitations = snapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error fetching pending invitations: $e');
    }
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

// ใน account_page.dart
  Future<void> _fetchUserGroups() async {
    try {
      // ดึงกลุ่มที่มี email อยู่ใน memberEmails
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('memberEmails', arrayContains: widget.userEmail)
          .get();

      setState(() {
        _userGroups = groupsSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'name': doc.data()['name'] ?? 'Unnamed Group',
                })
            .toList();
      });
    } catch (e) {
      print('Error fetching groups: $e');
    }
  }

  Future<void> _loadAllUserData() async {
    final startTime = DateTime.now();

    setState(() {
      _isLoading = true;
      _userActivities = [];
      _userGroups = [];
      _userNotifications = [];
      _totalActivitiesCount = 0;
      _pendingInvitations = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // สร้าง Map เพื่อเก็บข้อมูลทั้งหมด
        Map<String, dynamic> allData = {
          'userData': {},
          'activities': [],
          'totalActivitiesCount': 0,
          'groups': [],
          'notifications': [],
          'pendingInvitations': 0
        };

        // เพิ่ม Future.wait เพื่อรอให้ทุก Future โหลดเสร็จ
        await Future.wait([
          // ดึงข้อมูลผู้ใช้
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .then((snapshot) {
            allData['userData'] = snapshot.data() ?? {};
          }).catchError((error) {
            print('Error loading user data: $error');
          }),

          // ดึงกิจกรรม
          FirebaseFirestore.instance
              .collection('activities')
              .where('userId', isEqualTo: user.uid)
              .limit(5)
              .get()
              .then((snapshot) {
            allData['activities'] = snapshot.docs
                .map((doc) =>
                    {...doc.data() as Map<String, dynamic>, 'id': doc.id})
                .toList();
          }).catchError((error) {
            print('Error loading activities: $error');
          }),

          // นับจำนวนกิจกรรมทั้งหมด
          FirebaseFirestore.instance
              .collection('activities')
              .where('userId', isEqualTo: user.uid)
              .count()
              .get()
              .then((snapshot) {
            allData['totalActivitiesCount'] = snapshot.count;
          }).catchError((error) {
            print('Error counting activities: $error');
          }),

          // ดึงกลุ่ม
          FirebaseFirestore.instance
              .collection('groups')
              .where('memberEmails', arrayContains: widget.userEmail)
              .limit(5)
              .get()
              .then((snapshot) {
            allData['groups'] = snapshot.docs
                .map((doc) => {
                      'id': doc.id,
                      'name': (doc.data() as Map<String, dynamic>)['name'] ??
                          'Unnamed Group',
                    })
                .toList();
          }).catchError((error) {
            print('Error loading groups: $error');
          }),

          // ดึงการแจ้งเตือน
          FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .where('isRead', isEqualTo: false)
              .limit(5)
              .get()
              .then((snapshot) {
            allData['notifications'] = snapshot.docs
                .map((doc) => {
                      ...doc.data() as Map<String, dynamic>,
                      'id': doc.id,
                    })
                .toList();
          }).catchError((error) {
            print('Error loading notifications: $error');
          }),

          // ดึงคำเชิญที่รอการตอบรับ
          FirebaseFirestore.instance
              .collectionGroup('members')
              .where('email', isEqualTo: widget.userEmail)
              .where('status', isEqualTo: 'pending')
              .get()
              .then((snapshot) {
            allData['pendingInvitations'] = snapshot.docs.length;
          }).catchError((error) {
            print('Error loading pending invitations: $error');
          }),
        ]);

        final loadDuration = DateTime.now().difference(startTime);
        final minimumLoadTime = Duration(seconds: MINIMUM_LOADING_TIME);

        // ถ้าโหลดเร็วกว่า 2 วินาที ให้รอจนครบ
        if (loadDuration < minimumLoadTime) {
          await Future.delayed(minimumLoadTime - loadDuration);
        }

        // ตรวจสอบว่า widget ยังคงอยู่และ mounted
        if (mounted) {
          setState(() {
            // กำหนดค่าจากข้อมูลที่โหลด
            _userData = allData['userData'] ?? {};
            _userActivities = allData['activities'] ?? [];
            _totalActivitiesCount = allData['totalActivitiesCount'] ?? 0;
            _userGroups = allData['groups'] ?? [];
            _userNotifications = allData['notifications'] ?? [];
            _pendingInvitations = allData['pendingInvitations'] ?? 0;

            // ปิด Loading State
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // จัดการข้อผิดพลาด
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => _buildErrorState(errorMessage),
    );
  }

  Future<void> _fetchUserGroupsAsync() async {
    try {
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('memberEmails', arrayContains: widget.userEmail)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          _userGroups = groupsSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'name': doc.data()['name'] ?? 'Unnamed Group',
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching groups: $e');
    }
  }

  Future<void> _fetchUserNotificationsAsync() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('isRead', isEqualTo: false)
            .limit(5)
            .get();

        if (mounted) {
          setState(() {
            _userNotifications = notificationsSnapshot.docs
                .map((doc) => {
                      ...doc.data(),
                      'id': doc.id,
                    })
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<void> _fetchPendingInvitationsAsync() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('members')
          .where('email', isEqualTo: widget.userEmail)
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _pendingInvitations = snapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error fetching pending invitations: $e');
    }
  }

  Future<void> _fetchUserActivities() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // First, get the total count of activities
        final totalCountQuery = await FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: user.uid)
            .count()
            .get();

        final activitiesSnapshot = await FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: user.uid)
            .limit(5)
            .get();

        setState(() {
          _userActivities = activitiesSnapshot.docs
              .map((doc) => {
                    ...doc.data(),
                    'id': doc.id,
                  })
              .toList();
          _totalActivitiesCount = totalCountQuery.count!;
        });
      }
    } catch (e) {
      print('Error fetching activities: $e');
    }
  }

  Future<void> _fetchUserNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('isRead', isEqualTo: false)
            .limit(5)
            .get();

        setState(() {
          _userNotifications = notificationsSnapshot.docs
              .map((doc) => {
                    ...doc.data(),
                    'id': doc.id,
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Widget _buildAccountStatistics() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
              'Activities',
              _userActivities.length == 5 && _totalActivitiesCount > 5
                  ? '5+'
                  : _userActivities.length.toString(),
              FontAwesomeIcons.chartLine),
          _buildStatItem(
              'Notifications',
              _pendingInvitations > 5 ? '5+' : _pendingInvitations.toString(),
              FontAwesomeIcons.bell),
          _buildStatItem(
              'Groups',
              _userGroups.length == 5 && _userGroups.length > 5
                  ? '5+'
                  : _userGroups.length.toString(),
              FontAwesomeIcons.users),
        ],
      ),
    );
  }

  Widget _buildContactInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Contact Information'),
        ContactInfoCard(
          icon: FontAwesomeIcons.phoneVolume,
          title: 'Phone Number',
          value: _userData['phone'] ?? 'Not provided',
          color: Colors.blue,
        ),
        ContactInfoCard(
          icon: FontAwesomeIcons.mapMarkerAlt,
          title: 'Address',
          value: _userData['address'] ?? 'Not provided',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildAdditionalInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Additional Information'),
        ContactInfoCard(
          icon: FontAwesomeIcons.calendarPlus,
          title: 'Registration Date',
          value: _formatTimestamp(_userData['createdAt']),
          color: Colors.green,
        ),
        ContactInfoCard(
          icon: FontAwesomeIcons.sync,
          title: 'Last Updated',
          value: _formatTimestamp(_userData['lastUpdated']),
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildRecentActivitiesSection() {
    print(
        'Building Recent Activities: ${_userActivities.length} activities'); // Debug print
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Recent Activities'),
        _userActivities.isEmpty
            ? _buildEmptyStateWidget('No recent activities')
            : Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: _userActivities.map((activity) {
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade100,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: FaIcon(
                            FontAwesomeIcons.playCircle,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          activity['title'] ?? 'Activity',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                        subtitle: Text(
                          activity['description'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }

  Widget _buildProfileImage() {
    String? profileImageUrl = _userData['profileImageUrl'];

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200,
            blurRadius: 15,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: ClipOval(
        child: profileImageUrl != null && profileImageUrl.isNotEmpty
            ? Image.asset(
                profileImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.green.shade700,
                ),
              )
            : Container(
                color: Colors.green.shade100,
                child: Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.green.shade700,
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.green.shade700,
            size: 24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingState()
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 350.0,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: Text(
                      'My Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: _buildProfileHeader(),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.white),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditProfilePage(userData: _userData),
                          ),
                        );
                        if (result == true) {
                          _loadUserData();
                        }
                      },
                    ),
                  ],
                ),
              ],
              body: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildAccountStatistics(),
                  SizedBox(height: 16),
                  _buildRecentActivitiesSection(),
                  SizedBox(height: 16),
                  _buildContactInformationSection(),
                  SizedBox(height: 16),
                  _buildAdditionalInformationSection(),
                  SizedBox(height: 16),
                  _buildLogoutButton(),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildRecentNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Recent Notifications'),
        _userNotifications.isEmpty
            ? _buildEmptyStateWidget('No new notifications')
            : Column(
                children: _userNotifications.map((notification) {
                  return ListTile(
                    leading: Icon(
                      Icons.notifications_active,
                      color: Colors.red.shade700,
                    ),
                    title: Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      notification['message'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildEmptyStateWidget(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo with Pulse Effect
              _buildAnimatedLogo(),

              SizedBox(height: 40),

              // Sleek Loading Progress Indicator
              _buildSleekProgressIndicator(),

              SizedBox(height: 30),

              // Professional Loading Text
              _buildProfessionalLoadingText(),

              SizedBox(height: 20),

              // Descriptive Subtext
              _buildLoadingSubtext(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return TweenAnimationBuilder<double>(
      duration: Duration(seconds: 1),
      tween: Tween(begin: 0.8, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade500,
                  Colors.green.shade800,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade200,
                  blurRadius: 25,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.cloud_download, // More professional download icon
                color: Colors.white,
                size: 100,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSleekProgressIndicator() {
    return Container(
      width: 300,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TweenAnimationBuilder<double>(
        duration: Duration(seconds: 2),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, progress, child) {
          return FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade400,
                    Colors.green.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfessionalLoadingText() {
    return Text(
      'Preparing Your Download',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.green.shade800,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildLoadingSubtext() {
    return Text(
      'Optimizing resources for a smooth experience...',
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 16,
        fontStyle: FontStyle.italic,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoadingText() {
    return TweenAnimationBuilder<double>(
      duration: Duration(seconds: 1),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Text(
            'Loading Your Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
              letterSpacing: 1.2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomProgressIndicator() {
    return Container(
      width: 250,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TweenAnimationBuilder<double>(
        duration: Duration(seconds: 2),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, progress, child) {
          return FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade400,
                    Colors.green.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescriptiveText() {
    return TweenAnimationBuilder<double>(
      duration: Duration(seconds: 1),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Text(
            'Preparing your personalized experience...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

// Bonus: Animated Error State
  Widget _buildErrorState(String errorMessage) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon with Animation
            TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 500),
              tween: Tween(begin: 0.5, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red.shade400,
                    size: 100,
                  ),
                );
              },
            ),

            SizedBox(height: 20),

            // Error Title
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),

            SizedBox(height: 10),

            // Error Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                errorMessage,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: 30),

            // Retry Button
            ElevatedButton(
              onPressed: () {
                // Implement retry logic
                _loadAllUserData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerHeader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 350,
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shimmer Profile Image
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 15),

            // Shimmer Username
            Container(
              width: 200,
              height: 24,
              color: Colors.white,
            ),
            SizedBox(height: 8),

            // Shimmer Email
            Container(
              width: 150,
              height: 16,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerStatistics() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: 50,
                height: 16,
                color: Colors.white,
              ),
              SizedBox(height: 4),
              Container(
                width: 40,
                height: 12,
                color: Colors.white,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildShimmerSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shimmer Section Title
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 150,
            height: 24,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),

        // Shimmer List Items
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            children: List.generate(3, (index) {
              return Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C8C4B), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProfileImage(),
              SizedBox(height: 15),
              Text(
                _userData['username'] ?? widget.initialUsername,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.userEmail,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Color(0xFF0C5217),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: appTheme.colorScheme.secondary.withOpacity(0.1),
          child: Icon(icon, color: appTheme.colorScheme.secondary),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value.isEmpty ? 'Not provided' : value,
          style: TextStyle(
            fontSize: 16,
            color: value.isEmpty ? Colors.grey : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade200,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
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

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }
}

class ContactInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const ContactInfoCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: FaIcon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: value == 'Not provided' ? Colors.grey : Colors.black87,
          ),
        ),
      ),
    );
  }
}
