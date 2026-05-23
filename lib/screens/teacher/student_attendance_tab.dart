import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../models/teacher_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';
import 'student_attendance_screen.dart';

class StudentAttendanceTab extends StatelessWidget {
  const StudentAttendanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
          builder: (context, dashState) {
            final subjects = dashState.teacher?.subjects ?? [];
            final courses = dashState.teacher?.courses ?? [];
            final items = [...courses, ...subjects];

            if (dashState.status == TeacherDashboardStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Student Attendance',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a class or course to mark attendance.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (items.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No classes assigned to you.',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isCourse = item is TeacherCourseAssignment;
                          
                          String title;
                          String subtitle;
                          String badge;
                          
                          if (isCourse) {
                            title = item.courseName;
                            subtitle = 'Course Level Access';
                            badge = 'COURSE';
                          } else {
                            final s = item as TeacherSubjectAssignment;
                            title = s.subjectName;
                            subtitle = s.batchName ?? 'All Students';
                            badge = s.courseName ?? 'Subject';
                          }

                          return _buildAssignmentCard(
                            context: context,
                            title: title,
                            subtitle: subtitle,
                            badge: badge,
                            isCourse: isCourse,
                            item: item,
                            campusId: dashState.teacher?.campusId,
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAssignmentCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required bool isCourse,
    required dynamic item,
    String? campusId,
  }) {
    return GestureDetector(
      onTap: () {
        if (isCourse) {
          final c = item as TeacherCourseAssignment;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StudentAttendanceScreen(
              subjectId:   '', // Empty for course-level
              subjectName: c.courseName,
              batchId:     '', // Empty for course-level
              batchName:   'All Students in Course',
              courseId:    c.courseId,
              campusId:    campusId,
            ),
          ));
        } else {
          final s = item as TeacherSubjectAssignment;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StudentAttendanceScreen(
              subjectId:   s.subjectId,
              subjectName: s.subjectName,
              batchId:     s.batchId ?? '',
              batchName:   s.batchName,
              courseId:    s.courseId,
              campusId:    campusId,
            ),
          ));
        }
      },
      child: NeuBox(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isCourse 
                  ? AppColors.primary.withValues(alpha: 0.1) 
                  : AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isCourse ? LucideIcons.bookOpen : LucideIcons.bookmark,
                color: isCourse ? AppColors.primary : AppColors.info,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
