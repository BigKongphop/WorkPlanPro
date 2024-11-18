import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Define UserProfileManager class first
class UserProfileManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> updateProfileImage(
      String username, ImageSource source) async {
    // ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
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

      // อัพเดทข้อมูลใน Firestore โดยใช้ path ของรูปภาพ
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'profileImageUrl': image.path, // เก็บ path แทน URL จาก Storage
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('อัปเดตรูปภาพโปรไฟล์สำเร็จ');
        return image.path;
      } else {
        print('ไม่พบผู้ใช้ที่มีชื่อผู้ใช้ตามที่ระบุ');
        return null;
      }
    } catch (e) {
      print('Unexpected Error: $e');
      return null;
    }
  }
}
