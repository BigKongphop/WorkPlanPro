import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

mixin SafeNavigationMixin<T extends StatefulWidget> on State<T> {
  bool _isLoading = false;
  bool _hasInternetConnection = true;

  // ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
  Future<bool> checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternetConnection = connectivityResult != ConnectivityResult.none;
    });
    return _hasInternetConnection;
  }

  // เมธอดนำทางที่ปลอดภัย
  void safeNavigate(BuildContext context, Widget destinationPage) {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destinationPage),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // แสดง Error Dialog
  void showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Okay'),
          ),
        ],
      ),
    );
  }

  // แสดง SnackBar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // จัดการ Error อย่างครอบคลุม
  void handleError(dynamic error, {String? customMessage}) {
    String errorMessage = customMessage ?? 'An unknown error occurred.';

    // จำแนกประเภท Error
    if (error is FirebaseException) {
      errorMessage = _mapFirebaseError(error);
    } else if (error is TimeoutException) {
      errorMessage = 'Connection timed out Please try again.';
    } else if (error is SocketException) {
      errorMessage = 'There was a network connection problem.';
    }

    // บันทึก Log หรือส่ง Error ไปยัง Error Tracking Service
    print('Error: $errorMessage');

    // แสดง Error Dialog หรือ SnackBar
    if (mounted) {
      showErrorDialog('An error occurred.', errorMessage);
    }
  }

  // แมพ Error จาก Firebase
  String _mapFirebaseError(FirebaseException error) {
    // เพิ่ม FirebaseException
    switch (error.code) {
      case 'network-request-failed':
        return 'Network connection failed.';
      case 'permission-denied':
        return 'No access to data';
      case 'unavailable':
        return 'Service unavailable';
      case 'invalid-credential':
        return 'Invalid credentials';
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'The password is incorrect.';
      case 'too-many-requests':
        return 'Too many requests Please try again later.';
      default:
        return error.message ?? 'An error occurred from Firebase.';
    }
  }

  // เมธอดสำหรับการโหลดข้อมูล
  Future<void> safeLoadData(Future<void> Function() loadFunction) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
      if (!await checkInternetConnection()) {
        showSnackBar('No internet connection', isError: true);
        return;
      }

      // โหลดข้อมูล
      await loadFunction();
    } catch (e) {
      handleError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
