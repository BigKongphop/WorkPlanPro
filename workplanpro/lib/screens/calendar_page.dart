//calendar_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:intl/intl.dart';
import 'package:workplanpro/screens/activity_service.dart';
import 'note_page.dart';
import 'account_page.dart';
import 'group_page.dart';
import 'home_page.dart';
import 'add_activity_screen.dart';
import '../models/activity.dart';
import '../services/activity_database.dart';
import 'package:table_calendar/table_calendar.dart';

class Calendar extends StatelessWidget {
  DateTime _currentMonth = DateTime.now();
  List<Activity> _activities = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'December 2024',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDayHeader('Sun'),
                _buildDayHeader('Mon'),
                _buildDayHeader('Tue'),
                _buildDayHeader('Wed'),
                _buildDayHeader('Thu'),
                _buildDayHeader('Fri'),
                _buildDayHeader('Sat'),
              ],
            ),
            SizedBox(height: 8.0),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                ),
                itemCount: 35,
                itemBuilder: (context, index) {
                  int day = index + 1;
                  bool isToday = day == 2; // Assuming today is the 2nd
                  return Container(
                    decoration: BoxDecoration(
                      color: isToday ? Colors.green : Colors.transparent,
                      border: Border.all(
                        color: isToday ? Colors.green : Colors.grey.shade400,
                        width: isToday ? 2.0 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          color: isToday ? Colors.white : Colors.grey.shade700,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(String day) {
    return Text(
      day,
      style: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
      ),
    );
  }
}

// CalendarPage
class CalendarPage extends StatefulWidget {
  final String username;
  final String userEmail; // Add this line

  const CalendarPage(
      {Key? key,
      required this.username,
      required this.userEmail // Add this parameter
      })
      : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final ActivityDatabase _activityDatabase = ActivityDatabase();
  final ActivityService _activityService = ActivityService();
  List<Activity> _activities = [];
  SortType _currentSortType = SortType.nearestDate;
  int _currentIndex = 3;
  DateTime _currentMonth = DateTime.now();
  List<Activity> _groupActivities = [];
  bool _isCalendarExpanded = true;
  bool _isPersonalActivitiesExpanded = true;
  bool _isGroupActivitiesExpanded = true;
  bool _isLoading = true;
  List<Activity> _filteredActivities = []; // เพิ่มบรรทัดนี้
  String _selectedCategory = 'All'; // เพิ่มบรรทัดนี้
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadActivities().then((_) {
      setState(() {
        _selectedCategory = 'All'; // ตั้งค่าเริ่มต้นเป็น All
        _filteredActivities = _filterActivities(); // กรองกิจกรรมทันที
      });
    }).catchError((error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดกิจกรรม: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Future<void> _loadActivities() async {
    try {
      // Fetch activities for the current user
      final activities = await _activityService.fetchActivities();

      setState(() {
        _activities = activities;
        _filteredActivities = _filterActivities();
      });
    } catch (e) {
      print('Error loading activities: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load activities'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Colors.green.shade700,
            title: Text(
              'My Calendar',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [],
          ),
          SliverToBoxAdapter(
            child: _buildActivityOverviewCards(),
          ),
          SliverToBoxAdapter(
            child: _buildEnhancedCalendarSection(),
          ),
          SliverToBoxAdapter(
            child: _buildCategoryChips(),
          ),
          _buildActivityListSliver(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  SliverList _buildActivityListSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return _buildAnimatedActivityCard(_filteredActivities[index]);
        },
        childCount: _filteredActivities.length,
      ),
    );
  }

  Widget _buildAnimatedActivityCard(Activity activity) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(activity.status).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIconForActivityType(activity.type),
            color: _getStatusColor(activity.status),
          ),
        ),
        title: Text(
          activity.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0C5217),
          ),
        ),
        subtitle: Text(
          '${DateFormat('HH:mm').format(activity.date)} - ${activity.description}',
          style: TextStyle(color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _getStatusColor(activity.status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            activity.status,
            style: TextStyle(
              color: _getStatusColor(activity.status),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () => _showActivityDetailsModal(activity, 0, _activities),
      ),
    );
  }

  Color _getActivityTypeColor(String type) {
    switch (type) {
      case 'Personal':
        return Colors.blue.shade400;
      case 'Group':
        return Colors.purple.shade400;
      default:
        return Colors.green.shade400;
    }
  }

  Widget _buildActivityCardContent(Activity activity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                activity.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getActivityTypeColor(activity.type),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                activity.type,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          activity.description,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.green.shade600,
                ),
                SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(activity.date),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(activity.status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activity.status,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarWithDraggableSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.4, // ขนาดเริ่มต้นของ Sheet
      minChildSize: 0.2, // ขนาดต่ำสุด
      maxChildSize: 0.9, // ขนาดสูงสุด
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, -4),
                )
              ]),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Handle สำหรับลาก
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    width: 50,
                    height: 6,
                    margin: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),

              // ปฏิทิน
              SliverToBoxAdapter(
                child: TableCalendar(
                  firstDay: DateTime.utc(2010, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _currentMonth,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.green.shade700,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    _showDayActivities(selectedDay);
                  },
                ),
              ),

              // กิจกรรมประจำวัน
              _buildDailyActivitiesList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyActivitiesList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // สร้าง Widget สำหรับแสดงกิจกรรมแต่ละรายการ
          return _buildActivityCard(_filteredActivities[index]);
        },
        childCount: _filteredActivities.length,
      ),
    );
  }

  Widget _buildEnhancedCalendarSection() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 20) {
          _toggleCalendarFormat();
        } else if (details.delta.dy < -20) {
          _toggleCalendarFormat();
        }
        HapticFeedback.lightImpact();
      },
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade100.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Custom Header with Month Navigation
            _buildCustomCalendarHeader(),

            // Animated Calendar
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: TableCalendar(
                key: UniqueKey(),
                firstDay: DateTime.utc(2010, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _currentMonth,

                // Calendar Format Control
                calendarFormat: _calendarFormat,
                availableCalendarFormats: {
                  CalendarFormat.month: 'Month',
                  CalendarFormat.week: 'Week',
                },

                // Styling
                headerVisible: false, // Hide default header
                daysOfWeekStyle: _buildDaysOfWeekStyle(),
                calendarStyle: _buildCalendarStyle(),

                // Custom Day Builder
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: _enhancedDayBuilder,
                  todayBuilder: _todayBuilder,
                  selectedBuilder: _selectedBuilder,
                  markerBuilder: _eventMarkerBuilder,
                ),

                // Interactions
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _currentMonth = focusedDay;
                  });
                  _showEnhancedDayActivities(selectedDay);
                },

                // Format Change
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },

                // Event Loader
                eventLoader: _getEventsForDay,
              ),
            ),

            // Activity Indicator
            _buildActivityIndicator(),
          ],
        ),
      ),
    );
  }

  void _showEnhancedDayActivities(DateTime selectedDay) {
    final dayActivities = _getEventsForDay(selectedDay);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle untuk drag
                  Container(
                    width: 50,
                    height: 6,
                    margin: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Header วันที่
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE, dd MMM yyyy').format(selectedDay),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0C5217),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline,
                              color: Color(0xFF0C5217)),
                          onPressed: _navigateToAddActivity,
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Divider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),

                  // Section Personal Activities
                  _buildActivitySection(
                      dayActivities, 'Personal Activities', 'Personal'),

                  // Section Group Activities
                  _buildActivitySection(
                      dayActivities, 'Group Activities', 'Group'),

                  // Kondisi ketika tidak ada aktivitas
                  if (dayActivities.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 100,
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No activities for this day',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Month and Year
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0C5217),
            ),
          ),

          // Navigation Buttons
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: Color(0xFF0C5217)),
                onPressed: _goToPreviousMonth,
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: Color(0xFF0C5217)),
                onPressed: _goToNextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _enhancedDayBuilder(
      BuildContext context, DateTime day, DateTime focusedDay) {
    final events = _getEventsForDay(day);
    final isToday = isSameDay(day, DateTime.now());

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isToday ? Colors.green.shade100 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: events.isNotEmpty
            ? Border.all(color: Colors.green.shade300, width: 1.5)
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isToday
                    ? Colors.green.shade900
                    : (events.isNotEmpty
                        ? Colors.green.shade700
                        : Colors.black87),
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            if (events.isNotEmpty)
              Container(
                width: 5,
                height: 5,
                margin: EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  DaysOfWeekStyle _buildDaysOfWeekStyle() {
    return DaysOfWeekStyle(
      weekdayStyle: TextStyle(
        color: Colors.green.shade700,
        fontWeight: FontWeight.w600,
      ),
      weekendStyle: TextStyle(
        color: Colors.red.shade400,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  CalendarStyle _buildCalendarStyle() {
    return CalendarStyle(
      // Today Decoration
      todayDecoration: BoxDecoration(
        color: Colors.green.shade700,
        shape: BoxShape.circle,
      ),

      // Selected Day Decoration
      selectedDecoration: BoxDecoration(
        color: Colors.green.shade800,
        shape: BoxShape.circle,
      ),

      // Styling
      defaultTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 14,
      ),
      weekendTextStyle: TextStyle(
        color: Colors.red.shade400,
        fontSize: 14,
      ),

      // Outside Days
      outsideDaysVisible: false,
    );
  }

  Widget? _eventMarkerBuilder(BuildContext context, DateTime day, List events) {
    if (events.isNotEmpty) {
      return Positioned(
        right: 5,
        bottom: 5,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildActivityIndicator() {
    // Count activities for the current month
    int monthActivities = _activities
        .where((activity) =>
            activity.date.year == _currentMonth.year &&
            activity.date.month == _currentMonth.month)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Activities this month',
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              // Added 'child' parameter here
              '$monthActivities',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCalendarFormat() {
    setState(() {
      _calendarFormat = _calendarFormat == CalendarFormat.month
          ? CalendarFormat.week
          : CalendarFormat.month;
    });
  }

  Widget _buildEventMarker(int eventCount) {
    return Positioned(
      right: 5,
      bottom: 5,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$eventCount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 6,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: ['All', 'Personal', 'Group']
              .map((category) => _buildCategoryChip(category))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          category,
          style: TextStyle(
            color: _selectedCategory.toLowerCase() == category.toLowerCase()
                ? Colors.white
                : Colors.green.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: _selectedCategory.toLowerCase() == category.toLowerCase(),
        selectedColor: Colors.green.shade700,
        backgroundColor: Colors.green.shade100,
        pressElevation: 5,
        shadowColor: Colors.green.shade200,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : 'All';
            _filteredActivities = _filterActivities();
          });
        },
      ),
    );
  }

  void _showImprovedActivityDetails(Activity activity) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(DateFormat('dd MMM yyyy').format(activity.date)),
              // เพิ่มรายละเอียดกิจกรรมเพิ่มเติมที่ต้องการแสดง
            ],
          ),
        );
      },
    );
  }

  SliverList _buildImprovedActivityList(List<Activity> activities) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildEnhancedActivityCard(activities[index]),
        childCount: activities.length,
      ),
    );
  }

  Widget _buildEnhancedActivityCard(Activity activity) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(activity.status).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIconForActivityType(activity.type),
            color: _getStatusColor(activity.status),
          ),
        ),
        title: Text(
          activity.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0C5217),
          ),
        ),
        subtitle: Text(
          DateFormat('dd MMM yyyy').format(activity.date),
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Chip(
          label: Text(
            activity.status,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: _getStatusColor(activity.status),
        ),
        onTap: () => _showImprovedActivityDetails(activity),
      ),
    );
  }

  IconData _getIconForActivityType(String type) {
    switch (type) {
      case 'Personal':
        return Icons.person;
      case 'Group':
        return Icons.group;
      default:
        return Icons.event;
    }
  }

  Widget _buildFancyFloatingActionButton() {
    return FloatingActionButton.extended(
      icon: Icon(Icons.add, color: Colors.white),
      label: Text('Add Activity'),
      backgroundColor: Color(0xFF0C5217),
      elevation: 10,
      onPressed: _navigateToAddActivity,
    );
  }

  SliverList _buildCompactActivityList(List<Activity> activities) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildCompactActivityCard(activities[index]),
        childCount: activities.length,
      ),
    );
  }

  Widget _buildDayActivities(DateTime day) {
    final activities = _getEventsForDay(day);
    return ExpansionTile(
      title: Text(DateFormat('EEEE, MMM d').format(day)),
      children: activities.map((activity) {
        return ListTile(
          title: Text(activity.title),
          subtitle: Text(DateFormat('HH:mm').format(activity.date)),
          trailing: Chip(
            label: Text(activity.status),
            backgroundColor: _getStatusColor(activity.status),
          ),
          onTap: () => _showActivityDetails(activity),
        );
      }).toList(),
    );
  }

  Widget _buildCompactActivityCard(Activity activity) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // เพิ่มความโค้งมน
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // เพิ่ม Gradient Background
            colors: [Colors.white, Colors.green.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          title: Text(
            activity.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0C5217),
              fontSize: 16, // เพิ่มขนาดฟอนต์
            ),
          ),
          subtitle: Text(
            DateFormat('dd MMM yyyy').format(activity.date),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _getStatusColor(activity.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              activity.status,
              style: TextStyle(
                color: _getStatusColor(activity.status),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          onTap: () => _showActivityDetailsModal(activity, 0, _activities),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Color(0xFF0C5217),
      floating: true,
      pinned: true,
      title: Text(
        'Calendar',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list, color: Colors.white),
          onPressed: _showFilterOptions,
        ),
        IconButton(
          icon: Icon(Icons.sort, color: Colors.white),
          onPressed: _showSortOptions,
        ),
      ],
    );
  }

  Widget _buildCalendarSection(BoxConstraints constraints) {
    return Container(
      height: 250, // กำหนดความสูงคงที่
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C5217), Color(0xFF0C5217).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Month Navigation Header
          _buildMonthNavigationHeader(),

          // Calendar with Constrained Height
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TableCalendar(
                // Basic configuration
                firstDay: DateTime.utc(2010, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: _currentMonth,

                // Remove default header
                headerVisible: false,

                // Custom builders to prevent overflow
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: _customCompactDayBuilder,
                ),

                // Compact styling
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 10, // Smaller font
                  ),
                  weekendTextStyle: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),

                  // Minimal padding
                  cellPadding: EdgeInsets.zero,
                  cellMargin: EdgeInsets.all(1),
                ),

                // Days of week styling
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: Colors.white70,
                    fontSize: 8, // Very small font
                  ),
                  weekendStyle: TextStyle(
                    color: Colors.white54,
                    fontSize: 8,
                  ),
                ),

                // Day selection handler
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _currentMonth = focusedDay;
                  });
                  _showDayActivities(selectedDay);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customCompactDayBuilder(
      BuildContext context, DateTime day, DateTime focusedDay) {
    final events = _getEventsForDay(day);
    final isToday = isSameDay(day, DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: isToday ? Colors.white.withOpacity(0.3) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isToday
                    ? Colors.white
                    : (events.isNotEmpty ? Colors.white : Colors.white70),
                fontSize: 10, // Very small font
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // Tiny event indicator
            if (events.isNotEmpty)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customDayBuilder(
      BuildContext context, DateTime day, DateTime focusedDay) {
    final events = _getEventsForDay(day);
    final isToday = isSameDay(day, DateTime.now());

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isToday ? Colors.green.shade100 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: events.isNotEmpty
            ? Border.all(color: Colors.green.shade300, width: 1)
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isToday
                    ? Colors.green.shade900
                    : (events.isNotEmpty
                        ? Colors.green.shade700
                        : Colors.black87),
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: _calendarFormat == CalendarFormat.month ? 14 : 10,
              ),
            ),
            if (events.isNotEmpty && _calendarFormat == CalendarFormat.month)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _preventOverflow(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _todayBuilder(
      BuildContext context, DateTime day, DateTime focusedDay) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _selectedBuilder(
      BuildContext context, DateTime day, DateTime focusedDay) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: Color(0xFF0C5217),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _markerBuilder(BuildContext context, DateTime day, List events) {
    return events.isNotEmpty
        ? Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.amber.shade200,
                shape: BoxShape.circle,
              ),
            ),
          )
        : Container();
  }

  Widget _buildMonthNavigationHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _goToPreviousMonth,
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _goToNextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  } // Month Navigation Methods

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddActivity,
      backgroundColor: Color(0xFF0C5217),
      icon: Icon(
        Icons.add,
        color: Colors.white,
      ),
      label: Text(
        'New Activity',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // ทำมุมมนมากขึ้น
      ),
    );
  }

  Widget _buildActivitiesSection(String title, List<Activity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        _buildActivityList(activities),
      ],
    );
  }

  void _handleActivityUpdate(Map<String, dynamic> result) {
    if (result == null) return;

    switch (result['action']) {
      case 'create':
        _addNewActivity(result['activity']);
        break;
      case 'update':
        _updateExistingActivity(result['activity']);
        break;
      case 'delete':
        _removeActivity(result['activityId']);
        break;
    }
  }

  void _addNewActivity(Activity newActivity) {
    setState(() {
      _activities.add(newActivity);
      _filteredActivities = _filterActivities();
    });
  }

  void _updateExistingActivity(Activity updatedActivity) {
    setState(() {
      final index = _activities.indexWhere((a) => a.id == updatedActivity.id);
      if (index != -1) {
        _activities[index] = updatedActivity;
        _filteredActivities = _filterActivities();
      }
    });
  }

  void _removeActivity(String activityId) {
    setState(() {
      _activities.removeWhere((a) => a.id == activityId);
      _filteredActivities = _filterActivities();
    });
  }

  List<Activity> _getEventsForDay(DateTime day) {
    return _activities.where((activity) {
      return activity.date.year == day.year &&
          activity.date.month == day.month &&
          activity.date.day == day.day;
    }).toList();
  }

  void _showDayActivities(DateTime selectedDay) {
    final dayActivities = _getEventsForDay(selectedDay);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle untuk drag
                  Container(
                    width: 50,
                    height: 6,
                    margin: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Header วันที่
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE, dd MMM yyyy').format(selectedDay),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0C5217),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline,
                              color: Color(0xFF0C5217)),
                          onPressed: _navigateToAddActivity,
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Divider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),

                  // Section Personal Activities
                  _buildActivitySection(
                      dayActivities, 'Personal Activities', 'Personal'),

                  // Section Group Activities
                  _buildActivitySection(
                      dayActivities, 'Group Activities', 'Group'),

                  // Kondisi ketika tidak ada aktivitas
                  if (dayActivities.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 100,
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No activities for this day',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivityCard(Activity activity) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text(
                activity.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF0C5217),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: TextStyle(color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${activity.startTime.format(context)} - ${activity.endTime.format(context)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(activity.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activity.status,
                  style: TextStyle(
                    color: _getStatusColor(activity.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              onTap: () => _showActivityDetails(activity),
            ),
            if (activity.groupName != null && activity.groupName!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 8, left: 16),
                child: Row(
                  children: [
                    Icon(Icons.group, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'From: ${activity.groupName}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(List<Activity> activities) {
    if (activities.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No activities found',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200, // จำกัดความสูงสูงสุด
              ),
              child: _buildActivityCard(activities[index]),
            );
          },
          childCount: activities.length,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0C5217),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                'See All',
                style: TextStyle(color: Color(0xFF0C5217)),
              ),
            ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Add filter options here
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Add sort options here
          ],
        ),
      ),
    );
  }

  void _showActivityOptions(Activity activity) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Options for ${activity.title}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              title: Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editActivity(activity);
              },
            ),
            ListTile(
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteActivity(activity);
              },
            ),
          ],
        ),
      ),
    );
  }

