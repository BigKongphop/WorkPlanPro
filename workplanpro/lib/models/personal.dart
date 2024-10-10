class User {
  String username;
  String email;
  String password;

  User({required this.username, required this.email, required this.password});

  Map<String, String> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
    };
  }

  static User fromJson(Map<String, String> json) {
    return User(
      username: json['username']!,
      email: json['email']!,
      password: json['password']!,
    );
  }
}
