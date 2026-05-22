import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/models/rating_model.dart';
import '../../data/repositories/rating_repository.dart';
import '../widgets/rating_widget.dart';

class ArtisanRatingsPage extends StatelessWidget {
  final String artisanId;
  final String artisanName;

  const ArtisanRatingsPage({
    super.key,
    required this.artisanId,
    required this.artisanName,
  });

  @override
  Widget build(BuildContext context) {
    final RatingRepository ratingRepository = RatingRepository();

    return Scaffold(
      appBar: AppBar(
        title: Text('تقييمات $artisanName'),
      ),
      body: StreamBuilder<List<RatingModel>>(
        stream: ratingRepository.getArtisanRatings(artisanId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final allRatings = snapshot.data ?? [];
          final ratings = allRatings.where((r) => !r.isHidden).toList();

          if (ratings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_outline,
                    size: 80,
                    color: AppColors.textHint.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد تقييمات بعد',
                    style: AppTextStyles.titleMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ratings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final rating = ratings[index];
              return _RatingCard(rating: rating);
            },
          );
        },
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final RatingModel rating;

  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rating.clientName,
                style: AppTextStyles.titleSmall,
              ),
              Text(
                '${rating.createdAt.day}/${rating.createdAt.month}/${rating.createdAt.year}',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RatingStars(rating: rating.rating, size: 16),
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              rating.comment,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
