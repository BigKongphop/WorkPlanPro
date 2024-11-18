// safe_navigation_mixin.dart
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
            child: Text('OK'),
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
    String errorMessage = customMessage ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ';

    // จำแนกประเภท Error
    if (error is FirebaseException) {
      errorMessage = _mapFirebaseError(error);
    } else if (error is TimeoutException) {
      errorMessage = 'หมดเวลาการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง';
    } else if (error is SocketException) {
      errorMessage = 'เกิดปัญหาการเชื่อมต่อเครือข่าย';
    }

    // บันทึก Log หรือส่ง Error ไปยัง Error Tracking Service
    print('Error: $errorMessage');

    // แสดง Error Dialog หรือ SnackBar
    if (mounted) {
      showErrorDialog('เกิดข้อผิดพลาด', errorMessage);
    }
  }

  // แมพ Error จาก Firebase
  String _mapFirebaseError(FirebaseException error) {
    // เพิ่ม FirebaseException
    switch (error.code) {
      case 'network-request-failed':
        return 'การเชื่อมต่อเครือข่ายล้มเหลว';
      case 'permission-denied':
        return 'ไม่มีสิทธิ์เข้าถึงข้อมูล';
      case 'unavailable':
        return 'บริการไม่พร้อมใช้งาน';
      case 'invalid-credential':
        return 'ข้อมูลประจำตัวไม่ถูกต้อง';
      case 'user-not-found':
        return 'ไม่พบผู้ใช้';
      case 'wrong-password':
        return 'รหัสผ่านไม่ถูกต้อง';
      case 'too-many-requests':
        return 'มีการร้องขอมากเกินไป กรุณาลองใหม่ภายหลัง';
      default:
        return error.message ?? 'เกิดข้อผิดพลาดจาก Firebase';
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
        showSnackBar('ไม่มีการเชื่อมต่ออินเทอร์เน็ต', isError: true);
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
