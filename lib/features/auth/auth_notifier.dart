import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class AuthNotifier extends AsyncNotifier<void> {
  late AuthService _authService;

  @override
  FutureOr<void> build() {
    _authService = ref.watch(authServiceProvider);
  }

  // Fungsi Login yang dipanggil dari UI
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signIn(email, password);
    });
  }

  // Fungsi Register yang dipanggil dari UI
  Future<void> signUp(
    String email,
    String password, {
    String? fullName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signUp(email, password, fullName: fullName);
      // Mark that this new user needs onboarding setup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', false);
    });
  }

  // Fungsi Logout
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signOut();
    });
  }
}

// Provider untuk Notifier
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(() {
  return AuthNotifier();
});
