import 'user.dart';

class Channel {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int maxUsers;
  final int createdBy;
  final DateTime createdAt;
  final int memberCount;
  final int? onlineUsers;

  Channel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.maxUsers,
    required this.createdBy,
    required this.createdAt,
    required this.memberCount,
    this.onlineUsers,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      maxUsers: json['max_users'] ?? 50,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      memberCount: json['member_count'] ?? 0,
      onlineUsers: json['online_users'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive,
      'max_users': maxUsers,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'member_count': memberCount,
      'online_users': onlineUsers,
    };
  }

  @override
  String toString() {
    return 'Channel{id: $id, name: $name, memberCount: $memberCount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class OnlineUser {
  final int id;
  final int userId;
  final int? channelId;
  final String socketId;
  final bool isSpeaking;
  final DateTime joinedAt;
  final DateTime lastActivity;
  final User? user;

  OnlineUser({
    required this.id,
    required this.userId,
    this.channelId,
    required this.socketId,
    required this.isSpeaking,
    required this.joinedAt,
    required this.lastActivity,
    this.user,
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) {
    return OnlineUser(
      id: json['id'],
      userId: json['user_id'],
      channelId: json['channel_id'],
      socketId: json['socket_id'],
      isSpeaking: json['is_speaking'] ?? false,
      joinedAt: DateTime.parse(json['joined_at']),
      lastActivity: DateTime.parse(json['last_activity']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'channel_id': channelId,
      'socket_id': socketId,
      'is_speaking': isSpeaking,
      'joined_at': joinedAt.toIso8601String(),
      'last_activity': lastActivity.toIso8601String(),
      'user': user?.toJson(),
    };
  }

  @override
  String toString() {
    return 'OnlineUser{userId: $userId, isSpeaking: $isSpeaking}';
  }
}
