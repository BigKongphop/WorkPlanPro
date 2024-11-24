// login_page.dart
import 'dart:io';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:lottie/lottie.dart';
import 'package:synchronized/synchronized.dart';
import 'package:workplanpro/screens/home_page.dart';
import 'package:workplanpro/screens/regis_page.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class CustomCacheManager {
  static Future<void> clearSpecificImageCache(String imageUrl) async {
    try {
      await CachedNetworkImage.evictFromCache(imageUrl);
    } catch (e) {
      print('Specific Image Cache Clear Error: $e');
    }
  }

  // เปลี่ยนเป็นเมธอดที่ต้องส่ง BuildContext
  static Future<void> preloadImage(
      BuildContext context, String imageUrl) async {
    try {
      // ส่ง BuildContext เข้าไปด้วย
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context, // เพิ่ม BuildContext เข้าไป
      );
    } catch (e) {
      print('Image Preload Error: $e');
    }
  }
}

// ตัวอย่างการใช้งาน
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ต้องส่ง context เข้าไปด้วย
    CustomCacheManager.preloadImage(context, 'https://example.com/image.jpg');

    return Container();
  }
}

class CacheMonitor {
  static Future<void> analyzeCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final docDir = await getApplicationDocumentsDirectory();

      // Calculate total cache size
      int tempSize = _calculateDirectorySize(tempDir);
      int docSize = _calculateDirectorySize(docDir);

      print('Temporary Cache Size: ${tempSize ~/ 1024} KB');
      print('Document Cache Size: ${docSize ~/ 1024} KB');
    } catch (e) {
      print('Cache Size Analysis Error: $e');
    }
  }

  static int _calculateDirectorySize(Directory directory) {
    int size = 0;
    directory.listSync(recursive: true).forEach((FileSystemEntity file) {
      if (file is File) {
        size += file.lengthSync();
      }
    });
    return size;
  }
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

