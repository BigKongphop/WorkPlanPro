import 'package:flutter/material.dart';
import 'regis_page.dart'; // นำเข้าหน้าลงทะเบียน

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
                // รูปภาพด้านบน
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'assets/login_image.png'), // เปลี่ยนเป็นภาพของคุณ
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 30),
                // ข้อความต้อนรับ
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C5217), // สีหลัก
                  ),
                ),
                SizedBox(height: 20),
                // ช่องกรอก Username
                TextField(
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
                ),
                SizedBox(height: 20),
                // ช่องกรอก Password
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    prefixIcon: Icon(Icons.lock, color: Color(0xFF0C5217)),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF0C5217)),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                // ปุ่ม Login
                ElevatedButton(
                  onPressed: () {
                    // โค้ดเข้าสู่ระบบ
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0C5217), // สีหลัก
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
                // ลิงค์ไปหน้าลงทะเบียน
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(_createRouteToRegisPage());
                  },
                  child: Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(color: Color(0xFF0C5217)), // สีหลัก
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ฟังก์ชันสำหรับสร้างอนิเมชันเมื่อไปยังหน้า RegisPage
  Route _createRouteToRegisPage() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => RegisPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

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
