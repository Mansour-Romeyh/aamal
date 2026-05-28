import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:works/features/chat/data/models/message_model.dart';
import 'package:works/features/chat/data/repositories/chat_repository.dart';
import 'package:works/core/services/notification_service.dart';
import 'package:works/features/auth/data/repositories/auth_repository.dart';
import 'package:works/app/di/injection_container.dart';
import 'package:works/core/constants/firebase_constants.dart';

part 'chat_state.dart';

/// Cubit لإدارة الشات
class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _chatRepository;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _conversationSubscription;
  List<MessageModel> _currentMessages = [];
  bool _isConversationClosed = false;
  Map<String, bool> _typingStatus = {};
  Map<String, String> _participantNames = {};
  String? _postId;
  String? _postTitle;

  ChatCubit({required ChatRepository chatRepository})
    : _chatRepository = chatRepository,
      super(const ChatInitial());

  // ── جلب أو إنشاء محادثة ───────────────────────────────────────
  Future<String> getOrCreateConversation({
    required String user1Id,
    required String user1Name,
    required String user2Id,
    required String user2Name,
    required String postId,
    required String postTitle,
  }) async {
    final conversation = await _chatRepository.getOrCreateConversation(
      user1Id: user1Id,
      user1Name: user1Name,
      user2Id: user2Id,
      user2Name: user2Name,
      postId: postId,
      postTitle: postTitle,
    );
    return conversation.id;
  }

  // ── تحميل الرسائل (real-time) ─────────────────────────────────
  void loadMessages(
    String conversationId,
    String currentUserId, {
    bool isReadOnly = false,
  }) {
    emit(const ChatLoading());

    _messagesSubscription?.cancel();
    _conversationSubscription?.cancel();

    // تعليم الرسائل الحالية كمقروءة عند البدء (فقط إذا لم يكن وضع القراءة فقط)
    if (!isReadOnly) {
      markAsRead(conversationId, currentUserId);
    }

    // استماع للرسائل
    _messagesSubscription = _chatRepository
        .getMessages(conversationId)
        .listen(
          (messages) {
            _currentMessages = messages;

            // إذا كان هناك رسائل غير مقروءة من الطرف الآخر، علمها كمقروءة (فقط في وضع المشاركة)
            final hasUnread = messages.any(
              (m) => !m.isRead && m.senderId != currentUserId,
            );
            if (hasUnread && !isReadOnly) {
              markAsRead(conversationId, currentUserId);
            }

            _emitLoadedState();
          },
          onError: (e) {
            emit(const ChatError(message: 'فشل في تحميل الرسائل'));
          },
        );

    // استماع لحالة المحادثة (هل هي مغلقة؟ ومن يكتب الآن؟ وهل هناك بيانات شغل؟)
    _conversationSubscription = _chatRepository
        .getConversation(conversationId)
        .listen((conversation) {
          _isConversationClosed = conversation.isClosed;
          _typingStatus = conversation.typingStatus;
          _participantNames = conversation.participantNames;
          _postId = conversation.postId;
          _postTitle = conversation.postTitle;

          // فحص ذكي: إذا كانت الرسائل في المحادثة غير مقروءة والمرسل ليس المستخدم الحالي، علمها كمقروءة
          // هذا يعالج حالة أن العلم `isLastMessageRead` غير متوافق مع حالة الرسائل
          if (!conversation.isLastMessageRead &&
              conversation.lastMessageSenderId != currentUserId &&
              !isReadOnly) {
            markAsRead(conversationId, currentUserId);
          }

          _emitLoadedState();
        }, onError: (e) => debugPrint('❌ Conversation Status Error: $e'));
  }

  void _emitLoadedState() {
    if (!isClosed) {
      emit(
        MessagesLoaded(
          messages: _currentMessages,
          isClosed: _isConversationClosed,
          typingStatus: _typingStatus,
          participantNames: _participantNames,
          postId: _postId,
          postTitle: _postTitle,
        ),
      );
    }
  }

  // ── تحديث حالة الكتابة ──────────────────────────────────────
  Future<void> setTypingStatus(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    try {
      await _chatRepository.setTypingStatus(conversationId, userId, isTyping);
    } catch (e) {
      debugPrint('❌ Set Typing Status Error: $e');
    }
  }

  // ── إرسال رسالة ──────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    required String receiverId,
    bool isLocation = false,
    double? latitude,
    double? longitude,
  }) async {
    // دعم فني يقدر يرسل حتى لو المحادثة "مغلقة" (مثلاً للمتابعة)
    if (_isConversationClosed && senderId != FirebaseConstants.supportId)
      return;

    try {
      // تحديث حالة المتصل بشكل منفصل ومستقل لضمان عدم تعطيل إرسال الرسالة
      sl<AuthRepository>()
          .updateUserOnlineStatus(senderId, true)
          .catchError(
            (e) =>
                debugPrint('❌ Online Status Update Error (Non-critical): $e'),
          );

      await _chatRepository.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        isLocation: isLocation,
        latitude: latitude,
        longitude: longitude,
      );

      // ── إرسال الإشعارات ──
      // إذا كانت الرسالة موجهة للدعم الفني، نستخدم دالة الأدمنز المخصصة (التي تم توحيدها الآن)
      if (receiverId == FirebaseConstants.supportId) {
        NotificationService.instance
            .sendNotificationToAdmins(
              title: 'طلب دعم فني جديد 🛠️',
              body: 'من $senderName: $text',
              data: {
                'type': 'chat',
                'conversationId': conversationId,
                'senderName': senderName,
                'senderId': senderId,
                'isSupport': 'true',
              },
            )
            .catchError(
              (e) => debugPrint('❌ Admin Support Notification Error: $e'),
            );
      } else {
        // إشعار لمستخدم عادي أو حرفي
        NotificationService.instance
            .sendNotificationToUser(
              targetUserId: receiverId,
              title: 'رسالة جديدة من $senderName 💬',
              body: text,
              data: {
                'type': 'chat',
                'conversationId': conversationId,
                'senderName': senderName,
                'senderId': senderId,
              },
            )
            .catchError((e) => debugPrint('❌ Chat Notification Error: $e'));
      }
    } catch (e) {
      debugPrint('❌ Send Message Critical Error: $e');
      // إرسال الكود الفني للخطأ ليساعدنا في التشخيص (مثلاً permission-denied)
      emit(ChatError(message: 'فشل في إرسال الرسالة: $e'));
    }
  }

  bool _isMarkingAsRead = false;

  // ── تعليم الرسائل كمقروءة ────────────────────────────────────
  Future<void> markAsRead(String conversationId, String currentUserId) async {
    if (_isMarkingAsRead) return;

    _isMarkingAsRead = true;
    try {
      await _chatRepository.markMessagesAsRead(conversationId, currentUserId);
    } catch (e) {
      debugPrint('❌ Mark As Read error: $e');
    } finally {
      _isMarkingAsRead = false;
    }
  }

  // ── بث خطأ يدوي (Manual Error Broadcast) ──────────────────────
  void emitError(String message) {
    if (!isClosed) emit(ChatError(message: message));
  }

  // ── إيقاف متابعة الرسائل وتصفير الحالة ─────────────────────────
  void stopLoadingMessages() {
    _messagesSubscription?.cancel();
    _conversationSubscription?.cancel();
    _messagesSubscription = null;
    _conversationSubscription = null;
    _currentMessages = [];
    _isConversationClosed = false;
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    _conversationSubscription?.cancel();
    return super.close();
  }
}
