part of 'chat_cubit.dart';

sealed class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class MessagesLoaded extends ChatState {
  final List<MessageModel> messages;
  final bool isClosed;
  final Map<String, bool> typingStatus;
  final Map<String, String> participantNames;
  final String? postId;
  final String? postTitle;

  const MessagesLoaded({
    required this.messages,
    this.isClosed = false,
    this.typingStatus = const {},
    this.participantNames = const {},
    this.postId,
    this.postTitle,
  });

  @override
  List<Object?> get props => [messages, isClosed, typingStatus, participantNames, postId, postTitle];
}

class ChatError extends ChatState {
  final String message;
  const ChatError({required this.message});

  @override
  List<Object?> get props => [message];
}
