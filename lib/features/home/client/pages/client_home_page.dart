import 'dart:math';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../notifications/presentation/widgets/notification_bottom_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/widgets/map_location_picker.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/models/post_model_extension.dart';
import '../../../chat/presentation/pages/conversations_page.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../ratings/presentation/widgets/rating_widget.dart';
import '../presentation/bloc/client_posts_cubit.dart';
import '../../../../app/widgets/custom_bottom_nav.dart';
import '../../../posts/data/models/offer_model.dart';
import '../../../posts/data/repositories/post_repository.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../chat/presentation/bloc/conversations_cubit.dart';
import '../../../requests/presentation/bloc/service_request_cubit.dart';
import '../../../auth/presentation/widgets/change_phone_dialog.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../../../core/services/notification_service.dart';

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // نستخدم context.read بدلاً من watch لمنع إعادة بناء الصفحة بالكامل عند تغير بيانات المستخدم (مثل الـ activeChatId)
    final currentState = context.read<AuthCubit>().state;

    if (currentState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = currentState.user;

    return BlocProvider(
      create: (context) => sl<ClientPostsCubit>()..loadClientPosts(user.uid),
      child: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (previous, current) => current is AuthUnauthenticated,
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            context.go('/login');
          }
        },
        builder: (context, state) {
          final currentUser = state is AuthAuthenticated ? state.user : user;
          return _ClientHomeContent(user: currentUser);
        },
      ),
    );
  }
}

class _ClientHomeContent extends StatefulWidget {
  final UserModel user;
  const _ClientHomeContent({required this.user});

  @override
  State<_ClientHomeContent> createState() => _ClientHomeContentState();
}

