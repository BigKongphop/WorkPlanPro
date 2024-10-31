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
    return;
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
