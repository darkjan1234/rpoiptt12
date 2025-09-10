class User {
  final int id;
  final String username;
  final String? email;
  final bool isAdmin;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.username,
    this.email,
    required this.isAdmin,
    required this.isActive,
    required this.createdAt,
    this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isAdmin: json['is_admin'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_admin': isAdmin,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, email: $email}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
