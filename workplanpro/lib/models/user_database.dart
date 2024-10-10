import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'personal.dart'; // Import ไฟล์ personal.dart

class UserDatabase {
  static const String _fileName = "user_data.json";

  // อ่านข้อมูลจากไฟล์
  Future<List<User>> _loadUsers() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_fileName');

    if (await file.exists()) {
      final data = await file.readAsString();
      List<dynamic> jsonData = jsonDecode(data);
      return jsonData
          .map((json) => User.fromJson(Map<String, String>.from(json)))
          .toList();
    }

    return [];
  }

  // บันทึกข้อมูลลงไฟล์
  Future<void> _saveUsers(List<User> users) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_fileName');
    final data = jsonEncode(users.map((user) => user.toJson()).toList());
    await file.writeAsString(data);
  }

  // ตรวจสอบว่ามี Username อยู่ในฐานข้อมูลแล้วหรือไม่
  Future<bool> isUsernameExists(String username) async {
    final users = await _loadUsers();
    return users.any((user) => user.username == username);
  }

  // ตรวจสอบว่า Email มีในฐานข้อมูลแล้วหรือไม่
  Future<bool> isEmailExists(String email) async {
    final users = await _loadUsers();
    return users.any((user) => user.email == email);
  }

  // ตรวจสอบข้อมูลการ Login
  Future<bool> isValidLogin(String username, String password) async {
    final users = await _loadUsers();
    final user = users.firstWhere(
      (user) => user.username == username,
      orElse: () =>
          User(username: '', email: '', password: ''), // ใช้ค่าเริ่มต้น
    );

    return user.username.isNotEmpty &&
        user.password == password; // คืนค่าการตรวจสอบรหัสผ่าน
  }

  // เพิ่มผู้ใช้ใหม่
  Future<void> registerUser(User newUser) async {
    final users = await _loadUsers();
    users.add(newUser);
    await _saveUsers(users);
  }

  Future<User?> fetchUser() async {
    final users = await _loadUsers();
    return users.isNotEmpty
        ? users.first
        : null; // Return the first user or null
  }

  // Update user data
  Future<void> updateUser(User updatedUser) async {
    final users = await _loadUsers();
    if (users.isNotEmpty) {
      users[0] = updatedUser; // Update the first user
      await _saveUsers(users);
    }
  }
}
