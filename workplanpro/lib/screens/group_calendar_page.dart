import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadActivities();
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

      if (memberDoc.docs.isNotEmpty && mounted) {
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
                hour: data['startTimeHour'] ?? 0,
                minute: data['startTimeMinute'] ?? 0,
              ),
              endTime: TimeOfDay(
                hour: data['endTimeHour'] ?? 0,
                minute: data['endTimeMinute'] ?? 0,
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
        ),
      ),
    );

    if (result is Activity) {
      try {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('activities')
            .add({
          'title': result.title,
          'description': result.description,
          'date': result.date,
          'startTimeHour': result.startTime.hour,
          'startTimeMinute': result.startTime.minute,
          'endTimeHour': result.endTime.hour,
          'endTimeMinute': result.endTime.minute,
          'type': result.type,
          'status': result.status,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.currentUserEmail,
        });

        _loadActivities();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Activity created successfully')),
          );
        }
      } catch (e) {
        print('Error creating activity: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating activity')),
          );
        }
      }
    }
  }

  List<Activity> _getEventsForDay(DateTime day) {
    return _activities
        .where((activity) =>
            activity.date.year == day.year &&
            activity.date.month == day.month &&
            activity.date.day == day.day)
        .toList();
  }

  List<Activity> _getEventsForMonth(DateTime month) {
    return _activities
        .where((activity) =>
            activity.date.year == month.year &&
            activity.date.month == month.month)
        .toList();
  }

  Widget _buildActivitiesList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final activities = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : _getEventsForMonth(_currentMonth);

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey.shade400),
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
        final activity = activities[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
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
                Text(
                  '${activity.startTime.format(context)} - ${activity.endTime.format(context)}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            onTap: () => _showActivityDetail(activity),
          ),
        );
      },
    );
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
                            child: Text(
                              'Edit',
                              style: TextStyle(color: Color(0xFF0C5217)),
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
              _deleteActivity(activity);
              Navigator.pop(context);
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

  Future<void> _editActivity(Activity activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          groupId: widget.groupId,
        ),
      ),
    );

    if (result is Activity) {
      try {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('activities')
            .doc(activity.id)
            .update({
          'title': result.title,
          'description': result.description,
          'date': result.date,
          'startTimeHour': result.startTime.hour,
          'startTimeMinute': result.startTime.minute,
          'endTimeHour': result.endTime.hour,
          'endTimeMinute': result.endTime.minute,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': widget.currentUserEmail,
        });

        _loadActivities();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Activity updated successfully')),
          );
        }
      } catch (e) {
        print('Error updating activity: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating activity')),
          );
        }
      }
    }
  }

  Future<void> _deleteActivity(Activity activity) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('activities')
          .doc(activity.id)
          .delete();

      _loadActivities();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activity deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting activity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting activity')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
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
                  Row(
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
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            icon: Icon(
                              Icons.chevron_left,
                              color: Color(0xFF0C5217),
                              size: 24,
                            ),
                            onPressed: () => setState(() {
                              _currentMonth = DateTime(
                                _currentMonth.year,
                                _currentMonth.month - 1,
                              );
                            }),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            icon: Icon(
                              Icons.chevron_right,
                              color: Color(0xFF0C5217),
                              size: 24,
                            ),
                            onPressed: () => setState(() {
                              _currentMonth = DateTime(
                                _currentMonth.year,
                                _currentMonth.month + 1,
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),

                  TableCalendar(
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
                  ),

                  Padding(
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
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  ),
                ],
              ),
            ),

            Expanded(
              child: _buildActivitiesList(),
            ),
          ],
        ),
        if (_isAdmin)
          Positioned(
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
          ),
      ],
    );
  }
}
