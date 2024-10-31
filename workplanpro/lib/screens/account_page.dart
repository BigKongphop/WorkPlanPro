import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'calendar_page.dart';
import 'group_page.dart';
import 'home_page.dart';
import 'note_page.dart';
import 'login_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _currentIndex = 1;
  String? currentUsername;
  Timer? _retryTimer;
  bool _hasInternetConnection = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _checkConnectivityAndLoadData();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _checkConnectivityAndLoadData() async {
    bool hasInternet = await _checkInternetConnection();
    if (mounted) {
      setState(() => _hasInternetConnection = hasInternet);
    }

    if (hasInternet) {
      await _loadUserData();
    } else {
      await _loadLocalUserData();
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _checkConnectivityAndLoadData();
      }
    });
  }

  Future<void> _loadLocalUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      if (username != null) {
        setState(() {
          userData = {
            'username': username,
            'email': prefs.getString('email') ?? 'N/A',
            'phone': prefs.getString('phone') ?? 'N/A',
            'address': prefs.getString('address') ?? 'N/A',
          };
          currentUsername = username;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading local user data: $e');
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    try {
      setState(() => isLoading = true);

      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        await _saveUserDataLocally(args);
        setState(() {
          userData = Map<String, dynamic>.from(args);
          currentUsername = args['username'] as String?;
          isLoading = false;
        });
        return;
      }

      await _loadLocalUserData();

      if (userData == null && currentUsername != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('user')
            .where('username', isEqualTo: currentUsername)
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Connection timed out'),
            );

        if (userDoc.docs.isNotEmpty) {
          final firestoreData = userDoc.docs.first.data();
          await _saveUserDataLocally(firestoreData);
          if (mounted) {
            setState(() {
              userData = firestoreData;
              isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => isLoading = false);
            _showError('User data not found');
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showError('Error loading user data: $e');
      }
    }
  }

  Future<void> _saveUserDataLocally(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', data['username'] ?? '');
      await prefs.setString('email', data['email'] ?? '');
      await prefs.setString('phone', data['phone'] ?? 'N/A');
      await prefs.setString('address', data['address'] ?? 'N/A');
    } catch (e) {
      print('Error saving user data locally: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _checkConnectivityAndLoadData(),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _navigateToPage(Widget page) {
    if (userData != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => page,
          settings: RouteSettings(arguments: userData),
        ),
      );
    } else {
      _showError('Unable to navigate: Please login again');
      _handleLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0C5217),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: !_hasInternetConnection
          ? _buildNoInternetView()
          : isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0C5217)),
                )
              : _buildUserDataView(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildNoInternetView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.signal_wifi_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Using locally stored data',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _checkConnectivityAndLoadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C5217),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDataView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            _buildProfileImage(),
            const SizedBox(height: 24),
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
    );
  }

  Widget _buildProfileImage() {
    return Container(
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
    );
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

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (index == _currentIndex) return;

        setState(() => _currentIndex = index);

        switch (index) {
          case 0:
            _navigateToPage(HomePage());
            break;
          case 2:
            _navigateToPage(NotePage());
            break;
          case 3:
            _navigateToPage(CalendarPage());
            break;
          case 4:
            _navigateToPage(GroupPage());
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
