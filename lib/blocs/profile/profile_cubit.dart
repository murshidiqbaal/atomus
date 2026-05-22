import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/profile_models.dart';
import '../../repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required ProfileRepository repository,
    Connectivity? connectivity,
  }) : _repository = repository,
       _connectivity = connectivity ?? Connectivity(),
       super(const ProfileState());

  final ProfileRepository _repository;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncDebounce;
  bool _isSyncing = false;

  void startConnectivitySync() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final connected = _hasConnection(results);
      emit(state.copyWith(isOffline: !connected));
      if (connected && state.pendingUploadCount > 0) {
        _syncDebounce?.cancel();
        _syncDebounce = Timer(
          const Duration(milliseconds: 700),
          retryPendingUploads,
        );
      }
    });
  }

  Future<void> loadProfile() async {
    emit(
      state.copyWith(status: ProfileStatus.loading, clearErrorMessage: true),
    );
    await _loadAppVersion();

    final cached = await _repository.getCachedProfileForCurrentUser();
    if (cached != null) {
      final pending = await _repository.pendingUploads(cached.parent.id);
      emit(
        state.copyWith(
          status: ProfileStatus.loaded,
          snapshot: cached,
          isFromCache: true,
          pendingUploadCount: pending.length,
        ),
      );
    }

    final connected = _hasConnection(await _connectivity.checkConnectivity());
    if (!connected) {
      emit(
        state.copyWith(
          status: cached == null ? ProfileStatus.failure : ProfileStatus.loaded,
          isOffline: true,
          errorMessage: cached == null
              ? 'No cached profile is available on this device yet.'
              : null,
          clearErrorMessage: cached != null,
        ),
      );
      return;
    }

    try {
      final remote = await _repository.fetchProfile();
      final synced = await _repository.syncPendingUploads(remote);
      final pending = await _repository.pendingUploads(synced.parent.id);
      emit(
        state.copyWith(
          status: ProfileStatus.loaded,
          snapshot: synced,
          isOffline: false,
          isFromCache: false,
          pendingUploadCount: pending.length,
          clearErrorMessage: true,
          clearActiveUploadKey: true,
        ),
      );
    } catch (error) {
      if (cached != null) {
        emit(
          state.copyWith(
            status: ProfileStatus.loaded,
            snapshot: cached,
            isOffline: true,
            isFromCache: true,
            errorMessage: error.toString(),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ProfileStatus.failure,
            errorMessage: error.toString(),
            isOffline: true,
          ),
        );
      }
    }
  }

  Future<void> saveParentDetails({
    required String fullName,
    required String phoneNumber,
    required String address,
  }) async {
    final snapshot = state.snapshot;
    if (snapshot == null) return;

    final optimisticParent = snapshot.parent.copyWith(
      fullName: fullName,
      phoneNumber: phoneNumber,
      address: address,
    );
    final optimisticSnapshot = snapshot.copyWith(
      parent: optimisticParent,
      updatedAt: DateTime.now(),
    );

    emit(
      state.copyWith(
        status: ProfileStatus.loaded,
        snapshot: optimisticSnapshot,
        clearErrorMessage: true,
      ),
    );

    try {
      final saved = await _repository.updateParentDetails(
        snapshot,
        optimisticParent,
      );
      emit(state.copyWith(status: ProfileStatus.loaded, snapshot: saved));
    } catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          snapshot: snapshot,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> updateParentImage(ImageSource source) async {
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    await _pickCacheAndUpload(
      source: source,
      target: ProfileUploadTarget.parent,
      targetId: snapshot.parent.id,
      filePrefix: 'parent_${snapshot.parent.id}',
    );
  }

  Future<void> updateStudentImage(String studentId, ImageSource source) async {
    await _pickCacheAndUpload(
      source: source,
      target: ProfileUploadTarget.student,
      targetId: studentId,
      filePrefix: 'student_$studentId',
    );
  }

  Future<void> retryPendingUploads() async {
    if (_isSyncing) return;
    final snapshot = state.snapshot;
    if (snapshot == null) {
      await loadProfile();
      return;
    }

    final connected = _hasConnection(await _connectivity.checkConnectivity());
    if (!connected) {
      emit(state.copyWith(isOffline: true));
      return;
    }

    _isSyncing = true;
    emit(
      state.copyWith(status: ProfileStatus.syncing, clearErrorMessage: true),
    );
    try {
      final synced = await _repository.syncPendingUploads(snapshot);
      final pending = await _repository.pendingUploads(synced.parent.id);
      emit(
        state.copyWith(
          status: ProfileStatus.loaded,
          snapshot: synced,
          pendingUploadCount: pending.length,
          isOffline: false,
          clearActiveUploadKey: true,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.uploadFailed,
          errorMessage: error.toString(),
        ),
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pickCacheAndUpload({
    required ImageSource source,
    required ProfileUploadTarget target,
    required String targetId,
    required String filePrefix,
  }) async {
    final current = state.snapshot;
    if (current == null) return;

    String? pickedLocalPath;
    try {
      pickedLocalPath = await _repository.pickAndPersistImage(
        source: source,
        filePrefix: filePrefix,
      );
      final localPath = pickedLocalPath;
      if (localPath == null) return;

      final cached = await _repository.cacheLocalImage(
        current: current,
        target: target,
        targetId: targetId,
        localPath: localPath,
      );
      final uploadKey = _uploadKey(target, targetId);
      emit(
        state.copyWith(
          status: ProfileStatus.uploading,
          snapshot: cached,
          activeUploadKey: uploadKey,
          clearErrorMessage: true,
        ),
      );

      final connected = _hasConnection(await _connectivity.checkConnectivity());
      if (!connected) {
        await _repository.enqueueUpload(
          current: cached,
          target: target,
          targetId: targetId,
          localPath: localPath,
          error: 'Waiting for internet connection.',
        );
        final pending = await _repository.pendingUploads(cached.parent.id);
        emit(
          state.copyWith(
            status: ProfileStatus.uploadFailed,
            snapshot: cached,
            isOffline: true,
            pendingUploadCount: pending.length,
            errorMessage: 'Image saved locally and will upload when online.',
          ),
        );
        return;
      }

      final uploaded = await _repository.uploadImage(
        current: cached,
        target: target,
        targetId: targetId,
        localPath: localPath,
      );
      final pending = await _repository.pendingUploads(uploaded.parent.id);
      emit(
        state.copyWith(
          status: ProfileStatus.uploadSuccess,
          snapshot: uploaded,
          pendingUploadCount: pending.length,
          isOffline: false,
          clearActiveUploadKey: true,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      final failedSnapshot = state.snapshot;
      if (failedSnapshot != null && pickedLocalPath != null) {
        final localPath = pickedLocalPath;
        await _repository.enqueueUpload(
          current: failedSnapshot,
          target: target,
          targetId: targetId,
          localPath: localPath,
          error: error,
        );
        final pending = await _repository.pendingUploads(
          failedSnapshot.parent.id,
        );
        emit(
          state.copyWith(
            status: ProfileStatus.uploadFailed,
            pendingUploadCount: pending.length,
            errorMessage:
                'Image saved locally. Upload will retry automatically.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: ProfileStatus.uploadFailed,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _loadAppVersion() async {
    if (state.appVersion != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      emit(state.copyWith(appVersion: '${info.version}+${info.buildNumber}'));
    } catch (_) {
      emit(state.copyWith(appVersion: '1.0.0'));
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  String _uploadKey(ProfileUploadTarget target, String targetId) {
    return '${target.apiValue}:$targetId';
  }

  @override
  Future<void> close() {
    _syncDebounce?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
