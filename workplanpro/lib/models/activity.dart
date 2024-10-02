import 'package:flutter/material.dart';

class Activity {
  String title;
  String description;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;

  Activity({
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      title: map['title'],
      description: map['description'],
      date: DateTime.parse(map['date']),
      startTime: TimeOfDay(hour: map['startTimeHour'], minute: map['startTimeMinute']),
      endTime: TimeOfDay(hour: map['endTimeHour'], minute: map['endTimeMinute']),
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