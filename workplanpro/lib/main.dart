import 'package:flutter/material.dart';
import 'package:workplanpro/screens/home_page.dart';
import 'package:workplanpro/screens/group_page.dart';
import 'package:workplanpro/screens/calendar_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}