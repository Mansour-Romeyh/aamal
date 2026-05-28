import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../data/models/message_model.dart';
import '../bloc/chat_cubit.dart';
import 'package:works/features/reports/presentation/widgets/report_dialog.dart';
import 'package:works/app/widgets/app_components.dart';
import 'package:works/features/auth/data/models/user_model.dart';
import 'package:works/core/services/notification_service.dart';
import 'package:works/features/auth/data/repositories/auth_repository.dart';
import 'package:works/app/di/injection_container.dart';
import 'package:works/core/constants/firebase_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:works/app/widgets/map_location_picker.dart';

import '../bloc/conversations_cubit.dart' show ConversationsCubit;

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;
  final bool isAdminView;
  final bool isSupportView;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
    this.isAdminView = false,
    this.isSupportView = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  late ChatCubit _chatCubit;
  String _currentUserId = '';
  bool _isAdminMode = false;
  bool _isSupportMode = false;

  int _loadStage = 0; // 0: Skeleton, 1: Shell only, 2: Full UI + Logic

  Stream<UserModel>? _otherUserStream;

  @override
  void initState() {
    super.initState();
    _chatCubit = context.read<ChatCubit>();
    
    // محاربة الـ Race Condition (Ant-Race Strategy)
    _initializeChat();

    if (!_isAdminMode || _isSupportMode) {
      _messageController.addListener(_onTextChanged);
    }
  }

  void _initializeChat() {
    final authState = context.read<AuthCubit>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    final isSupportConv = widget.conversationId.contains(
      FirebaseConstants.supportId,
    );
    
    _isAdminMode = widget.isAdminView;
    _isSupportMode = widget.isSupportView || isSupportConv;

    // 🚀 المسار السريع للفنيين والإدارة (Bypass Auth Check)
    // إذا كنت أدمن أو دعم، لا ننتظر أي توثيق، نستخدم هويتك فوراً من الإشعار أو الثوابت
    if (_isAdminMode || _isSupportMode) {
      debugPrint('⚡ Super Fast Track: Admin/Support Mode detected');
      setState(() {
        _currentUserId = _isSupportMode ? FirebaseConstants.supportId : (user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '');
        _loadStage = 2; // تفعيل الواجهة فوراً
      });

      _executeFastInit();
      return;
    }

    // للمستخدمين العاديين، ننتظر التوثيق
    setState(() {
      _currentUserId = user?.uid ?? '';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_currentUserId.isEmpty) {
        if (context.read<AuthCubit>().state is AuthLoading) return;
        
        _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (_currentUserId.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        }
      }

      if (_currentUserId.isNotEmpty) {
        _executeFastInit();
      } else {
        final currentAuth = context.read<AuthCubit>().state;
        if (currentAuth is AuthUnauthenticated) {
          if (mounted) setState(() => _loadStage = 2);
          _chatCubit.emitError('يجب تسجيل الدخول أولاً');
        }
      }
    });
  }

  void _executeFastInit() {
    if (_currentUserId.isEmpty && !(_isAdminMode || _isSupportMode)) return;

    debugPrint('🎬 Executing Chat Init (User: $_currentUserId)');
    try {
      context.read<ConversationsCubit>().pauseUpdates();
      if (_loadStage < 2) setState(() => _loadStage = 2);

      NotificationService.instance.currentOpenedChatId = widget.conversationId;
      final targetResetUid = _isSupportMode ? FirebaseConstants.supportId : _currentUserId;
      
      // تنفيذ تصفير العداد والوجود بحذر (لو الأدمن لسه مش مسجل توثيق كامل، نستخدم الهوية المتاحة)
      if (targetResetUid.isNotEmpty) {
        sl<AuthCubit>().resetUnreadCount(targetResetUid, widget.conversationId);
        sl<AuthCubit>().updateActiveChatId(widget.conversationId, isSupport: _isSupportMode);
      }

      if (widget.otherUserId.isNotEmpty && _otherUserStream == null) {
        setState(() {
          _otherUserStream = sl<AuthRepository>().getUserStream(widget.otherUserId);
        });
      }
      
      _chatCubit.loadMessages(
        widget.conversationId,
        _isSupportMode ? FirebaseConstants.supportId : _currentUserId,
        isReadOnly: _isAdminMode && !_isSupportMode,
      );
    } catch (e) {
      debugPrint('⚠️ Fast Init Warning: $e');
    }
  }

  Widget _buildSkeletonUI() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.otherUserName,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body:
          const SizedBox.shrink(), // إزالة آخر علامة تحميل لضمان نقاء الواجهة تماماً
    );
  }

  void _onTextChanged() {
    if (!mounted || (_isAdminMode && !_isSupportMode)) return;
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _chatCubit.setTypingStatus(widget.conversationId, _currentUserId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping && mounted) {
        _isTyping = false;
        _chatCubit.setTypingStatus(
          widget.conversationId,
          _currentUserId,
          false,
        );
      }
    });
  }

  @override
  void dispose() {
    NotificationService.instance.currentOpenedChatId = null;

    // استئناف تحديثات قائمة المحادثات الخلفية
    try {
      sl<ConversationsCubit>().resumeUpdates();
    } catch (e) {
      debugPrint('⚠️ Resume Error: $e');
    }

    // مسح الحالة النشطة بشكل آمن لضمان عدم تعليق الواجهة
    final authCubit = sl<AuthCubit>();
    authCubit.updateActiveChatId(null, isSupport: _isSupportMode);

    if (_isSupportMode) {
      authCubit.removeActiveSupportChat(widget.conversationId);
    }

    _chatCubit.stopLoadingMessages();
    if (_currentUserId.isNotEmpty && _isTyping) {
      _chatCubit.setTypingStatus(widget.conversationId, _currentUserId, false);
    }
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _sendMessage() {
    // 1. التحقق من وضع الأدمن والمعاينة
    if (_isAdminMode && !_isSupportMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ وضع المعاينة فقط: لا يمكن الإرسال إلا في محادثات الدعم الفني',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 2. التحقق من حالة التوثيق
    final authState = context.read<AuthCubit>().state;

    // محاولة الحصول على بيانات المستخدم حتى لو الحالة مش Authenticated (احتياطي للأدمن)
    UserModel? currentUser;
    if (authState is AuthAuthenticated) {
      currentUser = authState.user;
    }

    // لو إحنا في محادثة دعم، نقدر نبعت حتى لو مفيش مستخدم مسجل (زي حالة الأدمن اللي داخل بكلمة سر)
    if (currentUser != null || _isSupportMode) {
      // التأكد من استخدام هوية الدعم الفني إذا كانت هذه محادثة دعم
      final finalSenderId = _isSupportMode
          ? FirebaseConstants.supportId
          : (currentUser?.uid ?? '');
      final finalSenderName = _isSupportMode
          ? 'الدعم الفني'
          : (currentUser?.name ?? 'مستخدم');

      _chatCubit.sendMessage(
        conversationId: widget.conversationId,
        senderId: finalSenderId,
        senderName: finalSenderName,
        text: text,
        receiverId: widget.otherUserId,
      );
      _messageController.clear();
      _scrollToBottom();
    } else {
      // لو لسه فيه مشكلة، نظهر الحالة الحالية للتشخيص
      final stateName = authState.runtimeType.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ فشل التحقق من الهوية (الحالة: $stateName). حاول الخروج والدخول ثانية.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          0.0, // reverse ListView: 0 is the bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendLocation() async {
    if (_isAdminMode && !_isSupportMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ وضع المعاينة فقط: لا يمكنك الإرسال',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await MapLocationPicker.show(context);
    if (result != null && mounted) {
      final text = result.address.isNotEmpty ? result.address : 'موقعي الجغرافي';
      
      final authState = context.read<AuthCubit>().state;
      UserModel? currentUser;
      if (authState is AuthAuthenticated) {
        currentUser = authState.user;
      }
      final finalSenderId = _isSupportMode
          ? FirebaseConstants.supportId
          : (currentUser?.uid ?? '');
      final finalSenderName = _isSupportMode
          ? 'الدعم الفني'
          : (currentUser?.name ?? 'مستخدم');

      _chatCubit.sendMessage(
        conversationId: widget.conversationId,
        senderId: finalSenderId,
        senderName: finalSenderName,
        text: '📍 ' + text,
        receiverId: widget.otherUserId,
        isLocation: true,
        latitude: result.latitude,
        longitude: result.longitude,
      );
      _scrollToBottom();
    }
  }

  String _formatLastSeen(DateTime? lastSeen, DateTime? createdAt) {
    final targetDate = lastSeen ?? createdAt;
    if (targetDate == null) return 'نشط منذ فترة';
    final now = DateTime.now();
    final diff = now.difference(targetDate);
    if (diff.inMinutes < 1) return 'منذ ثوانٍ';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'نشط منذ ${_formatDate(targetDate)}';
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (!_isDifferentDay(date, now)) return 'اليوم';
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1)
      return 'أمس';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadStage == 0) {
      return _buildSkeletonUI();
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listenWhen: (prev, curr) => prev is AuthLoading && curr is AuthAuthenticated,
          listener: (context, state) {
            debugPrint('🔄 Auth settled, retrying chat init...');
            _initializeChat();
          },
        ),
        BlocListener<ChatCubit, ChatState>(
          listenWhen: (prev, curr) {
            if (prev is MessagesLoaded && curr is MessagesLoaded) {
              return curr.messages.length > prev.messages.length;
            }
            return curr is MessagesLoaded && prev is! MessagesLoaded;
          },
          listener: (context, state) {
            if (state is MessagesLoaded) {
              // 1. النزول للرسالة الجديدة تلقائياً
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              // 2. التحقق الديناميكي: لو الأدمن فتح محادثة دعم من بره تبويب الدعم
              // نتأكد إننا في وضع الدعم عشان يقدر يرد بصفة رسمية
              final isSupport = state.participantNames.containsKey(
                FirebaseConstants.supportId,
              );
              if (isSupport && _isAdminMode && !_isSupportMode) {
                if (_currentUserId != FirebaseConstants.supportId) {
                  setState(() {
                    _isSupportMode = true;
                    _currentUserId = FirebaseConstants.supportId;
                  });
                  _chatCubit.loadMessages(
                    widget.conversationId,
                    _currentUserId,
                    isReadOnly: false,
                  );
                }
              }
            }
          },
        ),
      ],
      child: BlocBuilder<ChatCubit, ChatState>(
        buildWhen: (prev, curr) {
          // لا نعيد بناء الهيكل الخارجي إلا إذا انتقلنا من حالة تحميل إلى نجاح أو خطأ
          return prev.runtimeType != curr.runtimeType;
        },
        builder: (context, chatState) {
          final authState = context.read<AuthCubit>().state;

          return Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: const Color(0xFFF0F2F5),
            appBar: _buildAppBar(authState),
            body: Column(
              children: [
                // ── Moderation Banner ──
                if (_isAdminMode && !_isSupportMode) _buildModerationBanner(),

                // ── Order Context Bar ──
                if (_loadStage >= 1 &&
                    !_isAdminMode &&
                    !_isSupportMode &&
                    widget.otherUserId != FirebaseConstants.supportId)
                  _buildOrderContextBar(),

                // ── Messages List ──
                Expanded(
                  child: RepaintBoundary(
                    child: _buildMainContent(chatState, authState),
                  ),
                ),

                // ── Typing Indicator ──
                if (_loadStage >= 2) _buildTypingIndicator(),

                // ── Input Area ──
                if (_loadStage >= 2 && !(_isAdminMode && !_isSupportMode))
                  _buildInputArea(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(ChatState chatState, AuthState authState) {
    // نستخدم BlocBuilder داخلي مخصص فقط لقائمة الرسائل لمنع تأثر بقية الصفحة
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (prev, curr) {
        if (prev is MessagesLoaded && curr is MessagesLoaded) {
          // نعيد بناء القائمة فقط إذا تغير عدد الرسائل أو حالة الإغلاق
          return prev.messages.length != curr.messages.length || 
                 prev.isClosed != curr.isClosed;
        }
        return prev.runtimeType != curr.runtimeType;
      },
      builder: (context, state) {
        if (state is ChatLoading || (authState is AuthLoading && _currentUserId.isEmpty)) {
          return _buildShimmerMessages();
        }

        if (state is ChatError) {
          return AppComponents.errorState(
            message: state.message,
            onRetry: () => _initializeChat(),
          );
        }

        if (state is MessagesLoaded) {
          return _buildMessagesList(state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  APP BAR
  // ══════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(AuthState authState) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black12,
      centerTitle: false,
      titleSpacing: 0,
      foregroundColor: AppColors.textPrimary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      title: (_isAdminMode && !_isSupportMode)
          ? Text(
              '🔒 معاينة المحادثة',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            )
          : _buildChatHeader(),
      actions: [
        StreamBuilder<UserModel>(
          stream: _otherUserStream,
          builder: (context, snapshot) {
            final user = snapshot.data;
            if (user == null || user.phone.isEmpty || widget.otherUserId == FirebaseConstants.supportId) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.call_rounded, color: AppColors.primary, size: 22),
              tooltip: 'اتصال',
              onPressed: () async {
                final Uri url = Uri(scheme: 'tel', path: user.phone);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  if (context.mounted) {
                    AppComponents.showSnackBar(context, 'لا يمكن فتح تطبيق الاتصال', isError: true);
                  }
                }
              },
            );
          },
        ),
        if (!widget.isAdminView &&
            !widget.isSupportView &&
            widget.otherUserId != FirebaseConstants.supportId &&
            (authState is! AuthAuthenticated ||
                authState.user.role != FirebaseConstants.roleAdmin))
          IconButton(
            icon: const Icon(
              Icons.report_problem_outlined,
              color: AppColors.error,
              size: 22,
            ),
            tooltip: 'إبلاغ',
            onPressed: () {
              if (authState is AuthAuthenticated) {
                showDialog(
                  context: context,
                  builder: (context) => ReportDialog(
                    reporterId: authState.user.uid,
                    reportedId: widget.otherUserId,
                    chatId: widget.conversationId,
                  ),
                );
              }
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Row(
      children: [
        // Avatar
        StreamBuilder<UserModel>(
          stream: _otherUserStream,
          builder: (context, snapshot) {
            final user = snapshot.data;
            return AppComponents.userAvatar(
              imageUrl: user?.profileImage,
              name: widget.otherUserName,
              radius: 18,
              showBorder: true,
            );
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<UserModel>(
            stream: _otherUserStream,
            builder: (context, snapshot) {
              final user = snapshot.data;
              final isOnline = user?.isOnline ?? false;
              final isVerifiedAdmin =
                  user?.role == 'admin' ||
                  user?.role == 'Admin' ||
                  widget.otherUserId == FirebaseConstants.supportId;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.otherUserName,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isVerifiedAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'دعم معتمد',
                                style: GoogleFonts.cairo(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // إخفاء حالة النشاط للدعم الفني بناءً على طلب المستخدم
                  if (widget.otherUserId != FirebaseConstants.supportId)
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppColors.success
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline
                              ? 'متصل الآن'
                              : _formatLastSeen(
                                  user?.lastSeen,
                                  user?.createdAt,
                                ),
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: isOnline
                                ? AppColors.success
                                : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  MODERATION BANNER
  // ══════════════════════════════════════════════════════════════
  Widget _buildModerationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade700, Colors.amber.shade900],
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'وضع المعاينة: قراءة فقط - لا يمكنك إرسال رسائل',
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ORDER CONTEXT BAR
  // ══════════════════════════════════════════════════════════════
  Widget _buildOrderContextBar() {
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (prev, curr) {
        if (prev is MessagesLoaded && curr is MessagesLoaded) {
          return prev.postTitle != curr.postTitle || prev.postId != curr.postId;
        }
        return true;
      },
      builder: (context, state) {
        if (state is MessagesLoaded &&
            state.postTitle != null &&
            state.postTitle!.isNotEmpty &&
            state.postId != 'support') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.handyman_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بخصوص طلبك:',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                      Text(
                        state.postTitle!,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.pushNamed(
                    'postDetails',
                    queryParameters: {'postId': state.postId},
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'عرض التفاصيل',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  MESSAGES LIST (REVERSED for performance)
  // ══════════════════════════════════════════════════════════════
  Widget _buildMessagesList(MessagesLoaded state) {
    final messages = state.messages;
    final pNames = state.participantNames;

    if (messages.isEmpty) {
      return _buildEmptyChat();
    }

          // في وضع الأدمن: أول مرسل = طرف اليمين
          String? adminSideId;
          if (_isAdminMode && messages.isNotEmpty) {
            adminSideId = messages.first.senderId;
          }

    // Reversed list: last message at index 0
    final reversedMessages = messages.reversed.toList();

    return ListView.builder(
      key: const PageStorageKey('chat_messages'),
      controller: _scrollController,
      reverse: true, // أحدث رسالة في الأسفل - أداء أفضل
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: reversedMessages.length,
      itemBuilder: (context, index) {
        final message = reversedMessages[index];
        // لأن القائمة معكوسة، الرسالة التالية (الأقدم) هي index + 1
        final nextMessage = index < reversedMessages.length - 1
            ? reversedMessages[index + 1]
            : null;

        final isMine = _isSupportMode
            ? (message.senderId == FirebaseConstants.supportId)
            : (_isAdminMode
                  ? (message.senderId == adminSideId)
                  : (message.senderId == _currentUserId));

        // نعرض تاريخ اليوم إذا كانت الرسالة التالية (الأقدم) من يوم مختلف أو إذا هي آخر رسالة
        final showDate =
            nextMessage == null ||
            _isDifferentDay(nextMessage.timestamp, message.timestamp);

        // هل الرسالة التالية (الأحدث) من نفس المرسل - لتجميع الفقاعات
        final prevMessage = index > 0
            ? reversedMessages[index - 1]
            : null;
        final isFirstInGroup =
            nextMessage == null ||
            nextMessage.senderId != message.senderId ||
            showDate;
        final isLastInGroup =
            prevMessage == null ||
            prevMessage.senderId != message.senderId;

        return Column(
          children: [
            if (showDate) _buildDateHeader(message.timestamp),
            _MessageBubble(
              key: ValueKey(message.id),
              message: message,
              isMine: isMine,
              showSenderName: widget.isAdminView && isFirstInGroup,
              senderName: pNames[message.senderId] ?? 'مستخدم',
              isFirstInGroup: isFirstInGroup,
              isLastInGroup: isLastInGroup,
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TYPING INDICATOR
  // ══════════════════════════════════════════════════════════════
  Widget _buildTypingIndicator() {
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (prev, curr) {
        if (curr is! MessagesLoaded)
          return true; // إعادة البناء لو الحالة اتغيرت لغيرMessagesLoaded
        if (prev is! MessagesLoaded) return true;
        return (prev.typingStatus[widget.otherUserId] ?? false) !=
            (curr.typingStatus[widget.otherUserId] ?? false);
      },
      builder: (context, state) {
        bool isOtherTyping = false;
        if (state is MessagesLoaded) {
          isOtherTyping = state.typingStatus[widget.otherUserId] ?? false;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isOtherTyping ? 32 : 0,
          curve: Curves.easeOutCubic,
          child: isOtherTyping
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTypingDots(),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.otherUserName} يكتب...',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildTypingDots() {
    return SizedBox(
      width: 30,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 600 + (i * 200)),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.4 + (value * 0.3)),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SHIMMER LOADING
  // ══════════════════════════════════════════════════════════════
  Widget _buildShimmerMessages() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(8, (index) {
            final isRight = index % 3 == 0;
            // استخدام قيم ثابتة أو محسوبة مسبقاً لتقليل الجهد في كل Build
            final widthFactor = (0.3 + (index * 7 % 4) * 0.1);
            return Align(
              alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: screenWidth * widthFactor,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ).animate(onPlay: (c) => c.repeat()).shimmer(
                    duration: 1500.ms,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
            );
          }),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  EMPTY CHAT
  // ══════════════════════════════════════════════════════════════
  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد رسائل بعد',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ المحادثة الآن مع ${widget.otherUserName}',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DATE HEADER
  // ══════════════════════════════════════════════════════════════
  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _formatDate(date),
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INPUT AREA
  // ══════════════════════════════════════════════════════════════
  Widget _buildInputArea() {
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (prev, curr) {
        if (prev is MessagesLoaded && curr is MessagesLoaded) {
          return prev.isClosed != curr.isClosed;
        }
        return curr is MessagesLoaded;
      },
      builder: (context, state) {
        final isClosed = state is MessagesLoaded && state.isClosed;
        // الدعم الفني يقدر يرسل حتى لو المحادثة مغلقة
        final showLocked = isClosed && !_isSupportMode;

        return Container(
          decoration: const BoxDecoration(color: Colors.transparent),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: showLocked ? _buildLockedInput() : _buildActiveInput(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLockedInput() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            size: 18,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 8),
          Text(
            'هذه المحادثة مغلقة لانتهاء العمل',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textHint,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Location Button
        IconButton(
          onPressed: _sendLocation,
          icon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
          tooltip: 'إرسال الموقع',
        ),
        // TextField Container
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.8,
              ), // خفيف جدا لمجرد التمييز
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _messageController,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: _isSupportMode ? 'اكتب رد الدعم...' : 'اكتب رسالة...',
                hintStyle: GoogleFonts.cairo(
                  color: AppColors.textHint,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Send Button Container
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _sendMessage,
            borderRadius: BorderRadius.circular(25),
            splashColor: Colors.white24,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  MESSAGE BUBBLE - StatelessWidget مع تحسينات الأداء
// ══════════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showSenderName;
  final String senderName;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSenderName = false,
    required this.senderName,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    // تقليل المسافات عند تجميع الرسائل
    final topMargin = isFirstInGroup ? 8.0 : 2.0;
    final bottomMargin = isLastInGroup ? 8.0 : 2.0;

    // الزوايا - أكثر نعومة مع التجميع
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isMine ? 20 : (isFirstInGroup ? 20 : 6)),
      topRight: Radius.circular(isMine ? (isFirstInGroup ? 20 : 6) : 20),
      bottomLeft: Radius.circular(isMine ? 20 : (isLastInGroup ? 4 : 6)),
      bottomRight: Radius.circular(isMine ? (isLastInGroup ? 4 : 6) : 20),
    );

    final responsiveMargin = MediaQuery.of(context).size.width * 0.15;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: topMargin,
          bottom: bottomMargin,
          left: isMine ? responsiveMargin : 0,
          right: isMine ? 0 : responsiveMargin,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMine ? AppColors.primaryGradient : null,
          color: isMine ? null : Colors.white,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: isMine
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            // اسم المرسل (في وضع الأدمن)
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isMine ? Colors.white70 : AppColors.primary,
                  ),
                ),
              ),

            // نص الرسالة أو عرض الموقع
            if (message.isLocation && message.latitude != null && message.longitude != null)
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${message.latitude},${message.longitude}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      AppComponents.showSnackBar(context, 'لا يمكن فتح الخريطة', isError: true);
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_rounded,
                        color: isMine ? Colors.white : AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.text,
                          style: GoogleFonts.cairo(
                            color: isMine ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                message.text,
                style: GoogleFonts.cairo(
                  color: isMine ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
                textDirection: TextDirection.rtl,
              ),

            const SizedBox(height: 4),

            // الوقت + علامة القراءة
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.cairo(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textHint,
                    fontSize: 10,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 14,
                    color: message.isRead
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