// เพิ่มฟังก์ชันในการแสดงกิจกรรม
  Widget _buildActivitiesList(List<Activity> activities) {
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            title: Text(activity.title),
            subtitle: Text(DateFormat('dd MMM yyyy').format(activity.date)),
            trailing: Text(activity.status),
            onTap: () => _showActivityDetailsModal(activity, index,
                activities), // เปลี่ยนเป็นเรียกใช้ _showActivityDetailsModal
          ),
        );
      },
    );
  }

  Widget _buildCalendarActivitiesList(List<Activity> activities) {
    return Container(
      color: Colors.white,
      child: activities.isEmpty
          ? Center(
              child: Text(
                'No activities found',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    title: Text(
                      activity.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0C5217),
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy').format(activity.date),
                      style: TextStyle(color: Colors.grey),
                    ),
                    trailing: Text(
                      activity.status,
                      style: TextStyle(
                        color: _getStatusColor(activity.status),
                      ),
                    ),
                    onTap: () =>
                        _showActivityDetailsModal(activity, index, activities),
                  ),
                );
              },
            ),
    );
  } // แก้ไขฟังก์ชันแสดงรายละเอียดกิจกรรมให้รับ 3 argument

  void _showActivityDetailsModal(
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
                    SizedBox(height: 10),
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
                    Text(
                      activity.description,
                      style: TextStyle(fontSize: 16.0),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _editActivity(activity);
                      },
                      child: Text('Edit Activity'),
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

// เพิ่มฟังก์ชันสำหรับแสดงสถานะกิจกรรม
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green.shade700;
      case 'In Progress':
        return Colors.blue.shade700;
      case 'Pending':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Future<void> _fetchActivities() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final activities =
            await _activityService.fetchActivities(userId: user.uid);

        setState(() {
          _activities = activities;
          _filteredActivities = _filterActivities();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดกิจกรรม: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Activity> _filterActivities() {
    return _activities.where((activity) {
      return _selectedCategory == 'All' || activity.type == _selectedCategory;
    }).toList();
  }

  void _navigateToAddActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddActivityScreen()),
    );

    if (result is Activity) {
      try {
        // สร้าง Activity ใหม่
        await _activityService.createActivity(result);
        // รีโหลดรายการกิจกรรม
        await _loadActivities(); // เพิ่ม () เพื่อเรียกใช้ฟังก์ชัน
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สร้างกิจกรรมสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCalendar() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2010, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _currentMonth,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _currentMonth = focusedDay;
          });
          _showDayActivities(selectedDay);
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.green.shade700,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.green.shade800,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityOverviewCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: Container(
              width: 160,
              margin: EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  )
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                  SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwipeableActivityCard(Activity activity) {
    return Dismissible(
      key: Key(activity.id ?? UniqueKey().toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteActivity(activity);
      },
      child: _buildAnimatedActivityCard(activity),
    );
  }

  Widget _buildActivitySection(
      List<Activity> activities, String title, String type) {
    final filteredActivities =
        activities.where((activity) => activity.type == type).toList();

    if (filteredActivities.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          'No $title found',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C5217),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredActivities.length,
              itemBuilder: (context, index) {
                final activity = filteredActivities[index];
                return _buildAnimatedActivityCard(activity);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showActivityDetails(Activity activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Date: ${DateFormat('EEEE, MMM d, y').format(activity.date)}',
                style: TextStyle(fontSize: 16.0),
              ),
              Text(
                'Time: ${activity.startTime.format(context)} - ${activity.endTime.format(context)}',
                style: TextStyle(fontSize: 16.0),
              ),
              SizedBox(height: 16.0),
              Text(
                'Description:',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              Text(
                activity.description,
                style: TextStyle(fontSize: 16.0),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _editActivity(activity);
                },
                child: Text('Edit Activity'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _customCalendarDayBuilder(
      BuildContext context, DateTime day, DateTime focusedDay) {
    final events = _getEventsForDay(day);
    final isToday = isSameDay(day, DateTime.now());

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
          color: isToday ? Colors.green.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: events.isNotEmpty
              ? Border.all(color: Colors.green.shade300, width: 2)
              : null),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: isToday ? Colors.green.shade900 : Colors.black87,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (events.isNotEmpty)
            Positioned(
              bottom: 3,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityDetailsSheet(Activity activity) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMMM yyyy').format(activity.date),
                style: TextStyle(color: Colors.grey.shade600),
              ),
              Chip(
                label: Text(
                  activity.status,
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: _getStatusColor(activity.status),
              ),
            ],
          ),
          // ... (เพิ่มรายละเอียดอื่นๆ)
        ],
      ),
    );
  }

  void _editActivity(Activity activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(activityToEdit: activity),
      ),
    );

    if (result is Map) {
      try {
        if (result['action'] == 'update') {
          Activity updatedActivity = result['activity'];

          // Validate ID
          if (updatedActivity.id == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Activity ID is required for update'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Update activity
          await _activityService.updateActivity(updatedActivity);

          // Reload activities
          await _loadActivities();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activity updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (result['action'] == 'create') {
          Activity newActivity = result['activity'];

          // Add new activity to the list
          setState(() {
            _activities.add(newActivity);
            _filteredActivities = _filterActivities();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New activity created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (result['action'] == 'delete') {
          // จัดการการลบกิจกรรม
          String? deletedActivityId = result['activityId'];

          if (deletedActivityId != null) {
            // ลบกิจกรรมออกจากรายการ
            setState(() {
              _activities
                  .removeWhere((activity) => activity.id == deletedActivityId);
              _filteredActivities = _filterActivities();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('กิจกรรมถูกลบเรียบร้อย'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteActivity(Activity activity) async {
    try {
      if (activity.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่พบ ID กิจกรรม'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _activityService.deleteActivity(activity.id!);
      setState(() {
        _activities.removeWhere((a) => a.id == activity.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบกิจกรรมสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบกิจกรรม: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEnhancedBottomNavBar() {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_circle),
          label: 'Account',
        ),
      ],
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index; // ตรวจสอบว่า index อยู่ในช่วงที่ถูกต้อง
        });
      },
    );
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
    return MotionTabBar(
      labels: const ["Home", "Account", "Notes", "Calendar", "Groups"],
      icons: const [
        Icons.home,
        Icons.person,
        Icons.book,
        Icons.calendar_today,
        Icons.group
      ],
      initialSelectedTab: "Calendar",
      tabIconColor: const Color(0xFF0C5217),
      tabSelectedColor: Colors.green,
      onTabItemSelected: (int index) {
        switch (index) {
          case 0: // Home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  username: widget.username,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;

          case 1: // Account
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AccountPage(
                  initialUsername: widget.username,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;

          case 2: // Notes
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => NotePage(
                  username: widget.username,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;

          case 3: // Calendar (ปัจจุบัน)
            // ไม่ต้องทำอะไรเพราะอยู่ใน Calendar แล้ว
            break;

          case 4: // Groups
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GroupPage(
                  username: widget.username,
                  userEmail: widget.userEmail,
                ),
              ),
            );
            break;
        }
      },
    );
  }
}
