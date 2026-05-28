import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../models/message_model.dart';

/// مستودع المحادثات والرسائل
class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _conversationsRef =>
      _firestore.collection(FirebaseConstants.conversationsCollection);

  // ── إنشاء أو جلب محادثة بين مستخدمين ─────────────────────────
  Future<ConversationModel> getOrCreateConversation({
    required String user1Id,
    required String user1Name,
    required String user2Id,
    required String user2Name,
    required String postId,
    required String postTitle,
  }) async {
    // جلب بيانات الطرفين لضمان وجود الصور والأدوار
    final user1Doc = await _firestore.collection(FirebaseConstants.usersCollection).doc(user1Id).get();
    final user2Doc = await _firestore.collection(FirebaseConstants.usersCollection).doc(user2Id).get();
    
    final user1Data = user1Doc.data() ?? {};
    final user2Data = user2Doc.data() ?? {};

    final user1Role = user1Id == FirebaseConstants.supportId ? 'admin' : (user1Data['role'] ?? 'client');
    final user2Role = user2Id == FirebaseConstants.supportId ? 'admin' : (user2Data['role'] ?? 'client');
    
    final user1Image = user1Data['profileImage'] ?? '';
    final user2Image = user2Data['profileImage'] ?? '';

    final user1Specialty = user1Data['specialty'] ?? '';
    final user2Specialty = user2Data['specialty'] ?? '';

    // البحث عن محادثة موجودة بين المستخدمين
    final existing = await _conversationsRef
        .where('participants', arrayContains: user1Id)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      final docPostId = data['postId'] ?? '';

      // يجب أن يتطابق الطرفان وأيضاً رقم الطلب (PostId) لإنشاء شات مخصص لكل طلب
      if (participants.contains(user2Id) && docPostId == postId) {
        // تحديث البيانات إذا كانت ناقصة (للمحادثات القديمة)
        if (data['participantRoles'] == null || data['participantImages'] == null || data['participantSpecialties'] == null) {
          await doc.reference.update({
            'participantRoles': {user1Id: user1Role, user2Id: user2Role},
            'participantImages': {user1Id: user1Image, user2Id: user2Image},
            'participantSpecialties': {user1Id: user1Specialty, user2Id: user2Specialty},
          });
        }
        return ConversationModel.fromFirestore(await doc.reference.get());
      }
    }

    // إنشاء محادثة جديدة
    final conversation = ConversationModel(
      id: '',
      participants: [user1Id, user2Id],
      postId: postId,
      postTitle: postTitle,
      lastMessageTime: DateTime.now(),
      participantNames: {user1Id: user1Name, user2Id: user2Name},
      participantRoles: {user1Id: user1Role, user2Id: user2Role},
      participantImages: {user1Id: user1Image, user2Id: user2Image},
      participantSpecialties: {user1Id: user1Specialty, user2Id: user2Specialty},
    );

    final conversationMap = conversation.toMap();
    conversationMap['unread_count'] = {user1Id: 0, user2Id: 0};

    final docRef = await _conversationsRef.add(conversationMap);
    return ConversationModel(
      id: docRef.id,
      participants: conversation.participants,
      postId: conversation.postId,
      postTitle: conversation.postTitle,
      lastMessageTime: conversation.lastMessageTime,
      participantNames: conversation.participantNames,
      participantRoles: conversation.participantRoles,
      participantImages: conversation.participantImages,
      participantSpecialties: conversation.participantSpecialties,
      isClosed: conversation.isClosed,
    );
  }

  // ── إرسال رسالة ──────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    bool isLocation = false,
    double? latitude,
    double? longitude,
  }) async {
    final message = MessageModel(
      id: '',
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      isLocation: isLocation,
      latitude: latitude,
      longitude: longitude,
    );

    // إضافة الرسالة
    await _conversationsRef
        .doc(conversationId)
        .collection(FirebaseConstants.messagesSubcollection)
        .add(message.toMap());

    // تحديث آخر رسالة في المحادثة
    await _conversationsRef.doc(conversationId).update({
      'lastMessage': text,
      'lastMessageSenderId': senderId,
      'lastMessageTime': Timestamp.now(),
      'isLastMessageRead': false,
      'unread_count.$receiverId': FieldValue.increment(1),
    });
  }

  // ── إغلاق المحادثة ───────────────────────────────────────────
  Future<void> closeConversation(String conversationId) async {
    await _conversationsRef.doc(conversationId).update({'isClosed': true});
  }

  // ── تحديث حالة الكتابة ──────────────────────────────────────
  Future<void> setTypingStatus(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    await _conversationsRef.doc(conversationId).update({
      'typingStatus.$userId': isTyping,
    });
  }

  // ── جلب رسائل المحادثة (real-time) ────────────────────────────
  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .collection(FirebaseConstants.messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  // ── جلب محادثات المستخدم ──────────────────────────────────────
  Stream<List<ConversationModel>> getUserConversations(String userId) {
    return _conversationsRef
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConversationModel.fromFirestore(doc))
              .toList(),
        );
  }

  // ── جلب محادثة معينة (real-time) ─────────────────────────────
  Stream<ConversationModel> getConversation(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .snapshots()
        .map((doc) => ConversationModel.fromFirestore(doc));
  }

  // ── تعليم الرسائل كمقروءة ────────────────────────────────────
  Future<void> markMessagesAsRead(
    String conversationId,
    String currentUserId,
  ) async {
    // جلب بيانات المحادثة للتحقق من المشاركين
    final convDoc = await _conversationsRef.doc(conversationId).get();
    if (!convDoc.exists) return;

    final data = convDoc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? []);

    // منع التعليم كمقروء إذا كان الشخص مجرد مراقب (ليس طرفاً في المحادثة وليس الدعم الفني)
    final isParticipant = participants.contains(currentUserId);
    final isSupport = currentUserId == FirebaseConstants.supportId;

    if (!isParticipant && !isSupport) {
      return;
    }

    // البحث عن الرسائل غير المقروءة التي لم يرسلها المستخدم الحالي
    final messages = await _conversationsRef
        .doc(conversationId)
        .collection(FirebaseConstants.messagesSubcollection)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    bool hasUpdates = false;

    if (messages.docs.isNotEmpty) {
      for (var doc in messages.docs) {
        if (doc.data()['senderId'] != currentUserId) {
          batch.update(doc.reference, {'isRead': true});
          hasUpdates = true;
        }
      }
    }

    // حتى لو لم تكن هناك رسائل غير مقروءة، قد يكون العلم في مستوى المحادثة غير صحيح (Stale)
    // لذا نتأكد من تحديثه إذا كان المرسل الأخير ليس المستخدم الحالي
    final lastSenderId = data['lastMessageSenderId'] ?? '';
    final isLastRead = data['isLastMessageRead'] ?? true;

    if (hasUpdates || (!isLastRead && lastSenderId != currentUserId)) {
      if (hasUpdates) {
        await batch.commit();
      }

      // تحديث العلم في مستوى المحادثة لضمان اختفاء النقطة من القائمة
      await _conversationsRef.doc(conversationId).update({
        'isLastMessageRead': true,
        'unread_count.$currentUserId': 0,
      });
    }
  }

  // ── جلب كل المحادثات (للأدمن) ─────────────────────────────────
  Stream<List<ConversationModel>> getAllConversations() {
    return _conversationsRef
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConversationModel.fromFirestore(doc))
              .toList(),
        );
  }

  // ── مزامنة البيانات الوصفية لجميع محادثات مستخدم معين ───────────
  Future<void> syncConversationsMetadata(String userId) async {
    try {
      final query = await _conversationsRef.where('participants', arrayContains: userId).get();
      
      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        
        final existingRoles = data['participantRoles'] as Map? ?? {};
        final existingImages = data['participantImages'] as Map? ?? {};
        final existingSpecialties = data['participantSpecialties'] as Map? ?? {};
        
        // تحديث إذا كانت البيانات ناقصة أو إذا كان هناك 'client' قد يكون تغير دوره
        bool needsUpdate = existingRoles.isEmpty || 
                          existingImages.isEmpty || 
                          existingSpecialties.isEmpty ||
                          existingRoles.values.contains('client') ||
                          (participants.contains(FirebaseConstants.supportId) && 
                           existingRoles[FirebaseConstants.supportId] != 'admin');

        if (needsUpdate) {
          Map<String, String> roles = {};
          Map<String, String> images = {};
          Map<String, String> specialties = {};
          
          for (var pId in participants) {
            if (pId == FirebaseConstants.supportId) {
              roles[pId] = 'admin';
              images[pId] = '';
              specialties[pId] = '';
              continue;
            }
            
            final uDoc = await _firestore.collection(FirebaseConstants.usersCollection).doc(pId).get();
            if (uDoc.exists) {
              final uData = uDoc.data() as Map<String, dynamic>;
              roles[pId] = uData['role'] ?? 'client';
              images[pId] = uData['profileImage'] ?? '';
              specialties[pId] = uData['specialty'] ?? '';
            } else {
              roles[pId] = 'client';
              images[pId] = '';
              specialties[pId] = '';
            }
          }
          
          await doc.reference.update({
            'participantRoles': roles,
            'participantImages': images,
            'participantSpecialties': specialties,
          });
        }
      }
    } catch (e) {
      print('Error syncing metadata: $e');
    }
  }
}
