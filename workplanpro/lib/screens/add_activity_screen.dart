import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';

class AddActivityScreen extends StatefulWidget {
  final Activity? activityToEdit;

  AddActivityScreen({this.activityToEdit});

  @override
  _AddActivityScreenState createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.activityToEdit?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.activityToEdit?.description ?? '');
    _selectedDate = widget.activityToEdit?.date ?? DateTime.now();
    _startTime = widget.activityToEdit?.startTime ?? TimeOfDay.now();
    _endTime = widget.activityToEdit?.endTime ??
        TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0C5217),
        title: Text(
            widget.activityToEdit == null ? 'New Activity' : 'Edit Activity',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => _showDiscardChangesDialog(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF0C5217), width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF0C5217), width: 2),
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 24),
            Text(
              'Date and Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('EEE, MMM d, yyyy').format(_selectedDate)),
                    Icon(Icons.calendar_today, color: Color(0xFF0C5217)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, isStartTime: true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(_startTime.format(context)),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, isStartTime: false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(_endTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),
            Row(
              children: [
                if (widget.activityToEdit != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showDeleteConfirmationDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                if (widget.activityToEdit != null) SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showSaveConfirmationDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0C5217),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.activityToEdit == null ? 'Save' : 'Update',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
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

  Future<void> _selectTime(BuildContext context,
      {required bool isStartTime}) async {
    final TimeOfDay initialTime = isStartTime ? _startTime : _endTime;

    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      if (isStartTime) {
        setState(() {
          _startTime = picked;
          _endTime = TimeOfDay(
            hour: picked.hour + 1 >= 24 ? 23 : picked.hour + 1,
            minute: picked.minute,
          );
        });
      } else {
        bool isValid = false;

        if (_startTime.period != picked.period) {
          isValid = picked.period == DayPeriod.pm &&
              _startTime.period == DayPeriod.am;
        } else {
          isValid = _timeToDouble(picked) > _timeToDouble(_startTime);
        }

        if (!isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('End time must be after start time'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _endTime = picked;
        });
      }
    }
  }

  double _timeToDouble(TimeOfDay time) {
    double hour = time.hour.toDouble();
    if (time.period == DayPeriod.pm && time.hour != 12) {
      hour += 12;
    }
    if (time.period == DayPeriod.am && time.hour == 12) {
      hour = 0;
    }
    return hour + time.minute / 60.0;
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
          title: Text('Delete Activity?'),
          content: Text(
              'Are you sure you want to delete this activity? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteActivity();
              },
            ),
          ],
        );
      },
    );
  }

  void _saveActivity() {
    Activity activity = Activity(
      title: _titleController.text,
      description: _descriptionController.text,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
    );
    Navigator.of(context).pop(activity);
  }

  void _deleteActivity() {
    Navigator.of(context).pop('delete');
  }
}
