//Account
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workplanpro/screens/EditProfilePage.dart';
import 'package:workplanpro/screens/calendar_page.dart';
import 'package:workplanpro/screens/group_page.dart';
import 'package:workplanpro/screens/home_page.dart';
import 'package:workplanpro/screens/login_page.dart';
import 'package:workplanpro/screens/note_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';

class FirebaseService {
  static Future<Map<String, dynamic>> fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseCustomException('ไม่พบผู้ใช้งาน', 'user_not_found');
      }

      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw FirebaseCustomException(
            'ไม่มีการเชื่อมต่ออินเทอร์เน็ต', 'no_internet');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            Duration(seconds: 10),
            onTimeout: () => throw FirebaseCustomException(
              'หมดเวลาการเชื่อมต่อ',
              'timeout',
            ),
          );

      if (!userDoc.exists) {
        throw FirebaseCustomException('ไม่พบข้อมูลผู้ใช้', 'data_not_found');
      }

      return userDoc.data() ?? {};
    } on FirebaseException catch (e) {
      throw FirebaseCustomException(
        _mapFirebaseErrorMessage(e),
        e.code,
      );
    } on TimeoutException {
      throw FirebaseCustomException(
        'หมดเวลาการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง',
        'timeout',
      );
    } catch (e) {
      throw FirebaseCustomException(
        'เกิดข้อผิดพลาดที่ไม่คาดคิด',
        'unknown_error',
      );
    }
  }

  static String _mapFirebaseErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'ไม่มีสิทธิ์เข้าถึงข้อมูล';
      case 'unavailable':
        return 'บริการไม่พร้อมใช้งาน';
      case 'network-request-failed':
        return 'การเชื่อมต่อเครือข่ายล้มเหลว';
      default:
        return e.message ?? 'เกิดข้อผิดพลาดจาก Firebase';
    }
  }
}

class FirebaseCustomException implements Exception {
  final String message;
  final String code;

  FirebaseCustomException(this.message, this.code);

  @override
  String toString() => 'FirebaseCustomException: $message (Code: $code)';
}

class UserProfileManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> getUserProfile(String username) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (userDoc.docs.isNotEmpty) {
        return userDoc.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<String?> updateProfileImage(
      String username, ImageSource source) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
      return null;
    }
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) {
        print('ไม่ได้เลือกรูปภาพ');
        return null;
      }

      final File imageFile = File(image.path);
      final String fileName =
          'profile_images/$username/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference ref = _storage.ref().child(fileName);
      final UploadTask uploadTask =
          ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));

      try {
        final TaskSnapshot snapshot =
            await uploadTask.whenComplete(() {}).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException("การอัปโหลดใช้เวลานานเกินไป");
          },
        );

        final String downloadUrl = await snapshot.ref.getDownloadURL().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException("การดาวน์โหลด URL ใช้เวลานานเกินไป");
          },
        );

        final querySnapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.update({
            'profileImageUrl': downloadUrl,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          print('อัปเดตรูปภาพโปรไฟล์สำเร็จ');
        } else {
          print('ไม่พบผู้ใช้ที่มีชื่อผู้ใช้ตามที่ระบุ');
        }
      } catch (e) {
        print('Error during upload: $e');
      }
    } on FirebaseException catch (e) {
      print('Firebase Error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected Error: $e');
      return null;
    }
  }

  Future<bool> updateUsername(String oldUsername, String newUsername) async {
    try {
      final usernameCheck = await _firestore
          .collection('users')
          .where('username', isEqualTo: newUsername)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        throw 'ชื่อผู้ใช้นี้ถูกใช้งานแล้ว';
      }

      final userDoc = await _firestore
          .collection('users')
          .where('username', isEqualTo: oldUsername)
          .get();

      if (userDoc.docs.isEmpty) {
        throw 'ไม่พบผู้ใช้';
      }

      await userDoc.docs.first.reference.update({
        'username': newUsername,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating username: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> verifyPhoneNumber(String phoneNumber) async {
    final Completer<Map<String, dynamic>> completer = Completer();
    String? verificationId;

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.currentUser
                ?.updatePhoneNumber(credential);
            completer.complete({
              'success': true,
              'message': 'การยืนยันเบอร์โทรศัพท์สำเร็จ',
            });
          } catch (e) {
            completer.complete({
              'success': false,
              'message': 'เกิดข้อผิดพลาดในการยืนยัน: $e',
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          completer.complete({
            'success': false,
            'message': 'การยืนยันล้มเหลว: ${e.message}',
          });
        },
        codeSent: (String vId, int? token) {
          verificationId = vId;
          completer.complete({
            'success': true,
            'verificationId': vId,
            'resendToken': token,
            'message': 'ส่งรหัสยืนยันแล้ว',
          });
        },
        codeAutoRetrievalTimeout: (String vId) {
          verificationId = vId;
        },
        timeout: const Duration(seconds: 60),
      );

      return await completer.future;
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  Future<bool> verifyOTP(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await _auth.currentUser?.updatePhoneNumber(credential);
      return true;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }
}

class UserProfileNotifier extends ValueNotifier<Map<String, dynamic>?> {
  UserProfileNotifier() : super(null);
  // ... rest of the code
}

class AccountPage extends StatefulWidget {
  final String initialUsername;
  final Map<String, dynamic>? initialUserData;

  const AccountPage(
      {Key? key, required this.initialUsername, this.initialUserData})
      : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

// แก้ไข error และปรับการทำงานของ account_profile ให้รองรับ account_page
class AccountPageManager {
  final UserProfileManager _userProfileManager = UserProfileManager();

  // ฟังก์ชันเพื่อดึงข้อมูลโปรไฟล์ผู้ใช้
  Future<Map<String, dynamic>?> fetchUserProfile(String username) async {
    return await _userProfileManager.getUserProfile(username);
  }

  // ฟังก์ชันเพื่ออัพเดทข้อมูลผู้ใช้
  Future<bool> updateUserProfile(
      String username, Map<String, dynamic> updates) async {
    // Example: convert map to a specific type or extract a specific value
    String updateValue = updates['someKey'];
    return await _userProfileManager.updateUsername(username, updateValue);
  }

  // ฟังก์ชันเพื่ออัพโหลดรูปโปรไฟล์
  Future<String?> uploadProfileImage(
      String username, ImageSource source) async {
    return await _userProfileManager.updateProfileImage(username, source);
  }

  // ฟังก์ชันเพื่อยืนยันเบอร์โทรศัพท์
  Future<Map<String, dynamic>> confirmPhoneNumber(String phoneNumber) async {
    return await _userProfileManager.verifyPhoneNumber(phoneNumber);
  }

  // ฟังก์ชันเพื่อยืนยัน OTP
  Future<bool> confirmOTP(String verificationId, String smsCode) async {
    return await _userProfileManager.verifyOTP(verificationId, smsCode);
  }
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';
  int _currentIndex = 1;
  bool _hasInternetConnection = true;
  String _currentUsername = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isDisposed = false;
  final UserProfileManager _profileManager = UserProfileManager();
  final UserProfileNotifier _userProfileNotifier = UserProfileNotifier();
  bool _isLoading = true;
  String _errorMessage = '';
  String? _profileImageUrl;
  bool _hasShownUpdateSnackbar = false; // ตัวแปรสำหรับตรวจสอบการแสดง SnackBar
  final TextEditingController _emailController = TextEditingController();
  // เพิ่มการประกาศตัวแปรสำหรับการล็อกอิน
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.initialUsername;

    // โหลดข้อมูลผู้ใช้
    _loadUserData();

    // ฟังก์ชันติดตามการเปลี่ยนแปลงอีเมล
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // ตรวจสอบว่า mounted อยู่หรือไม่
        if (mounted) {
          setState(() {
            // อัปเดตอีเมลโดยตรงจาก Firebase Auth
            if (userData != null) {
              userData?['email'] = user.email ?? '';
            }
          });
        }
      }
    });
  }

  void _editProfile() async {
    if (userData != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfilePage(userData: userData!),
        ),
      );
      // เมื่อกลับมาจากหน้า EditProfilePage ให้โหลดข้อมูลใหม่
      _loadUserData();
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(userData: userData!),
      ),
    ).then((_) => _loadUserData());
  }

  Future<void> _checkUserAuthenticationStatus() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // ถ้าไม่มีผู้ใช้ล็อกอิน ให้ไปหน้า Login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } else {
      // โหลดข้อมูลผู้ใช้
      await _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userData = await FirebaseService.fetchUserData();
      if (mounted) {
        setState(() {
          this.userData = userData;
          _isLoading = false;
          _currentUsername = userData['username'] ?? _currentUsername;
          _emailController.text = userData['email'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading user data: $e';
        });
        _showErrorDialog('Error', _errorMessage);
      }
    }
  }

  Future<Map<String, dynamic>?> _loadCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_user_data');
      if (cachedData != null) {
        return json.decode(cachedData) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('บัญชีของฉัน'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _editProfile,
            tooltip: 'แก้ไขโปรไฟล์',
          )
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ข้อมูลเพิ่มเติม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.calendar_today,
                title: 'วันที่สมัคร',
                value: _formatDate(userData?['createdAt']),
              ),
              Divider(),
              _buildInfoRow(
                icon: Icons.update,
                title: 'อัปเดตล่าสุด',
                value: _formatDate(userData?['lastUpdated']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return 'ไม่มีข้อมูล';

      DateTime? dateTime;

      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is Map) {
        // กรณีที่อาจได้รับข้อมูลเป็น Map จาก Firestore
        dateTime = (timestamp['seconds'] != null)
            ? DateTime.fromMillisecondsSinceEpoch(timestamp['seconds'] * 1000)
            : null;
      } else if (timestamp is int) {
        // กรณีได้รับ timestamp เป็น milliseconds
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }

      if (dateTime != null) {
        return '${_formatDateWithLeadingZero(dateTime.day)}/${_formatDateWithLeadingZero(dateTime.month)}/${dateTime.year} '
            '${_formatDateWithLeadingZero(dateTime.hour)}:${_formatDateWithLeadingZero(dateTime.minute)} น.';
      }

      return 'ไม่มีข้อมูล';
    } catch (e) {
      print('Error formatting date: $e');
      return 'ไม่มีข้อมูล';
    }
  }

  String _formatDateWithLeadingZero(int number) {
    return number.toString().padLeft(2, '0');
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'การดำเนินการด่วน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _changeProfileImage,
                icon: Icon(Icons.camera_alt),
                label: Text('เปลี่ยนรูปโปรไฟล์'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _editUsername,
                icon: Icon(Icons.edit),
                label: Text('แก้ไขชื่อผู้ใช้'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: Icon(Icons.logout),
                label: Text('ออกจากระบบ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _buildProfileImage(userData),
          SizedBox(height: 16),
          Text(
            userData?['username'] ?? 'ชื่อผู้ใช้',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          // ดึงอีเมลจาก Firebase Authentication
          Text(
            FirebaseAuth.instance.currentUser?.email ?? 'อีเมล',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                icon: Icons.phone,
                title: 'เบอร์โทรศัพท์',
                value: userData?['phone'] ?? 'ยังไม่ได้เพิ่ม',
              ),
              Divider(),
              _buildDetailRow(
                icon: Icons.location_on,
                title: 'ที่อยู่',
                value: userData?['address'] ?? 'ยังไม่ได้เพิ่ม',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _isDisposed =
        true; // ใช้ตัวแปรนี้เพื่อป้องกันการเรียก setState() หลังจาก dispose
    _emailController.dispose();
    super.dispose();
  }

  Future<void> uploadProfileImage(File imageFile) async {
    // ตรวจสอบขนาดและประเภทของไฟล์
    if (imageFile.lengthSync() > 1024 * 1024) {
      showSnackBar('กรุณาเลือกไฟล์ที่มีขนาดไม่เกิน 1MB');
      return;
    }

    setState(() {
      isLoading = true; // แสดงสถานะการโหลด
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showSnackBar('ผู้ใช้ไม่ถูกต้อง');
        return;
      }

      final storageRef =
          FirebaseStorage.instance.ref().child('profile_pics/${user.uid}.jpg');

      // อัปโหลดไฟล์
      await storageRef.putFile(imageFile);
      final imageUrl = await storageRef.getDownloadURL();

      // อัพเดต Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': _currentUsername, // แก้ไขตรงนี้
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      showSnackBar('อัพเดตสำเร็จ');
    } catch (e) {
      if (e is FirebaseException) {
        print('Firebase Error: ${e.code} - ${e.message}');
      } else {
        print('Unexpected Error: $e');
      }
      showSnackBar('เกิดข้อผิดพลาดในการอัพโหลด: $e');
    } finally {
      setState(() {
        isLoading = false; // ปิดสถานะการโหลด
      });
    }
  }

// ฟังก์ชันแสดง SnackBar
  void showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (!_isDisposed && mounted) {
        setState(() {
          _hasInternetConnection = result != ConnectivityResult.none;
        });
      }
    } catch (e) {
      print('Error checking connectivity: $e');
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (!_isDisposed && mounted) {
        final result = results.first; // Take the first result
        setState(() {
          _hasInternetConnection = result != ConnectivityResult.none;
        });
        if (_hasInternetConnection) {
          _loadUserData();
        }
      }
    });
  }

  // สร้างโปรไฟล์ใหม่
  Future<void> _createUserProfile(User currentUser) async {
    try {
      // เตรียมข้อมูลโปรไฟล์
      Map<String, dynamic> newUserData = {
        'uid': currentUser.uid,
        'username':
            currentUser.displayName ?? 'User${currentUser.uid.substring(0, 5)}',
        'email': currentUser.email ?? '',
        'phone': currentUser.phoneNumber ?? '',
        'profileImageUrl': currentUser.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // บันทึกข้อมูลผู้ใช้ใหม่
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(newUserData, SetOptions(merge: true));

      // อัพเดท State
      setState(() {
        userData = newUserData;
        _currentUsername = newUserData['username'];
        isLoading = false;
        isError = false;
      });

      // บันทึกข้อมูลลงเครื่อง
      await _saveUserDataLocally(newUserData);
    } catch (e) {
      print('Create User Profile Error: $e');
      _handleLoadError(e);
    }
  }

// จัดการข้อผิดพลาด
  void _handleLoadError(dynamic error) {
    String errorMessage = 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ';

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          errorMessage = 'ไม่มีสิทธิ์เข้าถึงข้อมูล';
          break;
        case 'unavailable':
          errorMessage = 'เครือข่ายไม่พร้อมใช้งาน';
          break;
        default:
          errorMessage = 'เกิดข้อผิดพลาด Firebase: ${error.message}';
      }
    } else if (error is Exception) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    setState(() {
      isLoading = false;
      isError = true;
      this.errorMessage = errorMessage;
    });

    // ลองโหลดข้อมูลจาก cache
    _loadCachedUserData();
  }

  Future<Map<String, dynamic>?> _fetchUserDataFromFirestore() async {
    try {
      // Validate username
      if (_currentUsername.isEmpty) {
        throw Exception('ชื่อผู้ใช้ไม่ถูกต้อง');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _currentUsername)
          .get();

      if (userDoc.docs.isEmpty) {
        // Check if email login was used instead
        final emailDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _currentUsername)
            .get();

        if (emailDoc.docs.isEmpty) {
          throw Exception('ไม่พบข้อมูลผู้ใช้');
        }
        return emailDoc.docs.first.data();
      }

      return userDoc.docs.first.data();
    } catch (e) {
      print('Error fetching user data: $e');
      throw Exception('ไม่พบข้อมูลผู้ใช้');
    }
  }

  Future<void> _changeProfileImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('ถ่ายภาพ'),
                onTap: () async {
                  Navigator.pop(context);
                  String? uploadedUrl =
                      await _pickAndUpdateProfileImage(ImageSource.camera);

                  if (uploadedUrl != null) {
                    setState(() {
                      _profileImageUrl = uploadedUrl;
                      if (userData != null) {
                        userData!['profileImageUrl'] = uploadedUrl;
                      }
                    });
                    // แสดง Snackbar เมื่ออัปโหลดสำเร็จ
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('อัปเดตรูปโปรไฟล์สำเร็จ'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากคลังภาพ'),
                onTap: () async {
                  Navigator.pop(context);
                  String? uploadedUrl =
                      await _pickAndUpdateProfileImage(ImageSource.gallery);

                  if (uploadedUrl != null) {
                    setState(() {
                      _profileImageUrl = uploadedUrl;
                      if (userData != null) {
                        userData!['profileImageUrl'] = uploadedUrl;
                      }
                    });
                    // แสดง Snackbar เมื่ออัปโหลดสำเร็จ
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('อัปเดตรูปโปรไฟล์สำเร็จ'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _pickAndUpdateProfileImage(ImageSource source) async {
    try {
      // ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showErrorSnackBar('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
        return null;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker
          .pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      )
          .catchError((error) {
        // ดักจับ error จากการเลือกรูปภาพ
        _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $error');
        return null;
      });

      if (image == null) {
        _showErrorSnackBar('ไม่ได้เลือกรูปภาพ');
        return null;
      }

      final File imageFile = File(image.path);

      // ตรวจสอบขนาดไฟล์
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        _showErrorSnackBar('ขนาดไฟล์ใหญ่เกินไป (เกิน 5MB)');
        return null;
      }

      // เรียกใช้เมธอด updateProfileImage จาก UserProfileManager
      final String? url = await _profileManager.updateProfileImage(
        _currentUsername,
        source,
      );

      if (url == null) {
        _showErrorSnackBar('ไม่สามารถอัปโหลดรูปภาพได้');
        return null;
      }

      // แสดง Snackbar เมื่ออัปโหลดสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อัปเดตรูปโปรไฟล์สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      return url;
    } catch (e) {
      // ดักจับ error ทั่วไป
      _showErrorSnackBar('เกิดข้อผิดพลาดที่ไม่คาดคิด: $e');
      return null;
    }
  }

// เพิ่มเมธอดแสดง SnackBar สำหรับ error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('User  not found');
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${currentUser.uid}.jpg');

      await storageRef.putFile(imageFile);

      final imageUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'profileImageUrl': imageUrl,
      });

      setState(() {
        _profileImageUrl = imageUrl; // อัปเดต _profileImageUrl
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editUsername() async {
    String initialUsername = userData?['username'] ?? // ดึงจาก userData ก่อน
        _currentUsername ?? // ถ้าไม่มีใน userData ใช้ _currentUsername
        FirebaseAuth
            .instance.currentUser?.displayName ?? // ถ้ายังไม่มีใช้ display name
        'User';

    final TextEditingController controller = TextEditingController(
      text: initialUsername, // ใช้ username ที่ถูกต้อง
    );

    bool isValidUsername(String username) {
      // ตรวจสอบความยาว
      if (username.length < 3 || username.length > 20) {
        return false;
      }

      // ตรวจสอบอักขระที่อนุญาต (ตัวอักษร ตัวเลข และ underscore)
      final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
      return validCharacters.hasMatch(username);
    }

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขชื่อผู้ใช้'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'ชื่อผู้ใช้ใหม่',
            helperText: 'ความยาว 3-20 ตัวอักษร ประกอบด้วยตัวอักษร ตัวเลข และ _',
            errorText: isValidUsername(controller.text)
                ? null
                : 'รูปแบบชื่อผู้ใช้ไม่ถูกต้อง',
          ),
          onChanged: (value) {
            // Validate in real-time
            controller.value = TextEditingValue(
              text: value,
              selection: controller.selection,
            );
          },
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              // ตรวจสอบความถูกต้องก่อนปิด Dialog
              if (isValidUsername(controller.text.trim())) {
                Navigator.pop(context, true);
              } else {
                // แสดง SnackBar แจ้งเตือนถ้าชื่อผู้ใช้ไม่ถูกต้อง
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณากรอกชื่อผู้ใช้ให้ถูกต้อง'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      final newUsername = controller.text.trim();

      // แสดง Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Colors.green,
          ),
        ),
      );

      try {
        // ตรวจสอบว่าชื่อผู้ใช้ซ้ำหรือไม่
        final usernameCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .get();

        if (usernameCheck.docs.isNotEmpty) {
          // ปิด Loading dialog
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ชื่อผู้ใช้ "$newUsername" มีอยู่แล้ว'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // ดำเนินการเปลี่ยนชื่อผู้ใช้
        final success = await _profileManager.updateUsername(
          _currentUsername,
          newUsername,
        );

        // ปิด Loading dialog
        Navigator.of(context).pop();

        if (success) {
          // อัปเดต State และ Firestore
          setState(() {
            _currentUsername = newUsername;
            userData?['username'] = newUsername;
          });

          // อัปเดตข้อมูลใน Firestore
          await _updateProfile({
            'username': newUsername,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // แสดง Success SnackBar เพียงครั้งเดียว
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เปลี่ยนชื่อผู้ใช้เป็น "$newUsername" สำเร็จ'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // รีเซ็ตสถานะการแสดง SnackBar
          _hasShownUpdateSnackbar = false;

          await _loadUserData(); // โหลดข้อมูลใหม่ทันที

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เปลี่ยนชื่อผู้ใช้เป็น "$newUsername" สำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // ปิด Loading dialog
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (result == true && controller.text.isNotEmpty) {
      try {
        final success = await _profileManager.updateUsername(
          _currentUsername,
          controller.text,
        );

        if (success) {
          // Update the local state immediately
          setState(() {
            _currentUsername = controller.text;
            userData!['username'] = controller.text; // Update UI immediately
          });

          // Update the profile in Firestore
          await _updateProfile({
            'username': controller.text,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Show success message
          if (!_isDisposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('อัพเดตชื่อผู้ใช้สำเร็จ')),
            );
          }
        }
      } catch (e) {
        if (!_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
          );
        }
      }
    }
  }

  void _updateNavigationWithNewUsername() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AccountPage(initialUsername: _currentUsername),
      ),
    );
  }

// เพิ่มฟังก์ชันยืนยันเบอร์โทรศัพท์
  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // ยืนยันเสร็จเรียบร้อย
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: $e');
        },
        codeSent: (String verificationId, int? resendToken) {
          // ส่งโค้ดยืนยันไปที่เบอร์โทร
          print('Verification code sent to $phoneNumber');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // หมดเวลาการรับรหัส
          print('Verification code timeout');
        },
      );
    } catch (e) {
      print('Error verifying phone number: $e');
    }
  }

  Widget _buildProfileImage(Map<String, dynamic>? userData) {
    // ตรวจสอบก่อนว่ามี URL หรือไม่
    if (userData == null ||
        userData['profileImageUrl'] == null ||
        userData['profileImageUrl'].isEmpty) {
      // กรณีไม่มี URL ให้ใช้ Avatar สีแบบใน Edit Profile
      return CircleAvatar(
        radius: 80,
        backgroundColor: Colors.green.shade100, // สีพื้นหลัง
        child: Icon(Icons.person,
            size: 80, color: Colors.green.shade800), // ไอคอนแทนที่
      );
    }

    return CachedNetworkImage(
      imageUrl: userData['profileImageUrl'],
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: 80,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: 80,
        backgroundColor: Colors.green.shade100,
        child: CircularProgressIndicator(
          color: Colors.green.shade800,
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: 80,
        backgroundColor: Colors.green.shade100, // สีพื้นหลังเมื่อเกิดข้อผิดพลาด
        child: Icon(Icons.person,
            size: 80, color: Colors.green.shade800), // ไอคอนแทนที่
      ),
    );
  }

  Future<void> _initializeData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      isError = false;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasInternet = connectivityResult != ConnectivityResult.none;

      if (!mounted) return;

      setState(() {
        _hasInternetConnection = hasInternet;
      });

      // First try to get cached data
      final prefs = await SharedPreferences.getInstance();
      final cachedData = {
        'username': prefs.getString('username'),
        'email': prefs.getString('email'),
        'phone': prefs.getString('phone'),
        'address': prefs.getString('address'),
      };

      // If we have cached data, show it immediately
      if (cachedData['username'] != null) {
        setState(() {
          userData = cachedData;
          isLoading = false;
        });
      }

      // If we have internet, fetch fresh data
      if (hasInternet) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: _currentUsername)
            .get();

        if (!mounted) return;

        if (userDoc.docs.isNotEmpty) {
          final data = userDoc.docs.first.data();
          await _saveUserDataLocally(data);

          setState(() {
            userData = data;
            isLoading = false;
            isError = false;
          });
        } else if (cachedData['username'] == null) {
          // Only show error if we don't have cached data
          setState(() {
            isError = true;
            errorMessage = 'ไม่พบข้อมูลผู้ใช้';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isError = true;
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorDialog(
          'ไม่มีการเชื่อมต่อ', 'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต');
      return false;
    }
    return true;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUserDataLocally(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_data', json.encode(data));
    await prefs.setString('last_sync', DateTime.now().toIso8601String());
  }

  // Add this function to handle data clearing with timeout
  Future<void> _clearUserDataWithTimeout() async {
    try {
      // Create a timeout for the clear operation
      final clearFuture = _clearUserData();
      await Future.any([
        clearFuture,
        Future.delayed(const Duration(seconds: 5))
            .then((_) => throw TimeoutException('การลบข้อมูลใช้เวลานานเกินไป')),
      ]);
    } on TimeoutException catch (_) {
      // If timeout occurs, continue with logout anyway
      print('Clear data timeout - proceeding with logout');
    } catch (e) {
      print('Error during clear data: $e');
      // Continue with logout even if clearing fails
    }
  }

  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear specific keys instead of clearing everything
      await Future.wait([
        prefs.remove('cached_user_data'),
        prefs.remove('last_sync'),
        prefs.remove('username'),
        prefs.remove('email'),
        prefs.remove('phone'),
        prefs.remove('address'),
      ]);
    } catch (e) {
      print('Error clearing user data: $e');
      throw e;
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    // Clear any user-related data
    await _clearUserData();
    // Navigate to LoginPage
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  Future<void> _updateProfile(Map<String, dynamic> updatedData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // เพิ่ม lastUpdated ลงในข้อมูลที่จะอัปเดต
        updatedData['lastUpdated'] = FieldValue.serverTimestamp();

        // Update Firestore
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.update(updatedData);

        // รีเซ็ตสถานะ SnackBar
        _hasShownUpdateSnackbar = false;

        // อัพเดต UI ทันที
        setState(() {
          // อัพเดตข้อมูลใน userData
          userData ??= {};
          userData!.addAll(updatedData);

          // Force update lastUpdated
          userData!['lastUpdated'] = {
            'seconds': DateTime.now().millisecondsSinceEpoch ~/ 1000
          };
        });

        // Trigger immediate data refresh
        await _loadUserData();

        print('Profile updated successfully');
      } else {
        print('User is not logged in');
      }
    } catch (e) {
      print('Error updating profile: $e');

      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัพเดตข้อมูลได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveImageUrl(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.update({'profileImageUrl': imageUrl});
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorView();
    }

    return RefreshIndicator(
      onRefresh: _loadUserData, // ใช้เมธอดโหลดข้อมูลเมื่อรีเฟรช
      child: ListView(
        children: [
          _buildProfileHeader(),
          _buildProfileDetails(),
          _buildAdditionalInfoSection(),
          _buildQuickActionButtons(),
          // เพิ่มปุ่มรีเฟรชข้อมูล
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _loadUserData,
              icon: Icon(Icons.refresh),
              label: Text('รีเฟรชข้อมูล'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 100,
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage,
            style: TextStyle(
              color: Colors.red,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserData,
            child: Text('ลองอีกครั้ง'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          )
        ],
      ),
    );
  }

  Future<void> _loadUserDataWithRetry({int retryCount = 3}) async {
    for (int i = 0; i < retryCount; i++) {
      try {
        await _loadUserData();
        return;
      } catch (e) {
        if (i == retryCount - 1) {
          throw e; // Throw error after all retries fail
        }
        await Future.delayed(
            Duration(seconds: 2 * (i + 1))); // Exponential backoff
      }
    }
  }

  Widget _buildUserDataView(Map<String, dynamic>? userData) {
    if (userData == null || userData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 100, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'ไม่พบข้อมูลผู้ใช้',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserData,
              child: Text('โหลดข้อมูลอีกครั้ง'),
            )
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileImage(userData),
          const SizedBox(height: 24),
          _buildInfoCard('ชื่อผู้ใช้', userData['username'] ?? 'ไม่มีข้อมูล',
              Icons.person),
          const SizedBox(height: 16),
          _buildInfoCard(
              'อีเมล', userData['email'] ?? 'ไม่มีข้อมูล', Icons.email),
          const SizedBox(height: 16),
          _buildInfoCard(
              'เบอร์โทรศัพท์', userData['phone'] ?? 'ไม่มีข้อมูล', Icons.phone),
          const SizedBox(height: 16),
          _buildInfoCard('ที่อยู่', userData['address'] ?? 'ไม่มีข้อมูล',
              Icons.location_on),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      elevation: 5, // เพิ่มเงา
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // มุมมน
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
                      color: Colors.black87,
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
      initialSelectedTab: 'Account',
      useSafeArea: true,
      labels: const ['Home', 'Account', 'Notes', 'Calendar', 'Groups'],
      icons: const [
        Icons.home,
        Icons.person,
        Icons.book,
        Icons.calendar_today,
        Icons.group
      ],
      tabSelectedColor: Colors.green,
      tabIconColor: const Color(0xFF0C5217),
      textStyle: const TextStyle(
        color: Colors.green,
        fontWeight: FontWeight.bold,
      ),
      onTabItemSelected: (index) {
        setState(() {
          _currentIndex = index;
        });

        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(username: _currentUsername),
              ),
            );
            break;
          case 1:
            break; // Current page
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => NotePage(username: _currentUsername),
              ),
            );
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CalendarPage(username: _currentUsername),
              ),
            );
            break;
          case 4:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GroupPage(username: _currentUsername),
              ),
            );
            break;
        }
      },
    );
  }

  Widget _buildNavBarItem(IconData icon, String label, int index) {
    bool isSelected = _currentIndex == index;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0C5217) : Colors.transparent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ขยับไอคอนขึ้นและขยายขนาดเมื่อเลือก
          Transform.translate(
            offset: isSelected
                ? Offset(0, -10)
                : Offset(0, 0), // ขยับไอคอนขึ้นเมื่อเลือก
            child: Icon(
              icon,
              size: isSelected ? 30 : 24, // ขยายขนาดไอคอนเมื่อเลือก
              color: isSelected ? Colors.white : const Color(0xFF0C5217),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF0C5217),
            ),
          ),
        ],
      ),
    );
  }
}
