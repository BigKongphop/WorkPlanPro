import 'package:flutter/material.dart';

class AccountScreen extends StatefulWidget {
  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int _currentIndex =
      1; // Set this to 1 to highlight the Account tab by default

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217), // Dark Green
        foregroundColor: Colors.white, // White icons and text
        title: Text('ACCOUNT'),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Handle back button press
          },
        ),
      ),
      body: Container(
        color: Color(0xFFEFEFEF), // Light gray background
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF0C5217), // Dark green outer circle
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white, // White inner circle
                    child: CircleAvatar(
                      radius: 45,
                      backgroundImage:
                          AssetImage('assets/profile_placeholder.png'),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 10,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor:
                        Colors.greenAccent, // Green online indicator
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'UKRIT PALANISONG',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            AccountDetailRow(title: 'ชื่อผู้ใช้', detail: 'UKRIT PALANISONG'),
            AccountDetailRow(title: 'อีเมล', detail: 'Ukrit.Pala@gmail.net'),
            AccountDetailRow(title: 'เบอร์โทรศัพท์', detail: '06-2589-6377'),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Handle logout
              },
              child: Text('ออกจากระบบ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5A5A5A), // Dark gray button
                padding: EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                textStyle: TextStyle(fontSize: 18), // Font size set here
                foregroundColor: Colors.white, // Set the text color to white
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.white, // สีของไอคอนและตัวอักษรเมื่อเลือก
        unselectedItemColor:
            Color(0xFF0C5217), // สีของไอคอนและตัวอักษรเมื่อไม่ได้เลือก
        backgroundColor: Colors.white, // สีพื้นหลังของแถบ navigation
        type: BottomNavigationBarType.fixed, // ให้มั่นใจว่าจะแสดงไอคอนทั้งหมด
        items: [
          BottomNavigationBarItem(
            icon: _currentIndex == 0
                ? Container(
                    width: double.infinity, // ใช้ให้เต็มความกว้างของ navBar
                    padding: EdgeInsets.symmetric(
                        vertical: 5), // ลด padding ด้านบนและล่าง
                    decoration: BoxDecoration(
                      color: Color(0xFF0C5217), // สีพื้นหลังเขียว
                      borderRadius:
                          BorderRadius.circular(0), // ลบความโค้งมนของมุม
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // จัดกึ่งกลาง
                      children: [
                        Icon(Icons.home, color: Colors.white), // ไอคอนสีขาว
                        Text(
                          'Home',
                          style: TextStyle(color: Colors.white), // ข้อความสีขาว
                        )
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center, // จัดกึ่งกลาง
                    children: [
                      Icon(Icons.home),
                      Text('Home'),
                    ],
                  ),
            label: '', // ทำให้ label ว่างเพราะเราจัดการเองใน icon
          ),
          BottomNavigationBarItem(
            icon: _currentIndex == 1
                ? Container(
                    width: double.infinity, // ใช้ให้เต็มความกว้างของ navBar
                    padding: EdgeInsets.symmetric(
                        vertical: 5), // ลด padding ด้านบนและล่าง
                    decoration: BoxDecoration(
                      color: Color(0xFF0C5217), // สีพื้นหลังเขียว
                      borderRadius:
                          BorderRadius.circular(0), // ลบความโค้งมนของมุม
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // จัดกึ่งกลาง
                      children: [
                        Icon(Icons.person, color: Colors.white), // ไอคอนสีขาว
                        Text(
                          'Account',
                          style: TextStyle(color: Colors.white), // ข้อความสีขาว
                        )
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center, // จัดกึ่งกลาง
                    children: [
                      Icon(Icons.person),
                      Text('Account'),
                    ],
                  ),
            label: '', // ทำให้ label ว่างเพราะเราจัดการเองใน icon
          ),
          BottomNavigationBarItem(
            icon: _currentIndex == 2
                ? Container(
                    width: double.infinity, // ใช้ให้เต็มความกว้างของ navBar
                    padding: EdgeInsets.symmetric(
                        vertical: 5), // ลด padding ด้านบนและล่าง
                    decoration: BoxDecoration(
                      color: Color(0xFF0C5217), // สีพื้นหลังเขียว
                      borderRadius:
                          BorderRadius.circular(0), // ลบความโค้งมนของมุม
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // จัดกึ่งกลาง
                      children: [
                        Icon(Icons.notifications,
                            color: Colors.white), // ไอคอนสีขาว
                        Text(
                          'Notification',
                          style: TextStyle(color: Colors.white), // ข้อความสีขาว
                        )
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center, // จัดกึ่งกลาง
                    children: [
                      Icon(Icons.notifications),
                      Text('Notification'),
                    ],
                  ),
            label: '', // ทำให้ label ว่างเพราะเราจัดการเองใน icon
          ),
          BottomNavigationBarItem(
            icon: _currentIndex == 3
                ? Container(
                    width: double.infinity, // ใช้ให้เต็มความกว้างของ navBar
                    padding: EdgeInsets.symmetric(
                        vertical: 5), // ลด padding ด้านบนและล่าง
                    decoration: BoxDecoration(
                      color: Color(0xFF0C5217), // สีพื้นหลังเขียว
                      borderRadius:
                          BorderRadius.circular(0), // ลบความโค้งมนของมุม
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // จัดกึ่งกลาง
                      children: [
                        Icon(Icons.calendar_today,
                            color: Colors.white), // ไอคอนสีขาว
                        Text(
                          'Calendar',
                          style: TextStyle(color: Colors.white), // ข้อความสีขาว
                        )
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center, // จัดกึ่งกลาง
                    children: [
                      Icon(Icons.calendar_today),
                      Text('Calendar'),
                    ],
                  ),
            label: '', // ทำให้ label ว่างเพราะเราจัดการเองใน icon
          ),
          BottomNavigationBarItem(
            icon: _currentIndex == 4
                ? Container(
                    width: double.infinity, // ใช้ให้เต็มความกว้างของ navBar
                    padding: EdgeInsets.symmetric(
                        vertical: 5), // ลด padding ด้านบนและล่าง
                    decoration: BoxDecoration(
                      color: Color(0xFF0C5217), // สีพื้นหลังเขียว
                      borderRadius:
                          BorderRadius.circular(0), // ลบความโค้งมนของมุม
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // จัดกึ่งกลาง
                      children: [
                        Icon(Icons.group, color: Colors.white), // ไอคอนสีขาว
                        Text(
                          'Group',
                          style: TextStyle(color: Colors.white), // ข้อความสีขาว
                        )
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center, // จัดกึ่งกลาง
                    children: [
                      Icon(Icons.group),
                      Text('Group'),
                    ],
                  ),
            label: '', // ทำให้ label ว่างเพราะเราจัดการเองใน icon
          ),
        ],
      ),
    );
  }
}

class AccountDetailRow extends StatelessWidget {
  final String title;
  final String detail;

  AccountDetailRow({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              detail,
              style: TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle edit action
            },
            child: Text('แก้ไข'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5A5A5A), // Dark gray edit button
              foregroundColor: Colors.white, // Set the text color to white
            ),
          ),
        ],
      ),
    );
  }
}
