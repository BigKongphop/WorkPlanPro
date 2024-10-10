import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For LengthLimitingTextInputFormatter
import 'package:workplanpro/screens/login_page.dart';
import 'account_page.dart';
import '../models/user_database.dart'; // Import UserDatabase
import '../models/personal.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final UserDatabase _userDatabase =
      UserDatabase(); // Create UserDatabase instance

  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  void _validateUsername(String value) {
    setState(() {
      if (value.isEmpty) {
        _usernameError = 'Username is required';
      } else if (!RegExp(r'^[a-z0-9]{10,20}$').hasMatch(value)) {
        _usernameError = 'Use 10-20 characters (a-z, 0-9)';
      } else {
        _usernameError = null;
      }
    });
  }

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = 'Email is required';
      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
        _emailError = 'Enter a valid email';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Password is required';
      } else if (!RegExp(r'^(?=.*[!@#\$&*~]).{10,20}$').hasMatch(value)) {
        _passwordError = 'Use 10-20 characters with 1 special character';
      } else {
        _passwordError = null;
      }
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      if (value != _passwordController.text) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });
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
                  // Image
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/register_image.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  // "Create Account" Text
                  Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0C5217),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Username Input
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      prefixIcon: Icon(Icons.person, color: Color(0xFF0C5217)),
                      errorText: _usernameError,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0C5217)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                    ],
                    onChanged: _validateUsername,
                  ),
                  SizedBox(height: 20),
                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      prefixIcon: Icon(Icons.email, color: Color(0xFF0C5217)),
                      errorText: _emailError,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0C5217)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(50),
                    ],
                    onChanged: _validateEmail,
                  ),
                  SizedBox(height: 20),
                  // Password Input
                  TextFormField(
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
                      errorText: _passwordError,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0C5217)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                    ],
                    onChanged: _validatePassword,
                  ),
                  SizedBox(height: 20),
                  // Confirm Password Input
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      prefixIcon: Icon(Icons.lock, color: Color(0xFF0C5217)),
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
                      errorText: _confirmPasswordError,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF0C5217)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                    ],
                    onChanged: _validateConfirmPassword,
                  ),
                  SizedBox(height: 30),
                  // Sign Up Button
                  ElevatedButton(
                    onPressed: () async {
                      // Validate all fields again when pressing SIGN UP
                      _validateUsername(_usernameController.text);
                      _validateEmail(_emailController.text);
                      _validatePassword(_passwordController.text);
                      _validateConfirmPassword(_confirmPasswordController.text);

                      // Check if all inputs are valid
                      if (_usernameError == null &&
                          _emailError == null &&
                          _passwordError == null &&
                          _confirmPasswordError == null &&
                          _formKey.currentState!.validate()) {
                        // Check if Username and Email already exist
                        final usernameExists = await _userDatabase
                            .isUsernameExists(_usernameController.text);
                        final emailExists = await _userDatabase
                            .isEmailExists(_emailController.text);

                        if (usernameExists) {
                          // Show a message that the Username already exists
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Username already exists')),
                          );
                        } else if (emailExists) {
                          // Show a message that the Email already exists
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Email already exists')),
                          );
                        } else {
                          // Register the new user
                          User newUser = User(
                            username: _usernameController.text,
                            email: _emailController.text,
                            password: _passwordController.text,
                          );
                          await _userDatabase.registerUser(newUser);
                          // Navigate to LoginPage after successful registration
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginPage()),
                          );
                        }
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
                      "SIGN UP",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Already have an account? Login now
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginPage()),
                          );
                        },
                        child: Text(
                          "Login now",
                          style: TextStyle(
                            color: Color(0xFF0C5217),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
