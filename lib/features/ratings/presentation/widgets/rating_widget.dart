import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/models/rating_model.dart';
import '../../data/repositories/rating_repository.dart';

/// ويدجت التقييم – لعرض وإضافة تقييم
class RatingWidget extends StatefulWidget {
  final String artisanId;
  final String clientId;
  final String clientName;
  final String postId;
  final VoidCallback? onRated;

  const RatingWidget({
    super.key,
    required this.artisanId,
    required this.clientId,
    required this.clientName,
    required this.postId,
    this.onRated,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget>
    with SingleTickerProviderStateMixin {
  final _commentController = TextEditingController();
  double _rating = 0;
  bool _isSubmitting = false;
  bool _hasRated = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  final RatingRepository _ratingRepository = RatingRepository();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();
    _checkIfRated();
  }

  Future<void> _checkIfRated() async {
    final result =
        await _ratingRepository.hasRated(widget.clientId, widget.postId);
    if (mounted) setState(() => _hasRated = result);
  }

  @override
  void dispose() {
    _animController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر تقييم أولاً'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _ratingRepository.addRating(
        RatingModel(
          id: '',
          artisanId: widget.artisanId,
          clientId: widget.clientId,
          clientName: widget.clientName,
          postId: widget.postId,
          rating: _rating,
          comment: _commentController.text.trim(),
          createdAt: DateTime.now(),
        ),
      );

      if (mounted) {
        setState(() {
          _hasRated = true;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال تقييمك بنجاح! ⭐'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onRated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إرسال التقييم'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasRated) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.success.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'تم التقييم بنجاح',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text('قيّم الخدمة', style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 40,
              unratedColor: AppColors.starInactive,
              itemBuilder: (context, _) => const Icon(
                Icons.star_rounded,
                color: AppColors.starActive,
              ),
              onRatingUpdate: (rating) {
                setState(() => _rating = rating);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              textDirection: TextDirection.rtl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب تعليقك (اختياري)...',
                hintStyle: AppTextStyles.bodySmall,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('إرسال التقييم', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ويدجت عرض نجوم التقييم (للقراءة فقط)
class RatingStars extends StatelessWidget {
  final double rating;
  final int count;
  final double size;

  const RatingStars({
    super.key,
    required this.rating,
    this.count = 0,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBarIndicator(
          rating: rating,
          itemCount: 5,
          itemSize: size,
          unratedColor: AppColors.starInactive,
          itemBuilder: (context, _) => Icon(
            Icons.star_rounded,
            color: AppColors.starActive,
            size: size,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Text(
            '(${rating.toStringAsFixed(1)})',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count تقييم',
            style: AppTextStyles.labelSmall,
          ),
        ],
      ],
    );
  }
}
