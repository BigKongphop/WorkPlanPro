import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebaseAuth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workplanpro/screens/login_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';
import 'dart:async';

class NetworkTimeout {
  static Future<T> run<T>({
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 15),
    String errorMessage = 'Operation timed out',
  }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException {
      // Log timeout
      FirebaseCrashlytics.instance.recordError(
        TimeoutException(errorMessage),
        null,
        fatal: false,
      );
      rethrow;
    } catch (e) {
      // Log other errors
      FirebaseCrashlytics.instance.recordError(
        e,
        null,
        fatal: false,
      );
      rethrow;
    }
  }
}

class RegisPage extends StatefulWidget {
  @override
  _RegisPageState createState() => _RegisPageState();
}

class _RegisPageState extends State<RegisPage> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger('RegistrationPage');

  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  @override
  void initState() {
    super.initState();
    // ตั้งค่า Global Error Handler
    FlutterError.onError = (FlutterErrorDetails details) {
      // บันทึก Error
      _logError(details.exception, details.stack);
    };

    // จัดการ Unhandled Errors
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      // บันทึก Error
      _logError(error, stackTrace);
      return true;
    };
    _setupComprehensiveErrorHandling();
  }

  void _setupComprehensiveErrorHandling() {
    // จัดการ Error ระดับ Global
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleGlobalError(details.exception, details.stack,
          errorContext: 'Registration Page Flutter Error');
    };

    // จัดการ Unhandled Errors ใน Async Zone
    runZonedGuarded(() {
      // Main app logic
    }, (error, stackTrace) {
      _handleGlobalError(error, stackTrace,
          errorContext: 'Registration Page Async Error');
    });
  }

  // เมธอดจัดการ Error อย่างครอบคลุม
  void _handleGlobalError(
    dynamic error,
    StackTrace? stackTrace, {
    String errorContext = 'Registration Page Async Error', // แก้ไขตรงนี้
  }) {
    try {
      // บันทึก Error ด้วย Crashlytics
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: errorContext,
        fatal: false,
      );

      // บันทึก Error ลง Log
      _logErrorToFile(error, stackTrace, errorContext);

      // แสดง Error Dialog แบบปลอดภัย
      _showSafeErrorDialog(error, errorContext);
    } catch (e) {
      // Fallback error handling
      print('Error handling failed: $e');
    }
  }

  // บันทึก Error ลงไฟล์
  void _logErrorToFile(
      dynamic error, StackTrace? stackTrace, String errorContext) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/registration_error_log.txt');

      final errorLog = '''
    Timestamp: ${DateTime.now()}
    Context: $errorContext
    Error: $error
    StackTrace: $stackTrace
    -------------------
    ''';

      await file.writeAsString(errorLog, mode: FileMode.append);
    } catch (e) {
      print('Failed to log error to file: $e');
    }
  }

  // แสดง Error Dialog แบบปลอดภัย
  void _showSafeErrorDialog(dynamic error, String errorContext) {
    if (!mounted) return;

    // แปลง Error เป็นข้อความที่เป็นมิตร
    String errorMessage = _getFriendlyErrorMessage(error, errorContext);

    showDialog(
      context: context, // ใช้ context จาก State
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Registration Error',
          style: TextStyle(color: Colors.red[700]),
        ),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // ใช้ dialogContext
              // Optional: Perform recovery action
              _attemptRecovery();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // แปลง Error เป็นข้อความที่เป็นมิตร
  String _getFriendlyErrorMessage(dynamic error, String context) {
    // จัดการ Error ประเภทต่างๆ
    if (error is firebaseAuth.FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(error);
    }

    if (error is SocketException) {
      return 'Network error. Please check your internet connection.';
    }

    if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    }

    // Error ทั่วไป
    return 'An unexpected error occurred during $context. Please try again later.';
  }

  // จัดการ Firebase Auth Error
  String _getFirebaseAuthErrorMessage(
      firebaseAuth.FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in or use a different email.';
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email format. Please check your email address.';
      case 'operation-not-allowed':
        return 'Registration is currently disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many registration attempts. Please try again later.';
      default:
        return 'Registration failed. Please check your details and try again.';
    }
  }

  // พยายามกู้คืนสถานะ
  void _attemptRecovery() {
    try {
      // รีเซ็ตฟอร์มและล้างข้อมูล
      _resetRegistrationForm();
    } catch (e) {
      print('Recovery attempt failed: $e');
    }
  }

  // รีเซ็ตฟอร์มการลงทะเบียน
  void _resetRegistrationForm() {
    setState(() {
      // ล้างข้อมูลในฟอร์ม
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();

      // รีเซ็ต Error state
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });
  }

  // เพิ่มการตรวจสอบเครือข่าย
  Future<bool> _checkNetworkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection');
      return false;
    }
    return true;
  }

  // เมธอดสำหรับบันทึก Error
  void _logError(dynamic error, StackTrace? stackTrace) {
    try {
      // บันทึก Error ด้วย Firebase Crashlytics
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
      );

      // Log ด้วย Logger
      _logger.severe('Unhandled Error', error, stackTrace);

      // แสดง Error Dialog
      _showErrorDialog(error.toString());
    } catch (e) {
      print('Error logging error: $e');
    }
  }

  // การลงทะเบียนที่มีการตรวจสอบความปลอดภัย
  Future<void> _performRegistrationWithSafetyChecks() async {
    try {
      // Create user
      final userCredential = await firebaseAuth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Check if user is created successfully
      final user = userCredential.user;
      if (user != null) {
        // Send verification email
        await _sendVerificationEmail(user);

        // Wait for email verification
        await _waitForEmailVerification(user);
      }
    } on firebaseAuth.FirebaseAuthException catch (e) {
      // Handle Firebase Authentication errors
      _handleAuthError(e);
    } catch (e) {
      // Show general error
      _showErrorSnackBar('Registration failed: ${e.toString()}');
    } finally {
      // Ensure loading indicator is closed
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _waitForEmailVerification(firebaseAuth.User user) async {
    final completer = Completer<void>();
    bool isDialogOpen = false;
    Timer? verificationTimer;

    if (!mounted) return;

    try {
      isDialogOpen = true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              // ฟังก์ชันตรวจสอบอีเมลและปิด Dialog
              Future<void> checkEmailVerification() async {
                try {
                  if (!mounted) return;

                  // รีโหลดข้อมูลผู้ใช้เพื่อตรวจสอบสถานะการยืนยันอีเมล
                  await user.reload();

                  // ดึงข้อมูลผู้ใช้ล่าสุด
                  final currentUser =
                      firebaseAuth.FirebaseAuth.instance.currentUser;

                  // ตรวจสอบว่าผู้ใช้ยังคงอยู่และอีเมลถูกยืนยันแล้ว
                  if (currentUser != null && currentUser.emailVerified) {
                    // ยกเลิก Timer ก่อน
                    verificationTimer?.cancel();

                    // ตรวจสอบว่า Dialog ยังเปิดอยู่และสามารถปิดได้
                    if (isDialogOpen && mounted) {
                      if (Navigator.of(dialogContext).canPop()) {
                        isDialogOpen = false;
                        Navigator.of(dialogContext).pop();
                      }
                    }

                    // แจ้งเตือนผู้ใช้
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Your email has been verified!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }

                    // บันทึกข้อมูลผู้ใช้ลง Firestore
                    await _saveUserToFirestore(currentUser);

                    // นำทางไปยังหน้าถัดไป
                    if (mounted) {
                      _navigateToNextScreen();
                    }

                    // จบการทำงาน
                    if (!completer.isCompleted) {
                      completer.complete();
                    }
                  }
                } catch (e) {
                  print('Error checking email verification: $e');
                  // ในกรณีที่เกิดข้อผิดพลาด ให้ยกเลิก Timer
                  verificationTimer?.cancel();
                }
              }

              // สร้าง Timer สำหรับตรวจสอบการยืนยันอีเมล
              verificationTimer =
                  Timer.periodic(Duration(seconds: 3), (timer) async {
                if (!mounted || !isDialogOpen) {
                  timer.cancel();
                  return;
                }
                await checkEmailVerification();
              });

              return WillPopScope(
                onWillPop: () async => false,
                child: AlertDialog(
                  title: Text('Verify Your Email'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Please check your email and verify your account.'),
                      SizedBox(height: 20),
                      CircularProgressIndicator(),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        try {
                          // ยกเลิก Timer ก่อน
                          verificationTimer?.cancel();

                          isDialogOpen = false;
                          if (mounted && Navigator.of(dialogContext).canPop()) {
                            Navigator.of(dialogContext).pop();
                          }

                          // ยกเลิกการลงทะเบียนอย่างปลอดภัย
                          if (user != null) {
                            await user.delete().timeout(
                              Duration(seconds: 5),
                              onTimeout: () {
                                throw TimeoutException(
                                    'User deletion timed out');
                              },
                            );
                          }

                          if (!completer.isCompleted) {
                            completer.complete();
                          }
                        } catch (e) {
                          print('Error during registration cancellation: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to cancel registration'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Text('Cancel Registration'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error in verification dialog: $e');
      // ในกรณีที่เกิดข้อผิดพลาด ให้ยกเลิก Timer
      verificationTimer?.cancel();

      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    } finally {
      // ยกเลิก Timer เมื่อออกจากฟังก์ชัน
      verificationTimer?.cancel();
      isDialogOpen = false;
    }

    return completer.future;
  }

  Future<void> _performEmailVerificationCheck(firebaseAuth.User user) async {
    // Attempt multiple verification checks
    for (int i = 0; i < 3; i++) {
      try {
        // Reload user with force refresh
        await user.reload();

        // Force token refresh
        await user.getIdToken(true);

        // Additional Firebase check
        final tokenResult = await user.getIdTokenResult(true);

        // Perform multiple checks
        if (user.emailVerified ||
            (tokenResult.claims?['email_verified'] == true)) {
          // Close loading indicator
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }

          // Close verification dialog
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }

          // Save user to Firestore
          await _saveUserToFirestore(user);

          // Navigate to next screen
          _navigateToNextScreen();

          return;
        }

        // Wait before next attempt
        await Future.delayed(Duration(seconds: 3));
      } catch (e) {
        print('Verification attempt $i failed: $e');

        // Wait before next attempt
        await Future.delayed(Duration(seconds: 2));
      }
    }

    // If all attempts fail
    // Close loading indicator
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    _showErrorSnackBar('Unable to verify email. Please try again.');
  }

  void _showErrorDialog(String errorMessage) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<T?> _safeAsyncOperation<T>(
    Future<T> Function() operation, {
    String? errorMessage,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      // บันทึก Error
      _logError(e, stackTrace);

      // แสดง Error Message
      _showErrorSnackBar(
        errorMessage ?? 'An unexpected error occurred: ${e.toString()}',
      );

      return null;
    }
  }

  void _validateUsername(String value) {
    setState(() {
      _usernameError = _validateUsernameRules(value);
    });
  }

  String? _validateUsernameRules(String value) {
    if (value.isEmpty) return 'Username is required';

    // More comprehensive username validation
    if (value.length < 10) return 'Username must be at least 10 characters';
    if (value.length > 20) return 'Username must not exceed 20 characters';

    // Check for allowed characters
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(value)) {
      return 'Username can only contain lowercase letters and numbers';
    }

    // Additional checks (e.g., prevent common usernames)
    final List<String> forbiddenUsernames = ['admin', 'root', 'user'];
    if (forbiddenUsernames.contains(value.toLowerCase())) {
      return 'This username is not allowed';
    }

    return null;
  }

  void _validateEmail(String value) {
    setState(() {
      _emailError = value.isEmpty
          ? 'Email is required'
          : (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)
              ? 'Enter a valid email'
              : null);
    });
  }

  void _validatePassword(String value) {
    setState(() {
      _passwordError = _validatePasswordStrength(value);
    });
  }

  String? _validatePasswordStrength(String value) {
    if (value.isEmpty) return 'Password is required';

    // More detailed password strength check
    if (value.length < 10) return 'Password must be at least 10 characters';
    if (value.length > 20) return 'Password must not exceed 20 characters';

    // แก้ไข RegExp ให้ถูกต้อง
    bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = value.contains(RegExp(r'[a-z]'));
    bool hasDigits = value.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = value.contains(RegExp(r'[!@#\$&*~]'));

    if (!hasUppercase) return 'Password must contain an uppercase letter';
    if (!hasLowercase) return 'Password must contain a lowercase letter';
    if (!hasDigits) return 'Password must contain a number';
    if (!hasSpecialChar) return 'Password must contain a special character';

    return null;
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      _confirmPasswordError =
          value != _passwordController.text ? 'Passwords do not match' : null;
    });
  }

  Future<void> _register() async {
    // ตรวจสอบ Form Validation ก่อน
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please correct the form errors');
      return;
    }

    // ตรวจสอบความถูกต้องของข้อมูล
    if (!_validateAllFields()) {
      _showErrorSnackBar('Please check all fields');
      return;
    }

    // ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
    if (!await _checkNetworkConnectivity()) {
      return;
    }

    try {
      // เพิ่ม Loading indicator
      _showLoadingIndicator();

      // ดำเนินการลงทะเบียน
      await _performRegistrationWithSafetyChecks();
    } catch (e) {
      // ซ่อน Loading indicator
      Navigator.of(context).pop();

      // จัดการ Error
      _handleRegistrationError(e);
    }
  }

  void _showLoadingIndicator() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C5217)),
          ),
        );
      },
    );
  }

  void _handleRegistrationError(dynamic error) {
    if (error is firebaseAuth.FirebaseAuthException) {
      _handleAuthError(error);
    } else {
      _showErrorSnackBar('Registration failed: ${error.toString()}');
    }
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    // ใช้ pushAndRemoveUntil แทน pushReplacement เพื่อล้าง stack ทั้งหมด
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  bool _validateAllFields() {
    _validateUsername(_usernameController.text);
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);
    _validateConfirmPassword(_confirmPasswordController.text);

    return _usernameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null;
  }

  void _handleAuthError(firebaseAuth.FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'email-already-in-use':
        message =
            'This email is already registered. Try logging in or use a different email.';
        break;
      case 'weak-password':
        message =
            'The password is too weak. Please choose a stronger password.';
        break;
      case 'invalid-email':
        message = 'Invalid email format. Please check your email address.';
        break;
      case 'operation-not-allowed':
        message = 'Registration is currently disabled. Please contact support.';
        break;
      case 'too-many-requests':
        message = 'Too many registration attempts. Please try again later.';
        break;
      default:
        message =
            'Registration failed. Please check your details and try again.';
    }
    _showErrorSnackBar(message);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _saveUserToFirestore(firebaseAuth.User user) async {
    // Perform final verification check
    await user.reload();

    if (!user.emailVerified) {
      _showErrorSnackBar('Email verification failed. Cannot save user.');
      throw Exception('Email not verified');
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'userId': user.uid,
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'emailVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'profileImageUrl': '',
        'phone': '',
        'address': '',
      });

      _showSuccessSnackBar('Account created successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to save user data: ${e.toString()}');
      rethrow;
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _sendVerificationEmail(firebaseAuth.User user) async {
    try {
      // Check if email is not verified
      if (!user.emailVerified) {
        // Attempt to send verification email multiple times
        for (int i = 0; i < 3; i++) {
          try {
            await user.sendEmailVerification();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Verification email sent. Please check your inbox.'),
                  backgroundColor: Colors.green,
                ),
              );
              return;
            }
          } catch (sendError) {
            print('Email verification send attempt $i failed: $sendError');

            // Wait before next attempt
            await Future.delayed(Duration(seconds: 2));
          }
        }

        // If all send attempts fail
        _showErrorSnackBar(
            'Failed to send verification email. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar(
          'Unexpected error sending verification email: ${e.toString()}');

      // Optional: Delete user if email verification fails
      try {
        await user.delete();
      } catch (deleteError) {
        print('Failed to delete user: $deleteError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0C5217),
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextFormField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.person,
                    errorText: _usernameError,
                    onChanged: _validateUsername,
                    helperText: 'Enter 10-20 characters (a-z, 0-9)',
                  ),
                  SizedBox(height: 20),
                  _buildTextFormField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    errorText: _emailError,
                    onChanged: _validateEmail,
                    helperText:
                        'Use a valid email format (e.g., user@example.com)',
                  ),
                  SizedBox(height: 20),
                  _buildTextFormField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    errorText: _passwordError,
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Color(0xFF0C5217),
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    onChanged: _validatePassword,
                    helperText: 'Include 1 special character (!@#\$&*~)',
                  ),
                  SizedBox(height: 20),
                  _buildTextFormField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock,
                    errorText: _confirmPasswordError,
                    obscureText: !_isConfirmPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Color(0xFF0C5217),
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    onChanged: _validateConfirmPassword,
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      backgroundColor: Color(0xFF0C5217),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      shadowColor: Color(0xFF0C5217).withOpacity(0.3),
                      elevation: 5,
                    ),
                    child: Text(
                      "Register",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text(
                      "Already have an account? Log in",
                      style: TextStyle(color: Color(0xFF0C5217)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
    bool obscureText = false,
    Widget? suffixIcon,
    required Function(String) onChanged,
    String? helperText,
  }) {
    return Tooltip(
      message: helperText ?? '',
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Color(0xFF0C5217)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          prefixIcon: Icon(icon, color: Color(0xFF0C5217)),
          suffixIcon: suffixIcon,
          errorText: errorText,
        ),
        obscureText: obscureText,
        onChanged: onChanged,
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }
}
