import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<Activity> _activities = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isCreator = false;
  bool _isCalendarExpanded = true;
  bool _isActivitiesExpanded = true;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadActivities();
  }

  Future<void> _checkUserRole() async {
    try {
      // Check if user is group creator
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (groupDoc.exists) {
        setState(() {
          _isCreator =
              groupDoc.data()?['creatorEmail'] == widget.currentUserEmail;
        });
      }

      // Check if user is admin
      final memberDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .where('email', isEqualTo: widget.currentUserEmail)
          .where('role', isEqualTo: 'admin')
          .where('status', isEqualTo: 'accepted')
          .get();

      setState(() {
        _isAdmin = memberDoc.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error checking user role: $e');
    }
  }

  Future<void> _loadActivities() async {
    try {
      setState(() => _isLoading = true);

      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('activities')
          .orderBy('date', descending: true)
          .get();

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
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCalendar() {
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final now = DateTime.now();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF0C5217), // เพิ่มสีพื้นหลังสีเขียว
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
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
                      _currentMonth.year,
                      _currentMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                      1,
                    );
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
                  child: Text(weekday, style: TextStyle(color: Colors.white)),
                );
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
                  activity.date.day == date.day);

              return Center(
                child: Container(
                  width: 32,
                  height: 32,
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
                        fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0C5217),
      body: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              colorScheme: ColorScheme.dark(primary: Colors.white),
            ),
            child: ExpansionTile(
              initiallyExpanded: _isCalendarExpanded,
              onExpansionChanged: (expanded) {
                setState(() => _isCalendarExpanded = expanded);
              },
              title: Text(
                'Group Calendar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              trailing: Icon(
                _isCalendarExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white,
              ),
              children: [_buildCalendar()],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.zero,
                  topRight: Radius.zero,
                ),
              ),
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          ExpansionTile(
                            initiallyExpanded: true,
                            title: Text(
                              'Group Activities',
                              style: TextStyle(
                                color: Color(0xFF0C5217),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            shape: Border.all(color: Colors.transparent),
                            children: [_buildActivitiesList()],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: (_isAdmin || _isCreator)
          ? FloatingActionButton.extended(
              onPressed: () => _createActivity(),
              backgroundColor: const Color(0xFF0C5217),
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                "New Activity",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _createActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddActivityScreen()),
    );

    if (result != null && result is Activity) {
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
          'createdBy': widget.currentUserEmail,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _loadActivities();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activity created successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating activity: $e')),
        );
      }
    }
  }

  Widget _buildActivitiesList() {
    if (_activities.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        return Card(
          margin: EdgeInsets.all(8.0),
          child: ListTile(
            onTap: () => _showActivityDetails(activity, index),
            title: Text(
              DateFormat('dd MMM yyyy').format(activity.date),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C5217),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title, style: TextStyle(fontSize: 16)),
                SizedBox(height: 4),
                Text(
                  '${activity.startTime.format(context)} - ${activity.endTime.format(context)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (activity.description.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: TextStyle(color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActivityDetails(Activity activity, int index) {
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
                    SizedBox(height: 4.0),
                    Text(
                      'Time: ${activity.startTime.format(context)} - ${activity.endTime.format(context)}',
                      style: TextStyle(fontSize: 16.0),
                    ),
                    if (activity.description.isNotEmpty) ...[
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
                    ],
                    if (_isAdmin || _isCreator) ...[
                      SizedBox(height: 24.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showDeleteConfirmation(activity);
                            },
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                          SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _editActivity(activity);
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(Activity activity) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this activity?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('activities')
                      .doc(activity.id)
                      .delete();

                  Navigator.of(context).pop();
                  _loadActivities();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Activity deleted successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting activity: $e')),
                  );
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editActivity(Activity activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(activityToEdit: activity),
      ),
    );

    if (result != null && result is Activity) {
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
        });

        _loadActivities();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activity updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating activity: $e')),
        );
      }
    }
  }
}
