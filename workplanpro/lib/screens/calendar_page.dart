import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';
import 'account_page.dart';
import 'group_page.dart';
import 'notification_page.dart';
import 'add_activity_screen.dart';
import '../models/activity.dart';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _currentIndex = 3;
  DateTime _currentMonth = DateTime.now();
  List<Activity> _personalActivities = [];
  List<Activity> _groupActivities = [];

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
              child: ListView(
                children: [
                  _buildActivitiesList(
                      'Personal Activities', _personalActivities),
                  _buildActivitiesList('Group Activities', _groupActivities),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddActivityScreen()),
            );
            if (result != null && result is Activity) {
              setState(() {
                _personalActivities.add(result);
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0C5217),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          icon: Icon(Icons.add, color: Colors.white),
          label: Text(
            "New Activity",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
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
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final now = DateTime.now();

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                        _currentMonth.year, _currentMonth.month - 1, 1);
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                        _currentMonth.year, _currentMonth.month + 1, 1);
                  });
                },
              ),
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
                final weekday =
                    ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'][index];
                return Center(
                    child:
                        Text(weekday, style: TextStyle(color: Colors.white)));
              }
              final day = index - 6;
              final date =
                  DateTime(_currentMonth.year, _currentMonth.month, day);
              final isToday = date.day == now.day &&
                  date.month == now.month &&
                  date.year == now.year;
              final hasActivity = _personalActivities.any((activity) =>
                      activity.date.year == date.year &&
                      activity.date.month == date.month &&
                      activity.date.day == date.day) ||
                  _groupActivities.any((activity) =>
                      activity.date.year == date.year &&
                      activity.date.month == date.month &&
                      activity.date.day == date.day);
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasActivity
                      ? Colors.white
                      : (isToday ? Colors.white.withOpacity(0.3) : null),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: hasActivity ? Color(0xFF0C5217) : Colors.white,
                      fontWeight: isToday || hasActivity
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

  Widget _buildActivitiesList(String title, List<Activity> activities) {
    return ExpansionTile(
      title: Text(title),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 150,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ListTile(
                title: Text(activity.title),
                subtitle: Text(
                    '${DateFormat('MMM d, y').format(activity.date)} ${activity.startTime.format(context)} - ${activity.endTime.format(context)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  AddActivityScreen(activityToEdit: activity)),
                        );
                        if (result != null && result is Activity) {
                          setState(() {
                            activities[activities.indexOf(activity)] = result;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          activities.remove(activity);
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
