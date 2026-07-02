import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Bootstrap & Cache
import 'app_bootstrap.dart';
import 'blocs/announcement/announcement_bloc.dart';
import 'blocs/announcement/announcement_event.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/connectivity/connectivity_cubit.dart';
import 'blocs/course/course_bloc.dart';
import 'blocs/course/course_event.dart';
import 'blocs/daily_report/daily_report_cubit.dart';
import 'blocs/fee/fee_bloc.dart';
import 'blocs/geofence/geofence_cubit.dart';
import 'blocs/marks/marks_cubit.dart';
import 'blocs/notification/notification_bloc.dart';
import 'blocs/profile/profile_cubit.dart';
import 'blocs/profile/teacher_profile_cubit.dart';
import 'blocs/student/student_bloc.dart';
import 'blocs/student_attendance/student_attendance_cubit.dart';
import 'blocs/teacher_attendance/teacher_attendance_cubit.dart';
import 'blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import 'blocs/teacher_session/teacher_session_cubit.dart';
// Blocs & Cubits
import 'blocs/theme/theme_bloc.dart';
import 'repositories/announcement_repository.dart';
// Repositories
import 'repositories/auth_repository.dart';
import 'repositories/course_repository.dart';
import 'repositories/daily_report_repository.dart';
import 'repositories/fee_repository.dart';
import 'repositories/marks_entry_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/parent_activity_repository.dart';
import 'repositories/student_attendance_teacher_repository.dart';
import 'repositories/student_repository.dart';
import 'repositories/teacher_attendance_repository.dart';
import 'repositories/teacher_repository.dart';
import 'services/auto_sync_manager.dart';
import 'services/drive_upload_service.dart';
import 'services/geofence_service.dart';
import 'services/google_drive_profile_upload_service.dart';
import 'services/hive_profile_cache_service.dart';
import 'services/parent_activity_service.dart';
// Services
import 'services/parent_identity_service.dart';
import 'services/password_recovery_service.dart';
import 'services/profile_image_service.dart';
import 'services/teacher_hive_service.dart';
import 'services/teacher_profile_hive_service.dart';

class AppProviders extends StatelessWidget {
  final AppBootstrapResult bootstrapResult;
  final Widget child;

