
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> signUp({
    required String username,
    required String email,
    required String password,
  });

  Future<UserEntity> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<UserEntity?> getCurrentUser();
}