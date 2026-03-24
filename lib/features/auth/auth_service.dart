import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  // Mengambil instance Supabase yang nanti diinisialisasi di main.dart
  final SupabaseClient _supabase = Supabase.instance.client;

  // Mendapatkan session saat ini (untuk cek apakah user sudah login)
  Session? get currentSession => _supabase.auth.currentSession;

  // Mendengarkan perubahan status autentikasi secara realtime
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Fungsi Login
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Fungsi Register
  Future<AuthResponse> signUp(String email, String password) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Fungsi Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}

// Provider untuk AuthService agar bisa diakses oleh Riverpod
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});
