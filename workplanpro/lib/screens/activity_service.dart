import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workplanpro/screens/home_page.dart';
import '../models/activity.dart';

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
}

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _logActivity(String action, Activity activity) async {
    await _firestore.collection('activity_logs').add({
      'userId': activity.userId,
      'activityId': activity.id,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'details': activity.toMap()
    });
  }

  Future<Activity> createOrUpdateActivity(Activity activity,
      {bool isUpdate = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthenticationException('User  must be authenticated');
      }

      activity = activity.copyWith(userId: user.uid);

      if (!_validateActivity(activity)) {
        throw ValidationException('Invalid activity details');
      }

      final activityData = activity.toFirestoreMap();

      if (isUpdate) {
        await _verifyActivityOwnership(activity.id!, user.uid);
        await _firestore
            .collection('activities')
            .doc(activity.id)
            .update(activityData);
        return activity;
      } else {
        final docRef =
            await _firestore.collection('activities').add(activityData);
        return activity.copyWith(id: docRef.id);
      }
    } catch (e) {
      print('Activity Service.createOrUpdateActivity: $e');
      rethrow;
    }
  }

  Future<void> _verifyActivityOwnership(
      String activityId, String userId) async {
    final doc = await _firestore.collection('activities').doc(activityId).get();
    if (doc.data()?['userId'] != userId) {
      throw AuthenticationException('Unauthorized activity modification');
    }
  }

  Future<void> safeDeleteActivity(String activityId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthenticationException('User not authenticated');
      }

      final activityDoc =
          await _firestore.collection('activities').doc(activityId).get();
      if (activityDoc.data()?['userId'] != user.uid) {
        throw AuthenticationException('Unauthorized deletion');
      }

      await _firestore.collection('activities').doc(activityId).delete();
    } catch (e) {
      print('Safe Delete Error: $e');
      rethrow;
    }
  }

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

  Future<List<Activity>> fetchActivities({String? userId}) async {
    try {
      userId ??= FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) throw AuthenticationException('No user logged in');

      final querySnapshot = await _firestore
          .collection('activities')
          .where('userId', isEqualTo: userId)
          .orderBy('date')
          .get();

      return querySnapshot.docs
          .map((doc) => Activity.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Fetch Activities Error: $e');
      return [];
    }
  }

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

  Future<Activity> createActivity(Activity activity) async {
    return handleActivityOperation(() async {
      if (!activity.validate()) {
        throw ValidationException('Invalid activity data');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw AuthenticationException('User not authenticated');

      final activityData = activity.toFirestoreMap();
      final docRef =
          await _firestore.collection('activities').add(activityData);

      return activity.copyWith(id: docRef.id);
    }, errorMessage: 'Failed to create activity');
  }

  Future<Activity> handleActivityOperation(
      Future<Activity> Function() operation,
      {String errorMessage = 'Operation failed'}) async {
    try {
      return await operation();
    } catch (e) {
      print('Activity Service Error: $e');
      throw Exception(errorMessage);
    }
  }

  bool _validateActivity(Activity activity) {
    return activity.title.isNotEmpty &&
        activity.description.isNotEmpty &&
        activity.date != null &&
        activity.startTime != null &&
        activity.endTime != null;
  }

  Future<void> updateActivity(Activity activity) async {
    try {
      if (activity.id == null) {
        throw Exception('Activity ID is required');
      }

      if (!activity.validate()) {
        throw ValidationException('Invalid activity data');
      }

      final activityData = {
        'title': activity.title,
        'description': activity.description,
        'date': Timestamp.fromDate(activity.date),
        'startTime': {
          'hour': activity.startTime.hour,
          'minute': activity.startTime.minute,
        },
        'endTime': {
          'hour': activity.endTime.hour,
          'minute': activity.endTime.minute,
        },
        'type': activity.type,
        'status': activity.status,
        'priority': activity.priority,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('activities')
          .doc(activity.id)
          .update(activityData);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteActivity(String activityId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _firestore.collection('activities').doc(activityId).delete();
    } catch (e) {
      print('Error deleting activity: $e');
      rethrow;
    }
  }

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
          return 0;
      }
    });

    return filteredActivities;
  }
}
