import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/post_model.dart';
import '../../data/models/offer_model.dart';
import '../../data/repositories/post_repository.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../../../core/services/notification_service.dart';

part 'post_state.dart';

class PostCubit extends Cubit<PostState> {
  final PostRepository _postRepository;
  final ChatRepository _chatRepository;

  PostCubit({
    required PostRepository postRepository,
    required ChatRepository chatRepository,
  })  : _postRepository = postRepository,
        _chatRepository = chatRepository,
        super(PostInitial());

  // إنشاء طلب جديد (بوست)
  Future<void> createPost({
    required UserModel client,
    required String title,
    required String description,
    required String specialty,
    required String location,
    double? latitude,
    double? longitude,
    required List<File> images,
  }) async {
    emit(PostLoading());
    try {
      if (latitude == null || longitude == null) {
        throw Exception('يرجى تحديد موقع الطلب من الخريطة قبل النشر');
      }
      final postId = const Uuid().v4();
      final post = PostModel(
        id: postId,
        clientId: client.uid,
        clientName: client.name,
        title: title,
        description: description,
        specialty: specialty,
        location: location,
        status: 'open',
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );

      await _postRepository.createPost(post, images);
      
      // إشعار الحرفيين بالتخصص مع الفلترة الجغرافية
      await NotificationService.instance.notifyArtisansBySpecialty(
        specialty: specialty,
        title: 'طلب جديد: $specialty',
        body: 'يوجد طلب جديد في تخصصك من العميل ${client.name}',
        clientLat: latitude,
        clientLng: longitude,
        data: {
          'type': 'new_post',
          'postId': postId,
        },
      );

      emit(const PostSuccess(message: 'تم نشر الطلب بنجاح'));
    } catch (e) {
      emit(PostError(message: 'حدث خطأ أثناء نشر الطلب: $e'));
    }
  }

  // تعديل بوست
  Future<void> updatePost({
    required String postId,
    required String title,
    required String description,
    required String specialty,
    required String location,
  }) async {
    emit(PostLoading());
    try {
      await _postRepository.updatePostDetails(postId, {
        'title': title,
        'description': description,
        'specialty': specialty,
        'location': location,
      }, isDirectRequest: false); // تعديل البوست دائماً في جدول البوستات حالياً
      emit(const PostSuccess(message: 'تم تعديل الطلب بنجاح'));
    } catch (e) {
      emit(PostError(message: 'حدث خطأ أثناء تعديل الطلب: $e'));
    }
  }

  // حذف بوست
  Future<void> deletePost(String postId) async {
    emit(PostLoading());
    try {
      await _postRepository.deletePost(postId);
      emit(const PostSuccess(message: 'تم حذف الطلب بنجاح'));
    } catch (e) {
      emit(PostError(message: 'حدث خطأ أثناء حذف الطلب: $e'));
    }
  }

  // قبول طلب من قِبل الحرفي
  Future<void> acceptPost({
    required PostModel post,
    required String artisanId,
    required String artisanName,
  }) async {
    emit(PostLoading());
    try {
      await _postRepository.updatePostStatus(post.id, 'accepted', artisanId: artisanId, isDirectRequest: post.isDirectRequest);
      
      // إشعار العميل بقبول الطلب (غير ملزم، لا يعطل قبول الطلب نفسه)
      debugPrint('🔔 Triggering notification for client: ${post.clientId}');
      NotificationService.instance.sendNotificationToUser(
        targetUserId: post.clientId,
        title: 'تم قبول طلبك: ${post.title} 🛠️',
        body: 'قام الحرفي $artisanName بقبول طلبك، يمكنك الآن التواصل معه.',
        data: {
          'type': 'post_accepted',
          'postId': post.id,
        },
      ).catchError((e) => debugPrint('❌ Accept Post Notification Error: $e'));

      emit(const PostSuccess(message: 'تم قبول الطلب، يمكنك الآن التواصل مع العميل'));
    } catch (e) {
      emit(PostError(message: 'حدث خطأ: $e'));
    }
  }

  // رفض طلب مباشر
  Future<void> declinePost({
    required PostModel post,
    required String artisanName,
  }) async {
    emit(PostLoading());
    try {
      await _postRepository.updatePostStatus(post.id, 'declined', isDirectRequest: post.isDirectRequest);
      
      // إشعار العميل بالرفض
      NotificationService.instance.sendNotificationToUser(
        targetUserId: post.clientId,
        title: 'اعتذار عن الطلب: ${post.title}',
        body: 'اعتذر الحرفي $artisanName عن قبول طلبك المباشر حالياً.',
        data: {
          'type': 'post_declined',
          'postId': post.id,
        },
      ).catchError((e) => debugPrint('❌ Decline Post Notification Error: $e'));

      emit(const PostSuccess(message: 'تم الاعتذار عن الطلب بنجاح'));
    } catch (e) {
      emit(PostError(message: 'حدث خطأ: $e'));
    }
  }

