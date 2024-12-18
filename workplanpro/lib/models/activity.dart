import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workplanpro/screens/activity_service.dart';

enum SortType { nearestDate, newest, oldest }

enum ActivityType { Personal, Group }

class Activity {
  late final String? id;
  final String title;
  final String? groupId;
  final String? groupName;
  final bool isGroupActivity;
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
    this.groupName,
    this.groupId,
    this.isGroupActivity = false,
    String? userId,
  }) : userId = userId ?? FirebaseAuth.instance.currentUser?.uid;

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'type': type,
      'status': status,
      'userId': userId,
      'groupId': groupId,
      'priority': priority,
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
  factory Activity.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Activity(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: _parseTimeOfDay(data['startTime']),
      endTime: _parseTimeOfDay(data['endTime']),
      type: data['type'] ?? (data['groupId'] != null ? 'Group' : 'Personal'),
      status: data['status'] ?? 'Pending',
      userId: data['userId'],
      groupId: data['groupId'],
      isGroupActivity: data['isGroupActivity'] ?? (data['groupId'] != null),
      priority: data['priority'] ?? 'Low',
    );
  }
// Method สำหรับแปลง Map เป็น Activity (เดิม)
  static Activity fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      date: map['date'],
      startTime: map['startTime'],
      endTime: map['endTime'],
      type: map['type'] ?? 'Personal',
      status: map['status'] ?? 'Pending',
      userId: map['userId'],
      groupId: map['groupId'],
      priority: map['priority'] ?? 'Low',
    );
  }

  // Helper method to parse TimeOfDay
  static TimeOfDay _parseTimeOfDay(dynamic timeData) {
    if (timeData == null) return TimeOfDay.now();

    // ถ้า timeData เป็น Map
    if (timeData is Map) {
      return TimeOfDay(
        hour: timeData['hour'] ?? 0,
        minute: timeData['minute'] ?? 0,
      );
    }

    // ถ้า timeData เป็น String
    if (timeData is String) {
      final parts = timeData.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return TimeOfDay.now();
  }

  // Copy method for immutability
  Activity copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? type,
    String? status,
    String? userId,
    String? groupId,
    String? priority,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      priority: priority ?? this.priority,
    );
  }

  bool isValidActivity() {
    return _validateBasicFields() &&
        _validateTimeConstraints() &&
        _validateOwnership();
  }

  bool _validateOwnership() {
    // ตรวจสอบว่ามี userId และตรงกับผู้ใช้ปัจจุบัน
    return userId != null && userId == FirebaseAuth.instance.currentUser?.uid;
  }

  // Validation method
  bool validate() {
    return title.isNotEmpty &&
        description.isNotEmpty &&
        date != null &&
        startTime != null &&
        endTime != null;
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
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
      'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
      'type': type,
      'status': status,
      'userId': userId,
      'groupId': groupId,
      'priority': priority,
    };
  }
}
