import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../notifications/presentation/widgets/notification_bottom_sheet.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/di/injection_container.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../chat/data/models/message_model.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/repositories/post_repository.dart';
import '../../../reports/data/models/report_model.dart';
import '../../../reports/data/repositories/report_repository.dart';
import '../../../ratings/data/models/rating_model.dart';
import '../../../ratings/data/repositories/rating_repository.dart';
import 'admin_specialties_tab.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../core/services/notification_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  لوحة تحكم الأدمن الاحترافية V4 - Premium Admin Dashboard
// ══════════════════════════════════════════════════════════════════════════════
class AdminPanelPage extends StatefulWidget {
  final int initialTabIndex;
  const AdminPanelPage({super.key, this.initialTabIndex = 0});
  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final Map<int, int> _seenTabEventCount = {};

  static const _tabs = <_TabItem>[
    _TabItem(Icons.dashboard_rounded, 'الرئيسية'),
    _TabItem(Icons.people_alt_rounded, 'المستخدمين'),
    _TabItem(Icons.support_agent_rounded, 'الدعم الفني'),
    _TabItem(Icons.work_history_rounded, 'الطلبات'),
    _TabItem(Icons.category_rounded, 'التخصصات'),
    _TabItem(Icons.chat_bubble_rounded, 'المحادثات'),
    _TabItem(Icons.flag_rounded, 'البلاغات'),
    _TabItem(Icons.star_rounded, 'التقييمات'),
    _TabItem(Icons.fact_check_rounded, 'طلبات التوثيق'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_handleTabChanged);

    // تهيئة حساب الإدارة وربطه بالجهاز الحالي لاستلام التنبيهات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = NotificationService.instance.fcmToken;
      // 1. تهيئة بنية حساب الدعم في قاعدة البيانات لو مش موجودة
      sl<AuthRepository>().setupSupportAccount(token);

      // 2. تحديث التوكين فوراً في السجل الموحد للأدمنز لضبان وصول الإشعارات لهذا الجهاز
      NotificationService.instance.saveTokenToFirestore(
        FirebaseConstants.supportId,
      );

      // 3. مزامنة بيانات المحادثات (إصلاح تلقائي للأدوار والصور المفقودة)
      sl<ChatRepository>().syncConversationsMetadata(
        FirebaseConstants.supportId,
      );
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    // عند فتح التبويب، نعتبر أحداثه "مقروءة" ونخفي النقطة عنه.
    setState(() {
      _seenTabEventCount[_tabController.index] = _seenTabEventCount[_tabController.index] ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DashboardTab(),
          _UsersTab(),
          _SupportTab(),
          _PostsTab(),
          AdminSpecialtiesTab(),
          _ConversationsTab(),
          _ReportsTab(),
          _RatingsTab(),
          _ApprovalsTab(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withOpacity(0.06),
      automaticallyImplyLeading: false,
      leading: null,
      titleSpacing: 0,
      centerTitle: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // ── Left: Admin Icon + Title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'مركز الإدارة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── Center-Right: Notification Bell
            _buildNotificationBell(),

            const SizedBox(width: 8),

            // ── Right: Logout Button
            Container(
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () => _showLogoutDialog(context),
                tooltip: 'تسجيل الخروج',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
      actions: const [], // moved into title row
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            unselectedLabelStyle: GoogleFonts.cairo(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: List.generate(_tabs.length, (index) {
              final t = _tabs[index];
              return Tab(
                height: 48,
                child: _buildTabWithEventBadge(index, t),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildTabWithEventBadge(int tabIndex, _TabItem tab) {
    final eventStream = _eventCountStreamForTab(tabIndex);
    if (eventStream == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tab.icon, size: 16),
          const SizedBox(width: 6),
          Text(tab.label),
        ],
      );
    }

    return StreamBuilder<int>(
      stream: eventStream,
      builder: (context, snapshot) {
        final currentCount = snapshot.data ?? 0;
        final selected = _tabController.index == tabIndex;
        final seenCount = _seenTabEventCount[tabIndex] ?? 0;

        if (selected && currentCount != seenCount) {
          _seenTabEventCount[tabIndex] = currentCount;
        }

        final shouldShowBadge =
            !selected && currentCount > (_seenTabEventCount[tabIndex] ?? 0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 16),
                const SizedBox(width: 6),
                Text(tab.label),
              ],
            ),
            if (shouldShowBadge)
              Positioned(
                right: -10,
                top: -4,
                child: _TabEventBadge(
                  count: currentCount,
                ),
              ),
          ],
        );
      },
    );
  }

  Stream<int>? _eventCountStreamForTab(int tabIndex) {
    switch (tabIndex) {
      case 2: // الدعم الفني
        return sl<ChatRepository>().getAllConversations().map(
          (conversations) => conversations
              .where(
                (c) =>
                    c.participants.contains(FirebaseConstants.supportId) &&
                    !c.isLastMessageRead &&
                    c.lastMessageSenderId != FirebaseConstants.supportId,
              )
              .length,
        );
      case 3: // الطلبات
        return sl<PostRepository>().getAllPosts().map(
          (posts) => posts.where((p) => p.status == 'open').length,
        );
      case 6: // البلاغات
        return sl<ReportRepository>().getAllReports().map(
          (reports) => reports.where((r) => r.status == 'pending').length,
        );
      case 8: // طلبات التوثيق
        return sl<AuthRepository>().getAllUsers().map(
          (users) => users
              .where(
                (u) => u.role == 'artisan' && u.approvalStatus == 'pending',
              )
              .length,
        );
      default:
        return null;
    }
  }

  Widget _buildNotificationBell() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        // في لوحة الإدارة، نستخدم التدفق المدمج الذي يجمع بين تنبيهاتك الشخصية وتنبيهات المنصة
        final targetId = authState is AuthAuthenticated
            ? authState.user.uid
            : FirebaseConstants.supportId;

        return StreamBuilder<int>(
          stream: sl<AuthRepository>().getAdminCombinedNotificationCountStream(
            targetId,
          ),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;

            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                      decoration: BoxDecoration(
                        color: unreadCount > 0
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          unreadCount > 0
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: unreadCount > 0
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 24,
                        ),
                        onPressed: () {
                          // 1. تصفير عداد التنبيهات الشخصية للأدمن
                          context.read<AuthCubit>().resetUnreadCount();
                          // 2. تصفير عداد التنبيهات العامة للمنصة (الدعم الفني)
                          context.read<AuthCubit>().resetUnreadCount(
                            FirebaseConstants.supportId,
                          );
                          // 3. عرض قائمة التنبيهات
                          NotificationBottomSheet.show(
                            context,
                            targetUserId: targetId,
                          );
                        },

                        tooltip: 'التنبيهات المدمجة',
                      ),
                    )
                    .animate(target: unreadCount > 0 ? 1 : 0)
                    .shimmer(duration: 2.seconds)
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                    ),
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child:
                        Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .scale(
                              duration: 1.2.seconds,
                              begin: const Offset(1, 1),
                              end: const Offset(2.2, 2.2),
                            )
                            .fadeOut(duration: 1.2.seconds),
                  ),
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child:
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4B2B), Color(0xFFFF416C)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ).animate().scale(
                          duration: 400.ms,
                          curve: Curves.bounceOut,
                        ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من المنصة؟',
          style: GoogleFonts.cairo(color: AppColors.textSecondary, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<AuthCubit>().logout();
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'تسجيل الخروج',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}

class _TabEventBadge extends StatelessWidget {
  final int count;

  const _TabEventBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 9 ? '9+' : '$count',
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  1) Dashboard Tab — الإحصائيات الحية
// ══════════════════════════════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Section: Users Stats
        _sectionHeader('إحصائيات المستخدمين', Icons.groups_rounded),
        const SizedBox(height: 14),
        StreamBuilder<List<UserModel>>(
          stream: sl<AuthRepository>().getAllUsers(),
          builder: (ctx, snap) {
            final users = snap.data ?? [];
            return Column(
              children: [
                Row(
                  children: [
                    _StatCard(
                      'إجمالي',
                      '${users.length}',
                      Icons.groups_rounded,
                      const Color(0xFF6366F1),
                      0,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      'عملاء',
                      '${users.where((u) => u.role == "client").length}',
                      Icons.person_rounded,
                      AppColors.primary,
                      80,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      'حرفيين',
                      '${users.where((u) => u.role == "artisan").length}',
                      Icons.engineering_rounded,
                      AppColors.secondary,
                      160,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                      'متصل',
                      '${users.where((u) => u.isOnline).length}',
                      Icons.circle,
                      AppColors.success,
                      240,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      'محظور',
                      '${users.where((u) => !u.isActive).length}',
                      Icons.block_rounded,
                      AppColors.error,
                      320,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      'موثّق',
                      '${users.where((u) => u.isVerified).length}',
                      Icons.verified_rounded,
                      const Color(0xFF8B5CF6),
                      400,
                    ),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        // ── Section: Posts & Reports Stats
        _sectionHeader('الطلبات والبلاغات', Icons.analytics_rounded),
        const SizedBox(height: 14),
        StreamBuilder<List<PostModel>>(
          stream: sl<PostRepository>().getAllPosts(),
          builder: (ctx, snap) {
            final p = snap.data ?? [];
            return Row(
              children: [
                _StatCard(
                  'مفتوح',
                  '${p.where((x) => x.status == "open").length}',
                  Icons.pending_actions_rounded,
                  AppColors.warning,
                  480,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  'مكتمل',
                  '${p.where((x) => x.status == "completed").length}',
                  Icons.task_alt_rounded,
                  AppColors.success,
                  560,
                ),
                const SizedBox(width: 12),
                StreamBuilder<List<ReportModel>>(
                  stream: sl<ReportRepository>().getAllReports(),
                  builder: (ctx, rSnap) => _StatCard(
                    'بلاغات',
                    '${(rSnap.data ?? []).where((r) => r.status == "pending").length}',
                    Icons.report_rounded,
                    AppColors.error,
                    640,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final int delay;
  const _StatCard(this.title, this.value, this.icon, this.color, this.delay);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child:
          Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      value,
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: delay),
                duration: 400.ms,
              )
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  2) Users Tab — المستخدمين
// ══════════════════════════════════════════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _filter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search Field
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {}),
            style: GoogleFonts.cairo(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'البحث عن طريق الاسم، البريد الإلكتروني، أو رقم الهاتف...',
              hintStyle: GoogleFonts.cairo(
                color: AppColors.textHint,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textHint,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // ── Filter Chips
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  'الكل',
                  _filter == 'all',
                  () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  'عملاء',
                  _filter == 'client',
                  () => setState(() => _filter = 'client'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  'حرفيين',
                  _filter == 'artisan',
                  () => setState(() => _filter = 'artisan'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  'مديرين',
                  _filter == 'admin',
                  () => setState(() => _filter = 'admin'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  'محظورين',
                  _filter == 'banned',
                  () => setState(() => _filter = 'banned'),
                ),
              ],
            ),
          ),
        ),

        // ── Users List
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: sl<AuthRepository>().getAllUsers(),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              var users = snap.data!;
              if (_filter == 'banned') {
                users = users.where((u) => !u.isActive).toList();
              } else if (_filter != 'all') {
                users = users.where((u) => u.role == _filter).toList();
              }

              final searchQuery = _searchController.text.trim().toLowerCase();
              if (searchQuery.isNotEmpty) {
                users = users.where((u) {
                  final nameMatch = u.name.toLowerCase().contains(searchQuery);
                  final emailMatch = u.email.toLowerCase().contains(searchQuery);
                  final phoneMatch = u.phone?.toLowerCase().contains(searchQuery) ?? false;
                  return nameMatch || emailMatch || phoneMatch;
                }).toList();
              }
              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 56,
                        color: AppColors.textHint.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا يوجد نتائج',
                        style: GoogleFonts.cairo(
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _UserCard(user: users[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user.role == 'client'
        ? 'عميل'
        : user.role == 'artisan'
        ? 'حرفي'
        : 'أدمن';
    final c = user.role == 'client'
        ? AppColors.primary
        : user.role == 'artisan'
        ? AppColors.secondary
        : AppColors.success;
    final banned = !user.isActive;

    return GestureDetector(
      onTap: () => _showUserDetails(context, user),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: banned ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: banned
              ? Border.all(color: AppColors.error.withOpacity(0.2))
              : Border.all(color: AppColors.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                AppComponents.userAvatar(
                  imageUrl: user.profileImage,
                  name: user.name,
                  radius: 24,
                ),
                if (user.isOnline)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                if (banned)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.block,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primary,
                          size: 15,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          role,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: c,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (user.role == 'artisan') ...[
                        const SizedBox(width: 8),
                        Text(
                          '${user.rating.toStringAsFixed(1)} ⭐',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (banned) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'محظور',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: AppColors.textHint,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              onSelected: (v) => _handleAction(context, v),
              itemBuilder: (_) => [
                _popupItem(
                  'verify',
                  user.isVerified
                      ? Icons.remove_circle_outline
                      : Icons.verified_rounded,
                  user.isVerified ? 'إلغاء التوثيق' : 'توثيق الحساب',
                  AppColors.primary,
                ),
                _popupItem(
                  'role',
                  user.role == 'admin'
                      ? Icons.person_remove_rounded
                      : Icons.admin_panel_settings_rounded,
                  user.role == 'admin' ? 'إلغاء الأدمن' : 'تعيين كأدمن',
                  const Color(0xFF7C3AED),
                ),
                _popupItem(
                  'ban',
                  banned ? Icons.lock_open_rounded : Icons.block_rounded,
                  banned ? 'فك الحظر' : 'حظر المستخدم',
                  AppColors.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static PopupMenuItem<String> _popupItem(
    String value,
    IconData icon,
    String text,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static void _showUserDetails(BuildContext context, UserModel u) {
    final role = u.role == 'client'
        ? 'عميل'
        : u.role == 'artisan'
        ? 'حرفي'
        : 'أدمن';
    final c = u.role == 'client'
        ? AppColors.primary
        : u.role == 'artisan'
        ? AppColors.secondary
        : AppColors.success;
    final banned = !u.isActive;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  // Profile Header
                  Center(
                    child: Stack(
                      children: [
                        AppComponents.userAvatar(
                          imageUrl: u.profileImage,
                          name: u.name,
                          radius: 50,
                          fontSize: 40,
                        ),
                        if (u.isOnline)
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.online,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              u.name,
                              style: GoogleFonts.cairo(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (u.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            role,
                            style: GoogleFonts.cairo(
                              color: c,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Contact Info
                  _detailSection('معلومات التواصل', Icons.email_outlined),
                  _infoTile(Icons.email_outlined, 'البريد الإلكتروني', u.email),
                  _infoTile(
                    Icons.phone_android_rounded,
                    'رقم الهاتف',
                    u.phone.isNotEmpty ? u.phone : 'غير مضاف',
                  ),

                  if (u.role == 'artisan') ...[
                    const SizedBox(height: 20),
                    _detailSection('بيانات الحرفي', Icons.engineering_rounded),
                    _infoTile(
                      Icons.workspace_premium_rounded,
                      'التخصص',
                      u.specialty,
                    ),
                    _infoTile(
                      Icons.star_rounded,
                      'التقييم العام',
                      '${u.rating.toStringAsFixed(1)} (${u.ratingCount} تقييم)',
                    ),
                    _infoTile(
                      Icons.location_on_outlined,
                      'العنوان',
                      u.address.isNotEmpty ? u.address : 'غير مدخل',
                    ),
                    _infoTile(
                      Icons.info_outline_rounded,
                      'نبذة',
                      u.bio.isNotEmpty ? u.bio : 'لا توجد نبذة',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'صورة الهوية / جواز السفر',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDocumentPreview(context, u.idCardImage),
                    const SizedBox(height: 16),
                    Text(
                      'صورة السيلفي',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDocumentPreview(context, u.selfieImage),
                    if (u.portfolioImages.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'معرض الأعمال',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: u.portfolioImages.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              u.portfolioImages[i],
                              width: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 20),
                  _detailSection('حالة الحساب', Icons.security_rounded),
                  _infoTile(
                    Icons.calendar_month_rounded,
                    'تاريخ الانضمام',
                    '${u.createdAt.day}/${u.createdAt.month}/${u.createdAt.year}',
                  ),
                  _infoTile(
                    Icons.security_rounded,
                    'حالة النشاط',
                    u.isActive ? 'نشط ✅' : 'محظور 🚫',
                  ),

                  const SizedBox(height: 32),
                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            sl<AuthRepository>().toggleUserVerified(
                              u.uid,
                              !u.isVerified,
                            );
                            Navigator.pop(ctx);
                          },
                          icon: Icon(
                            u.isVerified
                                ? Icons.remove_circle_outline
                                : Icons.verified_rounded,
                            size: 18,
                          ),
                          label: Text(
                            u.isVerified ? 'إلغاء التوثيق' : 'توثيق الحساب',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            sl<AuthRepository>().toggleUserActive(
                              u.uid,
                              banned,
                            );
                            Navigator.pop(ctx);
                          },
                          icon: Icon(
                            banned
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                            size: 18,
                          ),
                          label: Text(
                            banned ? 'فك الحظر' : 'حظر الحساب',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _detailSection(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _infoTile(IconData ic, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(ic, size: 16, color: AppColors.textHint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  val,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDocumentPreview(BuildContext context, String imageUrl) {
    return GestureDetector(
      onTap: imageUrl.isEmpty ? null : () => _showImageViewer(context, imageUrl),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: 40,
                      color: AppColors.textHint,
                    ),
                  ),
                )
              : const Center(child: Text('لا توجد صورة مرفوعة')),
        ),
      ),
    );
  }

  static void _showImageViewer(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.network(imageUrl))),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    if (action == 'verify') {
      sl<AuthRepository>().toggleUserVerified(user.uid, !user.isVerified);
      AppComponents.showSnackBar(
        context,
        user.isVerified ? 'تم إلغاء التوثيق' : 'تم توثيق الحساب ✓',
      );
    } else if (action == 'role') {
      final isAdmin = user.role == 'admin';
      AppComponents.showConfirmDialog(
        context: context,
        title: isAdmin ? 'إلغاء رتبة أدمن' : '🛡️ تعيين كمسؤول (أدمن)',
        message: isAdmin
            ? 'هل تريد سحب صلاحيات الأدمن من "${user.name}"؟ سيعود كمستخدم عادي.'
            : 'هل أنت متأكد من تعيين "${user.name}" كأدمن؟\n\nسيكون لديه صلاحيات كاملة للتحكم في المنصة.',
        confirmText: isAdmin ? 'تأكيد السحب' : 'تأكيد التعيين',
        icon: isAdmin
            ? Icons.person_remove_rounded
            : Icons.admin_panel_settings_rounded,
        iconColor: const Color(0xFF7C3AED),
        onConfirm: () {
          final newRole = isAdmin ? 'client' : 'admin';
          sl<AuthRepository>().updateUserRole(user.uid, newRole);
          AppComponents.showSnackBar(
            context,
            isAdmin ? 'تم سحب الصلاحيات' : 'تم تعيين كأدمن بنجاح ✓',
          );
        },
      );
    } else if (action == 'ban') {
      final isBanned = !user.isActive;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            isBanned ? 'فك حظر' : '⛔ حظر المستخدم',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Text(
            isBanned
                ? 'هل تريد فك الحظر عن "${user.name}"؟'
                : 'هل أنت متأكد من حظر "${user.name}"?\n\nلن يتمكن من الدخول للتطبيق أو القيام بأي عمليات.',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: AppColors.textHint,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                sl<AuthRepository>().toggleUserActive(user.uid, isBanned);
                Navigator.pop(ctx);
                AppComponents.showSnackBar(
                  context,
                  isBanned ? 'تم فك الحظر بنجاح ✓' : 'تم حظر المستخدم نهائياً',
                  isError: !isBanned,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isBanned ? AppColors.success : AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isBanned ? 'فك الحظر' : 'تأكيد الحظر',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  3) Posts Tab — الطلبات
// ══════════════════════════════════════════════════════════════════════════════
class _PostsTab extends StatelessWidget {
  const _PostsTab();

  static Color _statusColor(String s) => s == 'open'
      ? AppColors.primary
      : s == 'accepted'
      ? AppColors.warning
      : s == 'completed'
      ? AppColors.success
      : s == 'admin_rejected'
      ? const Color(0xFF7C3AED)
      : AppColors.error;

  static String _statusLabel(String s) => s == 'open'
      ? 'مفتوح'
      : s == 'accepted'
      ? 'قيد التنفيذ'
      : s == 'completed'
      ? 'مكتمل'
      : s == 'admin_rejected'
      ? 'مرفوض إدارياً'
      : s == 'cancelled'
      ? 'ملغي'
      : s;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostModel>>(
      stream: sl<PostRepository>().getAllPosts(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 12),
                Text(
                  'خطأ في تحميل الطلبات',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'تأكد من اتصال الانترنت',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_off_rounded,
                  size: 56,
                  color: AppColors.textHint.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد طلبات',
                  style: GoogleFonts.cairo(
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final p = posts[i];
            final c = _statusColor(p.status);
            return GestureDetector(
              onTap: () => _showPostDetails(context, p),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border(right: BorderSide(color: c, width: 4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            p.title,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _statusLabel(p.status),
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: c,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.description,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _iconLabel(Icons.person_outline_rounded, p.clientName),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _iconLabel(
                            Icons.location_on_outlined,
                            p.location,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${p.offersCount} عروض',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

  static Widget _iconLabel(IconData ic, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(ic, size: 14, color: AppColors.textHint),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          t,
          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textHint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  static void _showPostDetails(BuildContext context, PostModel p) {
    final c = _statusColor(p.status);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.work_rounded, color: c, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: c.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _statusLabel(p.status),
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: c,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _detailRow(
                    Icons.description_outlined,
                    'الوصف',
                    p.description,
                  ),
                  _detailRow(Icons.person_outline, 'العميل', p.clientName),
                  _detailRow(
                    Icons.build_circle_outlined,
                    'التخصص',
                    p.specialty,
                  ),
                  _detailRow(Icons.location_on_outlined, 'الموقع', p.location),
                  _detailRow(
                    Icons.local_offer_rounded,
                    'عدد العروض',
                    '${p.offersCount}',
                  ),
                  _detailRow(
                    Icons.calendar_today_rounded,
                    'تاريخ الإنشاء',
                    '${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}',
                  ),
                  if (p.acceptedArtisanId != null)
                    FutureBuilder<UserModel>(
                      future: sl<AuthRepository>().getUserById(
                        p.acceptedArtisanId!,
                      ),
                      builder: (context, snapshot) {
                        final name = snapshot.data?.name ?? '...';
                        return _detailRow(
                          Icons.engineering_rounded,
                          'الحرفي المقبول',
                          name,
                        );
                      },
                    ),
                  if (p.acceptedPrice != null)
                    _detailRow(
                      Icons.payments_rounded,
                      'السعر المتفق',
                      '${p.acceptedPrice} ج.م',
                    ),
                  if (p.images.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'صور الطلب (${p.images.length})',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: p.images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            p.images[i],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: AppColors.background,
                              child: const Icon(
                                Icons.broken_image,
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (p.status == 'open' || p.status == 'accepted')
                    ElevatedButton.icon(
                      onPressed: () {
                        sl<PostRepository>().updatePostStatus(
                          p.id,
                          'admin_rejected',
                        );
                        Navigator.pop(ctx);
                        AppComponents.showSnackBar(
                          context,
                          'تم رفض الطلب من قبل الإدارة',
                          isError: true,
                        );
                      },
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      label: Text(
                        'رفض الطلب (إدارياً)',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _detailRow(IconData ic, String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ic, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            val,
            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  4) Conversations Tab — المحادثات
// ══════════════════════════════════════════════════════════════════════════════
class _ConversationsTab extends StatelessWidget {
  const _ConversationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConversationModel>>(
      stream: sl<ChatRepository>().getAllConversations(),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final convs = snap.data!;
        if (convs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 56,
                  color: AppColors.textHint.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد محادثات',
                  style: GoogleFonts.cairo(
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: convs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final c = convs[i];
            final names = c.participantNames.values.toList();
            final display = names.length >= 2
                ? '${names[0]} ↔ ${names[1]}'
                : names.isNotEmpty
                ? names[0]
                : 'محادثة';
            return GestureDetector(
              onTap: () {
                if (c.participants.isEmpty) return;
                final u = c.participants.first;
                final isSupport = c.participants.contains(
                  FirebaseConstants.supportId,
                );
                context.push(
                  '/chat-room/${c.id}',
                  extra: {
                    'name': isSupport
                        ? 'دعم: ${c.participantNames[u] ?? "مستخدم"}'
                        : 'معاينة: ${c.participantNames[u] ?? "مستخدم"}',
                    'id': u,
                    'isAdminView': true,
                    'isSupportView': isSupport,
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (c.lastMessage.isNotEmpty)
                            Text(
                              c.lastMessage,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.textHint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (c.isClosed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textHint.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'مغلقة',
                              style: GoogleFonts.cairo(
                                fontSize: 9,
                                color: AppColors.textHint,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${c.lastMessageTime.day}/${c.lastMessageTime.month}',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: AppColors.textHint,
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

// ══════════════════════════════════════════════════════════════════════════════
//  5) Reports Tab — البلاغات
// ══════════════════════════════════════════════════════════════════════════════
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReportModel>>(
      stream: sl<ReportRepository>().getAllReports(),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final reports = snap.data!;
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 56,
                  color: AppColors.success.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد بلاغات 🎉',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (ctx, i) => _FullReportCard(report: reports[i]),
        );
      },
    );
  }
}

class _FullReportCard extends StatelessWidget {
  final ReportModel report;
  const _FullReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final p = report.status == 'pending';
    final sid = report.id.length > 6 ? report.id.substring(0, 6) : report.id;
    final accentColor = p ? AppColors.error : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(right: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  p ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<UserModel>(
                  future: sl<AuthRepository>().getUserById(report.reporterId),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final name = user?.name ?? 'نظام';
                    final role = user?.role == 'client'
                        ? 'عميل'
                        : user?.role == 'artisan'
                        ? 'حرفي'
                        : user?.role == 'admin'
                        ? 'أدمن'
                        : 'مستخدم';
                    final roleColor = user?.role == 'client'
                        ? AppColors.primary
                        : user?.role == 'artisan'
                        ? AppColors.secondary
                        : AppColors.success;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'المبلّغ: $name',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (user != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  role,
                                  style: GoogleFonts.cairo(
                                    fontSize: 9,
                                    color: roleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'بلاغ #$sid',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p ? 'قيد المراجعة' : 'تم الحل',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          Text(
            report.reason,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            report.details,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textHint),
          ),

          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              if (report.chatId != null && report.chatId!.isNotEmpty)
                Expanded(
                  child: _actionBtn(
                    'معاينة المحادثة',
                    Icons.forum_rounded,
                    AppColors.primary,
                    () => _viewChat(context, report.chatId!),
                  ),
                ),
              if (report.chatId != null && p) const SizedBox(width: 8),
              if (p)
                Expanded(
                  child: _actionBtn(
                    'حل البلاغ',
                    Icons.check_rounded,
                    AppColors.success,
                    () => _showResolveDialog(context, report),
                    filled: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    String t,
    IconData ic,
    Color c,
    VoidCallback onTap, {
    bool filled = false,
  }) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(ic, size: 16),
    label: Text(
      t,
      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: filled ? c : c.withOpacity(0.08),
      foregroundColor: filled ? Colors.white : c,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Future<void> _viewChat(BuildContext context, String chatId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final conversation = await sl<ChatRepository>()
          .getConversation(chatId)
          .first;
      if (!context.mounted) return;
      Navigator.pop(context);
      if (conversation.participants.isEmpty) {
        AppComponents.showSnackBar(context, 'المحادثة فارغة', isError: true);
        return;
      }
      final uid = conversation.participants.firstWhere(
        (p) => p != FirebaseConstants.supportId,
        orElse: () => conversation.participants.first,
      );
      final isSupport = chatId.contains(FirebaseConstants.supportId);
      if (context.mounted) {
        context.push(
          '/chat-room/$chatId',
          extra: {
            'name': isSupport
                ? 'دعم: ${conversation.participantNames[uid] ?? "مستخدم"}'
                : 'معاينة: ${conversation.participantNames[uid] ?? "مستخدم"}',
            'id': uid,
            'isAdminView': true,
            'isSupportView': isSupport,
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        AppComponents.showSnackBar(context, 'خطأ: $e', isError: true);
      }
    }
  }

  void _showResolveDialog(BuildContext context, ReportModel report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'حل البلاغ',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'اختر الإجراء المناسب لحل هذا البلاغ',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _resolveAndBanByRole(context, report, FirebaseConstants.roleClient, 'تم تقييد حساب العميل وحل البلاغ');
              },
              icon: const Icon(Icons.block_rounded, size: 20),
              label: Text(
                'تقييد حساب العميل',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withOpacity(0.1),
                foregroundColor: AppColors.error,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _resolveAndBanByRole(context, report, FirebaseConstants.roleArtisan, 'تم تقييد حساب الحرفي وحل البلاغ');
              },
              icon: const Icon(Icons.block_rounded, size: 20),
              label: Text(
                'تقييد حساب الحرفي',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                sl<ReportRepository>().updateReportStatus(report.id, 'resolved');
                AppComponents.showSnackBar(context, 'تم حل البلاغ بدون حظر');
              },
              child: Text(
                'حل البلاغ فقط',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveAndBanByRole(BuildContext context, ReportModel report, String targetRole, String successMsg) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final authRepo = sl<AuthRepository>();
      
      // جلب بيانات الطرفين لتحديد دور كل منهما بشكل ديناميكي
      final reporter = await authRepo.getUserById(report.reporterId);
      final reported = await authRepo.getUserById(report.reportedId);
      
      String? targetId;
      if (reporter.role == targetRole) {
        targetId = reporter.uid;
      } else if (reported.role == targetRole) {
        targetId = reported.uid;
      }

      if (targetId == null) {
        if (context.mounted) {
          Navigator.pop(context); // إغلاق التحميل
          AppComponents.showSnackBar(context, 'خطأ: لم يتم العثور على حساب بهذا الدور في البلاغ', isError: true);
        }
        return;
      }

      // تقييد حساب المستخدم
      await authRepo.toggleUserActive(targetId, false);
      // حل البلاغ
      await sl<ReportRepository>().updateReportStatus(report.id, 'resolved');
      
      if (context.mounted) {
        Navigator.pop(context); // إغلاق التحميل
        AppComponents.showSnackBar(context, successMsg);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // إغلاق التحميل إذا كان مفتوحاً
        AppComponents.showSnackBar(context, 'حدث خطأ أثناء تقييد الحساب: $e', isError: true);
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  6) Ratings Tab — التقييمات
// ══════════════════════════════════════════════════════════════════════════════
class _RatingsTab extends StatelessWidget {
  const _RatingsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RatingModel>>(
      stream: sl<RatingRepository>().getAllRatings(),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final ratings = snap.data!;
        if (ratings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_outline_rounded,
                  size: 56,
                  color: AppColors.starActive.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد تقييمات بعد',
                  style: GoogleFonts.cairo(
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: ratings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) => _RatingCard(rating: ratings[i]),
        );
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  final RatingModel rating;
  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: rating.isHidden ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: rating.isHidden
            ? Border.all(color: AppColors.error.withOpacity(0.15))
            : Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stars + Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.starActive.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < rating.rating.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 14,
                        color: AppColors.starActive,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.rating.toStringAsFixed(1),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.starActive,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (rating.isHidden)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'مخفي',
                    style: GoogleFonts.cairo(
                      fontSize: 9,
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.textHint,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                onSelected: (v) {
                  if (v == 'toggle')
                    sl<RatingRepository>().toggleRatingVisibility(
                      rating.id,
                      !rating.isHidden,
                    );
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      rating.isHidden ? 'إظهار التقييم' : 'إخفاء التقييم',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Client
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'العميل: ',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Flexible(
                child: Text(
                  rating.clientName,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Artisan
          FutureBuilder<UserModel>(
            future: sl<AuthRepository>().getUserById(rating.artisanId),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return Text(
                  'للحرفي: ${rating.artisanId.substring(0, 6)}...',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                );
              final art = snap.data!;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.secondary.withOpacity(0.1),
                      child: Text(
                        art.name.isNotEmpty ? art.name[0] : '?',
                        style: GoogleFonts.cairo(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                art.name,
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              if (art.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${art.specialty} • ${art.rating.toStringAsFixed(1)} ⭐ (${art.ratingCount})',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Comment
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '"${rating.comment}"',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${rating.createdAt.day}/${rating.createdAt.month}/${rating.createdAt.year}',
            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  7) Support Tab — الدعم الفني
// ══════════════════════════════════════════════════════════════════════════════
class _SupportTab extends StatelessWidget {
  const _SupportTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConversationModel>>(
      stream: sl<ChatRepository>().getUserConversations(
        FirebaseConstants.supportId,
      ),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final convs = snap.data!;
        if (convs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.support_agent_rounded,
                  size: 64,
                  color: AppColors.primary.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد طلبات دعم حالياً',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: convs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final c = convs[i];
            final otherUid = c.participants.firstWhere(
              (id) => id != FirebaseConstants.supportId,
              orElse: () => '',
            );
            final otherName = c.participantNames[otherUid] ?? 'مستخدم';
            final isUnread =
                !c.isLastMessageRead &&
                c.lastMessageSenderId != FirebaseConstants.supportId;

            return GestureDetector(
              onTap: () => context.push(
                '/chat-room/${c.id}',
                extra: {
                  'name': 'دعم: $otherName',
                  'id': otherUid,
                  'isAdminView': true,
                  'isSupportView': true,
                },
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: isUnread
                      ? Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        )
                      : Border.all(color: AppColors.border.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        AppComponents.userAvatar(
                          imageUrl: c.getOtherParticipantImage(
                            FirebaseConstants.supportId,
                          ),
                          name: otherName,
                          radius: 24,
                          showBorder: isUnread,
                        ),
                        if (isUnread)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  otherName,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildRoleBadge(
                                c.getOtherParticipantRole(
                                  FirebaseConstants.supportId,
                                ),
                                c.getOtherParticipantSpecialty(
                                  FirebaseConstants.supportId,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.lastMessage,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: isUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${c.lastMessageTime.hour}:${c.lastMessageTime.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'جديد',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

// ══════════════════════════════════════════════════════════════════════════════
//  9) Approvals Tab — طلبات توثيق الحرفيين
// ══════════════════════════════════════════════════════════════════════════════
class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: sl<AuthRepository>().getAllUsers(),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final pendingArtisans = snap.data!
            .where((u) => u.role == 'artisan' && u.approvalStatus == 'pending')
            .toList();

        if (pendingArtisans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'لا توجد طلبات معلقة حالياً',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'تمت معالجة جميع طلبات توثيق الحرفيين',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: pendingArtisans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) => _ApprovalCard(user: pendingArtisans[i]),
        );
      },
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final UserModel user;
  const _ApprovalCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppComponents.userAvatar(
                imageUrl: user.profileImage,
                name: user.name,
                radius: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      user.specialty,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'قيد الانتظار',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showReviewDialog(context, user),
                  icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                  label: Text(
                    'مراجعة المستندات',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, UserModel u) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مراجعة طلب التوثيق',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // User Info
              Row(
                children: [
                  AppComponents.userAvatar(
                    imageUrl: u.profileImage,
                    name: u.name,
                    radius: 30,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        u.phone,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ID Card
              Text(
                'صورة الهوية / جواز السفر:',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildDocumentView(context, u.idCardImage),

              const SizedBox(height: 24),

              // Selfie
              Text(
                'صورة السيلفي:',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildDocumentView(context, u.selfieImage),

              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _handleApproval(context, u.uid, 'approved', ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'قبول الحرفي',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _handleApproval(context, u.uid, 'rejected', ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'رفض الطلب',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentView(BuildContext context, String imageUrl) {
    return GestureDetector(
      onTap: () => _showFullImage(context, imageUrl),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: 40,
                      color: AppColors.textHint,
                    ),
                  ),
                )
              : const Center(child: Text('لا توجد صورة مرفوعة')),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.network(url))),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApproval(
    BuildContext context,
    String uid,
    String status,
    BuildContext dialogCtx,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await sl<AuthRepository>().updateApprovalStatus(uid, status);
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      AppComponents.showSnackBarForMessenger(
        messenger,
        status == 'approved' ? 'تم قبول الحرفي بنجاح' : 'تم رفض طلب التوثيق',
      );
    } catch (e) {
      AppComponents.showSnackBarForMessenger(
        messenger,
        'حدث خطأ أثناء المعالجة',
        isError: true,
      );
    }
  }
}

Widget _buildRoleBadge(String role, [String? specialty]) {
  String label = 'مستخدم';
  Color color = AppColors.success;

  if (role == 'artisan') {
    label = (specialty != null && specialty.isNotEmpty)
        ? 'حرفي - $specialty'
        : 'حرفي';
    color = AppColors.primary;
  } else if (role == 'admin') {
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
