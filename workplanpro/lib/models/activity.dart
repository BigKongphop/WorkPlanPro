import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workplanpro/screens/activity_service.dart';

enum SortType { nearestDate, newest, oldest }

class Activity {
  final String? id;
  final String title;
  String description;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  String type;
  String status;
  String priority;
  String? userId;

  Activity({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.type = 'Personal',
    this.status = 'Pending',
    this.priority = 'Low',
    String? userId,
  }) : userId = userId ?? FirebaseAuth.instance.currentUser?.uid;

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
      'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
      'type': type,
      'status': status,
      'priority': priority,
      'userId': userId
    };
  }

  static DateTime _parseDate(dynamic dateData) {
    try {
      // กรณี Timestamp จาก Firestore
      if (dateData is Timestamp) {
        return dateData.toDate();
      }

      // กรณี String ISO8601
      if (dateData is String) {
        return DateTime.parse(dateData);
      }

      // กรณี Map (สำหรับบางรูปแบบข้อมูล)
      if (dateData is Map) {
        // ตรวจสอบว่ามี seconds หรือ nanoseconds หรือไม่
        if (dateData.containsKey('seconds')) {
          return DateTime.fromMillisecondsSinceEpoch(
              (dateData['seconds'] * 1000).toInt());
        }
      }

      // กรณี int (timestamp)
      if (dateData is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateData);
      }

      // หากไม่ตรงเงื่อนไขใดๆ ให้ใช้วันปัจจุบัน
      print('Unsupported date format: $dateData');
      return DateTime.now();
    } catch (e) {
      // จัดการข้อผิดพลาดในการแปลง
      print('Error parsing date: $e, Original data: $dateData');
      return DateTime.now();
    }
  }

  static dynamic _safeConvert(dynamic value, dynamic defaultValue) {
    return value ?? defaultValue;
  }

  // Create from Firestore Map
  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
        id: _safeConvert(map['id'], map['docId']),
        title: _safeConvert(map['title'], ''),
        description: _safeConvert(map['description'], ''),
        date: _parseDate(_safeConvert(map['date'], DateTime.now())),
        startTime: _parseTimeOfDay(_safeConvert(map['startTime'], null)),
        endTime: _parseTimeOfDay(_safeConvert(map['endTime'], null)),
        type: _safeConvert(map['type'], 'Personal'),
        status: _safeConvert(map['status'], 'Pending'),
        priority: _safeConvert(map['priority'], 'Low'),
        userId: map['userId']);
  }

  // Helper method to parse TimeOfDay
  static TimeOfDay _parseTimeOfDay(dynamic timeData) {
    try {
      if (timeData == null) return TimeOfDay.now();

      if (timeData is Map) {
        return TimeOfDay(
            hour: _safeConvert(timeData['hour'], 0),
            minute: _safeConvert(timeData['minute'], 0));
      }

      if (timeData is String) {
        // กรณีเป็น String เช่น "14:30"
        List<String> parts = timeData.split(':');
        if (parts.length == 2) {
          return TimeOfDay(
              hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }

      return TimeOfDay.now();
    } catch (e) {
      print('Error parsing TimeOfDay: $e');
      return TimeOfDay.now();
    }
  }

  // Copy method for immutability
  Activity copyWith(
      {String? id,
      String? title,
      String? description,
      DateTime? date,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      String? type,
      String? status,
      String? priority,
      String? userId}) {
    return Activity(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        type: type ?? this.type,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        userId: userId ?? this.userId);
  }

  // Validation method
  bool validate() {
    return _validateBasicFields() && _validateTimeConstraints();
  }

  bool _validateBasicFields() {
    return title.trim().isNotEmpty &&
        description.trim().isNotEmpty &&
        date != null;
  }

  bool _validateTimeConstraints() {
    return startTime != null &&
        endTime != null &&
        _isValidTimeRange() &&
        date.isAfter(DateTime.now().subtract(Duration(days: 1)));
  }

  bool _isValidTimeRange() {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes > startMinutes;
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'date': Timestamp.fromDate(date),
      'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
      'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
      'type': type,
      'status': status,
      'priority': priority,
      'userId': userId
    };
  }
}
