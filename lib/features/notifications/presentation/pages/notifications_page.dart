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

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      context.read<NotificationCubit>().loadNotifications(
            authState.user.uid,
            isAdmin: authState.user.role == 'admin',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppComponents.premiumAppBar(context, title: 'التنبيهات'),
      body: BlocBuilder<NotificationCubit, NotificationState>(
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
              return RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: Center(
                  child: AppComponents.emptyState(
                    title: 'لا يوجد تنبيهات',
                    subtitle: 'سنقوم بإخطارك عند حدوث أي نشاط جديد في حسابك',
                    icon: Icons.notifications_none_outlined,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _loadData(),
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
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
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _handleNotificationTap(dynamic notification) {
    if (!notification.isRead) {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        context.read<NotificationCubit>().markAsRead(authState.user.uid, notification.id);
      }
    }
    
    final type = notification.data['type'];
    final postId = notification.data['postId'] ?? notification.data['requestId'];
    
    if (type == 'chat') {
      final convId = notification.data['conversationId'];
      if (convId != null) {
        context.push('/chat-room/$convId', extra: {
          'name': notification.data['senderName'] ?? 'محادثة',
          'id': notification.data['senderId'] ?? '',
        });
      }
    } else if (postId != null) {
      // التنقل لصفحة تفاصيل الطلب باستخدام الـ ID
      final isDirectRequest = notification.data['isDirectRequest'] == 'true' || 
                             type == 'service_request' || 
                             type == 'request_status';
      
      String path = '/post-details?postId=$postId';
      if (isDirectRequest) {
        path += '&isDirectRequest=true';
      }
      context.push(path);
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
