import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/constants/user_role.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(AuthRemoteDataSourceImpl());
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

// Provides the current user entity directly
final currentUserProvider = Provider<UserEntity?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.value;
});

// Provides the current user's role directly (defaulting to maker if unauthenticated)
final currentUserRoleProvider = Provider<UserRole>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.value?.role ?? UserRole.maker;
});

// Admin provider for managing all users
final adminUsersListProvider = FutureProvider.autoDispose<List<UserEntity>>((ref) async {
  final repo = ref.read(authRepositoryProvider);
  return await repo.getAllUsers();
});

class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(username: username, password: password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp(
    String username,
    String email,
    String password, {
    UserRole role = UserRole.maker,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signUp(
        username: username,
        email: email,
        password: password,
        role: role,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Admin method: Creates user without switching current admin session
  Future<UserEntity> createUserByAdmin({
    required String username,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    return await _repository.signUp(
      username: username,
      email: email,
      password: password,
      role: role,
    );
  }

  /// Admin method: Updates user role
  Future<bool> changeUserRole(String username, UserRole newRole) async {
    final success = await _repository.updateUserRole(
      username: username,
      newRole: newRole,
    );
    if (state.value?.username == username) {
      state = AsyncValue.data(state.value?.copyWith(role: newRole));
    }
    return success;
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _repository.logout();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}