//EditProfile
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:email_validator/email_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:workplanpro/screens/login_page.dart';

class FirebaseService {
  static Future<Map<String, dynamic>> fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseCustomException('ไม่พบผู้ใช้งาน', 'user_not_found');
      }

      // เพิ่มการตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw FirebaseCustomException(
            'ไม่มีการเชื่อมต่ออินเทอร์เน็ต', 'no_internet');
      }

      // เพิ่ม timeout เพื่อป้องกันการรอนานเกินไป
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
      // จัดการข้อผิดพลาดเฉพาะของ Firebase
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
      // จัดการข้อผิดพลาดอื่นๆ
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

// Create Provider for managing user data
class UserProfileProvider extends ChangeNotifier {
  Map<String, dynamic> _userData = {};
  bool _isLoading = false;

  Map<String, dynamic> get userData => _userData;
  bool get isLoading => _isLoading;

  Future<void> fetchUserData() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Fetch user data from Firestore
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();

      _userData = userData.data() ?? {};
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error fetching user data: $e');
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> updatedData) async {
    try {
      _isLoading = true;
      notifyListeners();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .update(updatedData);

      _userData.addAll(updatedData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}

class UserProfileNotifier extends ChangeNotifier {
  Map<String, dynamic>? _userData;

  Map<String, dynamic>? get userData => _userData;

  void updateUserData(Map<String, dynamic> newData) {
    _userData = newData;
    notifyListeners();
  }
}

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfilePage({Key? key, required this.userData}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  ResponsiveLayout(
      {required this.mobile, required this.tablet, required this.desktop});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) return mobile;
        if (constraints.maxWidth < 1200) return tablet;
        return desktop;
      },
    );
  }
}

class AnimatedProfileSection extends StatelessWidget {
  final Widget child;

  AnimatedProfileSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 50),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  AppErrorWidget({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 80),
          SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          if (onRetry != null)
            ElevatedButton(
              onPressed: onRetry,
              child: Text('ลองอีกครั้ง'),
            )
        ],
      ),
    );
  }
}

class AppLoadingIndicator extends StatelessWidget {
  final String? message;

