import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/activity.dart';

class ActivityDatabase {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ดึงข้อมูลกิจกรรมของ user
  Future<List<Activity>> loadActivities(String username) async {
    try {
      final snapshot = await _firestore
          .collection('activities')
          .where('username', isEqualTo: username)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        return Activity(
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          date: DateTime.parse(data['date']),
          startTime: TimeOfDay(
            hour: data['startTimeHour'] ?? 0,
            minute: data['startTimeMinute'] ?? 0,
          ),
          endTime: TimeOfDay(
            hour: data['endTimeHour'] ?? 0,
            minute: data['endTimeMinute'] ?? 0,
          ),
        );
      }).toList();
    } catch (e) {
      print('Error loading activities: $e');
      return [];
    }
  }

  // บันทึกกิจกรรมใหม่
  Future<void> saveActivity(String username, Activity activity) async {
    try {
      await _firestore.collection('activities').add({
        'username': username,
        'title': activity.title,
        'description': activity.description,
        'date': activity.date.toIso8601String(),
        'startTimeHour': activity.startTime.hour,
        'startTimeMinute': activity.startTime.minute,
        'endTimeHour': activity.endTime.hour,
        'endTimeMinute': activity.endTime.minute,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving activity: $e');
      throw e;
    }
  }

  // อัพเดทกิจกรรม
  Future<void> updateActivity(String docId, Activity activity) async {
    try {
      await _firestore.collection('activities').doc(docId).update({
        'title': activity.title,
        'description': activity.description,
        'date': activity.date.toIso8601String(),
        'startTimeHour': activity.startTime.hour,
        'startTimeMinute': activity.startTime.minute,
        'endTimeHour': activity.endTime.hour,
        'endTimeMinute': activity.endTime.minute,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating activity: $e');
      throw e;
    }
  }

  // ลบกิจกรรม
  Future<void> deleteActivity(String docId) async {
    try {
      await _firestore.collection('activities').doc(docId).delete();
    } catch (e) {
      print('Error deleting activity: $e');
      throw e;
    }
  }
}
