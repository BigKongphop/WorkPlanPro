import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workplanpro/screens/login_page.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    Logger().e("Failed to initialize Firebase: $e");
    // You can exit the app or handle the failure as needed
    return; // or use exit(1) if you want to terminate the app
  }

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
