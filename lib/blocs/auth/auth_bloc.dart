import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC for managing authentication state and operations
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  StreamSubscription<supabase.AuthState>? _authStateSubscription;

  AuthBloc({
    AuthService? authService,
  })  : _authService = authService ?? AuthService(),
        super(const AuthInitial()) {
    // Register event handlers
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthStatusRequested>(_onAuthStatusRequested);
    on<AuthStateChanged>(_onAuthStateChanged);

    // Listen to Supabase auth state changes
    _listenToAuthChanges();

    // Check initial auth status
    add(const AuthStatusRequested());
  }

  /// Listen to Supabase auth state changes
  void _listenToAuthChanges() {
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        add(AuthStateChanged(
          isAuthenticated: true,
          userData: {
            'user': session.user,
            'session': session,
          },
        ));
      } else {
        add(const AuthStateChanged(isAuthenticated: false));
      }
    });
  }

  /// Handle Google Sign-In request
  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Signing in with Google...'));

    try {
      final result = await _authService.signInWithGoogle();
      final user = result['user'] as supabase.User;
      final session = result['session'] as supabase.Session;

      emit(AuthAuthenticated(
        user: user,
        session: session,
      ));
    } catch (e) {
      emit(AuthError(
        message: e.toString().replaceAll('Exception: ', ''),
      ));
      // After showing error, go back to unauthenticated
      await Future.delayed(const Duration(seconds: 2));
      emit(const AuthUnauthenticated());
    }
  }

  /// Handle Sign-Out request
  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthSigningOut());

    try {
      await _authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(
        message: 'Sign out failed: ${e.toString()}',
      ));
      // Still try to go to unauthenticated state
      await Future.delayed(const Duration(seconds: 1));
      emit(const AuthUnauthenticated());
    }
  }

  /// Handle auth status check
  Future<void> _onAuthStatusRequested(
    AuthStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    final session = _supabase.auth.currentSession;

    if (session != null) {
      emit(AuthAuthenticated(
        user: session.user,
        session: session,
      ));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  /// Handle external auth state changes
  Future<void> _onAuthStateChanged(
    AuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.isAuthenticated && event.userData != null) {
      final user = event.userData!['user'] as supabase.User;
      final session = event.userData!['session'] as supabase.Session;
      
      emit(AuthAuthenticated(
        user: user,
        session: session,
      ));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}

