import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../screens/activity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String type;
  final String status;
  final String? groupId; // เพิ่มฟิลด์นี้

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    this.status = 'Pending',
    this.groupId, // เพิ่มฟิลด์นี้
  });

  // ฟังก์ชันสำหรับแปลง Activity เป็น ActivityModel
  factory ActivityModel.fromActivity(Activity activity) {
    return ActivityModel(
      id: activity.id ?? '', // ใช้ ID ที่เป็น null หรือให้เป็น ''
      title: activity.title,
      description: activity.description,
      date: activity.date,
      type: activity.type,
      status: activity.status,
      groupId: activity.groupId, // เพิ่มการดึง groupId
    );
  }
}

class AddActivityScreen extends StatefulWidget {
  final Activity? activityToEdit;
  final Function(Activity)? onActivitySaved;
  final String? groupId;
  final String? activityType;
  final ActivityType? initialType;
  final DateTime? initialDate;

  const AddActivityScreen({
    Key? key,
    this.activityToEdit,
    this.onActivitySaved,
    this.groupId,
    this.activityType,
    this.initialType = ActivityType.Personal,
    this.initialDate,
  }) : super(key: key);

  @override
  _AddActivityScreenState createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen>
    with SingleTickerProviderStateMixin {
  // เพิ่ม SingleTickerProviderStateMixin
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _selectedPriority = 'Low';
  String _selectedStatus = 'Pending';
  final activityService = ActivityService();
  late ActivityType _selectedType;
  // Animation Controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType!;

    // กำหนดวันที่เริ่มต้น
    if (widget.activityToEdit != null) {
      // ใช้วันที่ของกิจกรรมที่กำลังแก้ไขโดยตรง
      _selectedDate = widget.activityToEdit!.date;
      _startTime = widget.activityToEdit!.startTime;
      _endTime = widget.activityToEdit!.endTime;
    } else if (widget.initialDate != null) {
      // ถ้ามี initialDate ให้ใช้ initialDate
      _selectedDate = widget.initialDate!;
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay(
          hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
    } else {
      // ถ้าไม่มีทั้งสองอย่าง ใช้วันปัจจุบัน
      _selectedDate = DateTime.now();
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay(
          hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
    }

    // เพิ่มโค้ดนี้เพื่อให้แน่ใจว่าใช้วันที่จากกิจกรรมที่แก้ไข
    if (widget.activityToEdit != null) {
      _selectedDate = widget.activityToEdit!.date;
    }

    _initializeControllers();
    _titleController =
        TextEditingController(text: widget.activityToEdit?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.activityToEdit?.description ?? '');

    // Setup Animation Controller และส่วนอื่นๆ คงเดิม
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animationController, curve: Curves.easeOutQuad));

    _animationController.forward();
  }

  Activity _createActivity() {
    return Activity(
      id: widget.activityToEdit?.id,
      title: _titleController.text,
      description: _descriptionController.text,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      type: widget.groupId != null
          ? 'Group'
          : 'Personal', // ใช้ groupId เป็นเกณฑ์
      status: _selectedStatus,
      priority: _selectedPriority,
      groupId: widget.groupId, // ส่ง groupId
    );
  }

  void _deleteActivity() async {
    if (widget.activityToEdit == null || widget.activityToEdit!.id == null) {
      _showErrorSnackBar('No activity to delete');
      return;
    }

    try {
      final activityService = ActivityService();
      await activityService.safeDeleteActivity(widget.activityToEdit!.id!);

      // Consistent navigation and feedback
      Navigator.of(context)
          .pop({'action': 'delete', 'activityId': widget.activityToEdit!.id});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Activity deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Delete failed: $e');
    }
  }

  bool _validateTime() {
    // ตรวจสอบว่าเวลาเริ่มต้นน้อยกว่าเวลาสิ้นสุด
    return _timeToDouble(_startTime) < _timeToDouble(_endTime);
  }

