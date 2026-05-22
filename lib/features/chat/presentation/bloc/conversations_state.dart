part of 'conversations_cubit.dart';

sealed class ConversationsState extends Equatable {
  const ConversationsState();

  int unreadCount(String currentUserId) => 0;

  @override
  List<Object?> get props => [];
}

class ConversationsInitial extends ConversationsState {
  const ConversationsInitial();
}

class ConversationsLoading extends ConversationsState {
  const ConversationsLoading();
}

class ConversationsLoaded extends ConversationsState {
  final List<ConversationModel> conversations;
  const ConversationsLoaded({required this.conversations});

  @override
  int unreadCount(String currentUserId) {
    return conversations
        .where((c) => !c.isLastMessageRead && c.lastMessageSenderId != currentUserId)
        .length;
  }

  @override
  List<Object?> get props => [conversations];
}

class ConversationsError extends ConversationsState {
  final String message;
  const ConversationsError({required this.message});

  @override
  List<Object?> get props => [message];
}
