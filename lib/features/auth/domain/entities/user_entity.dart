import '../../../../core/constants/user_role.dart';

class UserEntity {
  final String id;
  final String username;
  final String email;
  final String? sessionToken;
  final UserRole role;

  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    this.sessionToken,
    this.role = UserRole.maker,
  });

  UserEntity copyWith({
    String? id,
    String? username,
    String? email,
    String? sessionToken,
    UserRole? role,
  }) {
    return UserEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      sessionToken: sessionToken ?? this.sessionToken,
      role: role ?? this.role,
    );
  }
}