class _ClientHomeContentState extends State<_ClientHomeContent> {
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
    final user = widget.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Column(
        children: [
          // عزل الهيدر لضمان عدم إعادة بناء الصفحة بالكامل عند تغير عداد الإشعارات
          if (_currentIndex != 3)
            BlocSelector<AuthCubit, AuthState, int>(
              selector: (state) => state is AuthAuthenticated
                  ? state.user.unreadNotificationsCount
                  : 0,
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
                  onAdminTap: user.isAdmin
                      ? () => context.go('/admin-selection')
                      : null,
                );
              },
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _MyRequestsTab(user: user),
                const _ArtisansTab(),
                const ConversationsPage(showAppBar: false),
                _ProfileTab(user: user),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => context.push('/create-post'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ).animate().scale(
              delay: 400.ms,
              duration: 400.ms,
              curve: Curves.easeOutBack,
            )
          : null,
      bottomNavigationBar: BlocBuilder<ConversationsCubit, ConversationsState>(
        builder: (context, state) {
          final unreadCount = state.unreadCount(user.uid);

          return CustomBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              CustomBottomNavItem(
                icon: Icons.assignment_outlined,
                label: 'طلباتي',
              ),
              CustomBottomNavItem(icon: Icons.search_rounded, label: 'بحث'),
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

class _ArtisansTab extends StatefulWidget {
  const _ArtisansTab();

  @override
  State<_ArtisansTab> createState() => _ArtisansTabState();
}

class _ArtisansTabState extends State<_ArtisansTab> {
  String _selectedSpecialty = 'الكل';
  bool _sortByRating = false;
  List<String> _specialties = [];
  bool _isLoadingSpecialties = true;

  // ── فلتر الموقع الجغرافي ──────────────────────────────────────
  LatLng? _filterLocation;
  String? _filterLocationName;

  /// حساب المسافة بالكيلومتر بين نقطتين (Haversine Formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0;
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _openLocationFilter() async {
    final result = await MapLocationPicker.show(
      context,
      initialLat: _filterLocation?.latitude,
      initialLng: _filterLocation?.longitude,
      initialAddress: _filterLocationName,
    );
    if (result != null && mounted) {
      setState(() {
        _filterLocation = LatLng(result.latitude, result.longitude);
        _filterLocationName = result.address;
        _sortByRating = false; // إلغاء ترتيب التقييم عند تفعيل الموقع
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSpecialties();
  }

  void _loadSpecialties() {
    try {
      sl<AuthRepository>().getActiveArtisanSpecialtiesStream().listen((
        specialtiesList,
      ) {
        if (mounted) {
          setState(() {
            _specialties = specialtiesList;
            _isLoadingSpecialties = false;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingSpecialties = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // فلترة احترافية
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              if (_isLoadingSpecialties)
                const SizedBox(
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFilterChip('الكل'),
                      const SizedBox(width: 10),
                      ..._specialties.map(
                        (s) => Row(
                          children: [
                            _buildFilterChip(s),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // ── ترتيب بالتقييم ──
                    Row(
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ترتيب حسب الأعلى تقييماً',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Switch.adaptive(
                          value: _sortByRating && _filterLocation == null,
                          activeColor: AppColors.primary,
                          onChanged: _filterLocation != null
                              ? null
                              : (val) => setState(() => _sortByRating = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ── فلتر الموقع ──
                    GestureDetector(
                      onTap: _openLocationFilter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _filterLocation != null
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _filterLocation != null
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1.5,
                          ),
                          boxShadow: _filterLocation != null
                              ? AppColors.shadowLevel1
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _filterLocation != null
                                  ? Icons.location_on_rounded
                                  : Icons.add_location_alt_outlined,
                              size: 20,
                              color: _filterLocation != null
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _filterLocation != null
                                    ? (_filterLocationName ?? 'تم تحديد الموقع')
                                    : 'فلترة حسب الأقرب لموقعك',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _filterLocation != null
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_filterLocation != null)
                              GestureDetector(
                                onTap: () => setState(() {
                                  _filterLocation = null;
                                  _filterLocationName = null;
                                }),
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // قائمة الحرفيين بتصميم كروت بريميوم
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _filterLocation != null
                ? sl<AuthRepository>().getArtisansWithinRadius(
                    centerLat: _filterLocation!.latitude,
                    centerLng: _filterLocation!.longitude,
                    radiusKm: 100.0,
                    specialty: _selectedSpecialty,
                  )
                : sl<AuthRepository>().getArtisansStream(
                    specialty: _selectedSpecialty,
                    sortByRating: _sortByRating,
                  ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 40,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'خطأ في جلب البيانات: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AppComponents.shimmerList(count: 3, height: 160);
              }
              var artisans = snapshot.data ?? [];

              // ── فرز إضافي وتفضيل الأعلى تقييماً (عند تقارب المسافة) ──
              if (_filterLocation != null) {
                final loc = _filterLocation!;

                // فرز: الأقرب أولاً، ثم الأعلى تقييماً عند تعادل المسافة (أقل من 5 كم فرق)
                artisans = List.from(artisans)
                  ..sort((a, b) {
                    final hasA = a.latitude != null && a.longitude != null;
                    final hasB = b.latitude != null && b.longitude != null;
                    if (!hasA && !hasB) return b.rating.compareTo(a.rating);
                    if (!hasA) return 1;
                    if (!hasB) return -1;
                    final distA = _calculateDistance(
                      loc.latitude,
                      loc.longitude,
                      a.latitude!,
                      a.longitude!,
                    );
                    final distB = _calculateDistance(
                      loc.latitude,
                      loc.longitude,
                      b.latitude!,
                      b.longitude!,
                    );
                    if ((distA - distB).abs() < 5.0) {
                      return b.rating.compareTo(a.rating);
                    }
                    return distA.compareTo(distB);
                  });
              }

              if (artisans.isEmpty) {
                return AppComponents.emptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا يوجد حرفيون',
                  subtitle: 'جرب تغيير خيارات البحث أو الفلترة',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: artisans.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final artisan = artisans[index];

                  // حساب المسافة لعرضها على الكارد
                  double? distKm;
                  if (_filterLocation != null &&
                      artisan.latitude != null &&
                      artisan.longitude != null) {
                    distKm = _calculateDistance(
                      _filterLocation!.latitude,
                      _filterLocation!.longitude,
                      artisan.latitude!,
                      artisan.longitude!,
                    );
                  }

                  return AppComponents.card(
                    padding: const EdgeInsets.all(12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AppComponents.userAvatar(
                        imageUrl: artisan.profileImage,
                        name: artisan.name,
                        radius: 28,
                      ),
                      title: Text(
                        artisan.name,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artisan.specialty,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              RatingStars(rating: artisan.rating, size: 14),
                              if (distKm != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.near_me_rounded,
                                        size: 12,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        distKm < 1
                                            ? '${(distKm * 1000).toStringAsFixed(0)} م'
                                            : '${distKm.toStringAsFixed(1)} كم',
                                        style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      onTap: () =>
                          context.push('/artisan-profile', extra: artisan),
                    ),
                  ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String specialty) {
    final isSelected = _selectedSpecialty == specialty;
    return GestureDetector(
      onTap: () => setState(() => _selectedSpecialty = specialty),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected ? AppColors.shadowLevel1 : null,
        ),
        child: Text(
          specialty,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MyRequestsTab extends StatelessWidget {
  final UserModel user;
  const _MyRequestsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientPostsCubit, ClientPostsState>(
      builder: (context, state) {
        if (state is ClientPostsLoading || state is ClientPostsInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ClientPostsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text('حدث خطأ: ${state.message}', style: GoogleFonts.cairo()),
                const SizedBox(height: 24),
                AppComponents.primaryButton(
                  label: 'إعادة المحاولة',
                  onPressed: () => context.read<ClientPostsCubit>().refresh(),
                  width: 180,
                ),
              ],
            ),
          );
        }

        final posts = (state as ClientPostsLoaded).posts;

        if (posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => context.read<ClientPostsCubit>().refresh(),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  child: AppComponents.emptyState(
                    icon: Icons.assignment_outlined,
                    title: 'لا توجد طلبات حالياً',
                    subtitle: 'ابدأ بإنشاء طلب جديد ليراه الحرفيون',
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<ClientPostsCubit>().refresh(),
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

class _PostCard extends StatelessWidget {
  final PostModel post;
  const _PostCard({required this.post});

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.cairo(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    '${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}',
                    style: GoogleFonts.cairo(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoTag(icon: Icons.handyman_rounded, label: post.specialty),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InfoTag(
                      icon: Icons.location_on_rounded,
                      label: post.location,
                    ),
                  ),
                ],
              ),
              if (post.status == 'open') ...[
                const SizedBox(height: 16),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.divider,
                ),
                const SizedBox(height: 12),
                if (post.isDirectRequest)
                  Row(
                    children: [
                      const Icon(
                        Icons.hourglass_empty_rounded,
                        color: AppColors.textHint,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'في انتظار موافقة الحرفي...',
                        style: GoogleFonts.cairo(
                          color: AppColors.textHint,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                    ],
                  )
                else
                  StreamBuilder<List<OfferModel>>(
                    stream: sl<PostRepository>().getOffersForPost(post.id),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Row(
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            color: count > 0
                                ? AppColors.secondary
                                : AppColors.textHint,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            count == 0
                                ? 'في انتظار أول عرض...'
                                : 'وصلك $count عروض',
                            style: GoogleFonts.cairo(
                              color: count == 0
                                  ? AppColors.textHint
                                  : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.textHint,
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary.withOpacity(0.6)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final UserModel user;
  const _ProfileTab({required this.user});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!mounted) return;
      final o = _scrollController.offset;
      final nextCollapsed = _showTitle ? (o > 170) : (o > 230);
      if (nextCollapsed != _showTitle) {
        setState(() => _showTitle = nextCollapsed);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProfileImage(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null) return;

    if (!context.mounted) return;
    final authCubit = context.read<AuthCubit>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = File(pickedFile.path);
      await authCubit.updateProfileImage(file);
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        AppComponents.showSnackBar(context, 'تم تحديث الصورة بنجاح');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        AppComponents.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Sliver App Bar ──
          SliverAppBar(
            expandedHeight: user.profileImage.isNotEmpty ? 400 : 280,
            pinned: true,
            stretch: false,
            backgroundColor: const Color(0xFF0047CC),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            forceMaterialTransparency: false,
            titleSpacing: 0,
            automaticallyImplyLeading: false,
            centerTitle: false,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _showTitle ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        children: [
                          const Spacer(),
                          Text(
                            user.name,
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'عميل',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Background
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    child: user.profileImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.profileImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: const Color(0xFF0047CC)),
                            errorWidget: (context, url, error) =>
                                Container(color: const Color(0xFF0047CC)),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1E6BFF),
                                  Color(0xFF0047CC),
                                  Color(0xFF003399),
                                ],
                              ),
                            ),
                          ),
                  ),

                  // 2. Decorative circles
                  if (user.profileImage.isEmpty) ...[
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: 60,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                    ),
                  ],

                  // 3. Readability Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(
                              user.profileImage.isNotEmpty ? 0.7 : 0.3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Edit Profile Image Button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => _pickAndUploadProfileImage(context),
                      child:
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ).animate().scale(
                            delay: 500.ms,
                            curve: Curves.elasticOut,
                          ),
                    ),
                  ),

                  // 4. Profile Identity
                  Positioned(
                    bottom: 36,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        if (user.profileImage.isEmpty)
                          AppComponents.userAvatar(
                            imageUrl: user.profileImage,
                            name: user.name,
                            radius: 65,
                            fontSize: 48,
                          ).animate().scale(
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          ),

                        const SizedBox(height: 14),

                        AnimatedOpacity(
                          opacity: _showTitle ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            user.name,
                            style: GoogleFonts.cairo(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'عميل في تطبيق أعمال',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإعدادات والحساب',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppComponents.card(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                if (user.role == 'admin') ...[
                                  _buildInteractiveOption(
                                    icon: Icons.admin_panel_settings_rounded,
                                    title: 'الذهاب للادمن',
                                    onTap: () => context.go('/admin'),
                                  ),
                                  const Divider(height: 1, indent: 56),
                                ],
                                _buildProfileOption(
                                  Icons.person_outline_rounded,
                                  'الاسم بالكامل',
                                  user.name,
                                ),
                                const Divider(height: 1, indent: 56),
                                _buildProfileOption(
                                  Icons.phone_outlined,
                                  'رقم الهاتف',
                                  user.phone.isNotEmpty
                                      ? user.phone
                                      : 'غير متوفر',
                                  trailing: GestureDetector(
                                    onTap: () =>
                                        ChangePhoneDialog.show(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'تغيير',
                                            style: GoogleFonts.cairo(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Divider(height: 1, indent: 56),
                                _buildInteractiveOption(
                                  icon: Icons.support_agent_rounded,
                                  title: 'تواصل مع الدعم الفني',
                                  onTap: () => _openSupportChat(context),
                                ),
                                const Divider(height: 1, indent: 56),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: AppComponents.primaryButton(
                                    label: 'تسجيل الخروج',
                                    onPressed: () =>
                                        context.read<AuthCubit>().logout(),
                                    backgroundColor: AppColors.error,
                                    prefixIcon: Icons.logout_rounded,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupportChat(BuildContext context) async {
    try {
      final conversation = await sl<ChatRepository>().getOrCreateConversation(
        user1Id: widget.user.uid,
        user1Name: widget.user.name,
        user2Id: FirebaseConstants.supportId,
        user2Name: 'الدعم الفني',
        postId: 'support',
        postTitle: 'دعم فني',
      );

      if (context.mounted) {
        context.push(
          '/chat-room/${conversation.id}',
          extra: {'name': 'الدعم الفني', 'id': FirebaseConstants.supportId},
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في الاتصال: $e', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildProfileOption(
    IconData icon,
    String title,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildInteractiveOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
