import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../posts/data/models/post_model.dart';
import '../../../../posts/data/repositories/post_repository.dart';

// --- State ---
abstract class ClientPostsState extends Equatable {
  const ClientPostsState();

  @override
  List<Object?> get props => [];
}

class ClientPostsInitial extends ClientPostsState {}

class ClientPostsLoading extends ClientPostsState {}

class ClientPostsLoaded extends ClientPostsState {
  final List<PostModel> posts;
  const ClientPostsLoaded({required this.posts});

  @override
  List<Object?> get props => [posts];
}

class ClientPostsError extends ClientPostsState {
  final String message;
  const ClientPostsError({required this.message});

  @override
  List<Object?> get props => [message];
}

// --- Cubit ---
class ClientPostsCubit extends Cubit<ClientPostsState> {
  final PostRepository _postRepository;
  StreamSubscription<List<PostModel>>? _subscription;
  String _currentClientId = '';

  ClientPostsCubit({required PostRepository postRepository})
    : _postRepository = postRepository,
      super(ClientPostsInitial());

  void loadClientPosts(String clientId) {
    _currentClientId = clientId;
    emit(ClientPostsLoading());
    _subscription?.cancel();
    _subscription = _postRepository
        .getUnifiedClientJobs(clientId)
        .listen(
          (posts) {
            if (!isClosed) emit(ClientPostsLoaded(posts: posts));
          },
          onError: (error) {
            if (!isClosed) emit(ClientPostsError(message: error.toString()));
          },
        );
  }

  Future<void> refresh() async {
    if (_currentClientId.isNotEmpty) {
      loadClientPosts(_currentClientId);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