  // تحديث حالة طلب خدمة (Service Request) بشكل مباشر
  Future<void> updateRequestStatus(String requestId, String status) async {
    emit(PostLoading());
    try {
      await _postRepository.updatePostStatus(requestId, status, isDirectRequest: true);
      emit(PostSuccess(message: 'تم تحديث حالة الطلب إلى $status'));
    } catch (e) {
      emit(PostError(message: 'حدث خطأ: $e'));
    }
  }

  // اكتمال العمل
  Future<void> completePost(PostModel post) async {
    emit(PostLoading());
    try {
      await _postRepository.updatePostStatus(post.id, 'completed', isDirectRequest: post.isDirectRequest);

      // إشعار الحرفي باكتمال العمل (غير ملزم)
      if (post.acceptedArtisanId != null) {
        // 1. إرسال إشعار
        NotificationService.instance.sendNotificationToUser(
          targetUserId: post.acceptedArtisanId!,
          title: 'اكتمل العمل: ${post.title} ✅',
          body: 'لقد أكد العميل اكتمال العمل بنجاح. شكراً لك!',
          data: {
            'type': 'post_completed',
            'postId': post.id,
          },
        ).catchError((e) => debugPrint('❌ Complete Post Notification Error: $e'));

        // 2. إرسال رسالة في الشات لتوثيق الانتهاء
        try {
          final conversation = await _chatRepository.getOrCreateConversation(
            user1Id: post.clientId,
            user1Name: post.clientName,
            user2Id: post.acceptedArtisanId!,
            user2Name: 'الحرفي', // يمكن تحسينه بجلب الاسم الفعلي إذا توفر
            postId: post.id,
            postTitle: post.title,
          );
          
          await _chatRepository.sendMessage(
            conversationId: conversation.id,
            senderId: post.clientId,
            receiverId: post.acceptedArtisanId!,
            text: '✅ تم انتهاء العمل بنجاح. شكراً لك!',
          );

          // 3. إغلاق المحادثة
          await _chatRepository.closeConversation(conversation.id);
        } catch (e) {
          debugPrint('❌ Complete Post Chat Message Error: $e');
        }
      }

      emit(const PostSuccess(message: 'تم إنهاء العمل بنجاح'));
    } catch (e) {
      emit(PostError(message: 'حدث خطأ: $e'));
    }
  }

  // إرسال عرض سعر
  Future<void> sendOffer({
    required String postId,
    required String artisanId,
    required String artisanName,
    required double artisanRating,
    required double price,
    required String comment,
    required String clientId,
    required String postTitle,
  }) async {
    emit(PostLoading());
    try {
      final offer = OfferModel(
        id: const Uuid().v4(),
        postId: postId,
        artisanId: artisanId,
        artisanName: artisanName,
        artisanRating: artisanRating,
        price: price,
        comment: comment,
        createdAt: DateTime.now(),
      );

      await _postRepository.sendOffer(offer);

      // إشعار العميل
      NotificationService.instance.sendNotificationToUser(
        targetUserId: clientId,
        title: 'عرض جديد لطلبك: $postTitle 💰',
        body: 'قام الحرفي $artisanName بتقديم عرض سعر جديد.',
        data: {
          'type': 'new_offer',
          'postId': postId,
        },
      ).catchError((e) => debugPrint('❌ Send Offer Notification Error: $e'));

      emit(const PostSuccess(message: 'تم إرسال عرضك بنجاح'));
    } catch (e) {
      emit(PostError(message: 'حدث خطأ: $e'));
    }
  }

  // قبول عرض سعر
  Future<void> acceptOffer({
    required String postId,
    required String offerId,
    required String artisanId,
    required String artisanName,
    required String postTitle,
    required String clientId,
    required String clientName,
    required double price,
  }) async {
    emit(PostLoading());
    try {
      await _postRepository.acceptOffer(postId, offerId, artisanId, price);

      // إنشاء أو جلب المحادثة
      final conversation = await _chatRepository.getOrCreateConversation(
        user1Id: clientId,
        user1Name: clientName,
        user2Id: artisanId,
        user2Name: artisanName,
        postId: postId,
        postTitle: postTitle,
      );

      // إشعار الحرفي
      NotificationService.instance.sendNotificationToUser(
        targetUserId: artisanId,
        title: 'تم قبول عرضك! 🎉',
        body: 'وافق العميل $clientName على عرضك لطلب: $postTitle. يمكنك الآن التواصل معه.',
        data: {
          'type': 'offer_accepted',
          'postId': postId,
          'conversationId': conversation.id,
        },
      ).catchError((e) => debugPrint('❌ Accept Offer Notification Error: $e'));

      emit(PostSuccess(
        message: 'تم قبول العرض بنجاح، جارٍ فتح المحادثة...',
        extraData: {
          'conversationId': conversation.id,
          'otherUserId': artisanId,
          'otherUserName': artisanName,
        },
      ));

    } catch (e) {
      emit(PostError(message: 'حدث خطأ: $e'));
    }
  }
}
