import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workplanpro/screens/regis_page.dart';
import 'account_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<QuerySnapshot?> getUserData(String username, String password) async {
    try {
      return await FirebaseFirestore.instance
          .collection('user')
          .where('username', isEqualTo: username)
          .where('passwrd', isEqualTo: password)
          .get();
    } catch (e) {
      throw e;
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/login_image.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C5217),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    prefixIcon: Icon(Icons.person, color: Color(0xFF0C5217)),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF0C5217)),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20),
                  ],
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    prefixIcon: Icon(Icons.lock, color: Color(0xFF0C5217)),
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
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF0C5217)),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20),
                  ],
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final querySnapshot = await getUserData(
                          _usernameController.text, _passwordController.text);
                      if (querySnapshot != null &&
                          querySnapshot.docs.isNotEmpty) {
                        print(
                            "Login successful"); // Print login success message
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AccountPage()),
                        );
                      } else {
                        print(
                            "Invalid username or password"); // Print invalid username or password
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Invalid username or password')),
                        );
                      }
                    } catch (e) {
                      print("Error: ${e.toString()}"); // Print error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0C5217),
                    padding:
                        EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'LOGIN',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(_createRouteToRegisPage());
                  },
                  child: Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(color: Color(0xFF0C5217)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Route _createRouteToRegisPage() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => RegisPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.easeInOut;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}
