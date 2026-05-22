part of 'post_cubit.dart';

abstract class PostState extends Equatable {
  const PostState();

  @override
  List<Object?> get props => [];
}

class PostInitial extends PostState {}

class PostLoading extends PostState {}

class PostSuccess extends PostState {
  final String message;
  final Map<String, dynamic>? extraData;
  const PostSuccess({required this.message, this.extraData});

  @override
  List<Object?> get props => [message, extraData];
}


class PostError extends PostState {
  final String message;
  const PostError({required this.message});

  @override
  List<Object?> get props => [message];
}
