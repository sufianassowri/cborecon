import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../../../core/constants/user_role.dart';
import '../../../../core/services/postgres_service.dart';

abstract class AuthRemoteDataSource {
  Future<ParseUser> signUp(String username, String email, String password, {UserRole role = UserRole.maker});
  Future<ParseUser> login(String username, String password);
  Future<void> logout();
  Future<ParseUser?> getCurrentUser();
  Future<List<ParseUser>> getAllUsers();
  Future<bool> updateUserRole(String username, UserRole newRole);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  @override
  Future<ParseUser> signUp(String username, String email, String password, {UserRole role = UserRole.maker}) async {
    final user = ParseUser(username, password, email);
    user.set<String>('role', role.name);
    final response = await user.signUp();

    if (response.success && response.result != null) {
      final createdUser = response.result as ParseUser;
      // Sync with Docker PostgreSQL
      await PostgresService.instance.saveUser(
        username: username,
        email: email,
        role: role.name,
      );
      return createdUser;
    } else {
      throw Exception(response.error?.message ?? 'Sign up failed');
    }
  }

  @override
  Future<ParseUser> login(String username, String password) async {
    final user = ParseUser(username, password, null);
    final response = await user.login();

    if (response.success && response.result != null) {
      final loggedInUser = response.result as ParseUser;
      // Ensure user role exists
      final roleStr = loggedInUser.get<String>('role') ?? 'maker';
      await PostgresService.instance.saveUser(
        username: username,
        email: loggedInUser.emailAddress ?? '',
        role: roleStr,
      );
      return loggedInUser;
    } else {
      throw Exception(response.error?.message ?? 'Login failed');
    }
  }

  @override
  Future<void> logout() async {
    final currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null) {
      final response = await currentUser.logout();
      if (!response.success) {
        throw Exception(response.error?.message ?? 'Logout failed');
      }
    }
  }

  @override
  Future<ParseUser?> getCurrentUser() async {
    final currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser == null) return null;

    if (currentUser.sessionToken != null) {
      final response = await ParseUser.getCurrentUserFromServer(currentUser.sessionToken!);
      if (response != null && response.success && response.result != null) {
        return response.result as ParseUser;
      }
    }
    return currentUser;
  }

  @override
  Future<List<ParseUser>> getAllUsers() async {
    final query = QueryBuilder<ParseUser>(ParseUser.forQuery());
    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.cast<ParseUser>();
    }
    return [];
  }

  @override
  Future<bool> updateUserRole(String username, UserRole newRole) async {
    final query = QueryBuilder<ParseUser>(ParseUser.forQuery())
      ..whereEqualTo('username', username);
    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      final user = response.results!.first as ParseUser;
      user.set<String>('role', newRole.name);
      await user.save();
    }
    await PostgresService.instance.updateUserRole(username, newRole.name);
    return true;
  }
}