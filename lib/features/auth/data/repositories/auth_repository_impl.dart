import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<UserEntity> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final parseUser = await remoteDataSource.signUp(username, email, password);
    return UserEntity(
      id: parseUser.objectId!,
      username: parseUser.username!,
      email: parseUser.emailAddress ?? '',
      sessionToken: parseUser.sessionToken,
    );
  }

  @override
  Future<UserEntity> login({
    required String username,
    required String password,
  }) async {
    final parseUser = await remoteDataSource.login(username, password);
    return UserEntity(
      id: parseUser.objectId!,
      username: parseUser.username!,
      email: parseUser.emailAddress ?? '',
      sessionToken: parseUser.sessionToken,
    );
  }

  @override
  Future<void> logout() async {
    await remoteDataSource.logout();
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final parseUser = await remoteDataSource.getCurrentUser();
    if (parseUser == null) return null;
    return UserEntity(
      id: parseUser.objectId!,
      username: parseUser.username!,
      email: parseUser.emailAddress ?? '',
      sessionToken: parseUser.sessionToken,
    );
  }
}