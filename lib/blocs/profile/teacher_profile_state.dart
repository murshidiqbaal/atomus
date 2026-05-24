import 'package:equatable/equatable.dart';
import '../../models/teacher_model.dart';

enum TeacherProfileStatus {
  initial,
  loading,
  loaded,
  updating,
  uploadingImage,
  syncPending,
  error,
}

class TeacherProfileState extends Equatable {
  final TeacherProfileStatus status;
  final TeacherModel? teacher;
  final String? errorMessage;
  final bool isOffline;
  final String? localPhotoPath;
  final bool isSyncPending;

  const TeacherProfileState({
    this.status = TeacherProfileStatus.initial,
    this.teacher,
    this.errorMessage,
    this.isOffline = false,
    this.localPhotoPath,
    this.isSyncPending = false,
  });

  TeacherProfileState copyWith({
    TeacherProfileStatus? status,
    TeacherModel? teacher,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isOffline,
    String? localPhotoPath,
    bool clearLocalPhotoPath = false,
    bool? isSyncPending,
  }) {
    return TeacherProfileState(
      status: status ?? this.status,
      teacher: teacher ?? this.teacher,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isOffline: isOffline ?? this.isOffline,
      localPhotoPath: clearLocalPhotoPath ? null : (localPhotoPath ?? this.localPhotoPath),
      isSyncPending: isSyncPending ?? this.isSyncPending,
    );
  }

  @override
  List<Object?> get props => [
        status,
        teacher,
        errorMessage,
        isOffline,
        localPhotoPath,
        isSyncPending,
      ];
}
