import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/firebase_constants.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../ratings/presentation/widgets/rating_widget.dart';
import '../../../ratings/data/models/rating_model.dart';
import '../../../ratings/data/repositories/rating_repository.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../../app/di/injection_container.dart';
import '../../../posts/data/repositories/post_repository.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../../auth/presentation/widgets/change_phone_dialog.dart';
import '../../../../app/widgets/map_location_picker.dart';

class ArtisanProfilePage extends StatefulWidget {
  final UserModel artisan;
  final bool isClient;
  final bool isSelf;
  final bool showBackButton;
  final bool showSettings;

  const ArtisanProfilePage({
    super.key,
    required this.artisan,
    this.isClient = false,
    this.isSelf = false,
    this.showBackButton = true,
    this.showSettings = false,
  });

  @override
  State<ArtisanProfilePage> createState() => _ArtisanProfilePageState();
}

class _ArtisanProfilePageState extends State<ArtisanProfilePage> {
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;

  /// جلب مرة واحدة لمعرفة إن كان العميل أرسل عرضاً مسبقاً (للشريط السفلي الثابت)
  Future<bool>? _clientOfferCheckFuture;

  void _syncCollapsedTitle() {
    if (!_scrollController.hasClients) return;
    final o = _scrollController.offset;
    // هستيريسيس يمنع وميض العنوان عند حدود طي الـ AppBar مع الارتداد
    final nextCollapsed = _showTitle ? (o > 170) : (o > 230);
    if (nextCollapsed != _showTitle) {
      setState(() => _showTitle = nextCollapsed);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncCollapsedTitle);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  UserModel get artisan => widget.artisan;

  Future<void> _contactSupport(BuildContext context) async {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      final user = authState.user;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final conversation = await sl<ChatRepository>().getOrCreateConversation(
          user1Id: user.uid,
          user1Name: user.name,
          user2Id: FirebaseConstants.supportId,
          user2Name: 'الدعم الفني',
          postId: 'support',
          postTitle: 'دعم فني - الملف الشخصي',
        );

        if (context.mounted) {
          Navigator.pop(context); // Close the loading dialog
          context.push(
            '/chat-room/${conversation.id}',
            extra: {'name': 'الدعم الفني', 'id': FirebaseConstants.supportId},
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      }
    }
  }

  Widget _buildStickyDirectRequestBar({
    required BuildContext context,
    required bool effectiveIsClient,
    required bool effectiveIsSelf,
    required AuthState authState,
  }) {
    if (!effectiveIsClient ||
        effectiveIsSelf ||
        authState is! AuthAuthenticated) {
      return const SizedBox.shrink();
    }

    _clientOfferCheckFuture ??= sl<PostRepository>()
        .checkIfArtisanHasOfferedToClient(artisan.uid, authState.user.uid);

    return FutureBuilder<bool>(
      future: _clientOfferCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data == true) {
          return const SizedBox.shrink();
        }

        final Widget inner;
        if (snapshot.connectionState == ConnectionState.waiting) {
          inner = Opacity(
            opacity: 0.55,
            child: IgnorePointer(
              child: AppComponents.primaryButton(
                label: 'إرسال طلب عمل للحرفي',
                suffixIcon: Icons.send_rounded,
                onPressed: () {},
              ),
            ),
          );
        } else {
          inner = AppComponents.primaryButton(
            label: 'إرسال طلب عمل للحرفي',
            suffixIcon: Icons.send_rounded,
            onPressed: () {
              context.push('/direct-request', extra: artisan);
            },
          );
        }

        return Material(
          elevation: 12,
          shadowColor: Colors.black26,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: SafeArea(top: false, child: inner),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          bool effectiveIsClient = widget.isClient;
          bool effectiveIsSelf = widget.isSelf;

          if (authState is AuthAuthenticated) {
            effectiveIsClient = authState.user.isClient;
            effectiveIsSelf = authState.user.uid == artisan.uid;
          }

          final showInfoForNonClient =
              !effectiveIsSelf &&
              (authState is AuthUnauthenticated ||
                  authState is AuthError ||
                  (authState is AuthAuthenticated && !authState.user.isClient));

          return Scaffold(
            backgroundColor: AppColors.background,
            bottomNavigationBar: _buildStickyDirectRequestBar(
              context: context,
              effectiveIsClient: effectiveIsClient,
              effectiveIsSelf: effectiveIsSelf,
              authState: authState,
            ),
            // تمرير بدون ارتداد قوي (Clamping) يقلل الاهتزاز مع SliverAppBar عند السحب لأعلى
            body: CustomScrollView(
              physics: const ClampingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              controller: _scrollController,
              slivers: [
                // ══════════════════════════════════════════
                // HERO HEADER — No blue lines, clean gradient
                // ══════════════════════════════════════════
                SliverAppBar(
                  expandedHeight: artisan.profileImage.isNotEmpty ? 400 : 280,
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
                        // ← زرار الرجوع (Always visible)
                        if (widget.showBackButton)
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),

                        // Elements that fade in on scroll
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: _showTitle ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Row(
                              children: [
                                const Spacer(),
                                // الاسم في المنتصف
                                Text(
                                  artisan.name,
                                  style: GoogleFonts.cairo(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                // الصنعة مع الأيقونة في النهاية
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
                                        Icons.handyman_rounded,
                                        size: 12,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        artisan.specialty,
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
                        // ── 1. Background (Image or Gradient) ──
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(32),
                          ),
                          child: artisan.profileImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: artisan.profileImage,
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

                        // ── 2. Decorative circles (Depth) - Only if NO image ──
                        if (artisan.profileImage.isEmpty) ...[
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

                        // ── 3. Readability Overlay ──
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
                                    artisan.profileImage.isNotEmpty ? 0.7 : 0.3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Edit Profile Image Button (Self only) ──
                        if (effectiveIsSelf)
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
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
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

                        // ── 4. Profile Identity ──
                        Positioned(
                          bottom: 36,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              // Avatar - Only if NO image in background
                              if (artisan.profileImage.isEmpty)
                                AppComponents.userAvatar(
                                  imageUrl: artisan.profileImage,
                                  name: artisan.name,
                                  radius: 65,
                                  fontSize: 48,
                                ).animate().scale(
                                  duration: 600.ms,
                                  curve: Curves.elasticOut,
                                ),

                              const SizedBox(height: 14),

                              // Name — بيختفي لما الـ AppBar title يظهر
                              AnimatedOpacity(
                                opacity: _showTitle ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  artisan.name,
                                  style: GoogleFonts.cairo(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Specialty pill
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
                                      Icons.handyman_rounded,
                                      size: 13,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      artisan.specialty,
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

                // ── Body content below header ──
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // ── Stats Card ──
                      Transform.translate(
                        offset: const Offset(0, -16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildStatsCard(),
                        ),
                      ),

                      if (showInfoForNonClient)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: _buildInfoBanner(),
                        ),

                      const SizedBox(height: 8),

                      // ── About Section ──
                      _buildSection(
                            icon: Icons.person_outline_rounded,
                            title: 'نبذة عن الحرفي',
                            trailing: effectiveIsSelf
                                ? GestureDetector(
                                    onTap: () => _editBio(context),
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
                                            'تعديل',
                                            style: GoogleFonts.cairo(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : null,
                            child: Text(
                              artisan.bio.isNotEmpty
                                  ? artisan.bio
                                  : 'لا يوجد نبذة تعريفية حالياً.',
                              style: GoogleFonts.cairo(
                                height: 1.7,
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.05, end: 0),

                      const SizedBox(height: 12),

                      // ── Portfolio Section ──
                      _buildSection(
                        icon: Icons.photo_library_outlined,
                        title: 'معرض الأعمال',
                        trailing:
                            effectiveIsSelf &&
                                artisan.portfolioImages.length < 10
                            ? GestureDetector(
                                onTap: () => _addPortfolioImage(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'إضافة (${artisan.portfolioImages.length}/10)',
                                        style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : effectiveIsSelf
                            ? Text(
                                '${artisan.portfolioImages.length}/10',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                        child: artisan.portfolioImages.isEmpty
                            ? _buildEmptyPortfolio(effectiveIsSelf)
                            : _buildPortfolioGrid(context, effectiveIsSelf),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

                      const SizedBox(height: 12),

                      // ── Ratings Section ──
                      _buildSection(
                            icon: Icons.star_outline_rounded,
                            title: 'التقييمات',
                            trailing: RatingStars(
                              rating: artisan.rating,
                              size: 16,
                            ),
                            child: _buildRatingsList(artisan.uid),
                          )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideY(begin: 0.05, end: 0),

                      if (widget.showSettings) ...[
                        const SizedBox(height: 12),
                        _buildSettingsSection(context)
                            .animate()
                            .fadeIn(delay: 400.ms)
                            .slideY(begin: 0.05, end: 0),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════

  Widget _buildStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                '',
                artisan.rating.toStringAsFixed(1),
                Icons.star_rounded,
                const Color(0xFFF59E0B),
              ),
            ),
            _buildDivider(),
            Expanded(
              child: _buildStatItem(
                '',
                artisan.address.trim().isNotEmpty
                    ? artisan.address.trim()
                    : 'غير محدد',
                Icons.location_on_rounded,
                AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.fade,
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 50, color: const Color(0xFFE5E7EB));
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'يجب أن تكون صاحب مشروع (عميل) لإرسال طلبات عمل لأي حرفي.',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPortfolio([bool isSelf = false]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 40,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Text(
              isSelf
                  ? 'أضف صور لأعمالك السابقة لجذب المزيد من العملاء'
                  : 'لا توجد صور في معرض الأعمال',
              style: GoogleFonts.cairo(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelf) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _addPortfolioImage(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'إضافة صور',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioGrid(BuildContext context, [bool isSelf = false]) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: artisan.portfolioImages.length,
      itemBuilder: (context, index) {
        final imageUrl = artisan.portfolioImages[index];
        return Stack(
              children: [
                GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                if (isSelf)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () =>
                          _confirmDeletePortfolioImage(context, imageUrl),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            )
            .animate(delay: (60 * index).ms)
            .fadeIn(duration: 300.ms)
            .scale(begin: const Offset(0.9, 0.9));
      },
    );
  }

  Widget _buildRatingsList(String artisanId) {
    return StreamBuilder<List<RatingModel>>(
      stream: sl<RatingRepository>().getArtisanRatings(artisanId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final allRatings = snapshot.data ?? [];
        final ratings = allRatings.where((r) => !r.isHidden).toList();

        if (ratings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.star_border_rounded,
                  size: 20,
                  color: AppColors.textSecondary.withOpacity(0.4),
                ),
                const SizedBox(width: 8),
                Text(
                  'لا توجد تقييمات بعد',
                  style: GoogleFonts.cairo(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ratings.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 24, color: Color(0xFFF3F4F6)),
          itemBuilder: (context, index) {
            final rating = ratings[index];
            return _buildRatingCard(rating, index);
          },
        );
      },
    );
  }

  Widget _buildRatingCard(RatingModel rating, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: Text(
                rating.clientName.isNotEmpty
                    ? rating.clientName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.cairo(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rating.clientName,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(rating.createdAt),
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            RatingStars(rating: rating.rating, size: 13),
          ],
        ),
        if (rating.comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            rating.comment,
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ],
    ).animate(delay: (80 * index).ms).fadeIn(duration: 300.ms);
  }

  // ── Portfolio Management Methods ──────────────────────────────────
  Future<void> _pickAndUploadProfileImage(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = File(pickedFile.path);
      await context.read<AuthCubit>().updateProfileImage(file);
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

  Future<void> _changeLocation(BuildContext context) async {
    final result = await MapLocationPicker.show(
      context,
      initialLat: widget.artisan.latitude,
      initialLng: widget.artisan.longitude,
      initialAddress: widget.artisan.address,
    );

    if (result != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await context.read<AuthCubit>().updateLocation(
              result.address,
              result.latitude,
              result.longitude,
            );
        if (context.mounted) {
          Navigator.pop(context); // close dialog
          AppComponents.showSnackBar(context, 'تم تحديث الموقع بنجاح');
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
  }

  void _editBio(BuildContext context) {
    final bioController = TextEditingController(text: artisan.bio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تعديل النبذة التعريفية',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              maxLines: 5,
              style: GoogleFonts.cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'اكتب نبذة عنك وعن خبراتك...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AppComponents.primaryButton(
              label: 'حفظ',
              onPressed: () async {
                final newBio = bioController.text.trim();
                Navigator.pop(ctx);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  await context.read<AuthCubit>().updateBio(newBio);
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppComponents.showSnackBar(context, 'تم حفظ النبذة بنجاح');
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppComponents.showSnackBar(
                      context,
                      e.toString().replaceAll('Exception: ', ''),
                      isError: true,
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _addPortfolioImage(BuildContext context) async {
    final source = await AppComponents.showImageSourceSheet(context);
    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1000,
      );
      if (pickedFile == null || !context.mounted) return;
      await _uploadPortfolioImage(context, File(pickedFile.path));
    } else {
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1000,
      );
      if (pickedFiles.isEmpty || !context.mounted) return;
      final currentCount = artisan.portfolioImages.length;
      final maxToAdd = 10 - currentCount;
      final filesToAdd = pickedFiles.take(maxToAdd).toList();
      for (final pf in filesToAdd) {
        if (!context.mounted) break;
        await _uploadPortfolioImage(context, File(pf.path));
      }
      if (pickedFiles.length > maxToAdd && context.mounted) {
        AppComponents.showSnackBar(
          context,
          'تم إضافة $maxToAdd صور فقط (الحد الأقصى 10 صور)',
          isError: true,
        );
      }
    }
  }

  Future<void> _uploadPortfolioImage(BuildContext ctx, File file) async {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ctx.read<AuthCubit>().addPortfolioImage(file);
      if (ctx.mounted) {
        Navigator.pop(ctx);
        AppComponents.showSnackBar(ctx, 'تم إضافة الصورة بنجاح');
      }
    } catch (e) {
      if (ctx.mounted) {
        Navigator.pop(ctx);
        AppComponents.showSnackBar(
          ctx,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  void _confirmDeletePortfolioImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف الصورة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف هذه الصورة من معرض أعمالك؟',
          style: GoogleFonts.cairo(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<AuthCubit>()
                  .deletePortfolioImage(imageUrl)
                  .then((_) {
                    if (context.mounted) {
                      AppComponents.showSnackBar(
                        context,
                        'تم حذف الصورة بنجاح',
                      );
                    }
                  })
                  .catchError((e) {
                    if (context.mounted) {
                      AppComponents.showSnackBar(
                        context,
                        'فشل حذف الصورة',
                        isError: true,
                      );
                    }
                  });
            },
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return _buildSection(
      icon: Icons.settings_rounded,
      title: 'الإعدادات والحساب',
      child: Column(
        children: [
          if (widget.artisan.role == 'admin') ...[
            _buildClickableOption(
              context: context,
              icon: Icons.admin_panel_settings_rounded,
              title: 'الذهاب للادمن',
              onTap: () => context.go('/admin'),
            ),
            const Divider(height: 32),
          ],
          _buildProfileOption(
            Icons.person_outline_rounded,
            'الاسم بالكامل',
            widget.artisan.name,
          ),
          const Divider(height: 32),
          _buildProfileOption(
            Icons.phone_outlined,
            'رقم الهاتف',
            widget.artisan.phone.isNotEmpty
                ? widget.artisan.phone
                : 'غير متوفر',
            trailing: GestureDetector(
              onTap: () => ChangePhoneDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
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
          const Divider(height: 32),
          _buildProfileOption(
            Icons.location_on_outlined,
            'الموقع',
            widget.artisan.address.isNotEmpty
                ? widget.artisan.address
                : 'غير متوفر',
            trailing: GestureDetector(
              onTap: () => _changeLocation(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
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
          const Divider(height: 32),
          _buildClickableOption(
            context: context,
            icon: Icons.support_agent_rounded,
            title: 'التواصل مع الدعم الفني',
            onTap: () => _contactSupport(context),
          ),
          const Divider(height: 32),
          AppComponents.primaryButton(
            label: 'تسجيل الخروج',
            onPressed: () => context.read<AuthCubit>().logout(),
            backgroundColor: AppColors.error,
            prefixIcon: Icons.logout_rounded,
          ),
          const SizedBox(
            height: 60,
          ), // Add space at the bottom for bottom nav bar visibility
        ],
      ),
    );
  }

  Widget _buildClickableOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.textHint,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(
    IconData icon,
    String title,
    String value, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: Image.network(imageUrl)),
            Positioned(
              top: 48,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
