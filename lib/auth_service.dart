import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Authentication service using Supabase (same as web app)
/// Handles Google OAuth sign-in and session management
class AuthService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  /// Sign in with Google using Supabase OAuth (same as web)
  /// Returns user data on success
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Start OAuth flow with custom scheme (must be added to Supabase Dashboard!)
      final bool success = await _supabase.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: 'com.turiya.now://login-callback',  // Custom scheme for mobile
        authScreenLaunchMode: supabase.LaunchMode.externalApplication,
      );

      if (!success) {
        throw Exception('Failed to initiate Google sign-in');
      }

      // The app will be reopened via deep link after OAuth completes
      // Listen for auth state change with timeout
      await for (final state in _supabase.auth.onAuthStateChange.timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) => sink.close(),
      )) {
        if (state.session != null) {
          print('✅ Supabase OAuth successful');
          print('   User ID: ${state.session!.user.id}');
          print('   Email: ${state.session!.user.email}');
          
          return {
            'user': state.session!.user,
            'session': state.session,
          };
        }
      }

      throw Exception('OAuth timed out or cancelled');
    } catch (e) {
      print('❌ Supabase OAuth error: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _supabase.auth.currentSession != null;
  }

  /// Get current access token (Supabase JWT)
  String? getAccessToken() {
    return _supabase.auth.currentSession?.accessToken;
  }

  /// Get current user
  supabase.User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    print('✅ Signed out successfully');
  }

  /// Listen to auth state changes
  Stream<supabase.AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}
