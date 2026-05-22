import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/conversations_cubit.dart';
import '../../../../app/widgets/app_components.dart';

class ConversationsPage extends StatefulWidget {
  final bool showAppBar;
  const ConversationsPage({super.key, this.showAppBar = true});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      context.read<ConversationsCubit>().loadConversations(authState.user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) _loadData();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(
                  'المحادثات',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                centerTitle: true,
                backgroundColor: Colors.white,
                elevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                    color: AppColors.border.withOpacity(0.5),
                    height: 1,
                  ),
                ),
              )
            : null,
        body: BlocBuilder<ConversationsCubit, ConversationsState>(
          builder: (context, state) {
            if (state is ConversationsLoading) {
              return AppComponents.shimmerList(count: 3, height: 100);
            }
            if (state is ConversationsError) {
              return AppComponents.errorState(message: state.message, onRetry: _loadData);
            }
            if (state is ConversationsLoaded) {
              if (state.conversations.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: Center(
                    child: AppComponents.emptyState(
                      title: 'لا توجد محادثات بعد',
                      subtitle: 'ستظهر المحادثات هنا عند البدء في أي عمل جديد',
                      icon: Icons.forum_outlined,
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: state.conversations.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final conversation = state.conversations[index];
                    final authState = context.read<AuthCubit>().state;
                    final currentUserId = authState is AuthAuthenticated ? authState.user.uid : '';
                    final otherName = conversation.getOtherParticipantName(currentUserId);
                    final otherId = conversation.getOtherParticipantId(currentUserId);

                     return _ConversationTile(
                      conversationId: conversation.id,
                      name: otherName,
                      otherUserId: otherId,
                      otherUserRole: conversation.getOtherParticipantRole(currentUserId),
                      otherUserImage: conversation.getOtherParticipantImage(currentUserId),
                      otherUserSpecialty: conversation.getOtherParticipantSpecialty(currentUserId),
                      postTitle: conversation.postTitle,
                      lastMessage: conversation.lastMessage,
                      time: conversation.lastMessageTime,
                      isUnread: !conversation.isLastMessageRead && conversation.lastMessageSenderId != currentUserId,
                      onTap: () {
                        context.push(
                          '/chat-room/${conversation.id}',
                          extra: {'name': otherName, 'id': otherId},
                        );
                      },
                    );
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String conversationId;
  final String name;
  final String otherUserId;
  final String otherUserRole;
  final String? otherUserImage;
  final String? otherUserSpecialty;
  final String postTitle;
  final String lastMessage;
  final DateTime time;
  final bool isUnread;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversationId,
    required this.name,
    required this.otherUserId,
    required this.otherUserRole,
    this.otherUserImage,
    this.otherUserSpecialty,
    required this.postTitle,
    required this.lastMessage,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppComponents.pressableCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // User Avatar
            AppComponents.userAvatar(
              imageUrl: otherUserImage,
              name: name,
              radius: 28,
              showBorder: isUnread,
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            _buildRoleBadge(otherUserRole, otherUserSpecialty),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(time),
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: isUnread ? AppColors.primary : AppColors.textHint,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (postTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          postTitle,
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  Text(
                    lastMessage.isNotEmpty ? lastMessage : 'ابدأ المحادثة الآن...',
                    style: GoogleFonts.cairo(
                      fontSize: 13, 
                      color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isUnread)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.border),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role, [String? specialty]) {
    String label = 'مستخدم';
    Color color = AppColors.success;

    final lowerRole = role.toLowerCase();
    if (lowerRole == 'artisan') {
      label = (specialty != null && specialty.isNotEmpty) ? 'حرفي - $specialty' : 'حرفي';
      color = AppColors.primary;
    } else if (lowerRole == 'admin') {
      label = 'دعم معتمد';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${date.day}/${date.month}';
  }
}
