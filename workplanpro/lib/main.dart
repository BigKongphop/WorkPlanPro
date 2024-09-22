import 'package:flutter/material.dart';
import 'package:workplanpro/screens/home.dart';

void main() {
  runApp(MaterialApp(
    title: "My title",
    home: Scaffold(
      appBar: AppBar(
        title: const Text("My Application"),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: const Home(),
    ),
  ));
}