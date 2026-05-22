import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository.dart';

part 'conversations_state.dart';

class ConversationsCubit extends Cubit<ConversationsState> {
  final ChatRepository _chatRepository;
  StreamSubscription? _conversationsSubscription;

  ConversationsCubit({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(const ConversationsInitial());

  void loadConversations(String userId) {
    emit(const ConversationsLoading());
    _conversationsSubscription?.cancel();
    _conversationsSubscription = _chatRepository.getUserConversations(userId).listen(
      (conversations) {
        emit(ConversationsLoaded(conversations: conversations));
        // مزامنة البيانات الوصفية في الخلفية لضمان دقة الأدوار والصور
        _chatRepository.syncConversationsMetadata(userId);
      },
      onError: (e) {
        emit(const ConversationsError(message: 'فشل في تحميل المحادثات'));
      },
    );
  }

  /// إيقاف التحديثات مؤقتاً لتقليل استهلاك المعالج خلال التنقل
  void pauseUpdates() {
    _conversationsSubscription?.pause();
  }

  /// استئناف التحديثات
  void resumeUpdates() {
    _conversationsSubscription?.resume();
  }

  @override
  Future<void> close() {
    _conversationsSubscription?.cancel();
    return super.close();
  }
}
