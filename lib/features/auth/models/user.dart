/// Модель пользователя
class User {
  final int id;
  final String username;
  final String name;
  final String role;
  final String? token;

  User({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      name: json['name'] as String? ?? json['username'] as String,
      role: json['role'] as String? ?? 'cashier',
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
      'token': token,
    };
  }
}
