//home
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workplanpro/models/activity.dart';
import 'package:workplanpro/screens/activity_service.dart';
import 'package:workplanpro/screens/add_activity_screen.dart';
import 'note_page.dart';
import 'account_page.dart';
import 'calendar_page.dart';
import 'group_page.dart';

// Custom Filter Model
class ActivityFilter {
  String type;
  String sortBy;
  bool isAscending;
  String? statusFilter;

  ActivityFilter({
    this.type = 'All',
    this.sortBy = 'Nearest Date',
    this.isAscending = true,
    this.statusFilter,
  });
}

class ActivityDetailsBottomSheet extends StatelessWidget {
  final ActivityModel activity;
  final Function onDelete;
  final Function onEdit;

  const ActivityDetailsBottomSheet({
    Key? key,
    required this.activity,
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          // Title Section
          Text(
            activity.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 10),

          // Date and Priority
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMMM yyyy').format(activity.date),
                style: TextStyle(color: Colors.grey.shade600),
              ),
              /*Chip(
                label: Text(
                  activity.priority,
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: _getPriorityColor(activity.priority),
              ),*/
            ],
          ),
          SizedBox(height: 15),

          // Description
          Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            activity.description,
            style: TextStyle(color: Colors.black87),
          ),
          SizedBox(height: 15),

          // Type
          Row(
            children: [
              Icon(Icons.category, color: Colors.green.shade600),
              SizedBox(width: 10),
              Text(
                'Type: ${activity.type}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Copy color method from HomePage
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}

// Custom Delegate สำหรับ Search Header
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SearchHeaderDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.green.shade50, // สีพื้นหลังที่เข้ากับธีม
      child: child,
    );
  }

  @override
  double get maxExtent => 80; // ความสูงสูงสุด

  @override
  double get minExtent => 80; // ความสูงต่ำสุด

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class ActivityModel {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String type;
  final String status;

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    this.status = 'Pending', // Nilai default
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      type: data['type'] ?? 'Personal',
      status: data['status'] ?? 'Pending', // Tambahkan ini
    );
  }
}

class HomePage extends StatefulWidget {
  final String username;
  final String userEmail;

