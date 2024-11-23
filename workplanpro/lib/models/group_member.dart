import 'package:cloud_firestore/cloud_firestore.dart';


class GroupMember {
  final String id;
  final String username; 
  final String role;
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    required this.username,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      role: map['role'] ?? 'member',
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}