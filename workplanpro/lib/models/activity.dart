import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum SortType { nearestDate, newest, oldest }

class Activity {
  String? id;
  String title;
  String description;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  String type;
  String status;
  String priority;
  String? userId;

  Activity(
      {this.id,
      required this.title,
      required this.description,
      required this.date,
      required this.startTime,
      required this.endTime,
      this.type = 'Personal',
      this.status = 'Pending',
      this.priority = 'Low',
      this.userId});

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

  // Create from Firestore Map
  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
        id: map['id'] ?? map['docId'],
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        date: map['date'] is Timestamp
            ? (map['date'] as Timestamp).toDate()
            : DateTime.parse(map['date']),
        startTime: _parseTimeOfDay(map['startTime']),
        endTime: _parseTimeOfDay(map['endTime']),
        type: map['type'] ?? 'Personal',
        status: map['status'] ?? 'Pending',
        priority: map['priority'] ?? 'Low',
        userId: map['userId']);
  }

  // Helper method to parse TimeOfDay
  static TimeOfDay _parseTimeOfDay(dynamic timeData) {
    if (timeData == null) return TimeOfDay.now();

    if (timeData is Map) {
      return TimeOfDay(
          hour: timeData['hour'] ?? 0, minute: timeData['minute'] ?? 0);
    }

    return TimeOfDay.now();
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
    return title.isNotEmpty &&
        description.isNotEmpty &&
        date != null &&
        startTime != null &&
        endTime != null;
  }
}
