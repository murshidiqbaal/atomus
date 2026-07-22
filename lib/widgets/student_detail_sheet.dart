import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'neu_box.dart';

void showStudentDetailsBottomSheet(
  BuildContext context, {
  required String studentId,
  required String studentName,
  String? rollNumber,
  String? admissionNumber,
  String? photoUrl,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _StudentDetailSheet(
      studentId: studentId,
      studentName: studentName,
      rollNumber: rollNumber,
      admissionNumber: admissionNumber,
      photoUrl: photoUrl,
    ),
  );
}

class _StudentDetailSheet extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final String? admissionNumber;
  final String? photoUrl;

  const _StudentDetailSheet({
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    this.admissionNumber,
    this.photoUrl,
  });

  @override
  State<_StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<_StudentDetailSheet> {
  Map<String, dynamic>? _fullDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('students')
          .select('*, campuses(name), courses(name), batches(name)')
          .eq('id', widget.studentId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _fullDetails = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final details = _fullDetails;

    final roll = widget.rollNumber ?? details?['roll_number']?.toString();
    final admission = widget.admissionNumber ?? details?['admission_number']?.toString();
    final phone = details?['phone_number']?.toString() ?? details?['student_phone']?.toString();
    final email = details?['email']?.toString() ?? details?['student_email']?.toString();
    final gender = details?['gender']?.toString();
    final dob = details?['dob']?.toString() ?? details?['date_of_birth']?.toString();
    final joiningDate = details?['joining_date']?.toString();
    final status = details?['academic_status']?.toString() ?? 'Active';
    final campusName = details?['campuses']?['name']?.toString() ?? 'N/A';
    final courseName = details?['courses']?['name']?.toString() ?? 'N/A';
    final batchName = details?['batches']?['name']?.toString() ?? 'N/A';
    final attendancePct = details?['attendance_percentage']?.toString();
    final address = details?['address']?.toString();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.neuBaseDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Avatar & Name
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    widget.studentName.isNotEmpty
                        ? widget.studentName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (roll != null && roll.isNotEmpty)
                            _badge('Roll: $roll', AppColors.primary),
                          if (admission != null && admission.isNotEmpty)
                            _badge('Adm: $admission', AppColors.accent),
                          _badge(status, AppColors.success),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              )
            else ...[
              const SizedBox(height: 12),
              // Section 1: Academic & Location
              _sectionHeader('ACADEMIC INFORMATION', LucideIcons.graduationCap),
              const SizedBox(height: 8),
              NeuBox(
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                child: Column(
                  children: [
                    _infoRow(LucideIcons.bookOpen, 'Course', courseName),
                    const Divider(height: 16),
                    _infoRow(LucideIcons.users, 'Batch', batchName),
                    const Divider(height: 16),
                    _infoRow(LucideIcons.building, 'Campus', campusName),
                    if (attendancePct != null) ...[
                      const Divider(height: 16),
                      _infoRow(LucideIcons.checkCircle2, 'Attendance', '$attendancePct%'),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Section 2: Contact & Personal Information
              _sectionHeader('PERSONAL & CONTACT', LucideIcons.user),
              const SizedBox(height: 8),
              NeuBox(
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                child: Column(
                  children: [
                    if (phone != null && phone.isNotEmpty) ...[
                      _infoRow(LucideIcons.phone, 'Phone', phone),
                      const Divider(height: 16),
                    ],
                    if (email != null && email.isNotEmpty) ...[
                      _infoRow(LucideIcons.mail, 'Email', email),
                      const Divider(height: 16),
                    ],
                    if (gender != null && gender.isNotEmpty) ...[
                      _infoRow(LucideIcons.userCheck, 'Gender', gender),
                      const Divider(height: 16),
                    ],
                    if (dob != null && dob.isNotEmpty) ...[
                      _infoRow(LucideIcons.calendar, 'Date of Birth', dob),
                      const Divider(height: 16),
                    ],
                    if (joiningDate != null && joiningDate.isNotEmpty) ...[
                      _infoRow(LucideIcons.clock, 'Joining Date', joiningDate),
                      const Divider(height: 16),
                    ],
                    if (address != null && address.isNotEmpty)
                      _infoRow(LucideIcons.mapPin, 'Address', address),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
