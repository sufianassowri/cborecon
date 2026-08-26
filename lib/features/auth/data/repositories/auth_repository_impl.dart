import '../../../../core/constants/user_role.dart';
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
    UserRole role = UserRole.maker,
  }) async {
    final parseUser = await remoteDataSource.signUp(
      username,
      email,
      password,
      role: role,
    );
    final roleStr = parseUser.get<String>('role');
    return UserEntity(
      id: parseUser.objectId ?? '',
      username: parseUser.username ?? '',
      email: parseUser.emailAddress ?? '',
      sessionToken: parseUser.sessionToken,
      role: UserRole.fromString(roleStr ?? role.name),
    );
  }

  @override
  Future<UserEntity> login({
    required String username,
    required String password,
  }) async {
    final parseUser = await remoteDataSource.login(username, password);
    final roleStr = parseUser.get<String>('role');
    return UserEntity(
      id: parseUser.objectId ?? '',
      username: parseUser.username ?? '',
      email: parseUser.emailAddress ?? '',
      sessionToken: parseUser.sessionToken,
      role: UserRole.fromString(roleStr),
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
    final roleStr = parseUser.get<String>('role');
    return UserEntity(
      id: parseUser.objectId ?? '',
      username: parseUser.username ?? '',
      email: parseUser.emailAddress ?? '',
      sessionToken: parseUser.sessionToken,
      role: UserRole.fromString(roleStr),
    );
  }

  @override
  Future<List<UserEntity>> getAllUsers() async {
    final list = await remoteDataSource.getAllUsers();
    return list.map((u) {
      final roleStr = u.get<String>('role');
      return UserEntity(
        id: u.objectId ?? '',
        username: u.username ?? '',
        email: u.emailAddress ?? '',
        role: UserRole.fromString(roleStr),
      );
    }).toList();
  }

  @override
  Future<bool> updateUserRole({
    required String username,
    required UserRole newRole,
  }) async {
    return remoteDataSource.updateUserRole(username, newRole);
  }
}