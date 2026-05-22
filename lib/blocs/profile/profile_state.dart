import 'package:equatable/equatable.dart';

import '../../models/profile_models.dart';

enum ProfileStatus {
  initial,
  loading,
  loaded,
  uploading,
  uploadSuccess,
  uploadFailed,
  syncing,
  failure,
}

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.snapshot,
    this.activeUploadKey,
    this.errorMessage,
    this.isOffline = false,
    this.isFromCache = false,
    this.pendingUploadCount = 0,
    this.appVersion,
  });

  final ProfileStatus status;
  final ProfileSnapshot? snapshot;
  final String? activeUploadKey;
  final String? errorMessage;
  final bool isOffline;
  final bool isFromCache;
  final int pendingUploadCount;
  final String? appVersion;

  bool get hasProfile => snapshot != null;

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileSnapshot? snapshot,
    String? activeUploadKey,
    bool clearActiveUploadKey = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isOffline,
    bool? isFromCache,
    int? pendingUploadCount,
    String? appVersion,
  }) {
    return ProfileState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      activeUploadKey: clearActiveUploadKey
          ? null
          : activeUploadKey ?? this.activeUploadKey,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      isOffline: isOffline ?? this.isOffline,
      isFromCache: isFromCache ?? this.isFromCache,
      pendingUploadCount: pendingUploadCount ?? this.pendingUploadCount,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  @override
  List<Object?> get props => [
    status,
    snapshot,
    activeUploadKey,
    errorMessage,
    isOffline,
    isFromCache,
    pendingUploadCount,
    appVersion,
  ];
}
