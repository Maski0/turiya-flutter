import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Base class for all authentication states
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state - checking authentication status
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// User is not authenticated
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Authentication in progress (e.g., Google sign-in)
class AuthLoading extends AuthState {
  final String? message;

  const AuthLoading({this.message});

  @override
  List<Object?> get props => [message];
}

/// User is authenticated
class AuthAuthenticated extends AuthState {
  final supabase.User user;
  final supabase.Session session;

  const AuthAuthenticated({
    required this.user,
    required this.session,
  });

  @override
  List<Object?> get props => [user.id, session.accessToken];
}

/// Authentication failed
class AuthError extends AuthState {
  final String message;
  final String? errorCode;

  const AuthError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}

/// Sign out in progress
class AuthSigningOut extends AuthState {
  const AuthSigningOut();
}

