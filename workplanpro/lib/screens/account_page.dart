import 'package:flutter/material.dart';
import 'home_page.dart';
import 'notification_page.dart';
import 'calendar_page.dart';
import 'group_page.dart';

class AccountPage extends StatefulWidget {
  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        foregroundColor: Colors.white,
        title: Text('ACCOUNT'),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {},
        ),
      ),
      body: Container(
        color: Color(0xFFEFEFEF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF0C5217),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white,
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
                    backgroundColor: Colors.greenAccent,
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
              onPressed: () {},
              child: Text('ออกจากระบบ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5A5A5A),
                padding: EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                foregroundColor: Colors.white,
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
          switch (index) {
            case 0:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()));
              break;
            case 1:
              // Already on Account page
              break;
            case 2:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NotificationPage()));
              break;
            case 3:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CalendarPage()));
              break;
            case 4:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GroupPage()));
              break;
          }
        },
        selectedItemColor: Colors.white,
        unselectedItemColor: Color(0xFF0C5217),
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.home, 'Home', 0),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.person, 'Account', 1),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.notifications, 'Notification', 2),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.calendar_today, 'Calendar', 3),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavBarItem(Icons.group, 'Group', 4),
            label: '',
          ),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(IconData icon, String label, int index) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: _currentIndex == index ? Color(0xFF0C5217) : Colors.transparent,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: _currentIndex == index ? Colors.white : Color(0xFF0C5217)),
          Text(
            label,
            style: TextStyle(
                color:
                    _currentIndex == index ? Colors.white : Color(0xFF0C5217)),
          )
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
            onPressed: () {},
            child: Text('แก้ไข'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5A5A5A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}