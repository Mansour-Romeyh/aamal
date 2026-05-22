import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/notification_cubit.dart';
import '../bloc/notification_state.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../../core/constants/firebase_constants.dart';


class NotificationBottomSheet extends StatefulWidget {
  final String? targetUserId;
  const NotificationBottomSheet({super.key, this.targetUserId});

  static void show(BuildContext context, {String? targetUserId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationBottomSheet(targetUserId: targetUserId),
    );
  }

  @override
  State<NotificationBottomSheet> createState() => _NotificationBottomSheetState();
}

class _NotificationBottomSheetState extends State<NotificationBottomSheet> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final uid = widget.targetUserId ?? (context.read<AuthCubit>().state is AuthAuthenticated 
        ? (context.read<AuthCubit>().state as AuthAuthenticated).user.uid 
        : null);
        
    if (uid != null) {
      final authState = context.read<AuthCubit>().state;
      final isAdmin = authState is AuthAuthenticated && authState.user.role == 'admin';
      context.read<NotificationCubit>().loadNotifications(uid, isAdmin: isAdmin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final isAdminView = authState is AuthAuthenticated && authState.user.role == 'admin';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التنبيهات',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isAdminView)
                      Text(
                        'إدارية فقط',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 32),

          // Content
          Expanded(
            child: BlocBuilder<NotificationCubit, NotificationState>(
              builder: (context, state) {
                if (state is NotificationLoading) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }

                if (state is NotificationError) {
                  return AppComponents.errorState(message: state.message, onRetry: _loadData);
                }

                if (state is NotificationLoaded) {
                  final notifications = state.notifications;

                  if (notifications.isEmpty) {
                    return Center(
                      child: AppComponents.emptyState(
                        title: 'لا يوجد تنبيهات',
                        subtitle: 'سنقوم بإخطارك عند حدوث أي نشاط جديد في حسابك',
                        icon: Icons.notifications_none_outlined,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationItem(
                        notification: notification,
                        onTap: () => _handleNotificationTap(notification),
                        onDelete: () => _handleDelete(notification),
                      ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(dynamic notification) async {
    // تحديد الـ UID المستخدم حالياً (إما الأدمن أو المستخدم العادي)
    final uid = widget.targetUserId ?? (context.read<AuthCubit>().state is AuthAuthenticated 
        ? (context.read<AuthCubit>().state as AuthAuthenticated).user.uid 
        : null);

    if (uid != null && !notification.isRead) {
      context.read<NotificationCubit>().markAsRead(uid, notification.id);
    }
    
    final type = notification.data['type'];
    final isSupportIdentity = widget.targetUserId == FirebaseConstants.supportId;

    if (type == 'chat') {
      final convId = notification.data['conversationId'];
      if (convId != null) {
        if (mounted) Navigator.pop(context); // Close bottom sheet
        if (mounted) {
          context.push('/chat-room/$convId', extra: {
            'name': notification.data['senderName'] ?? 'محادثة دعم',
            'id': notification.data['senderId'] ?? '',
            'isAdminView': isSupportIdentity,
            'isSupportView': isSupportIdentity && convId.contains(FirebaseConstants.supportId),
          });
        }
      }
    } else if (type == 'report' || type == 'admin_action') {
      // التوجيه لتبويب "البلاغات" في لوحة الإدارة
      if (mounted) Navigator.pop(context);
      if (mounted) context.push('/admin?tab=6');
    } else if (type == 'artisan_approval') {
      // التوجيه لتبويب "طلبات التوثيق" في لوحة الإدارة
      if (mounted) Navigator.pop(context);
      if (mounted) context.push('/admin?tab=8');
    } else if (type == 'service_request' || type == 'request_status' || notification.data['postId'] != null) {
      final postId = notification.data['postId'] ?? notification.data['requestId'];
      if (postId != null) {
        if (mounted) Navigator.pop(context); // Close bottom sheet
        
        final isDirectRequest = notification.data['isDirectRequest'] == 'true' || 
                               type == 'service_request' || 
                               type == 'request_status';
        
        String path = '/post-details?postId=$postId';
        if (isDirectRequest) {
          path += '&isDirectRequest=true';
        }
        
        if (mounted) context.push(path);
      }
    }
  }

  void _handleDelete(dynamic notification) {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      context.read<NotificationCubit>().deleteNotification(
        authState.user.uid,
        notification.id,
        notification.isRead,
      );
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final dynamic notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = notification.data['type'] as String?;
    final color = _getIconColor(type);
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) => onDelete(),
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      child: AppComponents.pressableCard(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: !notification.isRead ? Border(right: BorderSide(color: color, width: 4)) : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIcon(type), color: color, size: 22),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatDate(notification.createdAt),
                          style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textHint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'chat': return Icons.chat_bubble_outline_rounded;
      case 'post_accepted': return Icons.check_circle_outline_rounded;
      case 'new_post': return Icons.assignment_outlined;
      case 'post_completed': return Icons.verified_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'chat': return AppColors.primary;
      case 'post_accepted': return AppColors.success;
      case 'new_post': return AppColors.primary;
      case 'post_completed': return AppColors.success;
      default: return AppColors.textHint;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${date.day}/${date.month}';
  }
}
