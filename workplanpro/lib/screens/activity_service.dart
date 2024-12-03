import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workplanpro/screens/home_page.dart';
import '../models/activity.dart';

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
// Sorting Activities
  List<Activity> sortActivities(List<Activity> activities, SortType sortType) {
    switch (sortType) {
      case SortType.nearestDate:
        return activities
          ..sort((a, b) => a.date
              .difference(DateTime.now())
              .abs()
              .compareTo(b.date.difference(DateTime.now()).abs()));
      case SortType.newest:
        return activities..sort((a, b) => b.date.compareTo(a.date));
      case SortType.oldest:
        return activities..sort((a, b) => a.date.compareTo(b.date));
    }
  }

  // Fetch Activities with Advanced Filtering
  Future<List<Activity>> fetchActivities({String? userId}) async {
    try {
      userId ??= FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) throw Exception('ผู้ใช้ยังไม่ได้เข้าสู่ระบบ');

      final querySnapshot = await _firestore
          .collection('activities')
          .where('userId', isEqualTo: userId)
          .orderBy(
              'date') // เปลี่ยนให้เรียงตามวันเพื่อให้แสดงใน Calendar ได้ง่ายขึ้น
          .get();

      return querySnapshot.docs
          .map((doc) => Activity.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Activity Fetch Error: $e');
      return []; // คืนค่ากลับเป็นลิสต์ว่างแทนการแสดงผลผิดพลาด
    }
  }

  // Sorting Activities
  List<Activity> _sortActivities(List<Activity> activities, SortType sortType) {
    final now = DateTime.now();

    switch (sortType) {
      case SortType.nearestDate:
        return activities
          ..sort((a, b) => a.date
              .difference(now)
              .abs()
              .compareTo(b.date.difference(now).abs()));

      case SortType.newest:
        return activities..sort((a, b) => b.date.compareTo(a.date));

      case SortType.oldest:
        return activities..sort((a, b) => a.date.compareTo(b.date));
    }
  }

  // Create Activity
  Future<Activity> createActivity(Activity activity) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('ผู้ใช้ยังไม่ได้เข้าสู่ระบบ');

      // ตรวจสอบความถูกต้องของข้อมูล
      if (!_validateActivity(activity)) {
        throw Exception('ข้อมูลกิจกรรมไม่ถูกต้อง');
      }

      // เตรียมข้อมูลสำหรับบันทึก
      final activityData = {
        'userId': user.uid,
        'title': activity.title,
        'description': activity.description,
        'date': Timestamp.fromDate(activity.date),
        'startTime': {
          'hour': activity.startTime.hour,
          'minute': activity.startTime.minute
        },
        'endTime': {
          'hour': activity.endTime.hour,
          'minute': activity.endTime.minute
        },
        'type': activity.type,
        'status': activity.status,
        'priority': activity.priority,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // บันทึกลง Firestore
      final docRef =
          await _firestore.collection('activities').add(activityData);

      // คืนค่า Activity พร้อม ID
      return activity.copyWith(id: docRef.id);
    } catch (e) {
      print('เกิดข้อผิดพลาดในการสร้างกิจกรรม: $e');
      rethrow;
    }
  }

  bool _validateActivity(Activity activity) {
    return activity.title.isNotEmpty &&
        activity.description.isNotEmpty &&
        activity.date != null &&
        activity.startTime != null &&
        activity.endTime != null;
  }

  // Update Activity
  Future<void> updateActivity(Activity activity) async {
    try {
      if (activity.id == null) throw Exception('Activity ID is required');

      // Validate activity before updating
      if (!activity.validate()) {
        throw Exception('Invalid activity data');
      }

      await _firestore
          .collection('activities')
          .doc(activity.id)
          .update(activity.toMap());
    } catch (e) {
      print('Update Activity Error: $e');
      rethrow;
    }
  }

  // Delete Activity
  Future<void> deleteActivity(String activityId) async {
    try {
      await _firestore.collection('activities').doc(activityId).delete();
    } catch (e) {
      print('Delete Activity Error: $e');
      rethrow;
    }
  }

  // Advanced Filtering Method
  List<Activity> filterActivities(
    List<Activity> activities, {
    String? searchQuery,
    String? type,
    String? status,
    SortType sortType = SortType.nearestDate,
  }) {
    var filteredActivities = activities.where((activity) {
      bool matchesSearch = searchQuery == null ||
          activity.title.toLowerCase().contains(searchQuery.toLowerCase());
      bool matchesType = type == null || activity.type == type;
      bool matchesStatus = status == null || activity.status == status;

      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    // Sorting
    filteredActivities.sort((a, b) {
      switch (sortType) {
        case SortType.nearestDate:
          return a.date
              .difference(DateTime.now())
              .abs()
              .compareTo(b.date.difference(DateTime.now()).abs());
        case SortType.newest:
          return b.date.compareTo(a.date);
        case SortType.oldest:
          return a.date.compareTo(b.date);
        default:
          return 0; // เพิ่มกรณีที่ไม่รู้จัก
      }
    });

    return filteredActivities;
  }
}
