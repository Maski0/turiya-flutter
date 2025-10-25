import 'package:equatable/equatable.dart';

/// Base class for all authentication events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when user wants to sign in with Google
class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

/// Event triggered when user wants to sign out
class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// Event triggered to check current auth status
class AuthStatusRequested extends AuthEvent {
  const AuthStatusRequested();
}

/// Event triggered when auth state changes externally (e.g., session expired)
class AuthStateChanged extends AuthEvent {
  final bool isAuthenticated;
  final Map<String, dynamic>? userData;

  const AuthStateChanged({
    required this.isAuthenticated,
    this.userData,
  });

  @override
  List<Object?> get props => [isAuthenticated, userData];
}

