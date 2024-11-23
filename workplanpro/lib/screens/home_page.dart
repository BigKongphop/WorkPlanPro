import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'note_page.dart';
import 'account_page.dart';
import 'calendar_page.dart';
import 'group_page.dart';

class ActivityModel {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String type;
  final String priority;

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    this.priority = 'Normal',
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      type: data['type'] ?? 'Personal',
      priority: data['priority'] ?? 'Normal',
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

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // State Variables
  List<ActivityModel> _activities = [];
  List<ActivityModel> _filteredActivities = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _currentIndex = 0;
  bool _hasInternetConnection = true;
  bool _isDisposed = false;
  // Controllers
  final TextEditingController _searchController = TextEditingController();
// Connectivity
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupConnectivityListener();
    _loadCachedActivities();
    _fetchActivities();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (!_isDisposed) {
        final result = results.first;
        setState(() {
          _hasInternetConnection = result != ConnectivityResult.none;
        });

        if (_hasInternetConnection) {
          _fetchActivities();
        }
      }
    });
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
                    priority: activity['priority'],
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
                'priority': activity.priority,
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
        throw Exception('User not authenticated');
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

        // Cache activities after successful fetch
        await _cacheActivities();
      }
    } catch (e) {
      _handleError(e);
      // Fallback to cached activities if fetch fails
      await _loadCachedActivities();
    }
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
    WidgetsBinding.instance.removeObserver(this);
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

      // หลังจากสร้างเสร็จให้โหลดข้อมูลใหม่
      _fetchActivities();
    } catch (e) {
      print('Error creating sample activity: $e');
    }
  }

  List<ActivityModel> _filterActivities() {
    return _activities.where((activity) {
      bool matchesCategory =
          _selectedCategory == 'All' || activity.type == _selectedCategory;
      bool matchesSearch = _searchQuery.isEmpty ||
          activity.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
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
                Row(
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
                )
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
    String selectedType = activity.type;
    String selectedPriority = activity.priority;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              DropdownButton<String>(
                value: selectedType,
                items: ['Personal', 'Group', 'Work']
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
              DropdownButton<String>(
                value: selectedPriority,
                items: ['Normal', 'Medium', 'High']
                    .map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPriority = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _updateActivity(
                  activity.id,
                  titleController.text,
                  descriptionController.text,
                  selectedType,
                  selectedPriority,
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
      String type, String priority) async {
    try {
      await FirebaseFirestore.instance.collection('activities').doc(id).update({
        'title': title,
        'description': description,
        'type': type,
        'priority': priority,
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
      _fetchActivities();
    } catch (e) {
      print('Error deleting activity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showCreateActivityDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search activities...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filteredActivities = _filterActivities();
                });
              },
            ),
          ),

          // Category Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Personal', 'Group', 'Work']
                  .map((category) => _buildCategoryChip(category))
                  .toList(),
            ),
          ),

          // Activity List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredActivities.isEmpty
                    ? Center(child: Text('No activities found'))
                    : ListView.builder(
                        itemCount: _filteredActivities.length,
                        itemBuilder: (context, index) {
                          return _buildActivityCard(_filteredActivities[index]);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  void _showCreateActivityDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedType = 'Personal';
    String selectedPriority = 'Normal';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create New Activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              DropdownButton<String>(
                value: selectedType,
                items: ['Personal', 'Group', 'Work']
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
              DropdownButton<String>(
                value: selectedPriority,
                items: ['Normal', 'Medium', 'High']
                    .map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPriority = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _createActivity(
                  titleController.text,
                  descriptionController.text,
                  selectedType,
                  selectedPriority,
                );
                Navigator.of(context).pop();
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
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
      });

      // Reload activities after adding
      await _fetchActivities();
    } catch (e) {
      print('Error creating activity: $e');
      _handleError(e);
    }
  }

  // Widget untuk Menampilkan Chip Kategori
  Widget _buildCategoryChip(String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(category),
        selected: _selectedCategory == category,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : 'All';
            _filteredActivities = _filterActivities();
          });
        },
      ),
    );
  }

  // Dialog untuk Filter
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter Activities'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add more filter options as needed
              Text('Select category:'),
              // Example of category selection
              DropdownButton<String>(
                value: _selectedCategory,
                items:
                    ['All', 'Personal', 'Group', 'Work'].map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                    _filteredActivities = _filterActivities();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
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
