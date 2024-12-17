import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:workplanpro/screens/activity_service.dart';
import '../models/activity.dart';
import 'add_activity_screen.dart';

class GroupCalendarPage extends StatefulWidget {
  final String groupId;
  final String currentUserEmail;

  const GroupCalendarPage({
    Key? key,
    required this.groupId,
    required this.currentUserEmail,
  }) : super(key: key);

  @override
  _GroupCalendarPageState createState() => _GroupCalendarPageState();
}

class _GroupCalendarPageState extends State<GroupCalendarPage> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDay;
  List<Activity> _activities = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  StreamSubscription? _activitiesSubscription;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadActivities();
    _fetchActivities();
    _listenToActivities(); // เปลี่ยนจาก _loadActivities
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePageData();
    });
  } // เพิ่มเมธอดดึงกิจกรรม

  Future<void> _initializePageData() async {
    try {
      await _checkAdminStatus();
      _listenToActivities();
    } catch (e) {
      print('Initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToActivities() {
    _activitiesSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _activities = [];
    });

    _activitiesSubscription = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('activities')
        .orderBy('date', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _activities = snapshot.docs.map((doc) {
          final data = doc.data();
          return Activity(
            id: doc.id,
            title: data['title'] ?? '',
            description: data['description'] ?? '',
            date: (data['date'] as Timestamp).toDate(),
            startTime: _parseTimeOfDay(data['startTime']),
            endTime: _parseTimeOfDay(data['endTime']),
            type: data['type'] ?? 'Group',
            status: data['status'] ?? 'Pending',
            groupId: widget.groupId,
          );
        }).toList();

        _isLoading = false;
      });
    }, onError: (error) {
      print('Error listening to group activities: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  TimeOfDay _parseTimeOfDay(dynamic timeData) {
    if (timeData == null) return TimeOfDay.now();

    if (timeData is Map) {
      return TimeOfDay(
        hour: (timeData['hour'] ?? 0),
        minute: (timeData['minute'] ?? 0),
      );
    }

    if (timeData is String) {
      final parts = timeData.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return TimeOfDay.now();
  }

  @override
  void dispose() {
    // Cancel subscriptions
    _activitiesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchActivities() async {
    try {
      setState(() => _isLoading = true);
      final activities = await _activityService.fetchActivities();
      setState(() {
        // กรองเฉพาะกิจกรรมกลุ่ม
        _activities = _filterGroupActivities(activities);
      });
      setState(() {
        _isLoading = false; // ตั้งค่าเป็น false เมื่อโหลดเสร็จ
      });
    } catch (e) {
      // จัดการข้อผิดพลาด
      print('Error fetching activities: $e');
      // อาจแสดง Snackbar หรือ Dialog เพื่อแจ้งผู้ใช้
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load activity')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _navigateToAddGroupActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          initialType: ActivityType.Group, // กำหนดเป็น Group โดยอัตโนมัติ
        ),
      ),
    );

    if (result is Activity) {
      // บันทึกกิจกรรม
      _saveActivity(result);
    }
  }

  final ActivityService _activityService = ActivityService();

  void _saveActivity(Activity activity) async {
    try {
      // บันทึกลง Firestore
      await _activityService.addActivity(activity);

      // รีเฟรชรายการกิจกรรม
      _fetchActivities();
    } catch (e) {
      // จัดการข้อผิดพลาด
      print('Error saving activity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to record activity')),
      );
    }
  }

  List<Activity> _filterGroupActivities(List<Activity> activities) {
    return activities.where((activity) => activity.type == 'Group').toList();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .where('email', isEqualTo: widget.currentUserEmail)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (memberDoc.docs.isNotEmpty) {
        setState(() {
          _isAdmin = memberDoc.docs.first['role'] == 'admin';
        });
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  Future<void> _loadActivities() async {
    try {
      setState(() => _isLoading = true);

      // เจาะจงโหลดเฉพาะกิจกรรมของกลุ่มนี้
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('activities')
          .orderBy('date', descending: false)
          .get();

      if (mounted) {
        setState(() {
          _activities = snapshot.docs.map((doc) {
            final data = doc.data();
            return Activity(
              id: doc.id,
              title: data['title'] ?? '',
              description: data['description'] ?? '',
              date: (data['date'] as Timestamp).toDate(),
              startTime: TimeOfDay(
                hour: (data['startTime'] as Map<String, dynamic>)['hour'] ?? 0,
                minute:
                    (data['startTime'] as Map<String, dynamic>)['minute'] ?? 0,
              ),
              endTime: TimeOfDay(
                hour: (data['endTime'] as Map<String, dynamic>)['hour'] ?? 0,
                minute:
                    (data['endTime'] as Map<String, dynamic>)['minute'] ?? 0,
              ),
              type: data['type'] ?? 'Personal',
              status: data['status'] ?? 'Pending',
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading group activities: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          groupId: widget.groupId,
          initialType:
              ActivityType.Group, // กำหนดเป็น Group Activity โดยอัตโนมัติ
        ),
      ),
    );

    if (result is Activity) {
      // บันทึก Group Activity
      await _saveGroupActivity(result);
    }
  }

  Future<void> _saveGroupActivity(Activity activity) async {
    try {
      // Batch operation for saving activity
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // References for group and main activities
      final groupActivitiesRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('activities')
          .doc();

      final mainActivitiesRef =
          FirebaseFirestore.instance.collection('activities').doc();

      // Prepare activity data
      final activityData = {
        ...activity.toFirestoreMap(),
        'groupId': widget.groupId,
        'type': 'Group', // กำหนดประเภทเป็น Group
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add to batch
      batch.set(groupActivitiesRef, activityData);
      batch.set(mainActivitiesRef, activityData);

      // Commit batch
      await batch.commit();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Activity saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving group activity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save activity'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to get events for a specific month
  List<Activity> _getEventsForMonth(DateTime month) {
    return _activities
        .where((activity) =>
            activity.date.year == month.year &&
            activity.date.month == month.month)
        .toList();
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
            )
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
              onTap: () => _showActivityDetail(activity),
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

  Widget _buildActivitiesList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_activities.isEmpty) {
      return Center(
        child: Text('No activities found'),
      );
    }

    return ListView.builder(
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(_activities[index]);
      },
    );
  }

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

  void _showActivityDetail(Activity activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
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
                          onPressed: () => Navigator.pop(context),
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
                    if (_isAdmin) ...[
                      SizedBox(height: 24.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showDeleteConfirmationDialog(activity);
                            },
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          SizedBox(width: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _editActivity(activity);
                            },
                            child: Text('Edit'),
                            style: TextButton.styleFrom(
                              foregroundColor: Color(0xFF0C5217),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Activity activity) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete Activity'),
        content: Text('Are you sure you want to delete this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteActivity(activity);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _editActivity(Activity activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          activityToEdit: activity,
          groupId: widget.groupId,
          initialType: ActivityType.Group,
        ),
      ),
    );

    if (result == true) {
      // Reload activities after successful update
      await _loadActivities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteActivity(Activity activity) async {
    try {
      // สร้าง Batch เพื่อลบข้อมูลใน 2 Collection
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // อ้างอิงเอกสารที่ต้องการลบ
      final groupActivityRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('activities')
          .doc(activity.id);

      // ลบจาก Collection กลุ่ม
      batch.delete(groupActivityRef);

      // ค้นหาและลบจาก Collection หลัก
      final mainActivityQuery = await FirebaseFirestore.instance
          .collection('activities')
          .where('groupId', isEqualTo: widget.groupId)
          .where('date', isEqualTo: Timestamp.fromDate(activity.date))
          .get();

      // ลบเอกสารที่ตรงเงื่อนไข
      for (var doc in mainActivityQuery.docs) {
        final mainData = doc.data();
        if (mainData['title'] == activity.title &&
            mainData['description'] == activity.description) {
          batch.delete(doc.reference);
        }
      }

      // ดำเนินการ Batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Activity deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting activity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete activity'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Calendar Section
              Container(
                margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Calendar Header and Calendar Widget
                    _buildCalendarHeader(),
                    _buildTableCalendar(),
                    _buildActivitiesCountRow(),
                  ],
                ),
              ),

              // Activities List Section
              Expanded(
                child: _buildActivitiesList(),
              ),
            ],
          ),

          // Floating Action Button for Admin
          if (_isAdmin) _buildAdminFloatingActionButton(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(_currentMonth),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0C5217),
          ),
        ),
        Row(
          children: [
            _buildNavigationButton(Icons.chevron_left, () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
              });
            }),
            SizedBox(width: 8),
            _buildNavigationButton(Icons.chevron_right, () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(),
      icon: Icon(
        icon,
        color: Color(0xFF0C5217),
        size: 24,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildTableCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2010, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _currentMonth,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      headerVisible: false,
      daysOfWeekHeight: 20,
      rowHeight: 30,
      calendarFormat: CalendarFormat.month,
      availableGestures: AvailableGestures.none,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: Colors.green.shade700,
          fontSize: 12,
        ),
        weekendStyle: TextStyle(
          color: Colors.red.shade400,
          fontSize: 12,
        ),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle: TextStyle(fontSize: 12),
        weekendTextStyle: TextStyle(fontSize: 12),
        selectedTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        todayTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        todayDecoration: BoxDecoration(
          color: Color(0xFF0C5217),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.green.shade800,
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: Colors.green.shade400,
          shape: BoxShape.circle,
        ),
        markerSize: 4,
        cellMargin: EdgeInsets.all(2),
      ),
      eventLoader: _getEventsForDay,
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _currentMonth = focusedDay;
        });
      },
    );
  }

  Widget _buildActivitiesCountRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Activities this month',
            style: TextStyle(
              color: Colors.green.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_getEventsForMonth(_currentMonth).length}',
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFloatingActionButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.extended(
        onPressed: _createActivity,
        backgroundColor: const Color(0xFF0C5217),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Activity',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  List<Activity> _getEventsForDay(DateTime day) {
    return _activities.where((activity) {
      return activity.date.year == day.year &&
          activity.date.month == day.month &&
          activity.date.day == day.day;
    }).toList();
  }
}
