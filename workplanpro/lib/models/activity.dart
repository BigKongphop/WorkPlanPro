import 'package:flutter/material.dart';

class Activity {
  String? id;  // เพิ่ม id field
  String title;
  String description;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;

  Activity({
    this.id,  // เพิ่ม id ในคอนสตรัคเตอร์
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  factory Activity.fromMap(Map<String, dynamic> map, {String? id}) {  // เพิ่ม id parameter
    return Activity(
      id: id,  // ใส่ id
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: DateTime.parse(map['date']),
      startTime: TimeOfDay(
        hour: map['startTimeHour'] ?? 0,
        minute: map['startTimeMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: map['endTimeHour'] ?? 0,
        minute: map['endTimeMinute'] ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startTimeHour': startTime.hour,
      'startTimeMinute': startTime.minute,
      'endTimeHour': endTime.hour,
      'endTimeMinute': endTime.minute,
    };
  }
}