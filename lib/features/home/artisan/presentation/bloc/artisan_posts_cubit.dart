import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../auth/data/models/user_model.dart';
import '../../../../posts/data/models/post_model.dart';
import '../../../../posts/data/repositories/post_repository.dart';

// --- State ---
abstract class ArtisanPostsState extends Equatable {
  const ArtisanPostsState();

  @override
  List<Object?> get props => [];
}

class ArtisanPostsInitial extends ArtisanPostsState {}

class ArtisanPostsLoading extends ArtisanPostsState {}

class ArtisanPostsLoaded extends ArtisanPostsState {
  final List<PostModel> posts;
  const ArtisanPostsLoaded({required this.posts});

  @override
  List<Object?> get props => [posts];
}

class ArtisanPostsError extends ArtisanPostsState {
  final String message;
  const ArtisanPostsError({required this.message});

  @override
  List<Object?> get props => [message];
}

// --- Cubit ---
class ArtisanPostsCubit extends Cubit<ArtisanPostsState> {
  final PostRepository _postRepository;
  StreamSubscription<List<PostModel>>? _subscription;
  String _currentSpecialty = '';
  UserModel? _currentArtisan;

  ArtisanPostsCubit({required PostRepository postRepository})
    : _postRepository = postRepository,
      super(ArtisanPostsInitial());

  void loadOpenPosts(String specialty, UserModel artisan) {
    _currentSpecialty = specialty;
    _currentArtisan = artisan;
    emit(ArtisanPostsLoading());
    _subscription?.cancel();
    _subscription = _postRepository
        .getOpenPostsBySpecialty(specialty)
        .listen(
          (posts) {
            final filteredPosts = _filterVisiblePosts(posts, artisan);
            if (!isClosed) emit(ArtisanPostsLoaded(posts: filteredPosts));
          },
          onError: (error) {
            if (!isClosed) emit(ArtisanPostsError(message: error.toString()));
          },
        );
  }

  Future<void> refresh() async {
    if (_currentSpecialty.isNotEmpty && _currentArtisan != null) {
      loadOpenPosts(_currentSpecialty, _currentArtisan!);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  List<PostModel> _filterVisiblePosts(List<PostModel> posts, UserModel artisan) {
    // نفس مبدأ الإشعارات: الحرفي الذي لا يملك وسيلة Push لا يظهر له الطلب في الاستكشاف.
    final hasPrimaryToken = artisan.fcmToken.trim().isNotEmpty;
    final hasMultiTokens = artisan.fcmTokens.any((token) => token.trim().isNotEmpty);
    if (!hasPrimaryToken && !hasMultiTokens) return const [];

    return posts.where((post) {
      if (post.status != 'open') return false;

      // لا نظهر في الاستكشاف إلا الطلبات التي نعرف موقعها وموقع الحرفي بدقة.
      if (post.latitude == null || post.longitude == null) return false;
      if (artisan.latitude == null || artisan.longitude == null) return false;

      final distanceKm = _calculateDistanceKm(
        artisan.latitude!,
        artisan.longitude!,
        post.latitude!,
        post.longitude!,
      );
      return distanceKm <= 20.0;
    }).toList();
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
