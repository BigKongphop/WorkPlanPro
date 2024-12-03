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

  static Future<void> preloadImage(
      BuildContext context, String imageUrl) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      );
    } catch (e) {
      print('Image Preload Error: $e');
    }
  }
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    CustomCacheManager.preloadImage(context, 'https://example.com/image.jpg');

    return Container();
  }
}

class CacheMonitor {
  static Future<void> analyzeCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final docDir = await getApplicationDocumentsDirectory();

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
      await FirebaseAuth.instance.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await FirebaseFirestore.instance.clearPersistence();

      await _clearAllCaches();

      _usernameController.clear();
      _passwordController.clear();

      setState(() {
        _isLoading = false;
        _isProcessing = false;
        _isPasswordVisible = false;
      });

      _logSecurityEvent('app_reset');
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);

      _showErrorDialog('Reset Error', 'Unable to reset app state');
    }
  }

  Future<void> _clearAllCaches() async {
    try {
      await _clearImageCache();

      await _clearTemporaryFiles();

      await _clearAppCache();

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

        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('email', _usernameController.text.trim());
          await prefs.setString('password', _passwordController.text.trim());
        } else {
          await prefs.remove('remember_me');
          await prefs.remove('email');
          await prefs.remove('password');
        }

        await _handleUserAfterLogin(userCredential);
      } on FirebaseAuthException catch (e) {
        _handleFirebaseAuthError(e);
      } catch (e) {
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await FirebaseAuth.instance.signOut();

      await FirebaseFirestore.instance.clearPersistence();

      await _clearAllCaches();

      _usernameController.clear();
      _passwordController.clear();

      setState(() {
        _isLoading = false;
        _isProcessing = false;
        _isPasswordVisible = false;
      });

      _logSecurityEvent('app_reset');
    } catch (e) {
      print('Safe Reset App State Error: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);

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
      await _ensureNetworkConnectivity();

      await _clearAllUserData();

      await FirebaseAuth.instance.signOut();

      _logLogoutEvent();

      _navigateToLoginPage();
    } catch (e) {
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
              _attemptRecovery();
            },
            child: Text('Okay'),
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
      (route) => false,
    );
  }

  Future<void> _signOutFromFirebase() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Firebase sign out error: $e');
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await FirebaseFirestore.instance.clearPersistence();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _unsubscribeFromNotifications(currentUser.uid);

        await currentUser.reload();
      }

      await _clearAdditionalCaches();
    } catch (e) {
      print('Comprehensive logout error: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);
    }
  }

  Future<void> _unsubscribeFromNotifications(String userId) async {
    try {
    } catch (e) {
      print('Error unsubscribing from notifications: $e');
    }
  }

  Future<void> _clearAdditionalCaches() async {
    try {
      String profileImageUrl =
          'https://example.com/path/to/image.jpg';
      await clearImageCache(profileImageUrl);

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
    FirebaseCrashlytics.instance.recordError(
      error,
      null,
      fatal: false,
      reason: 'Logout Process Failed',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to log out: ${error.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );

    _navigateToLoginPage();
  }

  void _setupErrorHandling() {
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleGlobalError(details.exception, details.stack);
    };

    runZonedGuarded(() {
    }, (error, stackTrace) {
      _handleGlobalError(error, stackTrace);
    });
  }

  void _handleGlobalError(dynamic error, StackTrace? stackTrace) {
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
      );

      _logErrorToFile(error, stackTrace);

      _showSafeErrorDialog(
          'Unexpected Error', error.toString());
    } catch (e) {
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
    if (error is FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(error);
    }

    if (error is SocketException) {
      return 'Network error. Please check your internet connection.';
    }

    if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    }

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
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        await _clearUserData();
      }
    } catch (e) {
      print('Initial app state error: $e');
      await _resetAppState();
    }
  }

  Future<void> _logout() async {
    try {
      await _clearUserData();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_me');
      await prefs.remove('email');
      await prefs.remove('password');

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('email');
      await prefs.remove('uid');

      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.currentUser?.reload();
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  Future<void> _checkPreviousLogin() async {
    final prefs = await SharedPreferences.getInstance();

    bool rememberMeEnabled = prefs.getBool('remember_me') ?? false;

    if (rememberMeEnabled) {
      final savedEmail = prefs.getString('email');
      final savedPassword = prefs.getString('password');

      if (savedEmail != null) {
        _usernameController.text = savedEmail;
      }

      if (savedPassword != null) {
        _passwordController.text = savedPassword;
      }
    } else {
      await prefs.remove('email');
      await prefs.remove('password');

      _usernameController.clear();
      _passwordController.clear();
    }
  }

  bool _validateInputsWithSecurity() {
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

    if (!_isInputSafe(email) || !_isInputSafe(password)) {
      _showErrorDialog('Security Alert', 'Unsafe input detected');
      return false;
    }

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

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
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
          title: Text('Confirm email'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Please check your email to verify your account.'),
                Text('Send to: ${user.email}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Resend confirmation email'),
              onPressed: () async {
                try {
                  await user.sendEmailVerification();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Confirmation email sent'),
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
              child: Text('Agree'),
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
    if (!_isValidEmail(_usernameController.text.trim())) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Invalid email format',
      );
    }

    if (_passwordController.text.trim().length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters long.',
      );
    }

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
    if (!mounted) return;

    _logErrorToService(error);

    _showErrorDialog(
      'Unexpected Error',
      'An unexpected error occurred. Please try again later.',
    );
  }

  Future<void> _checkUserLoginStatus() async {
    try {
      print('Start checking login status');
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        print('Found user: ${user.email}');

        try {
          await user.reload();
          print('User data loaded successfully.');
        } catch (reloadError) {
          print('An error occurred loading data.: $reloadError');
          FirebaseCrashlytics.instance.recordError(reloadError, null,
              reason: 'Failed to load user data.');
        }

        if (!user.emailVerified) {
          print('Email has not been verified.');
          await _handleUnverifiedUser(user);
          return;
        }

        bool isIntegral = await _verifyUserIntegrity(user);
        if (!isIntegral) {
          print('User account verification failed.');
          await FirebaseAuth.instance.signOut();
          return;
        }

        try {
          await _saveUserData(user);
          print('User information was successfully saved.');
        } catch (saveError) {
          print('An error occurred while saving data.: $saveError');
          FirebaseCrashlytics.instance.recordError(saveError, null,
              reason: 'Failed to save user information.');
        }
      } else {
        print('The current user was not found.');
      }
    } catch (e) {
      print('A fatal error occurred in the status check.: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: true);

      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _handleUnverifiedUser(User user) async {
    try {
      await FirebaseAuth.instance.signOut();

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
      barrierDismissible: false,
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
                  await user.sendEmailVerification();

                  Navigator.of(context).pop();

                  _showVerificationResendSnackbar();
                } catch (e) {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );

    FirebaseCrashlytics.instance.recordError(error, null, fatal: false);
  }

  void _handleLoginStatusError(dynamic error) {
    try {
      FirebaseCrashlytics.instance.recordError(error, null,
          reason: 'Login Status Check Failure', fatal: false);

      FirebaseAuth.instance.signOut();

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
      await _clearPreviousUserData();
      await _saveUserData(user);
      await _updateUserEmailInFirestore(user);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      print('Error clearing previous user data: $e');
    }
  }

  Future<void> _resetAppState() async {
    try {
      await _clearUserData();

      await FirebaseAuth.instance.signOut();

      await FirebaseFirestore.instance.clearPersistence();

      _usernameController.clear();
      _passwordController.clear();

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

    if (_containsHarmfulCharacters(email) ||
        _containsHarmfulCharacters(password)) {
      _showErrorDialog('Invalid Input', 'Input contains invalid characters');
      return false;
    }

    if (!_isValidEmail(email)) {
      _showErrorDialog('Invalid Email', 'Please enter a valid email');
      return false;
    }

    return true;
  }

  bool _containsHarmfulCharacters(String input) {
    final harmfulPattern = RegExp(r'[<>{}()\/\\\[\]]');
    return harmfulPattern.hasMatch(input);
  }

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

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

  void _handleSpecificFirebaseAuthError(FirebaseAuthException e) {
    _logSecurityEvent('login_failure', metadata: {'error_code': e.code});

    switch (e.code) {
      case 'too-many-requests':
        _showErrorDialog('Too Many Attempts',
            'Account temporarily locked. Please try again later.');
        break;
      default:
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

      await prefs.setString('email', user.email ?? '');
      await prefs.setString('uid', user.uid);

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          transaction.set(userRef, {
            'email': user.email,
            'username':
                user.displayName ?? user.email?.split('@').first ?? 'User',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } else {
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

  Future<bool> _verifyUserIntegrity(User user) async {
    try {
      print('Verify user account integrity');
      await user.reload();
      return user.emailVerified &&
          !user.isAnonymous &&
          user.providerData.isNotEmpty;
    } catch (e) {
      print('Integrity check error: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);
      return false;
    }
  }

  void _handleLoginError(dynamic error) {
    setState(() {
      _isProcessing = false;
      _isLoading = false;
    });

    FirebaseCrashlytics.instance.recordError(error, null, fatal: false);

    if (error is FirebaseAuthException) {
      String errorMessage = _getFirebaseAuthErrorMessage(error);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      _showErrorDialog('Login Error', error.toString());
    }
  }

  Future<void> _clearAllCacheAndData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await FirebaseFirestore.instance.clearPersistence();

      await FirebaseAuth.instance.signOut();

      await _clearFirebaseCache();

      await _clearImageCache();

      await _clearAppCache();

      await _clearTemporaryFiles();

      await _resetAppState();
    } catch (e) {
      print('An error occurred cleaning data.: $e');
      FirebaseCrashlytics.instance.recordError(e, null, fatal: false);
    }
  }

  Future<void> _clearFirebaseCache() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();

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

      await CachedNetworkImage.evictFromCache('https://example.com/image.jpg');

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }

  Future<void> _clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }

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
      await FirebaseAuth.instance.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await FirebaseFirestore.instance.clearPersistence();

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }

      final docDir = await getApplicationDocumentsDirectory();
      final cacheFolder = Directory('${docDir.path}/cache');
      if (cacheFolder.existsSync()) {
        cacheFolder.deleteSync(recursive: true);
      }

      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    } catch (e) {
      print('Comprehensive Cache Clear Error: $e');
      FirebaseCrashlytics.instance.recordError(e, null);
    }
  }

  Future<void> clearAppDocumentCache() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();

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

  void _handleError(dynamic error) {
    print('Unexpected Error: $error');

    if (!mounted) return;

    setState(() => _isLoading = false);

    _showErrorDialog(
        'Error', 'An unexpected error occurred. Please try again later.');
  }

  void _navigateToHomePage(String email) async {
    if (!mounted) return;

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => HomePage(
            username: email,
            userEmail: email,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration:
              const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
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
                  _buildForgotPasswordLink(),
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
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }
}
