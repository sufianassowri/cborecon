import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

abstract class AuthRemoteDataSource {
  Future<ParseUser> signUp(String username, String email, String password);
  Future<ParseUser> login(String username, String password);
  Future<void> logout();
  Future<ParseUser?> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  @override
  Future<ParseUser> signUp(String username, String email, String password) async {
    final user = ParseUser(username, password, email);
    final response = await user.signUp();

    if (response.success && response.result != null) {
      return response.result as ParseUser;
    } else {
      throw Exception(response.error?.message ?? 'Sign up failed');
    }
  }

  @override
  Future<ParseUser> login(String username, String password) async {
    final user = ParseUser(username, password, null);
    final response = await user.login();

    if (response.success && response.result != null) {
      return response.result as ParseUser;
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

    final response = await ParseUser.getCurrentUserFromServer(currentUser.sessionToken!);
    if (response != null && response.success && response.result != null) {
      return response.result as ParseUser;
    }
    return currentUser;
  }
}