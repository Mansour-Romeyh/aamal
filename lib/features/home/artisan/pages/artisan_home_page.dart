import 'package:flutter/material.dart';
import '../../../notifications/presentation/widgets/notification_bottom_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/custom_bottom_nav.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/models/post_model_extension.dart';
import '../presentation/bloc/artisan_posts_cubit.dart';
import '../presentation/bloc/artisan_jobs_cubit.dart';
import '../../../ratings/presentation/widgets/rating_widget.dart';
import '../../../chat/presentation/pages/conversations_page.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../requests/presentation/bloc/service_request_cubit.dart';
import '../../../requests/presentation/bloc/service_request_state.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../../chat/presentation/bloc/conversations_cubit.dart';
import '../../../../core/services/notification_service.dart';
import 'artisan_profile_page.dart';

class ArtisanHomePage extends StatelessWidget {
  const ArtisanHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // نستخدم context.read بدلاً من watch لمنع إعادة بناء الصفحة بالكامل عند تغير بيانات المستخدم (مثل الـ activeChatId)
    final currentState = context.read<AuthCubit>().state;

    if (currentState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = currentState.user;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => sl<ArtisanPostsCubit>()..loadOpenPosts(user.specialty, user),
        ),
        BlocProvider(
          create: (context) => sl<ArtisanJobsCubit>()..loadArtisanJobs(user.uid),
        ),
        BlocProvider(
          create: (context) => sl<ServiceRequestCubit>()..loadArtisanRequests(user.uid),
        ),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        // المستمع فقط للتعامل مع تسجيل الخروج، لا يسبب إعادة بناء الواجهة (Rebuild)
        listenWhen: (previous, current) => current is AuthUnauthenticated,
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            context.go('/login');
          }
        },
        child: _ArtisanHomeContent(user: user),
      ),
    );
  }
}

class _ArtisanHomeContent extends StatefulWidget {
  final UserModel user;
  const _ArtisanHomeContent({required this.user});

  @override
  State<_ArtisanHomeContent> createState() => _ArtisanHomeContentState();
}

