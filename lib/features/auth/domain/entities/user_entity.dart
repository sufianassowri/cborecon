class UserEntity {
  final String id;
  final String username;
  final String email;
  final String? sessionToken;

  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    this.sessionToken,
  });
}