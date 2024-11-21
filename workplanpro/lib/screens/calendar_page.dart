import 'package:flutter/material.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:intl/intl.dart';
import 'note_page.dart';
import 'account_page.dart';
import 'group_page.dart';
import 'home_page.dart';
import 'add_activity_screen.dart';
import '../models/activity.dart';
import '../services/activity_database.dart';

class CalendarPage extends StatefulWidget {
  final String username;

  const CalendarPage({Key? key, required this.username}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final ActivityDatabase _activityDatabase = ActivityDatabase();
  int _currentIndex = 3;
  DateTime _currentMonth = DateTime.now();
  List<Activity> _activities = [];
  List<Activity> _groupActivities = [];
  bool _isCalendarExpanded = true;
  bool _isPersonalActivitiesExpanded = true;
  bool _isGroupActivitiesExpanded = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      setState(() => _isLoading = true);
      final activities =
          await _activityDatabase.loadActivities(widget.username);
      setState(() {
        _activities = activities;
        _sortActivities();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading activities: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activities: $e')),
        );
      }
    }
  }

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
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              colorScheme: ColorScheme.dark(
                primary: Colors.white,
              ),
            ),
            child: ExpansionTile(
              initiallyExpanded: _isCalendarExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _isCalendarExpanded = expanded;
                });
              },
              title: Text(
                'Mouth Calendar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              trailing: Icon(
                _isCalendarExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white,
              ),
              children: [
                _buildCalendar(),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: _isPersonalActivitiesExpanded,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _isPersonalActivitiesExpanded = expanded;
                          });
                        },
                        title: Text(
                          'Personal Activities',
                          style: TextStyle(
                            color: Color(0xFF0C5217),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        trailing: Icon(
                          _isPersonalActivitiesExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Color(0xFF0C5217),
                        ),
                        children: [
                          _buildActivitiesList(_activities),
                        ],
                      ),
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: _isGroupActivitiesExpanded,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _isGroupActivitiesExpanded = expanded;
                          });
                        },
                        title: Text(
                          'Group Activities',
                          style: TextStyle(
                            color: Color(0xFF0C5217),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        trailing: Icon(
                          _isGroupActivitiesExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Color(0xFF0C5217),
                        ),
                        children: [
                          _buildActivitiesList(_groupActivities),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddActivityScreen()),
          );
          if (result != null && result is Activity) {
            try {
              final savedActivity =
                  await _activityDatabase.saveActivity(widget.username, result);
              setState(() {
                _activities.add(savedActivity);
                _sortActivities();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Activity saved successfully')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error saving activity: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
        backgroundColor: const Color(0xFF0C5217),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        icon: const Icon(
          Icons.add,
          color: Colors.white,
          size: 20,
        ),
        label: const Text(
          "New Activity",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 2,
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 12.0,
        ),
      ),
      bottomNavigationBar: MotionTabBar(
        labels: const ["Home", "Account", "Notes", "Calendar", "Groups"],
        icons: const [
          Icons.home,
          Icons.person,
          Icons.book,
          Icons.calendar_today,
          Icons.group,
        ],
        initialSelectedTab: "Calendar",
        tabIconColor: const Color(0xFF0C5217),
        tabSelectedColor:
            Colors.green, // เปลี่ยนสีพื้นหลังของไอเทมที่เลือกเป็นสีเขียว
        onTabItemSelected: (int index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          HomePage(username: widget.username)));
              break;
            case 1:
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          AccountPage(initialUsername: widget.username)));
              break;
            case 2:
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          NotePage(username: widget.username)));
              break;
            case 3:
              // อยู่ที่หน้า Calendar อยู่แล้ว
              break;
            case 4:
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          GroupPage(username: widget.username)));
              break;
          }
        },
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
              final hasActivity = _activities.any((activity) =>
                      activity.date.year == date.year &&
                      activity.date.month == date.month &&
                      activity.date.day == date.day) ||
                  _groupActivities.any((activity) =>
                      activity.date.year == date.year &&
                      activity.date.month == date.month &&
                      activity.date.day == date.day);

              return Center(
                child: Container(
                  width: 32, // ลดขนาดความกว้าง
                  height: 32, // ลดขนาดความสูง
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
                        fontSize: 14, // ลดขนาดตัวอักษร
                      ),
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

  Widget _buildActivitiesList(List<Activity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        activities.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No activities found',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16.0,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return Card(
                    margin:
                        EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: InkWell(
                      onTap: () =>
                          _showActivityDetails(activity, index, activities),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd MMM. yyyy').format(activity.date),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0C5217),
                              ),
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              activity.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              '${activity.startTime.format(context)} - ${activity.endTime.format(context)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (activity.description.isNotEmpty) ...[
                              SizedBox(height: 8.0),
                              Text(
                                activity.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  void _showActivityDetails(
      Activity activity, int index, List<Activity> activities) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Activity Detail',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20.0,
                            color: Color(0xFF0C5217),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      'Date: ${DateFormat('EEEE, MMM d, y').format(activity.date)}',
                      style: TextStyle(fontSize: 16.0),
                    ),
                    SizedBox(height: 4.0),
                    Text(
                      'Time: ${activity.startTime.format(context)} - ${activity.endTime.format(context)}',
                      style: TextStyle(fontSize: 16.0),
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      'Description:',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.0),
                    Text(
                      activity.description,
                      style: TextStyle(fontSize: 16.0),
                    ),
                    SizedBox(height: 24.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _editActivity(activity, index, activities);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0C5217),
                          ),
                          child: Text('Edit',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editActivity(
      Activity activity, int index, List<Activity> activities) async {
    if (activity.id == null || activity.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot edit this activity: Missing ID')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(activityToEdit: activity),
      ),
    );

    if (result != null) {
      try {
        if (result == 'delete') {
          await _activityDatabase.deleteActivity(activity.id!);
          setState(() {
            activities.removeAt(index);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Activity deleted successfully')),
            );
          }
        } else if (result is Activity) {
          // สร้าง Activity ใหม่ที่มี id เดิม
          Activity updatedActivity = Activity(
            id: activity.id,
            title: result.title,
            description: result.description,
            date: result.date,
            startTime: result.startTime,
            endTime: result.endTime,
          );

          await _activityDatabase.updateActivity(activity.id!, updatedActivity);
          setState(() {
            activities[index] = updatedActivity;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Activity updated successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating activity: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _sortActivities() {
    _activities.sort((a, b) {
      int dateComparison = b.date.compareTo(a.date);
      if (dateComparison != 0) return dateComparison;
      return b.startTime.hour * 60 +
          b.startTime.minute -
          (a.startTime.hour * 60 + a.startTime.minute);
    });
    _groupActivities.sort((a, b) {
      int dateComparison = b.date.compareTo(a.date);
      if (dateComparison != 0) return dateComparison;
      return b.startTime.hour * 60 +
          b.startTime.minute -
          (a.startTime.hour * 60 + a.startTime.minute);
    });
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        switch (index) {
          case 0:
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => HomePage(username: widget.username)));
            break;
          case 1:
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        AccountPage(initialUsername: widget.username)));
            break;
          case 2:
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => NotePage(username: widget.username)));
            break;
          case 3:
            break; // อยู่ที่หน้า Calendar อยู่แล้ว
          case 4:
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        GroupPage(username: widget.username)));
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
          icon: _buildNavBarItem(Icons.book, 'Notes', 2),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: _buildNavBarItem(Icons.calendar_today, 'Calendar', 3),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: _buildNavBarItem(Icons.group, 'Groups', 4),
          label: '',
        ),
      ],
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