  void _initializeControllers() {
    if (widget.activityToEdit != null) {
      // ใช้ค่าจากกิจกรรมที่กำลังแก้ไข
      _selectedDate = widget.activityToEdit!.date;
      _startTime = widget.activityToEdit!.startTime;
      _endTime = widget.activityToEdit!.endTime;
      _selectedPriority = widget.activityToEdit!.priority ?? 'Low';
      _selectedStatus = widget.activityToEdit!.status ?? 'Pending';
    } else {
      // ค่าเริ่มต้นสำหรับการสร้างกิจกรรมใหม่
      _selectedDate = widget.initialDate ?? DateTime.now();
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay(
          hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
      _selectedPriority = 'Low';
      _selectedStatus = 'Pending';
    }
  }

  @override
  void dispose() {
    // ปิด Controller เมื่อออกจากหน้าจอ
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  Widget _buildAnimatedContainer(Widget child) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, widget) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildEnhancedDropdown({
    required List<String> items,
    required String value,
    required String label,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.green.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade200.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 3),
            )
          ]),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Color(0xFF0C5217)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item,
                    style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600))))
            .toList(),
        onChanged: onChanged,
        dropdownColor: Colors.white,
        icon: Icon(
          Icons.arrow_drop_down_circle_outlined,
          color: Color(0xFF0C5217),
        ),
        // Custom Search Functionality
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => _buildSearchDialog(items, value, onChanged),
          );
        },
      ),
    );
  }

  Widget _buildSearchDialog(List<String> items, String currentValue,
      ValueChanged<String?> onChanged) {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredItems = items;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                filteredItems = items
                    .where((item) =>
                        item.toLowerCase().contains(value.toLowerCase()))
                    .toList();
              });
            },
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: filteredItems
                  .map((item) => ListTile(
                        title: Text(item),
                        onTap: () {
                          onChanged(item);
                          Navigator.of(context).pop();
                        },
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomTimePicker(bool isStartTime) async {
    await showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Container(
            height: 300,
            child: Column(
              children: [
                Expanded(
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(
                        hours: isStartTime ? _startTime.hour : _endTime.hour,
                        minutes:
                            isStartTime ? _startTime.minute : _endTime.minute),
                    onTimerDurationChanged: (Duration duration) {
                      setState(() {
                        if (isStartTime) {
                          _startTime = TimeOfDay(
                              hour: duration.inHours,
                              minute: duration.inMinutes % 60);
                        } else {
                          _endTime = TimeOfDay(
                              hour: duration.inHours,
                              minute: duration.inMinutes % 60);
                        }
                      });
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Select'),
                )
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: _buildResponsiveAppBar(),
          body: _buildResponsiveBody(constraints),
        );
      },
    );
  }

  AppBar _buildResponsiveAppBar() {
    return AppBar(
      title: Text(
        widget.activityToEdit == null ? 'Create New Activity' : 'Edit Activity',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: Color(0xFF0C5217),
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.save, color: Colors.white),
          onPressed: _saveActivity,
          tooltip: 'Save Activity',
        ),
        if (widget.activityToEdit != null)
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: _showDeleteConfirmationDialog,
            tooltip: 'Delete Activity',
          ),
      ],
    );
  }

  Widget _buildResponsiveBody(BoxConstraints constraints) {
    return SingleChildScrollView(
      child: Container(
        width: constraints.maxWidth,
        padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth > 600 ? 100 : 16, vertical: 16),
        child: _buildAnimatedContainer(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Existing form fields with responsive sizing
              _buildTextField(_titleController, 'Title', Icons.title),
              SizedBox(height: 16),
              _buildTextField(
                  _descriptionController, 'Description', Icons.description,
                  maxLines: 3),
              SizedBox(height: 16),
              _buildDateTimePickers(),
              SizedBox(height: 16),
              _buildDropdowns(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveActivity,
                child: Text('Save Activity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0C5217),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdowns() {
    return Column(
      children: [
        _buildTypeDropdown(),
        SizedBox(height: 16),
        SizedBox(height: 16),
        _buildStatusDropdown(),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.green.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade200.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 3),
            )
          ]),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      decoration: InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: ['Pending', 'In Progress', 'Completed']
          .map((status) => DropdownMenuItem(value: status, child: Text(status)))
          .toList(),
      onChanged: (value) {
        setState(() => _selectedStatus = value!);
      },
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.green.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade200.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 3),
            )
          ]),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: Color(0xFF0C5217), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Color(0xFF0C5217).withOpacity(0.7)),
          prefixIcon: Icon(icon, color: Color(0xFF0C5217)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildDateTimePickers() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDatePicker(),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildTimePickers(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePickers() {
    return Row(
      children: [
        Expanded(
          child: _buildTimePicker(_startTime, 'Start Time', true),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildTimePicker(_endTime, 'End Time', false),
        ),
      ],
    );
  }

  Widget _buildTimePicker(TimeOfDay time, String label, bool isStartTime) {
    return InkWell(
      onTap: () => _selectTime(isStartTime),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          // ใช้ format 24 ชั่วโมง
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          final DateTime now = DateTime.now();
          final DateTime initialDate = _selectedDate.isBefore(now)
              ? now
              : _selectedDate; // Ensure initial date is not before today
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: now, // Set firstDate to now
            lastDate: DateTime(2101),
            builder: (context, child) {
              return Theme(
                data: ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Color(0xFF0C5217),
                    onPrimary: Colors.white,
                  ),
                  dialogBackgroundColor: Colors.white,
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setState(() => _selectedDate = picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date',
            labelStyle: TextStyle(color: Color(0xFF0C5217).withOpacity(0.7)),
            prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF0C5217)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
          child: Text(
            DateFormat('dd MMM yyyy').format(_selectedDate),
            style: TextStyle(
                color: Color(0xFF0C5217), fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _selectedDate.isBefore(now)
        ? now
        : _selectedDate; // ตรวจสอบให้แน่ใจว่า initialDate ไม่ก่อนวันนี้
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(), // หรือวันที่ที่คุณต้องการ
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay initialTime = isStartTime ? _startTime : _endTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
          // ปรับเวลาสิ้นสุดให้หลังเวลาเริ่มต้น
          if (_timeToDouble(picked) >= _timeToDouble(_endTime)) {
            _endTime =
                TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
          }
        } else {
          // ตรวจสอบว่าเวลาสิ้นสุดหลังเวลาเริ่มต้น
          if (_timeToDouble(picked) <= _timeToDouble(_startTime)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('The end time must be after the start time.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          _endTime = picked;
        }
      });
    }
  }

  bool _validateTimeRange() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes > startMinutes;
  }

  double _timeToDouble(TimeOfDay time) {
    return time.hour + time.minute / 60.0;
  }

  void _showDiscardChangesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Discard Changes?'),
          content: Text('Are you sure you want to discard your changes?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Discard'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete activity?'),
          content: Text(
              'Are you sure you want to delete this activity? This operation cannot be cancelled.'),
          actions: <Widget>[
            TextButton(
              child: Text('cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteActivity(); // เรียกใช้เมธอด _deleteActivity
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveActivity() async {
    if (_isSaving || !_validateInputs()) return;

    _isSaving = true;

    try {
      final activity = _prepareActivityData();

      if (widget.activityToEdit != null) {
        // UPDATE existing activity
        if (widget.groupId != null) {
          // ดึงชื่อกลุ่ม
          String groupName = '';
          try {
            final groupDoc = await FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .get();

            groupName = groupDoc.data()?['name'] ?? 'Unnamed Group';
          } catch (e) {
            print('Error fetching group name: $e');
            groupName = 'Unnamed Group';
          }

          final activityData = {
            ...activity.toFirestoreMap(),
            'groupId': widget.groupId,
            'groupName': groupName,
            'type': widget.groupId != null ? 'Group' : 'Personal',
            'isGroupActivity': widget.groupId != null,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // อัปเดตกิจกรรมในคอลเลคชัน activities
          await FirebaseFirestore.instance
              .collection('activities')
              .doc(widget.activityToEdit!.id)
              .update(activityData);

          // ถ้ามี groupId ให้อัปเดตใน group activities ด้วย
          if (widget.groupId != null) {
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('activities')
                .where('id', isEqualTo: widget.activityToEdit!.id)
                .get()
                .then((querySnapshot) {
              querySnapshot.docs.forEach((doc) {
                doc.reference.update(activityData);
              });
            });
          }
        } else {
          // อัปเดตกิจกรรมส่วนตัว
          await FirebaseFirestore.instance
              .collection('activities')
              .doc(widget.activityToEdit!.id)
              .update(activity.toFirestoreMap());
        }
      } else {
        // CREATE new activity
        if (widget.groupId != null) {
          // ดึงชื่อกลุ่ม
          String groupName = '';
          try {
            final groupDoc = await FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .get();

            groupName = groupDoc.data()?['name'] ?? 'Unnamed Group';
          } catch (e) {
            print('Error fetching group name: $e');
            groupName = 'Unnamed Group';
          }

          final activityData = {
            ...activity.toFirestoreMap(),
            'groupId': widget.groupId,
            'groupName': groupName,
            'type': widget.groupId != null ? 'Group' : 'Personal',
            'isGroupActivity': widget.groupId != null,
            'createdAt': FieldValue.serverTimestamp(),
          };

          // สร้างกิจกรรมเพียงครั้งเดียวใน activities
          final docRef = await FirebaseFirestore.instance
              .collection('activities')
              .add(activityData);

          // เพิ่มกิจกรรมใน group activities หากมี groupId
          if (widget.groupId != null) {
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('activities')
                .doc(docRef.id)
                .set(activityData);
          }
        } else {
          // Create personal activity
          await FirebaseFirestore.instance
              .collection('activities')
              .add(activity.toFirestoreMap());
        }
      }

      await _showSaveConfirmationDialog();
      Navigator.of(context).pop();
    } catch (error) {
      print('Error saving activity: $error');
      _isSaving = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save activity: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSaveConfirmationDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Activity Saved'),
          content: Text('Your activity has been saved.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<Activity> _performActivityOperation(
      ActivityService service, Activity activity, bool isUpdate) async {
    try {
      return await service.createOrUpdateActivity(activity, isUpdate: isUpdate);
    } catch (e) {
      // Rethrow with more context
      throw Exception('Failed to ${isUpdate ? 'update' : 'create'} activity');
    }
  }

  void _editActivity(Activity activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(activityToEdit: activity),
      ),
    );

    if (result is Map) {
      // Update activity logic
    }
  }

  bool _validateInputs() {
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a title');
      return false;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a description');
      return false;
    }

    if (!_validateTimeRange()) {
      _showErrorSnackBar('End time must be after start time');
      return false;
    }

    return true;
  }

  Activity _prepareActivityData() {
    return Activity(
      id: widget.activityToEdit?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      status: _selectedStatus,
      priority: _selectedPriority,
    );
  }

  void _handleSuccessfulSave(String action, Activity savedActivity) {
    // เรียก callback หากมี
    widget.onActivitySaved?.call(savedActivity);

    Navigator.of(context).pop({'action': action, 'activity': savedActivity});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Activity ${action}d successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
