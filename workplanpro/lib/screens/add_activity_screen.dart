//add_activity_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';

class AddActivityScreen extends StatefulWidget {
  final Activity? activityToEdit;
  final Function(Activity)? onActivitySaved;

  const AddActivityScreen({Key? key, this.activityToEdit, this.onActivitySaved})
      : super(key: key);

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
  String _selectedType = 'Personal';
  String _selectedPriority = 'Low';
  String _selectedStatus = 'Pending';

  // Animation Controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _titleController =
        TextEditingController(text: widget.activityToEdit?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.activityToEdit?.description ?? '');
    _selectedDate = widget.activityToEdit?.date ?? DateTime.now();
    _startTime = widget.activityToEdit?.startTime ?? TimeOfDay.now();
    _endTime = widget.activityToEdit?.endTime ??
        TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
    // Setup Animation Controller
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this, // 'this' now correctly refers to TickerProvider
    );

    // Create animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animationController, curve: Curves.easeOutQuad));

    // Start the animation
    _animationController.forward();
  }

  void _deleteActivity() {
    if (widget.activityToEdit != null) {
      // ถ้ามีกิจกรรมที่กำลังแก้ไข ให้ส่งค่า 'delete' กลับ
      Navigator.of(context).pop('delete');
    } else {
      // หากไม่มีกิจกรรมเดิม ให้แสดงข้อความแจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่มีกิจกรรมที่สามารถลบได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _validateTime() {
    // ตรวจสอบว่าเวลาเริ่มต้นน้อยกว่าเวลาสิ้นสุด
    return _timeToDouble(_startTime) < _timeToDouble(_endTime);
  }

  void _initializeControllers() {
    // Initialize text controllers
    _titleController =
        TextEditingController(text: widget.activityToEdit?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.activityToEdit?.description ?? '');

    // Initialize date and time
    _selectedDate = widget.activityToEdit?.date ?? DateTime.now();
    _startTime = widget.activityToEdit?.startTime ?? TimeOfDay.now();
    _endTime = widget.activityToEdit?.endTime ??
        TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);

    // Initialize other fields
    _selectedType = widget.activityToEdit?.type ?? 'Personal';
    _selectedPriority = widget.activityToEdit?.priority ?? 'Low';
    _selectedStatus = widget.activityToEdit?.status ?? 'Pending';
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
        _buildPriorityDropdown(),
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
      child: DropdownButtonFormField<String>(
        value: _selectedType,
        decoration: InputDecoration(
          labelText: 'Activity Type',
          prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF0C5217)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
        ),
        dropdownColor: Colors.white,
        style: TextStyle(color: Color(0xFF0C5217), fontWeight: FontWeight.w600),
        items: ['Personal', 'Group']
            .map((type) => DropdownMenuItem(
                value: type,
                child:
                    Text(type, style: TextStyle(color: Colors.green.shade800))))
            .toList(),
        onChanged: (value) {
          setState(() => _selectedType = value!);
        },
        icon: Icon(
          Icons.arrow_drop_down_circle_outlined,
          color: Color(0xFF0C5217),
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedPriority,
      decoration: InputDecoration(
        labelText: 'Priority',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: ['Low', 'Medium', 'High']
          .map((priority) =>
              DropdownMenuItem(value: priority, child: Text(priority)))
          .toList(),
      onChanged: (value) {
        setState(() => _selectedPriority = value!);
      },
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
        child: Text(time.format(context)),
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
          ]),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now(),
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
          if (pickedDate != null) {
            setState(() => _selectedDate = pickedDate);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date',
            labelStyle: TextStyle(color: Color(0xFF0C5217).withOpacity(0.7)),
            prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF0C5217)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none),
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
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
                content: Text('เวลาสิ้นสุดต้องหลังเวลาเริ่มต้น'),
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

  void _showSaveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget.activityToEdit == null
              ? 'Save Activity?'
              : 'Update Activity?'),
          content: Text(
              'Are you sure you want to ${widget.activityToEdit == null ? 'save' : 'update'} this activity?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                _saveActivity();
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
          title: Text('ลบกิจกรรม?'),
          content: Text(
              'คุณแน่ใจหรือไม่ว่าต้องการลบกิจกรรมนี้? การดำเนินการนี้ไม่สามารถยกเลิกได้'),
          actions: <Widget>[
            TextButton(
              child: Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('ลบ'),
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

  void _saveActivity() {
    // ตรวจสอบความถูกต้องของข้อมูล
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณากรอกชื่อกิจกรรม'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ตรวจสอบเวลาอย่างละเอียด
    if (!_validateTimeRange()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เวลาสิ้นสุดต้องหลังเวลาเริ่มต้น'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final activity = Activity(
      title: _titleController.text,
      description: _descriptionController.text,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      type: _selectedType,
      priority: _selectedPriority,
      status: _selectedStatus,
    );

    // ส่งกลับข้อมูลกิจกรรม
    Navigator.of(context).pop(activity);
  }
}
