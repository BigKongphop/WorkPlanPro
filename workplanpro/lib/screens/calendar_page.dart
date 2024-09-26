import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';
import 'account_page.dart';
import 'group_page.dart';
import 'notification_page.dart'; // Add this import

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _currentIndex = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0C5217),
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        title: Text('CALENDAR', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCalendar(),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildDropdownButton('กิจกรรมส่วนตัว'),
                  _buildDropdownButton('กิจกรรมกลุ่ม'),
                  Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.add),
                      label: Text('New activity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0C5217),
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ],
              ),
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
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (context) => HomePage()));
              break;
            case 1:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => AccountPage()));
              break;
            case 2:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => NotificationPage()));
              break;
            case 3:
              // Already on Calendar page
              break;
            case 4:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => GroupPage()));
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

  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(now),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
          SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 7 + daysInMonth,
            itemBuilder: (context, index) {
              if (index < 7) {
                final weekday = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'][index];
                return Center(
                    child:
                        Text(weekday, style: TextStyle(color: Colors.white)));
              }
              final day = index - 6;
              final date = DateTime(now.year, now.month, day);
              final isToday = date.day == now.day;
              final isSelected = day == 15;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white
                      : (isToday ? Colors.white.withOpacity(0.3) : null),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected ? Color(0xFF0C5217) : Colors.white,
                      fontWeight: isToday || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownButton(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        width: double.infinity,
        child: DropdownButton<String>(
          value: text,
          icon: Icon(Icons.arrow_drop_down),
          iconSize: 24,
          elevation: 16,
          style: TextStyle(color: Colors.black),
          underline: Container(
            height: 2,
            color: Color(0xFF0C5217),
          ),
          onChanged: (String? newValue) {},
          items: <String>[text].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}