  const HomePage({Key? key, required this.username, required this.userEmail})
      : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasInternetConnection = true;
  List<ActivityModel> _activities = [];
  List<ActivityModel> _filteredActivities = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _currentIndex = 0;
  bool _isDisposed = false;
  final ActivityService _activityService = ActivityService();
  // Controllers
  final TextEditingController _searchController = TextEditingController();
// Connectivity
  final ThemeData appTheme = ThemeData(
    primarySwatch: Colors.green,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.green.shade700,
      primary: Colors.green.shade700,
      secondary: Colors.greenAccent.shade400,
      background: Colors.green.shade50,
    ),
    fontFamily: 'Prompt', // ฟอนต์ที่อ่านง่าย
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );

  String _sortBy = 'Nearest Date'; // ค่าเริ่มต้นในการเรียง
  bool _isAscending = true; // สำหรับการเรียงลำดับ

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _setupConnectivityListener();
    _loadCachedActivities();
    _fetchActivities();
  }

  Future<void> _checkInitialConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternetConnection = connectivityResult != ConnectivityResult.none;
    });

    if (_hasInternetConnection) {
      _fetchActivities();
    } else {
      _loadCachedActivities();
      _showNoInternetSnackBar();
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      setState(() {
        _hasInternetConnection = results.first != ConnectivityResult.none;
      });

      if (_hasInternetConnection) {
        _fetchActivities();
      } else {
        _showOfflineWarning();
      }
    });
  }

  void _showOfflineWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No internet. Using cached data.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _loadCachedActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedActivitiesJson = prefs.getString('cached_activities');

      if (cachedActivitiesJson != null) {
        final List<dynamic> cachedActivitiesList =
            json.decode(cachedActivitiesJson);

        setState(() {
          _activities = cachedActivitiesList
              .map((activity) => ActivityModel(
                    id: activity['id'],
                    title: activity['title'],
                    description: activity['description'],
                    date: DateTime.parse(activity['date']),
                    type: activity['type'],
                    /*priority: activity['priority'],*/
                  ))
              .toList();
          _filteredActivities = _filterActivities();
        });
      }
    } catch (e) {
      print('Error loading cached activities: $e');
    }
  }

  Future<void> _cacheActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activitiesToCache = _activities
          .map((activity) => {
                'id': activity.id,
                'title': activity.title,
                'description': activity.description,
                'date': activity.date.toIso8601String(),
                'type': activity.type,
                /*'priority': activity.priority,*/
              })
          .toList();

      await prefs.setString(
          'cached_activities', json.encode(activitiesToCache));
    } catch (e) {
      print('Error caching activities: $e');
    }
  }

  Future<void> _fetchActivities() async {
    if (!_hasInternetConnection) {
      _showNoInternetSnackBar();
      return;
    }

    try {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User  not authenticated');
      }

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: user.uid)
          .get()
          .timeout(
            Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Connection timeout'),
          );

      List<ActivityModel> fetchedActivities = querySnapshot.docs
          .map((doc) => ActivityModel.fromFirestore(doc))
          .toList();

      fetchedActivities.sort((a, b) => b.date.compareTo(a.date));

      if (!_isDisposed) {
        setState(() {
          _activities = fetchedActivities;
          _filteredActivities = _filterActivities();
          _isLoading = false;
        });

        await _cacheActivities();
      }
    } catch (e) {
      _handleError(e);
      await _loadCachedActivities();
    }
  }

  void _handleErrorWithFallback(dynamic error) {
    // Log detailed error
    print('Detailed Error: ${error.toString()}');

    // Show user-friendly error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getErrorMessage(error)),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _fetchActivities,
        ),
      ),
    );

    // Fallback to cached or empty state
    setState(() {
      _isLoading = false;
      if (_activities.isEmpty) {
        _loadCachedActivities();
      }
    });
  }

  void _showNoInternetSnackBar() {
    if (!_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No internet connection'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    _isDisposed = true;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInternetConnection();
    }
  }

  Future<void> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (!_isDisposed) {
      setState(() {
        _hasInternetConnection = connectivityResult != ConnectivityResult.none;
      });

      if (_hasInternetConnection) {
        _fetchActivities();
      }
    }
  }

  Future<void> _createSampleActivity() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user.uid,
        'title': 'Test Activity',
        'description': 'This is a test activity',
        'date': Timestamp.now(),
        'type': 'Personal',
        'priority': 'Normal'
      });

      _fetchActivities();
    } catch (e) {
      print('Error creating sample activity: $e');
    }
  }

  void _showAdvancedFilterBottomSheet() {
    final filter = ActivityFilter();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Title
              Text('Advanced Filters',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

              // Type Filter
              _buildFilterSection(
                title: 'Activity Type',
                child: Wrap(
                  spacing: 10,
                  children: ['All', 'Personal', 'Group', 'Work']
                      .map((type) => ChoiceChip(
                            label: Text(type),
                            selected: filter.type == type,
                            onSelected: (selected) {
                              setState(() {
                                filter.type = type;
                              });
                            },
                          ))
                      .toList(),
                ),
              ),

              // Status Filter
              _buildFilterSection(
                title: 'Status',
                child: Wrap(
                  spacing: 10,
                  children: ['All', 'Pending', 'In Progress', 'Completed']
                      .map((status) => ChoiceChip(
                            label: Text(status),
                            selected: filter.statusFilter == status,
                            onSelected: (selected) {
                              setState(() {
                                filter.statusFilter = selected ? status : null;
                              });
                            },
                          ))
                      .toList(),
                ),
              ),

              // Status Filter Section
              _buildFilterSection(
                title: 'Status',
                child: Wrap(
                  spacing: 10,
                  children: ['All', 'Pending', 'In Progress', 'Completed']
                      .map((status) => ChoiceChip(
                            label: Text(status),
                            selected: filter.statusFilter == status,
                            onSelected: (selected) {
                              setState(() {
                                filter.statusFilter = selected ? status : null;
                              });
                            },
                            selectedColor: _getStatusChipColor(status),
                          ))
                      .toList(),
                ),
              ),

              // Sort By Section
              _buildFilterSection(
                title: 'Sort By',
                child: Column(
                  children: [
                    _buildSortOption(
                        setState, filter, 'Nearest Date', Icons.calendar_today),
                    _buildSortOption(
                        setState, filter, 'Created At', Icons.create),
                    _buildSortOption(setState, filter, 'Oldest', Icons.history),
                  ],
                ),
              ),

              // Sorting Direction
              _buildFilterSection(
                title: 'Sorting Direction',
                child: Row(
                  children: [
                    Text('Ascending'),
                    Switch(
                      value: filter.isAscending,
                      onChanged: (value) {
                        setState(() {
                          filter.isAscending = value;
                        });
                      },
                      activeColor: Colors.green.shade700,
                    ),
                    Text('Descending'),
                  ],
                ),
              ),

              // Apply Filters Button
              Spacer(),
              Center(
                  child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filteredActivities = _applyAdvancedFilters(filter);
                  });
                  Navigator.pop(context);
                },
                child: Text('Apply Filters'),
              ))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildSortOption(StateSetter setState, ActivityFilter filter,
      String option, IconData icon) {
    return RadioListTile(
      title: Text(option),
      secondary: Icon(icon),
      value: option,
      groupValue: filter.sortBy,
      onChanged: (value) {
        setState(() {
          filter.sortBy = value.toString();
        });
      },
      activeColor: Colors.green.shade700,
    );
  }

  Color _getStatusChipColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade100;
      case 'In Progress':
        return Colors.blue.shade100;
      case 'Completed':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  List<ActivityModel> _applyAdvancedFilters(ActivityFilter filter) {
    return _activities.where((activity) {
      // Type Filter
      bool matchesType = filter.type == 'All' || activity.type == filter.type;

      // Status Filter
      bool matchesStatus =
          filter.statusFilter == null || activity.status == filter.statusFilter;

      return matchesType && matchesStatus;
    }).toList()
      ..sort((a, b) {
        switch (filter.sortBy) {
          case 'Nearest Date':
            return filter.isAscending
                ? a.date.compareTo(b.date)
                : b.date.compareTo(a.date);
          case 'Created At':
            return filter.isAscending
                ? a.id.compareTo(b.id)
                : b.id.compareTo(a.id);
          case 'Oldest':
            return filter.isAscending
                ? b.date.compareTo(a.date)
                : a.date.compareTo(b.date);
          default:
            return 0;
        }
      });
  }

  String _selectedStatus = 'All';
  List<ActivityModel> _filterActivities() {
    return _activities.where((activity) {
      // Filter by Category
      bool matchesCategory =
          _selectedCategory == 'All' || activity.type == _selectedCategory;

      // Filter by Search Query
      bool matchesSearch = _searchQuery.isEmpty ||
          activity.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          activity.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

      // Filter by Status (เพิ่มการกรองสถานะ)
      bool matchesStatus =
          _selectedStatus == 'All' || activity.status == _selectedStatus;

      return matchesCategory && matchesSearch && matchesStatus;
    }).toList()
      ..sort((a, b) {
        switch (_sortBy) {
          case 'Nearest Date':
            return _isAscending
                ? a.date.compareTo(b.date)
                : b.date.compareTo(a.date);
          case 'Created At':
            return _isAscending ? a.id.compareTo(b.id) : b.id.compareTo(a.id);
          case 'Oldest':
            return _isAscending
                ? b.date.compareTo(a.date)
                : a.date.compareTo(b.date);
          default:
            return 0;
        }
      });
  }

  void _handleError(dynamic error) {
    if (_isDisposed) return;

    setState(() => _isLoading = false);

    String errorMessage = 'An error occurred: ';
    if (error is TimeoutException) {
      errorMessage += 'Connection timeout. Please check your internet.';
    } else if (error.toString().contains('permission-denied')) {
      errorMessage += 'Permission denied. Please check your account.';
    } else if (error.toString().contains('not-found')) {
      errorMessage += 'Data not found.';
    } else {
      errorMessage += error.toString();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _fetchActivities,
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied. Check your account.';
        case 'unavailable':
          return 'Network unavailable. Please check your connection.';
        default:
          return 'Firebase Error: ${error.message ?? 'Unknown error'}';
      }
    } else if (error is TimeoutException) {
      return 'Connection timeout. Please try again.';
    }
    return 'An unexpected error occurred: ${error.toString()}';
  }

  Future<void> _clearCachedActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_activities');
    } catch (e) {
      print('Error clearing cached activities: $e');
    }
  }

  // Widget untuk Menampilkan Aktivitas
  Widget _buildActivityCard(ActivityModel activity) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ExpansionTile(
        title: Text(
          activity.title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat('dd MMM yyyy').format(activity.date),
          style: TextStyle(color: Colors.grey),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: TextStyle(color: Colors.black87),
                ),
                SizedBox(height: 8),
                /*Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(activity.type),
                      backgroundColor: _getPriorityColor(activity.priority),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert),
                      onPressed: () => _showActivityOptions(activity),
                    )
                  ],
                )*/
              ],
            ),
          )
        ],
      ),
    );
  }

  // Warna Prioritas
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  void _showActivityOptions(ActivityModel activity) {
    showModalBottomSheet(
        context: context,
        builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit Activity'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditActivityDialog(activity);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete Activity'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteActivity(activity.id);
                  },
                ),
              ],
            ));
  }

  void _showEditActivityDialog(ActivityModel activity) {
    final TextEditingController titleController =
        TextEditingController(text: activity.title);
    final TextEditingController descriptionController =
        TextEditingController(text: activity.description);
    String selectedType =
        activity.type; // ตรวจสอบให้แน่ใจว่าค่านี้มีอยู่ในรายการ
    String selectedStatus =
        activity.status; // ตรวจสอบให้แน่ใจว่าค่านี้มีอยู่ในรายการ

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Activity'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Type',
                  ),
                  items: ['Personal', 'Group']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Status',
                  ),
                  items: [
                    'Pending',
                    'In Progress',
                    'Completed'
                  ] // ตรวจสอบให้แน่ใจว่ารายการนี้มีค่า selectedStatus
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateActivity(
                  activity.id,
                  titleController.text,
                  descriptionController.text,
                  selectedType,
                  selectedStatus,
                );
                Navigator.of(context).pop();
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateActivity(String id, String title, String description,
      String type, String status) async {
    try {
      await FirebaseFirestore.instance.collection('activities').doc(id).update({
        'title': title,
        'description': description,
        'type': type,
        'status': status, // Tambahkan status
      });

      // Reload activities after updating
      await _fetchActivities();
    } catch (e) {
      print('Error updating activity: $e');
      _handleError(e);
    }
  }

  Future<void> _deleteActivity(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(id)
          .delete();
      // Reload activities after deletion
      await _fetchActivities(); // เรียกใช้ฟังก์ชันเพื่อโหลดข้อมูลใหม่
    } catch (e) {
      print('Error deleting activity: $e');
      _handleError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*appBar: _buildAppBar(), // ลบ SliverAppBar ออก*/
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'My Activities', // เปลี่ยนเป็นภาษาอังกฤษ
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: Colors.green.shade700,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list, color: Colors.white),
          onPressed: _showFilterDialog,
          tooltip: 'Filter Activities', // เปลี่ยนเป็นภาษาอังกฤษ
        ),
      ],
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _fetchActivities,
      child: CustomScrollView(
        physics: BouncingScrollPhysics(), // เพิ่ม bouncing effect
        slivers: [
          SliverAppBar(
            floating: true, // ให้แถบเลื่อนขึ้นลงได้
            snap: true, // ให้แถบกระโดดกลับเร็ว
            backgroundColor: Colors.green.shade700,
            title: Text(
              'My Activities',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.filter_list, color: Colors.white),
                onPressed: _showFilterDialog,
                tooltip: 'Filter Activities',
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.only(top: 16), // เพิ่มระยะห่างด้านบน
            sliver: SliverToBoxAdapter(
              child: _buildOverviewCards(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildFirstTimeActivityCard(), // การ์ด Welcome
          ),
          SliverPersistentHeader(
            delegate: _SearchHeaderDelegate(
              child: _buildSearchAndFilterSection(),
            ),
            pinned: true, // ให้ติดด้านบนเมื่อเลื่อน
          ),
          SliverToBoxAdapter(
            child: _buildCategoryChips(),
          ),
          _buildActivityListSliver(),
        ],
      ),
    );
  }

  Widget _buildFirstTimeActivityCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade300, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Padding(
        // เพิ่ม Padding เพื่อให้การ์ดมีขนาดเล็กลง
        padding: EdgeInsets.all(12), // ปรับขนาด Padding ที่นี่
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Your Activity Tracker!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Start by creating your first activity.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _showCreateActivityDialog,
              child: Text('Create Activity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade200.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search activities...',
            prefixIcon: Icon(Icons.search, color: Colors.green.shade700),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.green.shade700),
                    onPressed: _clearSearch,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          ),
          onChanged: _handleSearchChange,
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filteredActivities = _filterActivities();
    });
  }

  void _handleSearchChange(String value) {
    setState(() {
      _searchQuery = value;
      _filteredActivities = _filterActivities();
    });
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: ['ทั้งหมด', 'ส่วนตัว', 'กลุ่ม']
              .map((category) => _buildCategoryChip(category))
              .toList(),
        ),
      ),
    );
  }

  void _showCreateActivityDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddActivityScreen()),
    );

    if (result is ActivityModel) {
      // คาดหวัง ActivityModel ที่นี่
      setState(() {
        _activities.add(result); // result ตอนนี้เป็นประเภท ActivityModel
        _filteredActivities = _filterActivities();
      });
    }
  }

  Future<void> _createActivity(
      String title, String description, String type, String priority) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user.uid,
        'title': title,
        'description': description,
        'date': Timestamp.now(),
        'type': type,
        'priority': priority,
        'status': 'Pending',
      });

      await _fetchActivities();
    } catch (e) {
      print('Error creating activity: $e');
      _handleError(e);
    }
  }

  // Widget untuk Menampilkan Chip Kategori
  Widget _buildCategoryChip(String category) {
    final displayNames = {
      'ทั้งหมด': 'All',
      'ส่วนตัว': 'Personal',
      'กลุ่ม': 'Group',
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          displayNames[category] ?? category,
          style: TextStyle(
            color: _selectedCategory.toLowerCase() ==
                    displayNames[category]?.toLowerCase()
                ? Colors.white
                : Colors.green.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: _selectedCategory.toLowerCase() ==
            displayNames[category]?.toLowerCase(),
        selectedColor: Colors.green.shade700,
        backgroundColor: Colors.green.shade100,
        pressElevation: 5,
        shadowColor: Colors.green.shade200,
        onSelected: (selected) {
          setState(() {
            _selectedCategory =
                selected ? (displayNames[category] ?? 'All') : 'All';
            _filteredActivities = _filterActivities();
          });
        },
      ),
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

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
          SizedBox(height: 16),
          Text(
            'กำลังโหลดกิจกรรม...',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/empty_state.json', // Add a Lottie animation
            width: 250,
            height: 250,
          ),
          SizedBox(height: 16),
          Text(
            'No Activities Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start organizing your day by\ncreating your first activity',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showCreateActivityDialog,
            icon: Icon(Icons.add_circle_outline),
            label: Text('Create New Activity'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildSummaryCard(
            icon: Icons.check_circle,
            title: 'Completed',
            value: _activities
                .where((a) => a.status == 'Completed')
                .length
                .toString(),
            color: Colors.green.shade400,
          ),
          _buildSummaryCard(
            icon: Icons.pending,
            title: 'Pending',
            value: _activities
                .where((a) => a.status == 'Pending')
                .length
                .toString(),
            color: Colors.orange.shade400,
          ),
          _buildSummaryCard(
            icon: Icons.play_arrow,
            title: 'In Progress',
            value: _activities
                .where((a) => a.status == 'In Progress')
                .length
                .toString(),
            color: Colors.blue.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovedActivityCard(ActivityModel activity) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _getActivityTypeColor(activity.type).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
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
                            color: Colors.green.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.green.shade600),
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
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildAnimatedActivityCard(ActivityModel activity) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getActivityTypeColor(activity.type).withOpacity(0.1),
            _getActivityTypeColor(activity.type).withOpacity(0.3)
          ],
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _showActivityDetails(activity),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _buildActivityCardContent(activity),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCardContent(ActivityModel activity) {
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

// เพิ่มฟังก์ชันเพื่อกำหนดสีสถานะ
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'In Progress':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showActivityDetails(ActivityModel activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => ActivityDetailsBottomSheet(
        activity: activity,
        onEdit: () {
          _showEditActivityDialog(activity); // เรียกใช้ฟังก์ชันแก้ไข
        },
        onDelete: () {
          _deleteActivity(activity.id); // เรียกใช้ฟังก์ชันลบ
        },
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showCreateActivityDialog,
      backgroundColor: Colors.green.shade700,
      icon: Icon(Icons.add, color: Colors.white),
      label: Text(
        'สร้างกิจกรรม',
        style: TextStyle(color: Colors.white),
      ),
      elevation: 5,
      tooltip: 'เพิ่มกิจกรรมใหม่',
    );
  }

  // Dialog untuk Filter
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Activities'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Type
                  Text('Select Type:'),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    items: [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(
                          value: 'Personal', child: Text('Personal')),
                      DropdownMenuItem(value: 'Group', child: Text('Group')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value ?? 'All';
                      });
                    },
                  ),

                  // New Status Filter
                  Text('Select Status:'),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    items: [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(
                          value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'In Progress', child: Text('In Progress')),
                      DropdownMenuItem(
                          value: 'Completed', child: Text('Completed')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value ?? 'All';
                      });
                    },
                  ),
                  SizedBox(height: 10),

                  // กรอง Sort By
                  Text('Sort By:'),
                  DropdownButton<String>(
                    value: _sortBy,
                    items: [
                      DropdownMenuItem(
                          value: 'Nearest Date', child: Text('Nearest Date')),
                      DropdownMenuItem(
                          value: 'Created At', child: Text('Created At')),
                      DropdownMenuItem(value: 'Oldest', child: Text('Oldest')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value ?? 'Nearest Date';
                      });
                    },
                  ),
                  SizedBox(height: 10),

                  // เลือกลำดับ
                  Row(
                    children: [
                      Text('Ascending'),
                      Switch(
                        value: _isAscending,
                        onChanged: (value) {
                          setState(() {
                            _isAscending = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    this.setState(() {
                      _filteredActivities = _filterActivities();
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void safeNavigate(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
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
      initialSelectedTab: "Home", // เปลี่ยนตาม page ที่กำลังแสดงอยู่
      tabIconColor: const Color(0xFF0C5217),
      tabSelectedColor: Colors.green,
      onTabItemSelected: (int index) {
        setState(() {
          _currentIndex = index;
        });

        switch (index) {
          case 0: // Home
            break;

          case 1: // Account
            if (!(this is AccountPage)) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountPage(
                    initialUsername: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
            }
            break;

          case 2: // Notes
            if (!(this is NotePage)) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => NotePage(
                    username: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
            }
            break;

          case 3: // Calendar
            if (!(this is CalendarPage)) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarPage(
                    username: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
            }
            break;

          case 4: // Groups
            if (!(this is GroupPage)) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupPage(
                    username: widget.username,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
            }
            break;
        }
      },
    );
  }
}