  const AppProviders({
    super.key,
    required this.bootstrapResult,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // Singletons from Bootstrap Result
        RepositoryProvider<TeacherHiveService>.value(
          value: bootstrapResult.teacherHiveService,
        ),
        RepositoryProvider<HiveProfileCacheService>.value(
          value: bootstrapResult.hiveProfileCacheService,
        ),
        RepositoryProvider<TeacherProfileHiveService>.value(
          value: bootstrapResult.teacherProfileHiveService,
        ),

        // Core Repositories
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(
          create: (ctx) => PasswordRecoveryService(
            authRepository: ctx.read<AuthRepository>(),
          )..initialize(),
        ),
        RepositoryProvider(create: (_) => StudentRepository()),
        RepositoryProvider(create: (_) => FeeRepository()),
        RepositoryProvider(create: (_) => AnnouncementRepository()),
        RepositoryProvider(create: (_) => CourseRepository()),
        RepositoryProvider(create: (_) => NotificationRepository()),
        RepositoryProvider(create: (_) => ParentIdentityService()),
        RepositoryProvider(create: (_) => ParentActivityRepository()),
        RepositoryProvider(
          create: (ctx) => ParentActivityService(
            client: Supabase.instance.client,
            parentIdentityService: ctx.read<ParentIdentityService>(),
            activityRepository: ctx.read<ParentActivityRepository>(),
            studentRepository: ctx.read<StudentRepository>(),
          ),
        ),
        RepositoryProvider(create: (_) => ProfileImageService()),
        RepositoryProvider(create: (_) => GoogleDriveProfileUploadService()),

        RepositoryProvider(
          create: (ctx) => ProfileRepository(
            cache: ctx.read<HiveProfileCacheService>(),
            driveUploader: ctx.read<GoogleDriveProfileUploadService>(),
            imageService: ctx.read<ProfileImageService>(),
            parentIdentityService: ctx.read<ParentIdentityService>(),
          ),
        ),

        // Teacher Repositories
        RepositoryProvider(
          create: (ctx) =>
              TeacherRepository(hive: ctx.read<TeacherHiveService>()),
        ),
        RepositoryProvider(
          create: (ctx) =>
              TeacherAttendanceRepository(hive: ctx.read<TeacherHiveService>()),
        ),
        RepositoryProvider(
          create: (ctx) => StudentAttendanceTeacherRepository(
            hive: ctx.read<TeacherHiveService>(),
          ),
        ),
        RepositoryProvider(
          create: (ctx) =>
              MarksEntryRepository(hive: ctx.read<TeacherHiveService>()),
        ),
        RepositoryProvider(
          create: (ctx) =>
              DailyReportRepository(hive: ctx.read<TeacherHiveService>()),
        ),
        RepositoryProvider(create: (_) => GeofenceService()),
        RepositoryProvider(
          create: (ctx) => DriveUploadService(
            imageService: ctx.read<ProfileImageService>(),
            uploader: ctx.read<GoogleDriveProfileUploadService>(),
          ),
        ),

        // AutoSyncManager Provider (depends on TeacherHiveService)
        RepositoryProvider(
          create: (ctx) =>
              AutoSyncManager(hive: ctx.read<TeacherHiveService>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          // Theme & Auth Blocs
          BlocProvider(create: (_) => ThemeBloc()),
          BlocProvider(
            create: (ctx) =>
                AuthBloc(authRepository: ctx.read<AuthRepository>())
                  ..add(AppStarted()),
          ),

          // Student Blocs
          BlocProvider(
            create: (ctx) =>
                StudentBloc(studentRepository: ctx.read<StudentRepository>()),
          ),
          BlocProvider(
            create: (ctx) => FeeBloc(feeRepository: ctx.read<FeeRepository>()),
          ),
          BlocProvider(
            create: (ctx) =>
                AnnouncementBloc(repository: ctx.read<AnnouncementRepository>())
                  ..add(LoadAnnouncements()),
          ),
          BlocProvider(
            create: (ctx) =>
                CourseBloc(courseRepository: ctx.read<CourseRepository>())
                  ..add(LoadCourses()),
          ),
          BlocProvider(
            create: (ctx) =>
                ProfileCubit(
                  repository: ctx.read<ProfileRepository>(),
                  authBloc: ctx.read<AuthBloc>(),
                )
                  ..startConnectivitySync(),
          ),
          BlocProvider(
            create: (ctx) => NotificationBloc(
              repository: ctx.read<NotificationRepository>(),
            ),
          ),

          // Teacher Blocs/Cubits
          BlocProvider(
            create: (ctx) =>
                TeacherSessionCubit(repository: ctx.read<TeacherRepository>()),
          ),
          BlocProvider(
            create: (ctx) => TeacherProfileCubit(
              teacherRepository: ctx.read<TeacherRepository>(),
              hiveService: ctx.read<TeacherProfileHiveService>(),
              driveUploadService: ctx.read<DriveUploadService>(),
              imageService: ctx.read<ProfileImageService>(),
              sessionCubit: ctx.read<TeacherSessionCubit>(),
              authBloc: ctx.read<AuthBloc>(),
            )..loadProfile(),
          ),
          BlocProvider(
            create: (ctx) => TeacherDashboardCubit(
              teacherRepository: ctx.read<TeacherRepository>(),
              attendanceRepository: ctx.read<TeacherAttendanceRepository>(),
              marksRepository: ctx.read<MarksEntryRepository>(),
              authBloc: ctx.read<AuthBloc>(),
            ),
          ),
          BlocProvider(
            create: (ctx) => TeacherAttendanceCubit(
              repository: ctx.read<TeacherAttendanceRepository>(),
            ),
          ),
          BlocProvider(
            create: (ctx) => StudentAttendanceCubit(
              repository: ctx.read<StudentAttendanceTeacherRepository>(),
            ),
          ),
          BlocProvider(
            create: (ctx) =>
                MarksCubit(repository: ctx.read<MarksEntryRepository>()),
          ),
          BlocProvider(
            create: (ctx) =>
                DailyReportCubit(repository: ctx.read<DailyReportRepository>()),
          ),
          BlocProvider(
            create: (ctx) =>
                GeofenceCubit(geofenceService: ctx.read<GeofenceService>()),
          ),
          BlocProvider(create: (_) => ConnectivityCubit()),
        ],
        child: child,
      ),
    );
  }
}
