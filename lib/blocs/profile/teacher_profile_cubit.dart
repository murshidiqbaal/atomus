import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/teacher_model.dart';
import '../../repositories/teacher_repository.dart';
import '../../services/drive_upload_service.dart';
import '../../services/profile_image_service.dart';
import '../../services/teacher_profile_hive_service.dart';
import '../teacher_session/teacher_session_cubit.dart';
import 'teacher_profile_state.dart';

class TeacherProfileCubit extends Cubit<TeacherProfileState> {
  final TeacherRepository _teacherRepository;
  final TeacherProfileHiveService _hiveService;
  final DriveUploadService _driveUploadService;
  final ProfileImageService _imageService;
  final TeacherSessionCubit _sessionCubit;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  TeacherProfileCubit({
    required TeacherRepository teacherRepository,
    required TeacherProfileHiveService hiveService,
    required DriveUploadService driveUploadService,
    required ProfileImageService imageService,
    required TeacherSessionCubit sessionCubit,
    Connectivity? connectivity,
  })  : _teacherRepository = teacherRepository,
        _hiveService = hiveService,
        _driveUploadService = driveUploadService,
        _imageService = imageService,
        _sessionCubit = sessionCubit,
        _connectivity = connectivity ?? Connectivity(),
        super(const TeacherProfileState()) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((result) => result != ConnectivityResult.none);
      emit(state.copyWith(isOffline: !isOnline));
      if (isOnline) {
        syncPendingData();
      }
    });
  }

  Future<void> loadProfile() async {
    emit(state.copyWith(status: TeacherProfileStatus.loading, clearErrorMessage: true));

    // 1. Try to load cached profile from Hive
    final cached = _hiveService.getProfile();
    final hasPendingUpdate = _hiveService.getPendingUpdate() != null;
    final hasPendingUpload = _hiveService.getPendingImageUpload() != null;
    final hasPendingSync = hasPendingUpdate || hasPendingUpload;

    final localImagePath = _hiveService.getLocalImagePath();

    if (cached != null) {
      emit(state.copyWith(
        status: TeacherProfileStatus.loaded,
        teacher: cached,
        localPhotoPath: localImagePath,
        isSyncPending: hasPendingSync,
      ));
    }

    // 2. Check current connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);

    if (!isOnline) {
      emit(state.copyWith(
        status: cached == null ? TeacherProfileStatus.error : TeacherProfileStatus.loaded,
        isOffline: true,
        errorMessage: cached == null ? 'No internet connection and no cached profile available.' : null,
      ));
      return;
    }

    // 3. Fetch from Supabase
    try {
      final remote = await _teacherRepository.fetchTeacherProfile();
      if (remote != null) {
        await _hiveService.saveProfile(remote);
        emit(state.copyWith(
          status: TeacherProfileStatus.loaded,
          teacher: remote,
          isOffline: false,
          isSyncPending: hasPendingSync,
        ));
        
        // Auto-sync if online
        syncPendingData();
      } else {
        throw Exception('Teacher profile not found on server.');
      }
    } catch (e) {
      if (cached != null) {
        emit(state.copyWith(
          status: TeacherProfileStatus.loaded,
          teacher: cached,
          errorMessage: e.toString(),
        ));
      } else {
        emit(state.copyWith(
          status: TeacherProfileStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String address,
    required String qualification,
    required int experienceYears,
  }) async {
    final current = state.teacher;
    if (current == null) return;

    // Create optimistic model to update UI immediately
    final optimisticTeacher = current.copyWith(
      fullName: fullName.trim(),
      phoneNumber: phoneNumber.trim(),
      address: address.trim(),
      qualification: qualification.trim(),
      experienceYears: experienceYears,
    );

    // Save optimistically to Hive cache and emit Loaded state immediately
    await _hiveService.saveProfile(optimisticTeacher);
    emit(state.copyWith(
      status: TeacherProfileStatus.loaded,
      teacher: optimisticTeacher,
      isSyncPending: true,
      clearErrorMessage: true,
    ));

    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);

    final updatePayload = {
      'full_name': fullName.trim(),
      'phone_number': phoneNumber.trim(),
      'address': address.trim(),
      'qualification': qualification.trim(),
      'experience_years': experienceYears,
    };

    if (!isOnline) {
      // Queue offline update in Hive
      await _hiveService.savePendingUpdate(updatePayload);
      emit(state.copyWith(
        status: TeacherProfileStatus.syncPending,
        isSyncPending: true,
        isOffline: true,
      ));
      return;
    }

    // Try to update Supabase online
    try {
      emit(state.copyWith(status: TeacherProfileStatus.updating));
      await Supabase.instance.client
          .from('teachers')
          .update(updatePayload)
          .eq('id', current.id);

      await _hiveService.clearPendingUpdate();
      
      // Update global session cubit
      _sessionCubit.refresh();

      emit(state.copyWith(
        status: TeacherProfileStatus.loaded,
        teacher: optimisticTeacher,
        isSyncPending: _hiveService.getPendingImageUpload() != null,
      ));
    } catch (e) {
      // Save update payload to Hive for offline retry
      await _hiveService.savePendingUpdate(updatePayload);
      emit(state.copyWith(
        status: TeacherProfileStatus.loaded,
        teacher: optimisticTeacher,
        isSyncPending: true,
        errorMessage: 'Failed to sync with server. Changes saved locally.',
      ));
    }
  }

  Future<void> updateProfileImage(ImageSource source) async {
    final current = state.teacher;
    if (current == null) return;

    try {
      // 1. Pick and compress image locally
      final localPath = await _imageService.pickAndPersistImage(
        source: source,
        filePrefix: 'teacher_profile_${current.id}',
      );
      if (localPath == null) return;

      // 2. Save local path in Hive and immediately show it in the UI
      await _hiveService.saveLocalImagePath(localPath);
      emit(state.copyWith(
        localPhotoPath: localPath,
        status: TeacherProfileStatus.uploadingImage,
        clearErrorMessage: true,
      ));

      // 3. Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);

      if (!isOnline) {
        // Queue offline upload in Hive
        await _hiveService.savePendingImageUpload(localPath);
        emit(state.copyWith(
          status: TeacherProfileStatus.syncPending,
          isSyncPending: true,
          isOffline: true,
        ));
        return;
      }

      // 4. Upload to Google Drive
      final result = await _driveUploadService.compressAndUpload(
        targetId: current.id,
        localPath: localPath,
      );

      if (!result.success) {
        throw Exception(result.error ?? 'Upload to Google Drive failed.');
      }

      // 5. Update teachers table
      await Supabase.instance.client
          .from('teachers')
          .update({'profile_photo_drive_id': result.driveFileId})
          .eq('id', current.id);

      // Clean up cached local paths
      await _hiveService.clearLocalImagePath();
      await _hiveService.clearPendingImageUpload();

      // Update cached and current state model
      final updatedTeacher = current.copyWith(profilePhotoDriveId: result.driveFileId);
      await _hiveService.saveProfile(updatedTeacher);

      // Refresh global session
      _sessionCubit.refresh();

      emit(state.copyWith(
        status: TeacherProfileStatus.loaded,
        teacher: updatedTeacher,
        clearLocalPhotoPath: true,
        isSyncPending: _hiveService.getPendingUpdate() != null,
      ));
    } catch (e) {
      final pendingUploadPath = _hiveService.getLocalImagePath();
      if (pendingUploadPath != null) {
        await _hiveService.savePendingImageUpload(pendingUploadPath);
      }
      emit(state.copyWith(
        status: TeacherProfileStatus.loaded,
        isSyncPending: true,
        errorMessage: 'Image upload failed. Saved locally and will sync later.',
      ));
    }
  }

  Future<void> syncPendingData() async {
    if (_isSyncing) return;
    final current = state.teacher;
    if (current == null) return;

    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult.any((result) => result != ConnectivityResult.none);
    if (!isOnline) return;

    _isSyncing = true;
    try {
      // 1. Sync pending image upload first
      final pendingUpload = _hiveService.getPendingImageUpload();
      String? driveFileId;

      if (pendingUpload != null && File(pendingUpload).existsSync()) {
        final result = await _driveUploadService.compressAndUpload(
          targetId: current.id,
          localPath: pendingUpload,
        );

        if (result.success) {
          driveFileId = result.driveFileId;
          await Supabase.instance.client
              .from('teachers')
              .update({'profile_photo_drive_id': driveFileId})
              .eq('id', current.id);

          await _hiveService.clearLocalImagePath();
          await _hiveService.clearPendingImageUpload();
        } else {
          throw Exception(result.error ?? 'Drive Upload Failed during sync.');
        }
      }

      // 2. Sync pending profile updates
      final pendingUpdate = _hiveService.getPendingUpdate();
      if (pendingUpdate != null) {
        await Supabase.instance.client
            .from('teachers')
            .update(pendingUpdate)
            .eq('id', current.id);

        await _hiveService.clearPendingUpdate();
      }

      // 3. Fetch latest profile to make sure local state matches Supabase exactly
      final latest = await _teacherRepository.fetchTeacherProfile();
      if (latest != null) {
        await _hiveService.saveProfile(latest);
        _sessionCubit.refresh();
        emit(state.copyWith(
          status: TeacherProfileStatus.loaded,
          teacher: latest,
          isSyncPending: false,
          clearLocalPhotoPath: true,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Background sync error: ${e.toString()}',
      ));
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
