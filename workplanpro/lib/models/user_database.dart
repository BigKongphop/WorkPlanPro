import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'personal.dart';

class UserDatabase {
  static const String _fileName = "user_data.json";

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

  Future<void> _saveUsers(List<User> users) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_fileName');
    final data = jsonEncode(users.map((user) => user.toJson()).toList());
    await file.writeAsString(data);
  }

  Future<bool> isUsernameExists(String username) async {
    final users = await _loadUsers();
    return users.any((user) => user.username == username);
  }

  Future<bool> isEmailExists(String email) async {
    final users = await _loadUsers();
    return users.any((user) => user.email == email);
  }

  Future<bool> isValidLogin(String username, String password) async {
    final users = await _loadUsers();
    final user = users.firstWhere(
      (user) => user.username == username,
      orElse: () =>
          User(username: '', email: '', password: ''),
    );

    return user.username.isNotEmpty &&
        user.password == password;
  }

  Future<void> registerUser(User newUser) async {
    final users = await _loadUsers();
    users.add(newUser);
    await _saveUsers(users);
  }

  Future<User?> fetchUser() async {
    final users = await _loadUsers();
    return users.isNotEmpty
        ? users.first
        : null;
  }

  Future<void> updateUser(User updatedUser) async {
    final users = await _loadUsers();
    if (users.isNotEmpty) {
      users[0] = updatedUser;
      await _saveUsers(users);
    }
  }
}
