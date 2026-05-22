import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../posts/data/models/post_model.dart';
import '../../../../posts/data/repositories/post_repository.dart';

// --- State ---
abstract class ArtisanJobsState extends Equatable {
  const ArtisanJobsState();

  @override
  List<Object?> get props => [];
}

class ArtisanJobsInitial extends ArtisanJobsState {}

class ArtisanJobsLoading extends ArtisanJobsState {}

class ArtisanJobsLoaded extends ArtisanJobsState {
  final List<PostModel> posts;
  const ArtisanJobsLoaded({required this.posts});

  @override
  List<Object?> get props => [posts];
}

class ArtisanJobsError extends ArtisanJobsState {
  final String message;
  const ArtisanJobsError({required this.message});

  @override
  List<Object?> get props => [message];
}

// --- Cubit ---
class ArtisanJobsCubit extends Cubit<ArtisanJobsState> {
  final PostRepository _postRepository;
  StreamSubscription<List<PostModel>>? _subscription;
  String _currentArtisanId = '';

  ArtisanJobsCubit({required PostRepository postRepository})
      : _postRepository = postRepository,
        super(ArtisanJobsInitial());

  void loadArtisanJobs(String artisanId) {
    _currentArtisanId = artisanId;
    emit(ArtisanJobsLoading());
    _subscription?.cancel();
    _subscription = _postRepository.getUnifiedArtisanJobs(artisanId).listen(
      (posts) {
        if (!isClosed) emit(ArtisanJobsLoaded(posts: posts));
      },
      onError: (error) {
        if (!isClosed) emit(ArtisanJobsError(message: error.toString()));
      },
    );
  }

  Future<void> refresh() async {
    if (_currentArtisanId.isNotEmpty) {
      loadArtisanJobs(_currentArtisanId);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