class _ArtisanHomeContentState extends State<_ArtisanHomeContent> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // تحميل المحادثات لمعرفة عدد الرسائل غير المقروءة للتنبيه
    context.read<ConversationsCubit>().loadConversations(widget.user.uid);

    // 🚀 تهيئة التنبيهات بتأجيل كبير جداً لضمان سلاسة التطبيق المطلقة (10 ثوانٍ)
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        NotificationService.instance.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final user = authState is AuthAuthenticated ? authState.user : widget.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Column(
        children: [
          // عزل الهيدر لضمان عدم إعادة بناء الصفحة بالكامل عند تغير عداد الإشعارات
          if (_currentIndex != 3)
            BlocSelector<AuthCubit, AuthState, int>(
              selector: (state) => state is AuthAuthenticated ? state.user.unreadNotificationsCount : 0,
              builder: (context, count) {
                return AppComponents.homeHeader(
                  context,
                  userName: user.name,
                  userAvatarUrl: user.profileImage,
                  unreadNotifications: count,
                  onNotificationTap: () {
                    context.read<AuthCubit>().resetUnreadCount();
                    NotificationBottomSheet.show(context);
                  },
                  subtitle: Row(
                    children: [
                      RatingStars(rating: user.rating, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '(${user.ratingCount} تقييم)',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _AvailablePostsTab(specialty: user.specialty),
                _RequestsAndJobsTab(artisanId: user.uid),
                const ConversationsPage(showAppBar: false),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    final currentUser = state is AuthAuthenticated ? state.user : user;
                    return ArtisanProfilePage(
                      artisan: currentUser,
                      isSelf: true,
                      showBackButton: false,
                      showSettings: true,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BlocBuilder<ConversationsCubit, ConversationsState>(
        builder: (context, state) {
          final unreadCount = state.unreadCount(user.uid);
          
          return CustomBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              CustomBottomNavItem(icon: Icons.explore_outlined, label: 'اكتشف'),
              CustomBottomNavItem(icon: Icons.work_outline, label: 'أعمالي'),
              CustomBottomNavItem(
                icon: Icons.forum_outlined,
                label: 'شات',
                badgeCount: unreadCount,
              ),
              CustomBottomNavItem(icon: Icons.person_outline, label: 'بروفايل'),
            ],
          );
        },
      ),
    );
  }

}

class _AvailablePostsTab extends StatefulWidget {
  final String specialty;
  const _AvailablePostsTab({required this.specialty});

  @override
  State<_AvailablePostsTab> createState() => _AvailablePostsTabState();
}

class _AvailablePostsTabState extends State<_AvailablePostsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<ArtisanPostsCubit, ArtisanPostsState>(
      builder: (context, state) {
        if (state is ArtisanPostsLoading || state is ArtisanPostsInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ArtisanPostsError) {
          return AppComponents.errorState(
            message: state.message,
            onRetry: () => context.read<ArtisanPostsCubit>().refresh(),
          );
        }

        final posts = (state as ArtisanPostsLoaded).posts;

        if (posts.isEmpty) {
          return AppComponents.emptyState(
            icon: Icons.explore_off_outlined,
            title: 'لا توجد طلبات متاحة',
            subtitle: 'سيظهر هنا أي طلب جديد في تخصصك (${widget.specialty})',
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<ArtisanPostsCubit>().refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _PostCard(post: posts[index])
                  .animate()
                  .fadeIn(delay: (index * 100).ms)
                  .slideY(begin: 0.1, end: 0);
            },
          ),
        );
      },
    );
  }
}

class _RequestsAndJobsTab extends StatefulWidget {
  final String artisanId;
  const _RequestsAndJobsTab({required this.artisanId});

  @override
  State<_RequestsAndJobsTab> createState() => _RequestsAndJobsTabState();
}

class _RequestsAndJobsTabState extends State<_RequestsAndJobsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'طلبات مباشرة'),
            Tab(text: 'مهامي الحالية'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ArtisanRequestsList(artisanId: widget.artisanId),
              _MyJobsTab(artisanId: widget.artisanId),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtisanRequestsList extends StatelessWidget {
  final String artisanId;
  const _ArtisanRequestsList({required this.artisanId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServiceRequestCubit, ServiceRequestState>(
      builder: (context, state) {
        if (state is ServiceRequestLoading || state is ServiceRequestInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ServiceRequestError) {
          return AppComponents.errorState(
            message: state.message,
            onRetry: () => context.read<ServiceRequestCubit>().loadArtisanRequests(artisanId),
          );
        }

        final requests = (state as ServiceRequestsLoaded).requests.where((r) => r.status == 'pending').toList();

        if (requests.isEmpty) {
          return AppComponents.emptyState(
            icon: Icons.notifications_none_rounded,
            title: 'لا توجد طلبات مباشرة',
            subtitle: 'سيظهر هنا أي عميل يطلب خدمتك مباشرة',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: requests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final request = requests[index];
            return InkWell(
              onTap: () => context.push('/post-details', extra: request.toPostModel()),
              borderRadius: BorderRadius.circular(20),
              child: AppComponents.card(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(request.clientName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '${request.createdAt.day}/${request.createdAt.month}',
                          style: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(request.message, style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'اضغط للاطلاع على التفاصيل',
                        style: GoogleFonts.cairo(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppComponents.primaryButton(
                            label: 'قبول وتواصل',
                            onPressed: () async {
                              // قبول الطلب
                              context.read<ServiceRequestCubit>().updateStatus(request.id, 'accepted', request);
                              
                              // إنشاء شات
                              final authState = context.read<AuthCubit>().state as AuthAuthenticated;
                              final chat = await sl<ChatRepository>().getOrCreateConversation(
                                user1Id: authState.user.uid,
                                user1Name: authState.user.name,
                                user2Id: request.clientId,
                                user2Name: request.clientName,
                                postId: request.id,
                                postTitle: 'طلب خدمة مباشرة (${authState.user.specialty})',
                              );
                              
                              if (context.mounted) {
                                context.push('/chat-room/${chat.id}', extra: {'name': request.clientName, 'id': request.clientId});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => context.read<ServiceRequestCubit>().updateStatus(request.id, 'declined', request),
                          child: Text('رفض', style: GoogleFonts.cairo(color: AppColors.error, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MyJobsTab extends StatefulWidget {
  final String artisanId;
  const _MyJobsTab({required this.artisanId});

  @override
  State<_MyJobsTab> createState() => _MyJobsTabState();
}

class _MyJobsTabState extends State<_MyJobsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<ArtisanJobsCubit, ArtisanJobsState>(
      builder: (context, state) {
        if (state is ArtisanJobsLoading || state is ArtisanJobsInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ArtisanJobsError) {
          return AppComponents.errorState(
            message: state.message,
            onRetry: () => context.read<ArtisanJobsCubit>().refresh(),
          );
        }

        final posts = (state as ArtisanJobsLoaded).posts;

        if (posts.isEmpty) {
          return AppComponents.emptyState(
            icon: Icons.assignment_outlined,
            title: 'لا توجد أعمال حالية',
            subtitle: 'ابدأ بتقديم عروض على الطلبات المتاحة لتبدأ العمل',
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<ArtisanJobsCubit>().refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _PostCard(post: posts[index], isMyJob: true)
                  .animate()
                  .fadeIn(delay: (index * 100).ms)
                  .slideY(begin: 0.1, end: 0);
            },
          ),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final bool isMyJob;
  const _PostCard({required this.post, this.isMyJob = false});

  @override
  Widget build(BuildContext context) {
    final statusColor = post.statusColor;
    final statusText = post.statusText;

    return AppComponents.card(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/post-details', extra: post),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.cairo(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Text(
                    '${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}',
                    style: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoIconLabel(icon: Icons.person_pin_rounded, label: post.clientName),
                  const SizedBox(width: 16),
                  Expanded(child: _InfoIconLabel(icon: Icons.location_on_rounded, label: post.location)),
                ],
              ),
              if (!isMyJob && post.status == 'open') ...[
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'قدم عرضك الآن ودشن عملك!',
                      style: GoogleFonts.cairo(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textHint),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoIconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoIconLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}


