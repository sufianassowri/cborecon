import '../../../../core/constants/user_role.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> signUp({
    required String username,
    required String email,
    required String password,
    UserRole role = UserRole.maker,
  });

  Future<UserEntity> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<UserEntity?> getCurrentUser();

  Future<List<UserEntity>> getAllUsers();

  Future<bool> updateUserRole({
    required String username,
    required UserRole newRole,
  });
}