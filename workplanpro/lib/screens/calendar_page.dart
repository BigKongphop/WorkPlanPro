//calendar

import 'dart:async';
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
import 'package:cloud_firestore/cloud_firestore.dart';

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
                  bool isToday = day == DateTime.now().day &&
                      _currentMonth.month == DateTime.now().month &&
                      _currentMonth.year ==
                          DateTime.now().year; // ตรวจสอบวันปัจจุบัน
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

  StreamSubscription? _activitiesSubscription;

  // รับ User ID ปัจจุบัน
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late Stream<List<Activity>> _activitiesStream;

  final _dayActivitiesController = StreamController<List<Activity>>.broadcast();
  @override
  void initState() {
    super.initState();
    _listenToActivities();
    _loadActivities().then((_) {
      setState(() {
        _selectedCategory = 'All';
        _filteredActivities = _filterActivities();

        // เพิ่มการเรียงลำดับกิจกรรม
        _sortActivitiesByDate();
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
    _initializeActivitiesStream();
  } // เพิ่มเมธอดการเรียงลำดับกิจกรรม

  Stream<List<Activity>> _getDayActivitiesStream(DateTime selectedDay) {
    return FirebaseFirestore.instance
        .collection('activities')
        .where('userId', isEqualTo: currentUserId)
        .where('date',
            isGreaterThanOrEqualTo:
                DateTime(selectedDay.year, selectedDay.month, selectedDay.day),
            isLessThan: DateTime(
                selectedDay.year, selectedDay.month, selectedDay.day + 1))
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList()
              ..sort((a, b) =>
                  a.startTime.hour * 60 +
                  a.startTime.minute -
                  (b.startTime.hour * 60 + b.startTime.minute)));
  }

  void _sortActivitiesByDate() {
    _activities.sort((a, b) {
      // เรียงตามวันที่ก่อน
      int dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) return dateComparison;

      // ถ้าวันเดียวกัน ให้เรียงตามเวลาเริ่มต้น
      return a.startTime.hour * 60 +
          a.startTime.minute -
          (b.startTime.hour * 60 + b.startTime.minute);
    });

    // อัปเดต filtered activities หลังจากเรียงลำดับ
    _filteredActivities = _filterActivities();
  }

  void _initializeActivitiesStream() {
    try {
      _activitiesStream = ActivityService().getActivitiesStream(
        startDate: DateTime.now().subtract(Duration(days: 30)),
        endDate: DateTime.now().add(Duration(days: 365)),
      );
    } catch (e) {
      print('Error initializing activities stream: $e');
      // จัดการข้อผิดพลาดที่นี่
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load activities')));
    }
  }

  void _listenToActivities() {
    _activitiesSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _activities = [];
    });

    _activitiesSubscription = FirebaseFirestore.instance
        .collection('activities')
        .where('userId',
            isEqualTo: currentUserId) // กรองเฉพาะกิจกรรมของผู้ใช้ปัจจุบัน
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _activities = snapshot.docs.map((doc) {
          final data = doc.data();
          return Activity.fromFirestore(doc);
        }).toList();

        _filteredActivities = _filterActivities(); // กรองกิจกรรมใหม่
        _isLoading = false; // ตั้งค่าเป็น false เมื่อโหลดเสร็จ
      });
    }, onError: (error) {
      print('Error listening to activities: $error');
      if (mounted) {
        setState(() {
          _isLoading = false; // ตั้งค่าเป็น false เมื่อเกิดข้อผิดพลาด
        });
      }
    });
  }

  @override
  void dispose() {
    // ยกเลิก Listener เมื่อปิดหน้า เพื่อประหยัดทรัพยากร
    _activitiesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    try {
      setState(() => _isLoading = true);
      final activities = await _activityService.fetchActivities();
      setState(() {
        _activities = activities;
        _filteredActivities = _filterActivities(); // กรองกิจกรรมใหม่
        _isLoading = false; // ตั้งค่าเป็น false เมื่อโหลดเสร็จ
      });
    } catch (e) {
      print('Error loading activities: $e');
      setState(
          () => _isLoading = false); // ตั้งค่าเป็น false เมื่อเกิดข้อผิดพลาด
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
              Icons.event, // Icon mặc định cho personal activity
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.startTime.hour, activity.startTime.minute))} - ${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.endTime.hour, activity.endTime.minute))}',
                style: TextStyle(fontSize: 14.0, color: Colors.grey.shade700),
              ),
              SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy').format(activity.date),
                style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
              ),
            ],
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
          onTap: () => _showActivityDetails(activity),
        ));
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // ฟังก์ชันโหลดกิจกรรมของวันที่เลือก
            List<Activity> _loadDayActivities() {
              return _activities.where((activity) {
                return isSameDay(activity.date, selectedDay) &&
                    activity.type == 'Personal' &&
                    activity.userId == currentUserId;
              }).toList()
                ..sort((a, b) {
                  return (a.startTime.hour * 60 + a.startTime.minute)
                      .compareTo(b.startTime.hour * 60 + b.startTime.minute);
                });
            }

            // โหลดกิจกรรมของวันที่เลือก
            List<Activity> dayActivities = _loadDayActivities();

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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30.0),
                    ),
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
                      // Drag Handle
                      Container(
                        width: 50,
                        height: 6,
                        margin: EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),

                      // Date Header
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade100,
                              Colors.green.shade50
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE').format(selectedDay),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy').format(selectedDay),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                color: Colors.green.shade800,
                                size: 30,
                              ),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddActivityScreen(
                                      initialType: ActivityType.Personal,
                                      initialDate: selectedDay,
                                    ),
                                  ),
                                );

                                // หลังจากสร้างกิจกรรมใหม่
                                if (result is Activity) {
                                  // อัปเดต state ของ modal
                                  setModalState(() {
                                    // โหลดกิจกรรมใหม่
                                    dayActivities = _loadDayActivities();
                                  });

                                  // อัปเดต state หลัก
                                  setState(() {
                                    _activities.add(result);
                                    _filteredActivities = _filterActivities();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // Activities List
                      Expanded(
                        child: dayActivities.isEmpty
                            ? _buildEmptyStateWidget(selectedDay)
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: dayActivities.length,
                                itemBuilder: (context, index) {
                                  return Dismissible(
                                    key: UniqueKey(), // เปลี่ยนเป็น UniqueKey
                                    background: Container(color: Colors.red),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (direction) {
                                      // ลบกิจกรรม
                                      _deleteActivity(dayActivities[index]);

                                      // อัปเดต state ของ modal
                                      setModalState(() {
                                        dayActivities.removeAt(index);
                                      });

                                      // อัปเดต state หลัก
                                      setState(() {
                                        _filteredActivities =
                                            _filterActivities();
                                      });
                                    },
                                    child: GestureDetector(
                                      onTap: () async {
                                        final editedActivity =
                                            await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddActivityScreen(
                                              activityToEdit:
                                                  dayActivities[index],
                                              initialDate:
                                                  selectedDay, // เพิ่มบรรทัดนี้
                                              initialType: ActivityType
                                                  .Personal, // เพิ่มบรรทัดนี้
                                            ),
                                          ),
                                        );

                                        // หากมีการแก้ไขกิจกรรม
                                        if (editedActivity is Activity) {
                                          setModalState(() {
                                            dayActivities =
                                                _loadDayActivities();
                                          });

                                          setState(() {
                                            _filteredActivities =
                                                _filterActivities();
                                          });
                                        }
                                      },
                                      child: _buildEnhancedActivityCard(
                                        dayActivities[index],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyStateWidget(DateTime selectedDay) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 80,
            color: Colors.green.shade200,
          ),
          SizedBox(height: 16),
          Text(
            'No activities on ${DateFormat('dd MMM yyyy').format(selectedDay)}',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Tap the + button to add a new activity',
            style: TextStyle(
              color: Colors.green.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddActivityWithDate(DateTime selectedDay) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          initialType: ActivityType.Personal,
          initialDate: selectedDay, // Pass the selected day here
        ),
      ),
    );

    if (result is Activity) {
      setState(() {
        _activities.add(result);
        _filteredActivities = _filterActivities();
        _sortActivitiesByDate();
      });
    }
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
        color: isToday ? Colors.green.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: Colors.green.shade700, width: 2)
            : events.isNotEmpty
                ? Border.all(color: Colors.green.shade200, width: 1.5)
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
            if (events.isNotEmpty && !isToday)
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
    // Count only personal activities for the current month
    int monthActivities = _activities
        .where((activity) =>
            activity.type == 'Personal' && // เพิ่มเงื่อนไขให้เป็นเฉพาะ Personal
            activity.date.year == _currentMonth.year &&
            activity.date.month == _currentMonth.month)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Personal Activities this month',
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
    return Container(); // ไม่แสดง Category Chips
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
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.green.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        title: Text(
          activity.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        subtitle: Text(
          '${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.startTime.hour, activity.startTime.minute))} - ${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.endTime.hour, activity.endTime.minute))}',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.green.shade600,
        ),
        onTap: () => _showActivityDetails(activity),
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
        color: Colors.green.shade700, // เปลี่ยนเป็นสีเขียวเข้ม
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: Colors.white, // คงสีขาวไว้
            fontWeight: FontWeight.bold,
            fontSize: 16, // เพิ่มขนาดตัวเลข
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

    // เรียงลำดับกิจกรรมหลังจากมีการเปลี่ยนแปลง
    _sortActivitiesByDate();
  }

  void _addNewActivity(Activity newActivity) {
    setState(() {
      _activities.add(newActivity);
      _sortActivitiesByDate(); // เรียงลำดับใหม่
    });
  }

  void _updateExistingActivity(Activity updatedActivity) {
    setState(() {
      final index = _activities.indexWhere((a) => a.id == updatedActivity.id);
      if (index != -1) {
        _activities[index] = updatedActivity;
        _sortActivitiesByDate(); // เรียงลำดับใหม่
      }
    });
  }

  void _removeActivity(String activityId) {
    setState(() {
      _activities.removeWhere((a) => a.id == activityId);
      _filteredActivities = _filterActivities();
    });
  }

  void _handleError(dynamic error) {
    // แสดงข้อความข้อผิดพลาด
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading activities: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  List<Activity> _getEventsForDay(DateTime day) {
    return _filteredActivities.where((activity) {
      return activity.type ==
              'Personal' && // เพิ่มเงื่อนไขให้เป็นเฉพาะ Personal
          activity.date.year == day.year &&
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
                  // Handle for dragging
                  Container(
                    width: 50,
                    height: 6,
                    margin: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Header for the date
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

                  // Display daily activities
                  Expanded(
                    child: ListView.builder(
                      itemCount: dayActivities.length,
                      itemBuilder: (context, index) {
                        return _buildActivityCard(dayActivities[index]);
                      },
                    ),
                  ),

                  // Condition when there are no activities
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              'No activities found',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(activities[index]);
      },
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

  Widget _buildActivitiesList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_filteredActivities.isEmpty) {
      return Center(
        child: Text('No activities found'),
      );
    }

    return ListView.builder(
      itemCount: _filteredActivities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(_filteredActivities[index]);
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
  }

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
                      'Time: ${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.startTime.hour, activity.startTime.minute))} - ${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.endTime.hour, activity.endTime.minute))}',
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
      print('There was an error loading the activity.: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Activity> _filterActivities() {
    return _activities.where((activity) {
      return activity.type == 'Personal'; // แสดงเฉพาะกิจกรรมส่วนตัว
    }).toList();
  }

  void _navigateToAddActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          initialType: ActivityType.Personal, // กำหนดเป็น Personal โดยอัตโนมัติ
        ),
      ),
    );

    if (result is Activity) {
      setState(() {
        _activities.add(result);
        _filteredActivities = _filterActivities();
      });
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
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(25.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
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

                  // Header with Activity Title and Status
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(activity.status),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            activity.status,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Divider(
                      color: Colors.green.shade200,
                      thickness: 1.5,
                    ),
                  ),

                  // Details Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          icon: Icons.calendar_today,
                          label: 'Date',
                          value: DateFormat('EEEE, dd MMM yyyy')
                              .format(activity.date),
                        ),
                        SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Time',
                          value:
                              '${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.startTime.hour, activity.startTime.minute))} - ${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.endTime.hour, activity.endTime.minute))}',
                        ),
                        SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.category,
                          label: 'Type',
                          value: activity.type,
                        ),
                      ],
                    ),
                  ),

                  // Description Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          activity.description.isEmpty
                              ? 'No description provided'
                              : activity.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: activity.description.isEmpty
                                ? Colors.grey
                                : Colors.black87,
                            fontStyle: activity.description.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _editActivity(activity);
                            },
                            icon: Icon(Icons.edit),
                            label: Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteActivity(activity);
                            },
                            icon: Icon(Icons.delete),
                            label: Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.green.shade700,
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      ],
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
                '${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.startTime.hour, activity.startTime.minute))} - ${DateFormat('HH:mm').format(DateTime(2023, 1, 1, activity.endTime.hour, activity.endTime.minute))}',
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

  Future<void> _editActivity(Activity activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(activityToEdit: activity),
      ),
    );

    if (result is Activity) {
      try {
        // อัปเดตกิจกรรมในฐานข้อมูล
        await _activityService.updateActivity(result);

        // อัปเดตรายการกิจกรรมในแอพ
        setState(() {
          // ค้นหาและแทนที่กิจกรรมเดิมด้วยกิจกรรมที่แก้ไข
          int index = _activities.indexWhere((a) => a.id == result.id);
          if (index != -1) {
            _activities[index] = result;
          }

          // อัปเดต filtered activities
          _filteredActivities = _filterActivities();
        });

        // แสดง Snackbar แจ้งผลสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activity updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error updating activity: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating activity: $e'),
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
            content: Text('Activity ID not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _activityService.deleteActivity(activity.id!);
      setState(() {
        _activities.removeWhere((a) => a.id == activity.id);
        _filteredActivities = _filterActivities(); // อัปเดตกิจกรรมที่กรองใหม่
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Activity successfully deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred deleting an activity: $e'),
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