  AppLoadingIndicator({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          SizedBox(height: 20),
          if (message != null)
            Text(
              message!,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            )
        ],
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final String title;
  final String value;

  const ProfileInfoCard({Key? key, required this.title, required this.value})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}

class _EditProfilePageState extends State<EditProfilePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Map<String, dynamic> _userData = {};
  StreamSubscription? _phoneVerificationSubscription;
  bool _isInitialized = false;
  late TextEditingController _usernameController;
  late TextEditingController _emailController; // Ensure this is declared
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  final UserProfileNotifier _userProfileNotifier = UserProfileNotifier();
  bool _isDisposed = false;
  bool _isPhoneVerified = false;
  bool _hasChanges = false;
  String? _profileImageUrl;
  String? _verificationId;
  String _phoneVerificationMessage = '';
  // เพิ่มตัวแปรสำหรับการจัดการสถานะ
  bool _hasInternetConnection = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isEmailVerified = false;
  String _emailVerificationStatus = '';
  final ThemeData appTheme = ThemeData(
      primarySwatch: Colors.green,
      fontFamily: 'Prompt', // ฟอนต์ที่อ่านง่าย
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.green, width: 2))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30))));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeControllers();
    _setupAnimations();
    _fetchInitialUserData();
    _listenForEmailChange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ลงทะเบียน WillPopScope หรือใช้การดักจับการออกจากหน้าแบบอื่น
      // เช่น Navigator.of(context).popUntil() หรือ Navigator.of(context).pop()
    });
    _setupConnectivityListener();
    _initializeData();
    // Delay the setup of change listeners to ensure all data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePage();
    });
  } // เพิ่มเมธอดติดตามสถานะการเชื่อมต่อ

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (!_isDisposed) {
        final result = results.first;
        setState(() {
          _hasInternetConnection = result != ConnectivityResult.none;
        });

        // โหลดข้อมูลใหม่เมื่อมีอินเทอร์เน็ต
        if (_hasInternetConnection) {
          _initializeData();
        }
      }
    });
  } // โหลดข้อมูลเริ่มต้นแบบปลอดภัย

  Future<void> _initializeData() async {
    if (_isDisposed) return;

    try {
      // ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showNoInternetSnackBar();
        return;
      }

      // โหลดข้อมูลจาก Cache ก่อน
      final cachedData = await _loadCachedUserData();
      if (cachedData != null) {
        _updateUIWithUserData(cachedData);
      }

      // โหลดข้อมูลล่าสุดจาก Firestore
      final userData = await _fetchLatestUserData();

      if (!_isDisposed) {
        // อัปเดต UI ด้วยข้อมูลล่าสุด
        _updateUIWithUserData(userData);

        // บันทึกข้อมูลลง Cache
        await _cacheUserData(userData);
      }
    } catch (e) {
      _handleDataLoadError(e);
    }
  } // โหลดข้อมูลจาก Cache

  Future<Map<String, dynamic>?> _loadCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataJson = prefs.getString('user_profile_cache');

      if (cachedDataJson != null) {
        return json.decode(cachedDataJson);
      }
      return null;
    } catch (e) {
      print('Error loading cached data: $e');
      return null;
    }
  } // บันทึกข้อมูลลง Cache

  Future<void> _cacheUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile_cache', json.encode(userData));
      await prefs.setString(
          'last_cache_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching user data: $e');
    }
  } // ดึงข้อมูลล่าสุดจาก Firestore

  Future<Map<String, dynamic>> _fetchLatestUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseCustomException('ไม่พบผู้ใช้งาน', 'user_not_found');
      }

      // เพิ่ม Timeout เพื่อป้องกันการรอนานเกินไป
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('หมดเวลาการเชื่อมต่อ'),
          );

      return userData.data() ?? {};
    } catch (e) {
      throw FirebaseCustomException(
        'เกิดข้อผิดพลาดในการดึงข้อมูล',
        'fetch_error',
      );
    }
  } // อัปเดต UI ด้วยข้อมูลผู้ใช้

  void _updateUIWithUserData(Map<String, dynamic> userData) {
    if (_isDisposed) return;

    setState(() {
      _usernameController.text = userData['username'] ?? '';
      _emailController.text = userData['email'] ?? '';
      _phoneController.text = userData['phone'] ?? '';
      _addressController.text = userData['address'] ?? '';
      _profileImageUrl = userData['profileImageUrl'];
    });
  } // จัดการข้อผิดพลาดในการโหลดข้อมูล

  void _handleDataLoadError(dynamic error) {
    if (_isDisposed) return;

    String errorMessage = 'เกิดข้อผิดพลาดที่ไม่คาดคิด';

    if (error is FirebaseCustomException) {
      errorMessage = error.message;
    } else if (error is TimeoutException) {
      errorMessage = 'หมดเวลาการเชื่อมต่อ กรุณาลองใหม่';
    }

    // แสดง SnackBar แบบปลอดภัย
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ),
    );
  } // แสดง SnackBar เมื่อไม่มีอินเทอร์เน็ต

  void _showNoInternetSnackBar() {
    if (_isDisposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ ต'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ฟังก์ชันโหลดข้อมูลเริ่มต้น
  Future<void> _initializePage() async {
    try {
      // โหลดข้อมูลผู้ใช้
      await _fetchInitialUserData();

      // อัปเดต State ด้วยข้อมูลที่โหลด
      setState(() {
        _initializeControllers();
        _isInitialized = true;
      });

      // ติดตั้งการฟังการเปลี่ยนแปลง
      _setupChangeListeners();
    } catch (e) {
      // บันทึกข้อผิดพลาดหากมี
      print('Initialization error: $e');
    }
  }

  // ฟังก์ชันติดตามการเปลี่ยนแปลง
  void _setupChangeListeners() {
    if (!_isInitialized) return;

    void checkChanges() {
      if (!mounted) return;

      bool usernameChanged = _usernameController.text.trim() !=
          (widget.userData['username'] ?? '').trim();
      bool emailChanged = _emailController.text.trim() !=
          (widget.userData['email'] ?? '').trim();
      bool phoneChanged = _phoneController.text.trim() !=
          (widget.userData['phone'] ?? '').trim();
      bool addressChanged = _addressController.text.trim() !=
          (widget.userData['address'] ?? '').trim();
      bool profileImageChanged = (_profileImageUrl ?? '') !=
          (widget.userData['profileImageUrl'] ?? '');

      safeSetState(() {
        _hasChanges = usernameChanged ||
            emailChanged ||
            phoneChanged ||
            addressChanged ||
            profileImageChanged;
      });
    }

    _usernameController.addListener(checkChanges);
    _emailController.addListener(checkChanges);
    _phoneController.addListener(checkChanges);
    _addressController.addListener(checkChanges);
  }

  // ฟังก์ชัน setState แบบปลอดภัย
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // ฟังก์ชันตรวจสอบการเปลี่ยนแปลง
  bool _checkForChanges() {
    // กำหนดค่าเริ่มต้นป้องกัน Null
    String originalUsername = widget.userData['username'] ?? '';
    String originalEmail = widget.userData['email'] ?? '';
    String originalPhone = widget.userData['phone'] ?? '';
    String originalAddress = widget.userData['address'] ?? '';
    String originalProfileImage = widget.userData['profileImageUrl'] ?? '';

    // ตรวจสอบการเปลี่ยนแปลงแต่ละฟิลด์
    bool usernameChanged =
        _usernameController.text.trim() != originalUsername.trim();
    bool emailChanged = _emailController.text.trim() != originalEmail.trim();
    bool phoneChanged = _phoneController.text.trim() != originalPhone.trim();
    bool addressChanged =
        _addressController.text.trim() != originalAddress.trim();
    bool profileImageChanged = (_profileImageUrl ?? '') != originalProfileImage;

    // คืนค่าว่ามีการเปลี่ยนแปลงหรือไม่
    return usernameChanged ||
        emailChanged ||
        phoneChanged ||
        addressChanged ||
        profileImageChanged;
  }

  @override
  void dispose() {
    // ลบ Observer
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _isDisposed = true;

    // ปิด Controllers
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ติดตามสถานะแอป
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // รีโหลดข้อมูลเมื่อกลับมาที่แอป
      _initializePage();
    }
  }

  void _initializeControllers() {
    _usernameController =
        TextEditingController(text: widget.userData['username'] ?? '');
    _phoneController =
        TextEditingController(text: widget.userData['phone'] ?? '');
    _addressController =
        TextEditingController(text: widget.userData['address'] ?? '');
    _emailController = TextEditingController(
        text: widget.userData['email'] ?? ''); // Initialize email controller
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _animationController.forward();
  }

  /**@override
  void dispose() {
    _phoneVerificationSubscription?.cancel();
    _animationController.dispose(); // Dispose the animation controller
    _usernameController.dispose();
    _emailController.dispose(); // Dispose email controller
    _phoneController.dispose();
    _addressController.dispose();
    _isDisposed = true;
    super.dispose();
  }*/

  void _listenForEmailChange() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && !_isDisposed) {
        setState(() {
          // Update email directly from Firebase Auth
          _emailController.text = user.email ?? '';
        });
      }
    });
  }

  void _checkInitialChanges() {
    setState(() {
      _hasChanges = _usernameController.text != widget.userData['username'] ||
          _emailController.text != widget.userData['email'] ||
          _phoneController.text != widget.userData['phone'] ||
          _addressController.text != widget.userData['address'] ||
          _profileImageUrl != widget.userData['profileImageUrl'];
    });
  }

  Future<void> _fetchInitialUserData() async {
    try {
      final userData = await _fetchUserData(); // ใช้เมธอดดึงข้อมูลที่มีอยู่
      setState(() {
        _userData = userData;
        // โตเตอะ controllers ด้วยข้อมูลล่าสุด
        _usernameController =
            TextEditingController(text: _userData['username'] ?? '');
        _emailController =
            TextEditingController(text: _userData['email'] ?? '');
        _phoneController =
            TextEditingController(text: _userData['phone'] ?? '');
        _addressController =
            TextEditingController(text: _userData['address'] ?? '');
      });
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงข้อมูล: $e');
    }
  }

  void _showPhoneVerificationDialog() {
    final TextEditingController phoneController = TextEditingController(
      text: _phoneController.text,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันเบอร์โทรศัพท์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'เบอร์โทรศัพท์',
                prefixText: '+66 ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
          ],
        ),
        actions: [
          if (_hasChanges) // ปุ่มบันทึกจะแสดงเมื่อมีการเปลี่ยนแปลง
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'บันทึก',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_isValidPhoneNumber(phoneController.text)) {
                _sendPhoneOTP(phoneController.text);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เบอร์โทรศัพท์ไม่ถูกต้อง'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('ส่ง OTP'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPhoneOTP(String otp) async {
    try {
      if (_verificationId == null) {
        _showErrorSnackBar('กรุณาขอ OTP ใหม่');
        return;
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: otp);

      await FirebaseAuth.instance.signInWithCredential(credential);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isPhoneVerified = true;
        });
      });

      Navigator.of(context, rootNavigator: true).pop();
      _showSuccessSnackBar('ยืนยัน OTP สำเร็จ');
    } catch (e) {
      _showErrorSnackBar('รหัส OTP ไม่ถูกต้อง');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  Future<void> _selectProfileImage() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เปลี่ยนรูปโปรไฟล์'),
        content: const Text('คุณต้องการเปลี่ยนรูปโปรไฟล์ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ใช่'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('เลือกรูปโปรไฟล์'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('ถ่ายรูป'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากคลังภาพ'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);

      if (pickedFile != null) {
        await _uploadProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
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
        _profileImageUrl = imageUrl;
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
        onPressed: () => _onWillPop().then((canPop) {
          if (canPop) Navigator.pop(context);
        }),
      ),
      title: Text(
        'แก้ไขโปรไฟล์',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      actions: [
        if (_hasChanges) // ปุ่มบันทึกจะแสดงเมื่อมีการเปลี่ยนแปลง
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'บันทึก',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: ListView(
        controller: _scrollController, // เพิ่ม ScrollController
        physics: BouncingScrollPhysics(), // เพิ่มการเลื่อนแบบกระดอน
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SizedBox(height: 20),
                  _buildProfileImageSection(),
                  SizedBox(height: 30),
                  _buildInfoSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return GestureDetector(
      onTap: _selectProfileImage,
      child: Hero(
        tag: 'profile_image',
        child: CircleAvatar(
          radius: 80,
          backgroundColor: Colors.green.shade100,
          backgroundImage: _profileImageUrl != null
              ? NetworkImage(_profileImageUrl!)
              : AssetImage('assets/default_profile.png') as ImageProvider,
          child: Align(
            alignment: Alignment.bottomRight,
            child:
                _buildCameraButton(), // ตรวจสอบให้แน่ใจว่า _buildCameraButton() คืนค่า Widget ที่ถูกต้อง
          ),
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green[700],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        // ย้าย Icon ไปที่นี่
        Icons.camera_alt,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _selectProfileImage,
      child: Hero(
        tag: 'profile_image',
        child: CachedNetworkImage(
          imageUrl: _profileImageUrl ?? 'default_image_url',
          placeholder: (context, url) => Container(
            color: Colors.grey[200], // สีพื้นหลังเมื่อกำลังโหลด
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.red[100], // สีพื้นหลังเมื่อเกิดข้อผิดพลาด
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red), // แสดงไอคอนข้อผิดพลาด
                SizedBox(height: 8),
                Text(
                  'ไม่สามารถโหลดรูปภาพ',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 150,
        width: 150,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInfoSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('ข้อมูลส่วนตัว'),
              SizedBox(height: 20),
              _buildTextField(
                controller: _usernameController,
                label: 'ชื่อผู้ใช้',
                icon: Icons.person_outline,
                validator: _validateUsername,
              ),
              SizedBox(height: 15),
              _buildTextField(
                controller: _addressController,
                label: 'ที่อยู่',
                icon: Icons.location_on_outlined,
                maxLines: 3,
                validator: _validateAddress,
              ),
              SizedBox(height: 25),
              _buildSectionTitle('ข้อมูลการติดต่อ'),
              SizedBox(height: 20),
              _buildContactInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.green[700],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.green[700]!),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  Widget _buildContactInfo() {
    return Column(
      children: [
        _buildContactTile(
          icon: Icons.email_outlined,
          title: 'อีเมล',
          value: FirebaseAuth.instance.currentUser?.email ?? 'ไม่มีอีเมล',
          verificationStatus: _emailVerificationStatus,
          isVerified: _isEmailVerified,
          onTap: () => _showEmailUpdateDialog(),
        ),
        SizedBox(height: 15),
        _buildContactTile(
          icon: Icons.phone_outlined,
          title: 'เบอร์โทรศัพท์',
          value: _phoneController.text,
          verificationStatus:
              _isPhoneVerified ? 'ยืนยันแล้ว' : 'ยังไม่ได้ยืนยัน',
          isVerified: _isPhoneVerified,
          onTap: () => _showPhoneUpdateDialog(),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String value,
    required String verificationStatus,
    required bool isVerified,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: isVerified ? Colors.green : Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.green[700]),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    verificationStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: isVerified ? Colors.green : Colors.orange,
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

  // Validation methods
  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกชื่อผู้ใช้';
    }
    if (value.length < 3) {
      return 'ชื่อผู้ใช้ต้องมีความยาวอย่างน้อย 3 ตัว อักษร';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกที่อยู่';
    }
    if (value.length < 10) {
      return 'กรุณากรอกที่อยู่ให้ครบถ้วน';
    }
    return null;
  }

  Future<bool> _onWillPop() async {
    // ตรวจสอบว่ามีการเปลี่ยนแปลงข้อมูลหรือไม่
    if (_hasChanges) {
      // แสดง Dialog แจ้งเตือน
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ข้อมูลยังไม่ได้บันทึก'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('คุณมีการแก้ไขข้อมูลที่ยังไม่ได้บันทึก'),
              SizedBox(height: 10),
              Text(
                'ต้องการออกโดยไม่บันทึกหรือไม่?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 15),
              // แสดงรายการฟิลด์ที่มีการเปลี่ยนแปลง
              ..._buildChangedFieldsList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('ออกโดยไม่บันทึก'),
            ),
          ],
        ),
      );

      // ถ้าผู้ใช้เลือกที่จะออก
      return result ?? false;
    }

    // ถ้าไม่มีการเปลี่ยนแปลง ให้ออกได้ตามปกติ
    return true;
  }

  List<Widget> _buildChangedFieldsList() {
    List<Widget> changedFields = [];

    if (_usernameController.text.trim() != widget.userData['username']) {
      changedFields.add(_buildChangedFieldItem('ชื่อผู้ใช้'));
    }
    if (_emailController.text.trim() != widget.userData['email']) {
      changedFields.add(_buildChangedFieldItem('อีเมล'));
    }
    if (_phoneController.text.trim() != widget.userData['phone']) {
      changedFields.add(_buildChangedFieldItem('เบอร์โทรศัพท์'));
    }
    if (_addressController.text.trim() != widget.userData['address']) {
      changedFields.add(_buildChangedFieldItem('ที่อยู่'));
    }
    if (_profileImageUrl != widget.userData['profileImageUrl']) {
      changedFields.add(_buildChangedFieldItem('รูปโปรไฟล์'));
    }

    return changedFields;
  }

  Widget _buildChangedFieldItem(String fieldName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.change_circle, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Text(
            fieldName,
            style: TextStyle(color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkInternetConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<Map<String, dynamic>> _fetchUserData() async {
    try {
      // Fetch user data from Firestore
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();

      return userData.data() ?? {};
    } catch (e) {
      print('Error fetching user data: $e');
      throw e; // หรือคุณอาจจะจัดการข้อผิดพลาดตามที่คุณต้องการ
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('แก้ไขโปรไฟล์'),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _saveProfile,
                child: Text(
                  'บันทึก',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: _isInitialized
            ? Stack(
                children: [
                  _buildBody(),
                  // Floating save button
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: AnimatedOpacity(
                      opacity: _hasChanges ? 1.0 : 0.0,
                      duration: Duration(milliseconds: 300),
                      child: _hasChanges
                          ? _buildFloatingActionButton()
                          : SizedBox.shrink(),
                    ),
                  ),
                ],
              )
            : Center(
                child: CircularProgressIndicator(),
              ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[900]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: Icon(Icons.save, color: Colors.white),
        label: Text(
          'บันทึกการเปลี่ยนแปลง',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _sendPhoneOTPAndVerify(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // ตรวจสอบความถูกต้องของเบอร์โทรศัพท์
    if (cleanNumber.length != 10) {
      _showErrorSnackBar('รูปแบบเบอร์โทรศัพท์ไม่ถูกต้อง');
      return;
    }

    final formattedNumber = cleanNumber.startsWith('0')
        ? '+66${cleanNumber.substring(1)}'
        : '+$cleanNumber';

    try {
      // รอการส่ง OTP และยืนยัน
      await _sendPhoneOTP(formattedNumber);
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการส่ง OTP: ${e.toString()}');
      rethrow; // ส่งต่อข้อผิดพลาดเพื่อให้เมธอดเรียกใช้จัดการต่อ
    }
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[900]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          'บันทึกการเปลี่ยนแปลง',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileForm(Map<String, dynamic> userData) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          // เปลี่ยนจาก Column เป็น ListView
          children: [
            // แสดงรูปโปรไฟล์
            Semantics(
              label: 'ปุ่มแก้ไขรูมโปรไฟล์',
              hint: 'แตะเพื่อเปลี่ยนรูปโปรไฟล์',
              child: GestureDetector(
                onTap: _selectProfileImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _profileImageUrl != null
                      ? NetworkImage(_profileImageUrl!)
                      : AssetImage('assets/default_profile.png')
                          as ImageProvider,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ชื่อผู้ใช้
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'ชื่อผู้ใช้',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกชื่อผู้ใช้';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // อีเมล
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'อีเมล',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกอีเมล';
                }
                if (!EmailValidator.validate(value)) {
                  return 'รูปแบบอีเมลไม่ถูกต้อง';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // เบอร์โทรศัพท์
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'เบอร์โทรศัพท์',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.verified,
                      color: _isPhoneVerified ? Colors.green : Colors.grey),
                  onPressed: _phoneController.text.isNotEmpty
                      ? () => _showPhoneVerificationDialog()
                      : null,
                ),
              ),
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    !_isValidPhoneNumber(value)) {
                  return 'รูปแบบเบอร์โทรศัพท์ไม่ถูกต้อง';
                }
                return null;
              },
            ),
            if (_phoneVerificationMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _phoneVerificationMessage,
                  style: TextStyle(
                    color: _isPhoneVerified ? Colors.green : Colors.red,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // ที่อยู่
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'ที่อยู่',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกที่อยู่';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ปุ่มบันทึก
            ElevatedButton(
              onPressed: _saveProfile,
              child: Text('บันทึกการเปลี่ยนแปลง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedProfileSection() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.green.shade100,
                blurRadius: 15,
                offset: Offset(0, 10))
          ]),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _selectProfileImage,
            child: Hero(
              tag: 'profile_image',
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.green.shade100,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 75,
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : AssetImage('assets/default_profile.png')
                              as ImageProvider,
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: _saveProfile,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade800,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            widget.userData['username'] ?? 'ชื่อผู้ใช้',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsCard() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCustomTextField(
              controller: _usernameController,
              labelText: 'ชื่อผู้ใช้',
              icon: Icons.person,
            ),
            SizedBox(height: 16),
            _buildCustomTextField(
              controller: _addressController,
              labelText: 'ที่อยู่',
              icon: Icons.location_on,
              maxLines: 3,
            ),
            SizedBox(height: 16),
            _buildContactSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showEmailUpdateDialog,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _emailController.text,
                  style: TextStyle(fontSize: 16),
                ),
                Icon(Icons.edit, color: Colors.green[800]),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: _showPhoneUpdateDialog,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _phoneController.text,
                  style: TextStyle(fontSize: 16),
                ),
                Icon(Icons.edit, color: Colors.green[800]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.green.shade800),
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.green.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.green.shade800, width: 2),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              Colors.green.shade800, // Replace 'primary' with 'backgroundColor'
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 10,
        ),
        child: Text(
          'บันทึกการเปลี่ยนแปลง',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    // ตรวจสอบ Widget state
    if (!mounted || !_isInitialized) return;

    try {
      // ตรวจสอบว่ามีการเปลี่ยนแปลง
      if (!_hasChanges) {
        print('ไม่มีการเปลี่ยนแปลง');
        return;
      }

      // ตรวจสอบความถูกต้องของข้อมูล
      if (!_validateInputs()) {
        return;
      }

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('ไม่พบผู้ใช้');
        return;
      }

      // เตรียม Map สำหรับอัปเดต
      Map<String, dynamic> updateData = {};

      // เพิ่มการตรวจสอบและเพิ่มข้อมูลที่ต้องการอัปเดต
      _checkAndAddUpdates(updateData);

      // ถ้าไม่มีการเปลี่ยนแปลง
      if (updateData.isEmpty) {
        _showErrorSnackBar('ไม่มีข้อมูลที่ต้องอัปเดต');
        return;
      }

      // อัปเดตอีเมลใน Firebase Authentication หากมีการเปลี่ยนแปลง
      if (_emailController.text.trim() != currentUser.email) {
        try {
          await _handleEmailUpdate(_emailController.text.trim());
        } catch (e) {
          _showErrorSnackBar('เกิดข้อผิดพลาดในการอัปเดตอีเมล: ${e.toString()}');
          return;
        }
      }

      // อัปเดตข้อมูลใน Firestore
      await _saveUpdateHistory(updateData);
      await _updateUserProfile(currentUser, updateData);

      safeSetState(() {
        _hasChanges = false;
      });
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึก: $e');

      // แสดง Snackbar แบบปลอดภัย
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _saveUpdateHistory(Map<String, dynamic> updateData) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('user_update_history')
        .doc(currentUser.uid)
        .collection('updates')
        .add({
      'updatedFields': updateData.keys.toList(),
      'updateData': updateData,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': currentUser.uid,
      'lastUpdated': FieldValue.serverTimestamp(), // เพิ่มฟิลด์นี้
    });
  }

  void _checkAndAddUpdates(Map<String, dynamic> updateData) {
    // เพิ่มเงื่อนไขสำหรับอีเมล
    if (_emailController.text.trim() != widget.userData['email']) {
      updateData['email'] = _emailController.text.trim();
    }

    if (_usernameController.text.trim() != widget.userData['username']) {
      updateData['username'] = _usernameController.text.trim();
    }

    if (_phoneController.text.trim() != widget.userData['phone']) {
      updateData['phone'] = _phoneController.text.trim();
    }

    if (_addressController.text.trim() != widget.userData['address']) {
      updateData['address'] = _addressController.text.trim();
    }

    // เพิ่มการอัปเดตรูปโปรไฟล์หากมีการเปลี่ยนแปลง
    if (_profileImageUrl != null &&
        _profileImageUrl != widget.userData['profileImageUrl']) {
      updateData['profileImageUrl'] = _profileImageUrl;
    }
  }

  Future<void> _updateUserProfile(
      User currentUser, Map<String, dynamic> updateData) async {
    try {
      updateData['lastUpdated'] = FieldValue.serverTimestamp();

      // อัปเดตข้อมูลใน Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(updateData);

      // อัปเดต local state
      setState(() {
        // อัปเดตข้อมูลใน widget.userData
        updateData.forEach((key, value) {
          widget.userData[key] = value;
        });
        _hasChanges = false;
      });

      // แสดง Snackbar แจ้งความสำเร็จ
      _showSuccessSnackBar('บันทึกข้อมูลสำเร็จ');
    } catch (e) {
      print('Error updating user profile: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการบันทึกข้อมูล: ${e.toString()}');
    }
  }

  void _handleError(dynamic error) {
    if (!mounted) return;

    String errorMessage = 'เกิดข้อผิดพลาดที่ไม่คาดคิด';

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          errorMessage = 'หมายเลขโทรศัพท์ไม่ถูกต้อง';
          break;
        case 'too-many-requests':
          errorMessage = 'มีการร้องขอมากเกินไป กรุณาลองใหม่ภายหลัง';
          break;
        case 'email-already-in-use':
          errorMessage = 'อีเมลนี้ถูกใช้งานแล้ว';
          break;
        case 'invalid-email':
          errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
          break;
        case 'weak-password':
          errorMessage = 'รหัสผ่านไม่เพียงพอ';
          break;
        default:
          errorMessage = error.message ?? errorMessage;
      }
    } else if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          errorMessage = 'ไม่มีสิทธิ์ในการดำเนินการ';
          break;
        case 'unavailable':
          errorMessage = 'บริการไม่พร้อมใช้งาน';
          break;
        default:
          errorMessage = error.message ?? errorMessage;
      }
    } else if (error is TypeError) {
      errorMessage = 'เกิดข้อผิดพลาดทางเทคนิค';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  bool _validateInputs() {
    if (_usernameController.text.isEmpty) {
      _showErrorSnackBar('กรุณากรอกชื่อผู้ใช้');
      return false;
    }
    if (_emailController.text != widget.userData['email']) {
      print('Current Email: ${widget.userData['email']}');
      print('New Email: ${_emailController.text}');
      _showErrorSnackBar('กรุณากรอกอีเมลที่ถูกต้อง');
      return false;
    }
    if (_phoneController.text.isNotEmpty &&
        !_isValidPhoneNumber(_phoneController.text)) {
      _showErrorSnackBar('รูปแบบเบอร์โทรศัพท์ไม่ถูกต้อง');
      return false;
    }
    return true;
  }

  bool _emailValidator(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return cleanNumber.length == 10 &&
        (cleanNumber.startsWith('0') || cleanNumber.startsWith('6'));
  }

  Future<void> _sendEmailVerification(String email) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _showErrorSnackBar('ไม่พบผู้ใช้');
        return;
      }

      // ตรวจสอบก่อนว่าอีเมลซ้ำหรือไม่
      if (await _isEmailAlreadyInUse(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อีเมลนี้ถูกใช้งานแล้ว')),
        );
        return;
      }

      // อัปเดตอีเมลและส่งการยืนยัน
      await currentUser.verifyBeforeUpdateEmail(email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งลิงก์ยืนยันอีเมลแล้ว กรุณาตรวจสอบอีเมล')),
      );
    } catch (e) {
      print('Error sending email verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการส่งอีเมลยืนยัน')),
      );
    }
  }

  Future<bool> _isEmailAlreadyInUse(String email) async {
    try {
      var methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  Future<void> _handleEmailUpdate(String newEmail) async {
    try {
      // อัปเดตอีเมล
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบผู้ใช้งาน');
      }

      // ตรวจสอบว่ามีการใช้งานอีเมลนี้แล้วหรือไม่
      if (await _isEmailAlreadyInUse(newEmail)) {
        throw Exception('อีเมลนี้ถูกใช้งานแล้ว');
      }

      await currentUser.updateEmail(newEmail);
      await currentUser.sendEmailVerification();

      // อัปเดตข้อมูลใน Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'email': newEmail,
        'emailVerified': false,
      });

      // รีโหลดข้อมูลผู้ใช้
      await currentUser.reload();
    } on FirebaseAuthException catch (e) {
      // จัดการข้อผิดพลาดเฉพาะของ Firebase Authentication
      _handleEmailUpdateError(e);
    } catch (e) {
      // จัดการข้อผิดพลาดอื่นๆ
      _showErrorSnackBar('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  void _handleEmailUpdateError(FirebaseAuthException error) {
    String errorMessage = 'เกิดข้อผิดพลาดในการอัปเดตอีเมล';

    switch (error.code) {
      case 'requires-recent-login':
        errorMessage = 'ต้องทำการล็อกอินใหม่เพื่อความปลอดภัย';
        _reAuthenticateUser(); // ฟังก์ชันที่ให้ผู้ใช้ล็อกอินใหม่
        break;
      case 'email-already-in-use':
        errorMessage = 'อีเมลนี้ถูกใช้งานแล้ว';
        break;
      case 'invalid-email':
        errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
        break;
      case 'user-not-found':
        errorMessage = 'ไม่พบผู้ใช้งาน';
        break;
      default:
        errorMessage = error.message ?? errorMessage;
    }

    _showErrorSnackBar(errorMessage);
  }

  Future<void> _reAuthenticateUser() async {
    // แสดง Dialog ให้ผู้ใช้ใส่รหัสผ่าน
    final password = await _showPasswordPromptDialog();

    if (password != null) {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        AuthCredential credential = EmailAuthProvider.credential(
            email: currentUser.email!, password: password);

        await currentUser.reauthenticateWithCredential(credential);
      }
    }
  }

  Future<String?> _showPasswordPromptDialog() {
    final passwordController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันตัวตน'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'กรอกรหัสผ่าน',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkEmailVerificationStatus() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.reload(); // รีโหลดข้อมูลล่าสุด

        // อัปเดตสถานะการยืนยันอีเมลใน Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'emailVerified': currentUser.emailVerified});

        setState(() {
          _isEmailVerified = currentUser.emailVerified;
          _emailVerificationStatus =
              _isEmailVerified ? 'ยืนยันอีเมลสำเร็จ' : 'กำลังรอการยืนยัน';
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการตรวจสอบอีเมล: $e');
      _handleError(e);
    }
  }

  Future<void> _reAuthenticateIfNeeded(User currentUser) async {
    try {
      // ตรวจสอบว่าต้องทำการ Re-authenticate หรือไม่
      if (currentUser.metadata.lastSignInTime != null) {
        final lastSignInTime = currentUser.metadata.lastSignInTime!;
        final currentTime = DateTime.now();
        final difference = currentTime.difference(lastSignInTime);

        // ถ้าล็อกอินมานานเกิน 5 นาที ให้ Re-authenticate
        if (difference.inMinutes > 5) {
          await _reAuthenticateUser();
        }
      }
    } catch (e) {
      print('Re-authenticate check error: $e');
      await _reAuthenticateUser();
    }
  }

// เพิ่มเมธอดจัดการ token หมดอายุ
  Future<void> _handleTokenExpiration() async {
    // แสดง Dialog แจ้งเตือนให้ล็อกอินใหม่
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('เซสชันหมดอายุ'),
        content: Text('กรุณาล็อกอินใหม่เพื่อดำเนินการต่อ'),
        actions: [
          ElevatedButton(
            onPressed: () {
              // ออกจากแอพและไปยังหน้าล็อกอิน
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginPage()),
                (Route<dynamic> route) => false,
              );
            },
            child: Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _showEmailUpdateDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'อัปเดตอีเมล',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'อีเมลใหม่',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.email, color: Colors.green[800]),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              Text(
                'กรุณากรอกอีเมลใหม่\nระบบจะส่งลิงก์ยืนยันไปยังอีเมลนี้',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'ยกเลิก',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      if (_isValidEmail(emailController.text)) {
                        _sendEmailVerification(emailController.text);
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('รูปแบบอีเมลไม่ถูกต้อง'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'ส่งการยืนยัน',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhoneUpdateDialog() {
    final TextEditingController phoneController =
        TextEditingController(text: _phoneController.text);
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('อัปเดตเบอร์โทรศัพท์'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'เบอร์โทรศัพท์ใหม่',
                  prefixText: '+66 ',
                  border: OutlineInputBorder(),
                  errorText: errorText,
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (value) {
                  setState(() {
                    errorText = _validatePhoneNumber(value);
                  });
                },
              ),
              if (_isPhoneVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'ยืนยันเบอร์โทรศัพท์แล้ว',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: _isValidPhoneNumber(phoneController.text)
                  ? () {
                      Navigator.pop(context);
                      _handlePhoneUpdate(context, phoneController.text);
                    }
                  : null,
              child: Text('ส่ง OTP'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePhoneNumber(String phoneNumber) {
    // ลบช่องว่างและตัวอักษรพิเศษ
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanNumber.isEmpty) {
      return 'กรุณากรอกเบอร์โทรศัพท์';
    }

    if (cleanNumber.length != 10) {
      return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
    }

    // ตรวจสอบรหัสนำหน้าที่ถูกต้อง
    if (!cleanNumber.startsWith('0') && !cleanNumber.startsWith('6')) {
      return 'รูปแบบเบอร์โทรศัพท์ไม่ถูกต้อง';
    }

    return null;
  }

  Future<void> _handlePhoneUpdate(
      BuildContext context, String phoneNumber) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      final formattedNumber = '+66${cleanNumber.substring(1)}';

      // ส่ง OTP
      await _sendPhoneOTP(formattedNumber);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่ง OTP: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Helper Methods
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _sendPhoneOTP(String phoneNumber) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          setState(() {
            _isPhoneVerified = true;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          _handleError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _showOTPVerificationDialog(phoneNumber);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _handleError(e);
    }
  }

  void _showOTPVerificationDialog(String phoneNumber) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('ยืนยัน OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('รหัส OTP ถูกส่งไปที่เบอร์ $phoneNumber'),
            TextField(
              decoration: InputDecoration(
                labelText: 'กรอกรหัส OTP',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (otp) {
                if (otp.length == 6) {
                  _verifyPhoneOTP(otp);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