/*
class _LoginRateLimiter {
  static const _maxAttempts = 5;
  static const _lockoutDuration = Duration(minutes: 15);

  int _attempts = 0;
  DateTime? _lastLockout;

  bool get isLocked {
    if (_lastLockout != null) {
      if (DateTime.now().difference(_lastLockout!) < _lockoutDuration) {
        return true;
      }
      _resetAttempts();
    }
    return false;
  }

  void recordFailedAttempt() {
    _attempts++;
    if (_attempts >= _maxAttempts) {
      _lastLockout = DateTime.now();
    }
  }

  void _resetAttempts() {
    _attempts = 0;
    _lastLockout = null;
  }
}
*/
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool _isPasswordVisible = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isProcessing = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _processingMutex = Lock();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _rememberMe = false;

  Future<void> _completeAppReset() async {
    try {
      // 1. ออกจากระบบ Firebase
      await FirebaseAuth.instance.signOut();

      // 2. ล้าง SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. ล้าง Firestore Persistence
      await FirebaseFirestore.instance.clearPersistence();

      // 4. ล้าง Cache ทั้งหมด
      await _clearAllCaches();

      // 5. รีเซ็ตสถานะ Controllers
      _usernameController.clear();
      _passwordController.clear();

      // 6. รีเซ็ตสถานะ State
      setState(() {
        _isLoading = false;
        _isProcessing = false;
        _isPasswordVisible = false;
      });

      // 7. บันทึกเหตุการณ์รีเซ็ต
      _logSecurityEvent('app_reset');
    } catch (e) {
      // บันทึกข้อผิดพลาด
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);

      // แสดงข้อผิดพลาด
      _showErrorDialog('Reset Error', 'Unable to reset app state');
    }
  } // ฟังก์ชันล้าง Cache อย่างครอบคลุม

  Future<void> _clearAllCaches() async {
    try {
      // ล้าง Image Cache
      await _clearImageCache();

      // ล้าง Temporary Files
      await _clearTemporaryFiles();

      // ล้าง Application Cache
      await _clearAppCache();

      // ล้าง Firebase Cache
      await _clearFirebaseCache();
    } catch (e) {
      print('Cache Clearing Error: $e');
    }
  }

  Future<void> _handleLogin() async {
    if (!await _checkInternetConnection()) {
      _showErrorDialog('No Internet', 'Please check your internet connection');
      return;
    }

    await _processingMutex.synchronized(() async {
      if (_isProcessing) return;

      setState(() {
        _isProcessing = true;
        _isLoading = true;
      });

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // บันทึกข้อมูลถ้าผู้ใช้เลือก "Remember Me"
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('email', _usernameController.text.trim());
          await prefs.setString('password', _passwordController.text.trim());
        } else {
          // ถ้าไม่เลือก Remember Me ให้ล้างข้อมูล
          await prefs.remove('remember_me');
          await prefs.remove('email');
          await prefs.remove('password');
        }

        // ตรวจสอบว่าผู้ใช้ล็อกอินสำเร็จหรือไม่
        await _handleUserAfterLogin(userCredential);
      } on FirebaseAuthException catch (e) {
        // จัดการข้อผิดพลาด Firebase
        _handleFirebaseAuthError(e);
      } catch (e) {
        // จัดการข้อผิดพลาดทั่วไป
        _handleGeneralError(e);
      } finally {
        _resetProcessingState();
      }
    });
  }

  Future<void> _handleUserAfterLogin(UserCredential userCredential) async {
    User? user = userCredential.user;

    if (user != null) {
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        _showEmailVerificationDialog(user);
        return;
      }

      _navigateToHomePage(user.email ?? '');
    }
  }

  Future<void> _logoutCurrentUser() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      print('Logout Current User Error: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);
    }
  }

  Future<void> _safeResetAppState() async {
    try {
      // 1. ล้าง SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. ออกจากระบบ Firebase
      await FirebaseAuth.instance.signOut();

      // 3. ล้าง Firestore Persistence
      await FirebaseFirestore.instance.clearPersistence();

      // 4. ล้าง Cache ทั้งหมด
      await _clearAllCaches();

      // 5. รีเซ็ตค่าคอนโทรลเลอร์
      _usernameController.clear();
      _passwordController.clear();

      // 6. รีเซ็ตสถานะ State
      setState(() {
        _isLoading = false;
        _isProcessing = false;
        _isPasswordVisible = false;
      });

      // 7. บันทึกเหตุการณ์รีเซ็ต
      _logSecurityEvent('app_reset');
    } catch (e) {
      print('Safe Reset App State Error: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);

      // แสดง Error Dialog แบบปลอดภัย
      _showSafeErrorDialog('Reset Error', 'Unable to reset app state');
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await _clearUserData();
    } catch (e) {
      print('Safe sign out error: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);
    }
  }

  Future<void> _performSafeLogout() async {
    try {
      // ตรวจสอบการเชื่อมต่อเครือข่าย
      await _ensureNetworkConnectivity();

      // ล้างข้อมูลผู้ใช้
      await _clearAllUserData();

      // ออกจากระบบ Firebase
      await FirebaseAuth.instance.signOut();

      // บันทึกเหตุการณ์
      _logLogoutEvent();

      // นำทางไปหน้า Login
      _navigateToLoginPage();
    } catch (e) {
      // จัดการข้อผิดพลาด
      _handleLogoutError(e);
    }
  }

  void _resetProcessingState() {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isLoading = false;
      });
    }
  }

  void _showSafeErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Optional: Perform recovery action
              _attemptRecovery();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
    _checkPreviousLogin();
  }

  void _showLogoutLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      ),
    );
  }

  void _navigateToLoginPage() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false, // ลบหน้าจอทั้งหมดออกจากสแต็ก
    );
  }

  Future<void> _signOutFromFirebase() async {
    try {
      // ตรวจสอบและออกจากระบบ Firebase
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Firebase sign out error: $e');
      // บันทึก error ด้วย Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        null,
        fatal: false,
      );
    }
  }

  void _dismissLoadingDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _logLogoutEvent() {
    try {
      // บันทึกเหตุการณ์ Logout ด้วย Firebase Analytics
      FirebaseAnalytics.instance.logEvent(
        name: 'logout',
        parameters: {
          'method': 'email',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error logging logout event: $e');
    }
  }

  Future<void> _clearAllUserData() async {
    try {
      // 1. ล้าง SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. ล้าง Firestore persistence
      await FirebaseFirestore.instance.clearPersistence();

      // 3. ล้าง Firebase Authentication state
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // ยกเลิกการสมัครรับการแจ้งเตือน
        await _unsubscribeFromNotifications(currentUser.uid);

        // รีโหลดข้อมูลผู้ใช้
        await currentUser.reload();
      }

      // 4. ล้าง Cache อื่นๆ ที่จำเป็น
      await _clearAdditionalCaches();
    } catch (e) {
      print('Comprehensive logout error: $e');
      // จัดการข้อผิดพลาดโดยไม่หยุดกระบวนการ
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);
    }
  }

  Future<void> _unsubscribeFromNotifications(String userId) async {
    try {
      // ยกเลิกการสมัครรับการแจ้งเตือนสำหรับผู้ใช้
      // คุณต้องใช้ Firebase Cloud Messaging หรือบริการแจ้งเตือนอื่นๆ
    } catch (e) {
      print('Error unsubscribing from notifications: $e');
    }
  }

  Future<void> _clearAdditionalCaches() async {
    try {
      // ล้าง Cache ของภาพโปรไฟล์ (ตัวอย่าง)
      String profileImageUrl =
          'https://example.com/path/to/image.jpg'; // เปลี่ยน URL ให้ตรงกับภาพที่ต้องการลบ
      await clearImageCache(profileImageUrl);

      // ล้าง Cache เพิ่มเติม เช่น
      await removeTemporaryFiles();
    } catch (e) {
      print('Error clearing additional caches: $e');
    }
  }

  Future<void> removeTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (e) {
      print('Error removing temporary files: $e');
    }
  }

  Future<void> clearImageCache(String imageUrl) async {
    try {
      await CachedNetworkImage.evictFromCache(imageUrl);
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }

  void _handleLogoutError(dynamic error) {
    // 1. บันทึก Error ด้วย Crashlytics
    FirebaseCrashlytics.instance.recordError(
      error,
      null,
      fatal: false,
      reason: 'Logout Process Failed',
    );

    // 2. แสดง Snackbar แจ้งเตือนผู้ใช้
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ออกจากระบบไม่สำเร็จ: ${error.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );

    // 3. บังคับนำทางไปหน้า Login
    _navigateToLoginPage();
  }

  void _setupErrorHandling() {
    // จัดการ Unhandled Errors ในระดับ App
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleGlobalError(details.exception, details.stack);
    };

    // จัดการ Unhandled Errors ใน Async Zone
    runZonedGuarded(() {
      // โค้ดหลักของแอพ
    }, (error, stackTrace) {
      _handleGlobalError(error, stackTrace);
    });
  }

  void _handleGlobalError(dynamic error, StackTrace? stackTrace) {
    try {
      // บันทึก Error ด้วย Crashlytics
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
      );

      // บันทึก Error ลง Log
      _logErrorToFile(error, stackTrace);

      // แสดง Error Dialog แบบปลอดภัย
      _showSafeErrorDialog(
          'Unexpected Error', error.toString()); // ส่ง title และ message
    } catch (e) {
      // Fallback error handling
      print('Error handling failed: $e');
    }
  }

  void _logErrorToFile(dynamic error, StackTrace? stackTrace) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/error_log.txt');

      final errorLog = '''
      ${DateTime.now()}
      Error: $error
      StackTrace: $stackTrace
      -------------------
      ''';

      await file.writeAsString(errorLog, mode: FileMode.append);
    } catch (e) {
      print('Failed to log error to file: $e');
    }
  }

  void _attemptRecovery() {
    try {
      // รีเซ็ตสถานะที่จำเป็น
      _resetAppState();
    } catch (e) {
      print('Recovery attempt failed: $e');
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Forgot Password'),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(
            hintText: 'Enter your email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: emailController.text.trim(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset email sent'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                _handleLoginError(e);
              }
            },
            child: Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  String _getFriendlyErrorMessage(dynamic error) {
    // จัดการ Error ประเภทต่างๆ
    if (error is FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(error);
    }

    if (error is SocketException) {
      return 'Network error. Please check your internet connection.';
    }

    if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    }

    // Error ทั่วไป
    return 'An unexpected error occurred. Please try again later.';
  }

  String _getFirebaseAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later';
      default:
        return 'Authentication failed';
    }
  }

  void _handleInitialAppState() async {
    try {
      // ตรวจสอบและจัดการสถานะเริ่มต้นของแอพ
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // ถ้ามีผู้ใช้ล็อกอินค้างอยู่ ให้ออกจากระบบ
        await _clearUserData();
      }
    } catch (e) {
      print('Initial app state error: $e');
      // จัดการข้อผิดพลาดที่เกิดขึ้น
      await _resetAppState();
    }
  }

  Future<void> _logout() async {
    try {
      // ล้างข้อมูลผู้ใช้
      await _clearUserData();

      // ล้าง SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_me');
      await prefs.remove('email');
      await prefs.remove('password');

      // นำทางไปยังหน้า Login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
      print('Logout error: $e');
    }
  }

  Future<void> _clearUserData() async {
    try {
      // ล้างข้อมูลใน SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('email');
      await prefs.remove('uid');

      // ลงชื่อออกจากระบบ Firebase
      await FirebaseAuth.instance.signOut();

      // ล้าง Cache ของ Firebase Auth
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  Future<void> _checkPreviousLogin() async {
    final prefs = await SharedPreferences.getInstance();

    // ตรวจสอบว่ามีการเลือก "Remember Me" ในครั้งก่อนหรือไม่
    bool rememberMeEnabled = prefs.getBool('remember_me') ?? false;

    if (rememberMeEnabled) {
      // ดึง email และ password เฉพาะเมื่อ Remember Me เปิดอยู่
      final savedEmail = prefs.getString('email');
      final savedPassword = prefs.getString('password');

      if (savedEmail != null) {
        _usernameController.text = savedEmail;
      }

      if (savedPassword != null) {
        _passwordController.text = savedPassword;
      }
    } else {
      // ถ้าไม่ได้เลือก Remember Me ให้ล้างข้อมูลเก่า
      await prefs.remove('email');
      await prefs.remove('password');

      // ล้าง TextField
      _usernameController.clear();
      _passwordController.clear();
    }
  }

  bool _validateInputsWithSecurity() {
    final email = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Check for Empty Inputs
    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Invalid Input', 'Please enter email and password');
      return false;
    }

    // 2. Email Format Validation
    if (!_isValidEmail(email)) {
      _showErrorDialog('Invalid Email', 'Please enter a valid email address');
      return false;
    }

    // 3. Input Safety Check
    if (!_isInputSafe(email) || !_isInputSafe(password)) {
      _showErrorDialog('Security Alert', 'Unsafe input detected');
      return false;
    }

    // 4. Password Complexity (Optional)
    if (!_isPasswordComplex(password)) {
      _showErrorDialog(
          'Weak Password', 'Password does not meet complexity requirements');
      return false;
    }

    return true;
  }

  bool _isInputSafe(String input) {
    final unsafePatterns = [
      RegExp(r'<script>'),
      RegExp(r'--'),
      RegExp(r';'),
      RegExp(r'\/\*'),
      RegExp(r'union\s+select'),
    ];

    return !unsafePatterns.any((pattern) => pattern.hasMatch(input));
  }

  Future<UserCredential> _loginWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await _performLoginWithTimeout();
      } catch (e) {
        if (attempt == maxRetries) rethrow;

        // Exponential backoff
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw Exception('Login failed after $maxRetries attempts');
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        _showErrorDialog(
            'No Internet', 'Please check your internet connection');
        return false;
      }

      return true;
    } catch (e) {
      _handleGeneralError(e);
      return false;
    }
  }

  // เพิ่มการตรวจสอบ Network อย่างมีประสิทธิภาพ
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      // แสดง Snackbar แจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No Internet Connection'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: const TextStyle(color: Color(0xFF0C5217))),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF0C5217))),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmailVerificationDialog(User user) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ยืนยันอีเมล'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('กรุณาตรวจสอบอีเมลเพื่อยืนยันบัญชีของคุณ'),
                Text('ส่งไปที่: ${user.email}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('ส่งอีเมลยืนยันอีกครั้ง'),
              onPressed: () async {
                try {
                  await user.sendEmailVerification();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ส่งอีเมลยืนยันแล้ว'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  _handleLoginError(e);
                }
              },
            ),
            TextButton(
              child: Text('ตกลง'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<UserCredential> _performLogin() async {
    // ตรวจสอบรูปแบบอีเมล
    if (!_isValidEmail(_usernameController.text.trim())) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'รูปแบบอีเมลไม่ถูกต้อง',
      );
    }

    // ตรวจสอบความยาวรหัสผ่าน
    if (_passwordController.text.trim().length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร',
      );
    }

    // ลงชื่อเข้าใช้ ```dart
    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  Future<void> _ensureNetworkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw SocketException('No internet connection');
    }
  }

  Future<UserCredential> _loginWithTimeout() async {
    try {
      return await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _usernameController.text.trim(),
            password: _passwordController.text.trim(),
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Login timeout'),
          );
    } on FirebaseAuthException catch (e) {
      // Log specific Firebase Auth errors
      _logSecurityEvent('login_failure', metadata: {'error_code': e.code});
      rethrow;
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    _logSecurityEvent('login_failure', metadata: {'error_code': e.code});
    switch (e.code) {
      case 'user-not-found':
        _showErrorDialog('Login Failed', 'No user found with this email');
        break;
      case 'wrong-password':
        _showErrorDialog('Login Failed', 'Incorrect password');
        break;
      case 'user-disabled':
        _showErrorDialog('Account Disabled', 'This account has been disabled');
        break;
      default:
        _handleGeneralError(e);
    }
  }

  void _handleGeneralError(dynamic error) {
    FirebaseCrashlytics.instance.recordError(error, null, fatal: false);
    _showErrorDialog(
        'Error', 'An unexpected error occurred. Please try again.');
  }

  void _logSecurityEvent(String eventType, {Map<String, dynamic>? metadata}) {
    try {
      FirebaseAnalytics.instance.logEvent(
        name: 'security_event',
        parameters: {
          'event_type': eventType,
          'timestamp': DateTime.now().toIso8601String(),
          ...?metadata
        },
      );
    } catch (e) {
      print('Security Event Logging Error: $e');
    }
  }

  Future<UserCredential> _performLoginWithTimeout() async {
    try {
      return await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _usernameController.text.trim(),
            password: _passwordController.text.trim(),
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Login timeout'),
          );
    } on FirebaseAuthException catch (e) {
      _logSecurityEvent('login_failure', metadata: {'error_code': e.code});
      rethrow;
    }
  }

  void _handleUnexpectedError(dynamic error) {
    // ตรวจสอบว่า mounted อยู่หรือไม่
    if (!mounted) return;

    // บันทึก Error สำหรับการวิเคราะห์
    _logErrorToService(error);

    // แสดง Error Dialog มีความเป็นมิตร
    _showErrorDialog(
      'Unexpected Error',
      'An unexpected error occurred. Please try again later.',
    );
  }

  Future<void> _checkUserLoginStatus() async {
    try {
      print('เริ่มตรวจสอบสถานะการล็อกอิน');
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        print('พบผู้ใช้: ${user.email}');

        try {
          await user.reload(); // โหลดข้อมูลผู้ใช้ใหม่
          print('โหลดข้อมูลผู้ใช้สำเร็จ');
        } catch (reloadError) {
          print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $reloadError');
          FirebaseCrashlytics.instance.recordError(reloadError, null,
              reason: 'โหลดข้อมูลผู้ใช้ล้มเหลว');
        }

        // ตรวจสอบการยืนยันอีเมล
        if (!user.emailVerified) {
          print('อีเมลยังไม่ได้รับการยืนยัน');
          await _handleUnverifiedUser(user);
          return;
        }

        // ตรวจสอบความสมบูรณ์ของบัญชีผู้ใช้
        bool isIntegral = await _verifyUserIntegrity(user);
        if (!isIntegral) {
          print('การตรวจสอบบัญชีผู้ใช้ล้มเหลว');
          await FirebaseAuth.instance.signOut();
          return;
        }

        // บันทึกข้อมูลผู้ใช้
        try {
          await _saveUserData(user);
          print('บันทึกข้อมูลผู้ใช้สำเร็จ');
        } catch (saveError) {
          print('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $saveError');
          FirebaseCrashlytics.instance.recordError(saveError, null,
              reason: 'บันทึกข้อมูลผู้ใช้ล้มเหลว');
        }
      } else {
        print('ไม่พบผู้ใช้ปัจจุบัน');
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดร้ายแรงในการตรวจสอบสถานะ: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: true);

      // บังคับออกจากระบบเพื่อความปลอดภัย
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _handleUnverifiedUser(User user) async {
    try {
      // ลงชื่อออกจากระบบทันที
      await FirebaseAuth.instance.signOut();

      // แสดงข้อความแจ้งเตือนที่ชัดเจนและเป็นมิตร
      await _showCustomVerificationDialog(user);
    } catch (e) {
      _handleLoginStatusError(e);
    }
  }

  void setupPeriodicCacheManagement() {
    Timer.periodic(Duration(days: 7), (timer) async {
      await clearAllAppCache();
    });
  }

  Future<void> _showCustomVerificationDialog(User user) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // ผู้ใช้ต้องกดปุ่ม
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Email Verification Required',
            style: TextStyle(color: Colors.red[700]),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Your email is not verified. Please check your inbox for the verification email.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 15),
                Text(
                  'Sent to: ${user.email}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Resend Verification',
                  style: TextStyle(color: Colors.blue)),
              onPressed: () async {
                try {
                  // ส่งอีเมลยืนยันอีกครั้ง
                  await user.sendEmailVerification();

                  // ปิด Dialog ปัจจุบัน
                  Navigator.of(context).pop();

                  // แสดง Snackbar แจ้งว่าส่งอีเมลแล้ว
                  _showVerificationResendSnackbar();
                } catch (e) {
                  // จัดการข้อผิดพลาดในการส่งอีเมลยืนยัน
                  _handleVerificationResendError(e);
                }
              },
            ),
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showVerificationResendSnackbar() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification email sent. Please check your inbox.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _handleVerificationResendError(dynamic error) {
    if (!mounted) return;

    String errorMessage =
        'Failed to send verification email. Please try again.';

    // จัดการข้อผิดพลาดเฉพาะจาก Firebase
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network error. Please check your internet connection.';
          break;
      }
    }

    // แสดง Snackbar แจ้งข้อผิดพลาด
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );

    // บันทึก Error สำหรับการวิเคราะห์
    FirebaseCrashlytics.instance.recordError(error, null, fatal: false);
  }

  void _handleLoginStatusError(dynamic error) {
    try {
      // บันทึก Error อย่างละเอียด
      FirebaseCrashlytics.instance.recordError(error, null,
          reason: 'Login Status Check Failure', fatal: false);

      // ลงชื่อออกจากระบบเพื่อความปลอดภัย
      FirebaseAuth.instance.signOut();

      // แสดงข้อความแจ้งเตือนแบบ Snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login error. Please try again.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Critical error in login status handling: $e');
    }
  }

  Future<void> _handleVerifiedUser(User user) async {
    try {
      // ล้างข้อมูลเก่า
      await _clearPreviousUserData();
      // บันทึกข้อมูลผู้ใช้ใหม่
      await _saveUserData(user);
      // อัปเดตอีเมลใน Firestore
      await _updateUserEmailInFirestore(user);
      // ตรวจสอบความสมบูรณ์ของผู้ใช้
      if (!await _verifyUserIntegrity(user)) {
        await FirebaseAuth.instance.signOut();
        throw Exception('User  integrity check failed');
      }
    } catch (e) {
      _handleLoginStatusError(e);
    }
  }

  Future<void> _updateUserEmailInFirestore(User user) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await userRef.update({
        'email': user.email,
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating email in Firestore: $e');
    }
  }

  Future<void> _clearPreviousUserData() async {
    try {
      // ล้าง SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // ล้าง Firestore cache
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      print('Error clearing previous user data: $e');
    }
  }

  Future<void> _resetAppState() async {
    try {
      // ล้างข้อมูลผู้ใช้
      await _clearUserData();

      // ล้าง Cache และข้อมูลที่เก็บไว้
      await FirebaseAuth.instance.signOut();

      // ล้าง Firestore cache
      await FirebaseFirestore.instance.clearPersistence();

      // รีเซ็ตค่าคอนโทรลเลอร์
      _usernameController.clear();
      _passwordController.clear();

      // รีเซ็ตสถานะ
      setState(() {
        _isLoading = false;
        _isPasswordVisible = false;
      });
    } catch (e) {
      print('Error resetting app state: $e');
      FirebaseCrashlytics.instance.recordError(e, null);
    }
  }

  void _logErrorToService(dynamic error) {
    // ตัวอย่างการใช้ Firebase Crashlytics
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        null,
        fatal: false,
      );
    } catch (e) {
      print('Error logging to Crashlytics: $e');
    }
  }

  bool _validateInputsDetailed() {
    final email = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Sanitize input
    if (_containsHarmfulCharacters(email) ||
        _containsHarmfulCharacters(password)) {
      _showErrorDialog('Invalid Input', 'Input contains invalid characters');
      return false;
    }

    // Validate email
    if (!_isValidEmail(email)) {
      _showErrorDialog('Invalid Email', 'Please enter a valid email');
      return false;
    }

    return true;
  } // ตรวจสอบตัวอักษรอันตราย

  bool _containsHarmfulCharacters(String input) {
    final harmfulPattern = RegExp(r'[<>{}()\/\\\[\]]');
    return harmfulPattern.hasMatch(input);
  } // ตรวจสอบความซับซ้อนของรหัสผ่าน

  bool _isPasswordComplex(String password) {
    final complexityRegex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');
    return complexityRegex.hasMatch(password);
  }

  void _setLoadingState(bool isLoading) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
      });
    }
  }

  bool _validateInputs() {
    final email = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Invalid Input', 'Please enter email and password');
      return false;
    }

    if (!_isValidEmail(email)) {
      _showErrorDialog('Invalid Email', 'Please enter a valid email address');
      return false;
    }

    return true;
  }

  // ฟังก์ชันตรวจสอบอีเมล
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

  void _handleSpecificFirebaseAuthError(FirebaseAuthException e) {
    // บันทึกเหตุการณ์ความปลอดภัย
    _logSecurityEvent('login_failure', metadata: {'error_code': e.code});

    // จำกัดการพยายามล็อกอิน
    /*_loginRateLimiter.recordFailedAttempt();*/

    switch (e.code) {
      case 'too-many-requests':
        _showErrorDialog('Too Many Attempts',
            'Account temporarily locked. Please try again later.');
        break;
      default:
        // จัดการข้อผิดพลาดอื่นๆ
        _showErrorDialog(
            'Login Failed', e.message ?? 'An unexpected error occurred.');
    }
  }

  bool _checkEmailVerification(User? user) {
    if (user == null || !user.emailVerified) {
      _showErrorDialog('Email Not Verified',
          'Please verify your email address before logging in.');
      return false;
    }
    return true;
  }

  Future<void> _saveUserData(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // บันทึกข้อมูลผู้ใช้
      await prefs.setString('email', user.email ?? '');
      await prefs.setString('uid', user.uid);

      // ตรวจสอบและสร้างเอกสารผู้ใช้ใน Firestore
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          // สร้างเอกสารผู้ใช้ใหม่หากยังไม่มี
          transaction.set(userRef, {
            'email': user.email,
            'username':
                user.displayName ?? user.email?.split('@').first ?? 'User',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } else {
          // อัปเดตการเข้าสู่ระบบล่าสุดและอีเมล
          transaction.update(userRef, {
            'email': user.email,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      _handleLoginStatusError(e);
      rethrow;
    }
  }

  // เพิ่มเมธอดตรวจสอบความปลอดภัยเพิ่มเติม
  Future<bool> _verifyUserIntegrity(User user) async {
    try {
      print('ตรวจสอบความสมบูรณ์ของบัญชีผู้ใช้');
      await user.reload();
      return user.emailVerified &&
          !user.isAnonymous &&
          user.providerData.isNotEmpty;
    } catch (e) {
      print('ข้อผิดพลาดในการตรวจสอบความสมบูรณ์: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);
      return false;
    }
  }

  void _handleLoginError(dynamic error) {
    // รีเซ็ตสถานะก่อนจัดการข้อผิดพลาด
    setState(() {
      _isProcessing = false;
      _isLoading = false;
    });

    // บันทึกข้อผิดพลาด
    FirebaseCrashlytics.instance.recordError(error, null, fatal: false);

    // จัดการข้อผิดพลาดเฉพาะ
    if (error is FirebaseAuthException) {
      String errorMessage = _getFirebaseAuthErrorMessage(error);

      // แสดง Snackbar หรือ Dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // ข้อผิดพลาดทั่วไป
      _showErrorDialog('Login Error', error.toString());
    }
  }

  Future<void> _clearAllCacheAndData() async {
    try {
      // 1. ล้าง SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. ล้าง Firestore persistence
      await FirebaseFirestore.instance.clearPersistence();

      // 3. ล้าง Firebase Authentication state
      await FirebaseAuth.instance.signOut();

      // 4. ล้าง Cache ของ Firebase
      await _clearFirebaseCache();

      // 5. ล้าง Cache ของ Image
      await _clearImageCache();

      // 6. ล้าง Cache ของ App
      await _clearAppCache();

      // 7. ล้าง Temporary Files
      await _clearTemporaryFiles();

      // 8. Reset App State
      await _resetAppState();
    } catch (e) {
      print('เกิดข้อผิดพลาดในการล้างข้อมูล: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);
    }
  }

  Future<void> _clearFirebaseCache() async {
    try {
      // ล้าง Firebase Authentication Cache
      await FirebaseAuth.instance.currentUser?.reload();

      // ล้าง Firestore Cache
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      print('Error clearing Firebase cache: $e');
    }
  }

  Future<void> clearSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _clearImageCache() async {
    try {
      // ล้าง Cache ของรูปภาพทั้งหมด
      // ต้องระบุ URL หรือ key ที่ต้องการล้าง
      await CachedNetworkImage.evictFromCache('https://example.com/image.jpg');

      // หรือถ้าต้องการล้าง Cache ของ Provider
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }

  Future<void> _clearAppCache() async {
    try {
      // ล้าง Application Cache Directory
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }

      // ล้าง Application Document Directory
      final docDir = await getApplicationDocumentsDirectory();
      if (docDir.existsSync()) {
        docDir.deleteSync(recursive: true);
      }
    } catch (e) {
      print('Error clearing app cache: $e');
    }
  }

  Future<void> clearAllAppCache() async {
    try {
      // 1. Clear User Authentication
      await FirebaseAuth.instance.signOut();

      // 2. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. Clear Firebase Caches
      await FirebaseFirestore.instance.clearPersistence();

      // 4. Clear Image Caches
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // 5. Clear Temporary Files
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }

      // 6. Clear Document Cache
      final docDir = await getApplicationDocumentsDirectory();
      final cacheFolder = Directory('${docDir.path}/cache');
      if (cacheFolder.existsSync()) {
        cacheFolder.deleteSync(recursive: true);
      }

      // 7. Reset App State
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    } catch (e) {
      print('Comprehensive Cache Clear Error: $e');
      FirebaseCrashlytics.instance.recordError(e, null);
    }
  }

  Future<void> clearAppDocumentCache() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();

      // Delete specific cache files/folders
      final cacheFolder = Directory('${docDir.path}/cache');
      if (cacheFolder.existsSync()) {
        cacheFolder.deleteSync(recursive: true);
      }
    } catch (e) {
      print('Document Cache Clear Error: $e');
    }
  }

  Future<void> _clearTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.listSync().forEach((file) {
          try {
            file.deleteSync(recursive: true);
          } catch (e) {
            print('Error deleting temporary file: $e');
          }
        });
      }
    } catch (e) {
      print('Error clearing temporary files: $e');
    }
  }

  // เพิ่มฟังก์ชันจัดการ Error แบบกว้าง
  void _handleError(dynamic error) {
    print('Unexpected Error: $error');

    // ตรวจสอบ mounted ก่อนแสดง Dialog
    if (!mounted) return;

    setState(() => _isLoading = false);

    // แสดง Error Dialog แบบทั่วไป
    _showErrorDialog(
        'Error', 'An unexpected error occurred. Please try again later.');
  } // สร้างเมธอด Navigation แบบปลอดภัย

  // สร้างเมธอด Navigation แบบปลอดภัย
  void _navigateToHomePage(String email) async {
    if (!mounted) return;

    try {
      // รีโหลดข้อมูลผู้ใช้
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => HomePage(
            username: email,
            userEmail: email, // Add this line
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0); // เริ่มจากด้านล่าง
            const end = Offset.zero; // ไปยังตำแหน่งปัจจุบัน
            const curve = Curves.easeInOut; // รูปแบบการเคลื่อนไหว

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration:
              const Duration(milliseconds: 500), // ระยะเวลาอนิเมชั่น
        ),
      );
    } catch (e) {
      // จัดการข้อผิดพลาดในการรีโหลดข้อมูล
      _handleLoginError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animation/animation_login_3.json',
                    height: 200,
                    repeat: true,
                  ),
                  const SizedBox(height: 40),
                  AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        'Login',
                        textStyle: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0C5217),
                        ),
                        speed: const Duration(milliseconds: 100),
                      ),
                    ],
                    totalRepeatCount: 1,
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _usernameFocusNode,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    isPassword: true,
                    focusNode: _passwordFocusNode,
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value!;
                          });
                        },
                      ),
                      const Text('Remember Me'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildForgotPasswordLink(), // เพิ่มลิงค์ลืมรหัสผ่าน
                  const SizedBox(height: 30),
                  _buildLoginButton(),
                  const SizedBox(height: 20),
                  _buildRegisterLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink() {
    return GestureDetector(
      onTap: _showForgotPasswordDialog,
      child: Text(
        'Forgot Password?',
        style: TextStyle(
          color: Color(0xFF0C5217),
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    Function(String)? onSubmitted,
    FocusNode? focusNode,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        keyboardType: keyboardType,
        focusNode: focusNode,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0C5217)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: const Color(0xFF0C5217),
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return _isLoading
        ? const CircularProgressIndicator(color: Color(0xFF0C5217))
        : ElevatedButton(
            onPressed: _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C5217),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 80),
            ),
            child: const Text('Login',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? "),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RegisPage()),
            );
          },
          child: const Text(
            'Register',
            style: TextStyle(
              color: Color(0xFF0C5217),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // ปิด Controller และ Clear Resources
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }
}
