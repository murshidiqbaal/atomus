import 'package:equatable/equatable.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading }

enum UserRole { parent, teacher, unknown }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserRole userRole;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.userRole = UserRole.unknown,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserRole? userRole,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status:       status    ?? this.status,
      userRole:     userRole  ?? this.userRole,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isTeacher => userRole == UserRole.teacher;
  bool get isParent  => userRole == UserRole.parent;

  @override
  List<Object?> get props => [status, userRole, errorMessage];
}
