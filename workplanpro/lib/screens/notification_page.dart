import 'package:flutter/material.dart';
import 'home_page.dart';
import 'account_page.dart';
import 'calendar_page.dart';
import 'group_page.dart';

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _currentIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        title: Text('NOTIFICATION', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFF0C5217),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'การแจ้งเตือน',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildNotificationItem(
                  'UKRIT PALANISONG',
                  'เชิญเข้าร่วมกลุ่ม',
                  true,
                ),
                _buildNotificationItem(
                  'UKRIT PALANISONG',
                  'หัวข้อ........................',
                  false,
                ),
                _buildNotificationItem(
                  'UKRIT PALANISONG',
                  'หัวข้อ........................',
                  false,
                ),
                _buildNotificationItem(
                  'UKRIT PALANISONG',
                  'หัวข้อ........................',
                  false,
                ),
                _buildNotificationItem(
                  'UKRIT PALANISONG',
                  'หัวข้อ........................',
                  false,
                ),
              ],
            ),
          ),
        ],
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
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AccountPage()));
              break;
            case 2:
              // Already on Notification page
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

  Widget _buildNotificationItem(String name, String content, bool hasActions) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, color: Colors.grey[600]),
            ),
            title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(content),
          ),
          if (hasActions)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('ปฏิเสธ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('ยอมรับ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0C5217),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}