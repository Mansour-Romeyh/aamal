import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReportDialog extends StatefulWidget {
  final String reporterId;
  final String reportedId;
  final String? postId;
  final String? chatId;

  const ReportDialog({
    super.key,
    required this.reporterId,
    required this.reportedId,
    this.postId,
    this.chatId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _detailsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final List<String> _reasons = [
    'سلوك غير لائق',
    'احتيال أو نصب',
    'جودة عمل سيئة',
    'تأخير غير مبرر',
    'محتوى مخالف',
    'أخرى',
  ];
  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? (size.width - 500) / 2 : 20,
        vertical: 24,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: AppColors.shadowLevel2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.report_gmailerrorred_rounded,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'إبلاغ عن مخالفة',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سيتم مراجعة هذا البلاغ من قبل فريق الإدارة في أقرب وقت ممكن.',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: _selectedReason,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textHint,
                        ),
                        decoration: InputDecoration(
                          labelText: 'سبب الإبلاغ',
                          labelStyle: GoogleFonts.cairo(
                            color: AppColors.textHint,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _reasons
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r,
                                  style: GoogleFonts.cairo(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _selectedReason = val),
                        validator: (val) => val == null ? 'يرجى اختيار سبب' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _detailsController,
                        maxLines: isTablet ? 6 : 4,
                        style: GoogleFonts.cairo(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'تفاصيل إضافية',
                          labelStyle: GoogleFonts.cairo(
                            color: AppColors.textHint,
                            fontSize: 13,
                          ),
                          hintText: 'وضّح ما حدث بالتفصيل...',
                          hintStyle: GoogleFonts.cairo(
                            color: AppColors.textHint.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (val) =>
                            (val == null || val.isEmpty) ? 'يرجى كتابة التفاصيل' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            // Fixed Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'إرسال البلاغ',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final report = ReportModel(
        id: '', 
        reporterId: widget.reporterId,
        reportedId: widget.reportedId,
        postId: widget.postId,
        chatId: widget.chatId,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
        createdAt: DateTime.now(),
      );

      await sl<ReportRepository>().sendReport(report);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال بلاغك بنجاح، سيتم مراجعته قريباً', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e', style: GoogleFonts.cairo())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }
}
