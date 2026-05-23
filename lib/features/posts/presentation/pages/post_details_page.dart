import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/models/post_model.dart';
import '../../data/models/post_model_extension.dart';
import '../../data/models/offer_model.dart';
import '../../data/repositories/post_repository.dart';
import '../bloc/post_cubit.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../chat/presentation/bloc/chat_cubit.dart';
import '../../../ratings/presentation/widgets/rating_widget.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../requests/data/repositories/service_request_repository.dart';
import '../../../../app/di/injection_container.dart';

class PostDetailsPage extends StatefulWidget {
  final PostModel? post;
  final String? postId;
  final bool isDirectRequest;

  const PostDetailsPage({
    super.key,
    this.post,
    this.postId,
    this.isDirectRequest = false,
  });

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  late ScrollController _scrollController;
  PostModel? _post;
  bool _isLoading = false;
  String? _error;
  final ValueNotifier<bool> _showTitleNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    if (widget.post != null) {
      _post = widget.post;
    } else if (widget.postId != null) {
      _fetchPost();
    }

    _scrollController.addListener(_syncCollapsedTitle);

    if (_post != null) {
      _checkAndScrollToRating();
    }
  }

  void _syncCollapsedTitle() {
    if (!_scrollController.hasClients) return;
    final o = _scrollController.offset;
    final nextCollapsed = _showTitleNotifier.value ? (o > 175) : (o > 220);
    if (nextCollapsed != _showTitleNotifier.value) {
      _showTitleNotifier.value = nextCollapsed;
    }
  }

  void _checkAndScrollToRating() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated &&
          _post != null &&
          _post!.status == 'completed' &&
          _post!.clientId == authState.user.uid) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutQuart,
            );
          }
        });
      }
    });
  }

  Future<void> _fetchPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      PostModel? result;
      if (_post?.isDirectRequest ?? widget.isDirectRequest) {
        final request = await sl<ServiceRequestRepository>().getRequestById(widget.postId ?? _post!.id);
        result = request?.toPostModel();
      } else {
        result = await sl<PostRepository>().getPostById(widget.postId ?? _post!.id);
        
        // Fallback: If not found in posts, try direct requests (for chat links)
        if (result == null && widget.postId != null) {
          final request = await sl<ServiceRequestRepository>().getRequestById(widget.postId!);
          result = request?.toPostModel();
        }
      }

      if (result != null) {
        setState(() {
          _post = result;
          _isLoading = false;
        });
        _checkAndScrollToRating();
      } else {
        setState(() {
          _error = 'الطلب غير موجود أو تم حذفه';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ أثناء تحميل البيانات';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _showTitleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppComponents.premiumAppBar(context, title: 'تحميل...'),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null || _post == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppComponents.premiumAppBar(context, title: 'خطأ'),
        body: AppComponents.errorState(
          message: _error ?? 'حدث خطأ غير متوقع',
          onRetry: _fetchPost,
        ),
      );
    }

    final post = _post!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<PostCubit, PostState>(
        listener: (context, state) {
          if (state is PostSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message, style: GoogleFonts.cairo()), backgroundColor: AppColors.success),
            );
            
            if (state.extraData != null && state.extraData!.containsKey('conversationId')) {
              final convId = state.extraData!['conversationId'];
              final name = state.extraData!['otherUserName'];
              final id = state.extraData!['otherUserId'];
              
              context.pushReplacement('/chat-room/$convId', extra: {'name': name, 'id': id});
            } else if (state.message == 'تم إنهاء العمل بنجاح') {
              // Stay on page, update status locally and scroll to rating
              setState(() {
                _post = _post!.copyWith(status: 'completed');
              });
              
              // Give UI time to rebuild with rating widget
              Future.delayed(const Duration(milliseconds: 600), () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutQuart,
                  );
                }
              });
            } else {
              if (GoRouter.of(context).canPop()) context.pop();
            }
          } else if (state is PostError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message, style: GoogleFonts.cairo()), backgroundColor: AppColors.error),
            );
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Premium Sliver App Bar ──────────────────
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              stretch: false,
              backgroundColor: AppColors.primary,
              elevation: 0,
              automaticallyImplyLeading: false,
              leadingWidth: 48,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => context.pop(),
              ),
              title: ValueListenableBuilder<bool>(
                valueListenable: _showTitleNotifier,
                builder: (context, showTitle, child) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: showTitle ? 1.0 : 0.0,
                  child: Text(
                    post.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              centerTitle: true,
              actions: const [SizedBox(width: 48)],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (post.images.isNotEmpty)
                      Image.network(post.images[0], fit: BoxFit.cover)
                    else
                      Container(
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                        child: Icon(
                          Icons.handyman_outlined,
                          size: 80,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    
                    // Improved Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),

                    // Status Badge
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: post.statusColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                            const SizedBox(width: 6),
                            Text(
                              post.statusText,
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.5, end: 0),

                    // Title at bottom (Expanded)
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _showTitleNotifier,
                        builder: (context, showTitle, child) => AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: showTitle ? 0.0 : 1.0,
                          child: Text(
                            post.title,
                            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5, end: 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Meta Info Row ───────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.shadowLevel1,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 420;
                          final itemWidth =
                              isCompact
                                  ? (constraints.maxWidth - 12) / 2
                                  : (constraints.maxWidth - 24) / 3;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                child: _buildHeaderStat(
                                  Icons.handyman_rounded,
                                  'التخصص',
                                  post.specialty,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildHeaderStat(
                                  Icons.location_on_rounded,
                                  'الموقع',
                                  post.location,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildHeaderStat(
                                  Icons.calendar_today_rounded,
                                  'التاريخ',
                                  '${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 32),

                    // ── Description ────────────────────────
                    Text(
                      'تفاصيل الطلب',
                      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.description,
                      style: GoogleFonts.cairo(fontSize: 15, color: AppColors.textSecondary, height: 1.6),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 32),

                    // ── Attached Images ───────────────────
                    if (post.images.isNotEmpty) ...[
                      Text(
                        'الصور المرفقة',
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          itemCount: post.images.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _showImageDialog(context, post.images[index]),
                              child: Hero(
                                tag: post.images[index],
                                child: Container(
                                  width: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: AppColors.shadowLevel1,
                                    image: DecorationImage(image: NetworkImage(post.images[index]), fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            ).animate().scale(delay: (index * 100).ms);
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // ── Participant Section ──────────
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, authState) {
                        if (authState is! AuthAuthenticated) return const SizedBox.shrink();
                        final currentUser = authState.user;

                        if (currentUser.isClient && (post.status == 'accepted' || post.status == 'completed' || (post.isDirectRequest && post.status == 'open')) && post.acceptedArtisanId != null) {
                          return Column(
                            key: const ValueKey('artisan_section'),
                            children: [
                              _buildArtisanSection(post.acceptedArtisanId ?? ''),
                              const SizedBox(height: 32),
                            ],
                          );
                        }

                        if (currentUser.isArtisan) {
                          return Column(
                            key: const ValueKey('client_section'),
                            children: [
                              _buildClientSection(post.clientId),
                              const SizedBox(height: 32),
                            ],
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),

                    // ── Offers & Ratings ────────────────
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, authState) {
                        if (authState is! AuthAuthenticated) return const SizedBox.shrink();
                        final currentUser = authState.user;

                        if (post.status == 'open' && currentUser.uid == post.clientId) {
                          if (post.isDirectRequest) {
                            return Column(
                              children: [
                                const SizedBox(height: 32),
                                AppComponents.card(
                                  padding: const EdgeInsets.all(24),
                                  backgroundColor: AppColors.primary.withOpacity(0.05),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'لقد قمت بإرسال هذا الطلب مباشرة للحرفي الموضح أدناه. في انتظار موافقته للبدء.',
                                          style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 400.ms);
                          }
                          return _buildOffersListForClient(currentUser);
                        }
                        
                        if (post.status == 'completed' && currentUser.uid == post.clientId) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: RatingWidget(
                              artisanId: post.acceptedArtisanId ?? '',
                              clientId: currentUser.uid,
                              clientName: currentUser.name,
                              postId: post.id,
                            ),
                          ).animate().fadeIn(delay: 400.ms);
                        }
                        
                        return const SizedBox.shrink();
                      },
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildHeaderStat(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textHint)),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) return const SizedBox.shrink();
        final currentUser = authState.user;

        return BlocBuilder<PostCubit, PostState>(
          builder: (context, postState) {
            final isLoading = postState is PostLoading;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, -4))],
              ),
              child: SafeArea(child: _getActionButtons(currentUser, isLoading)),
            );
          },
        );
      },
    );
  }

  Widget _getActionButtons(UserModel currentUser, bool isLoading) {
    if (_post!.clientId == currentUser.uid) {
      if (_post!.status == 'open') {
        return Row(
          children: [
            Expanded(
              child: AppComponents.primaryButton(
                label: 'حذف',
                onPressed: isLoading ? null : () => context.read<PostCubit>().deletePost(_post!.id),
                backgroundColor: AppColors.error,
                prefixIcon: Icons.delete_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppComponents.primaryButton(
                label: 'تعديل',
                onPressed: isLoading ? null : () => context.push('/edit-post', extra: _post),
                prefixIcon: Icons.edit_outlined,
              ),
            ),
          ],
        );
      }
      if (_post!.status == 'accepted') {
        return AppComponents.primaryButton(
          label: 'تأكيد إتمام العمل',
          onPressed: isLoading ? null : () => context.read<PostCubit>().completePost(_post!),
          backgroundColor: AppColors.success,
          prefixIcon: Icons.check_circle_outline,
        );
      }
    }

    if (currentUser.role == 'artisan') {
      if (_post!.status == 'open') {
        if (_post!.isDirectRequest && currentUser.uid == _post!.acceptedArtisanId) {
          return Row(
            children: [
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'رفض',
                  onPressed: isLoading ? null : () => context.read<PostCubit>().declinePost(post: _post!, artisanName: currentUser.name),
                  backgroundColor: AppColors.error,
                  prefixIcon: Icons.close_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'قبول وتواصل',
                  onPressed: isLoading ? null : () => context.read<PostCubit>().acceptPost(post: _post!, artisanId: currentUser.uid, artisanName: currentUser.name),
                  backgroundColor: AppColors.success,
                  prefixIcon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          );
        }
        
        if (_post!.isDirectRequest) {
          return Center(
            child: Text(
              'هذا طلب خدمة مباشر لحرفي معين',
              style: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 13),
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: AppComponents.secondaryButton(
                label: 'استفسار',
                onPressed: isLoading ? null : () => _startChat(currentUser),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppComponents.primaryButton(
                label: 'تقديم عرض',
                onPressed: isLoading ? null : () => _showOfferDialog(context, currentUser),
                backgroundColor: AppColors.secondary,
                prefixIcon: Icons.flash_on_rounded,
              ),
            ),
          ],
        );
      }
      if (_post!.status == 'accepted' && currentUser.uid == _post!.acceptedArtisanId) {
        return AppComponents.primaryButton(
          label: 'تواصل مع العميل',
          onPressed: () => _startChat(currentUser),
          prefixIcon: Icons.chat_bubble_outline_rounded,
        );
      }
    }

    return const SizedBox.shrink();
  }

  Future<void> _startChat(UserModel currentUser) async {
    final chatCubit = context.read<ChatCubit>();
    try {
      final convId = await chatCubit.getOrCreateConversation(
        user1Id: currentUser.uid,
        user1Name: currentUser.name,
        user2Id: _post!.clientId,
        user2Name: _post!.clientName,
        postId: _post!.id,
        postTitle: _post!.title,
      );
      if (mounted) {
        context.push('/chat-room/$convId', extra: {'name': _post!.clientName, 'id': _post!.clientId});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل بدء المحادثة')));
    }
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
            InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain)),
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersListForClient(UserModel currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'العروض المستلمة',
              style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            AppComponents.chip('${_post!.offersCount} عروض'),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<OfferModel>>(
          stream: sl<PostRepository>().getOffersForPost(_post!.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppComponents.shimmerList(count: 2, height: 120, padding: const EdgeInsets.symmetric(vertical: 8));
            }
            final offers = snapshot.data ?? [];
            if (offers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text('لا توجد عروض بعد', style: GoogleFonts.cairo(color: AppColors.textHint)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final offer = offers[index];
                return AppComponents.card(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: Text(
                                offer.artisanName[0],
                                style: GoogleFonts.cairo(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer.artisanName,
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                ),
                                RatingStars(rating: offer.artisanRating, size: 12),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${offer.price} ج.م',
                                style: GoogleFonts.cairo(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Text('عرض سعر', style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textHint)),
                            ],
                          ),
                        ],
                      ),
                      if (offer.comment.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            offer.comment,
                            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: AppComponents.secondaryButton(
                              label: 'الملف الشخصي',
                              onPressed: () {
                                sl<AuthRepository>().getUserById(offer.artisanId).then((artisan) {
                                  if (context.mounted) context.push('/artisan-profile', extra: artisan);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppComponents.primaryButton(
                              label: 'قبول العرض',
                              onPressed: () => context.read<PostCubit>().acceptOffer(
                                    offerId: offer.id,
                                    postId: _post!.id,
                                    artisanId: offer.artisanId,
                                    artisanName: offer.artisanName,
                                    postTitle: _post!.title,
                                    clientId: currentUser.uid,
                                    clientName: currentUser.name,
                                    price: offer.price,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
              },
            );
          },
        ),
      ],
    );
  }

  void _showOfferDialog(BuildContext context, UserModel artisan) {
    final priceController = TextEditingController();
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'تقديم عرض سعر',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الرجاء إدخال السعر المناسب لهذا الطلب',
                style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AppComponents.textField(
                hint: 'سعر العرض (ج.م)',
                controller: priceController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.money_rounded,
              ),
              const SizedBox(height: 16),
              AppComponents.textField(
                hint: 'رسالة إضافية (اختياري)',
                controller: commentController,
                maxLines: 3,
                prefixIcon: Icons.comment_outlined,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: AppComponents.primaryButton(
                  label: 'إرسال العرض',
                  backgroundColor: AppColors.primary,
                  onPressed: () {
                    final price = double.tryParse(priceController.text);
                    if (price == null || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال سعر صحيح')));
                      return;
                    }
                    context.read<PostCubit>().sendOffer(
                          postId: _post!.id,
                          artisanId: artisan.uid,
                          artisanName: artisan.name,
                          artisanRating: artisan.rating,
                          price: price,
                          comment: commentController.text,
                          clientId: _post!.clientId,
                          postTitle: _post!.title,
                        );
                    Navigator.pop(dialogContext);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientSection(String clientId) {
    return FutureBuilder<UserModel>(
      future: sl<AuthRepository>().getUserById(clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        if (snapshot.hasError || !snapshot.hasData) return const SizedBox.shrink();
        final client = snapshot.data!;

        return AppComponents.card(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'صاحب الطلب (العميل)',
                    style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                    child: Center(
                      child: Text(
                        client.name[0],
                        style: GoogleFonts.cairo(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'عميل نشط',
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              _buildClientInfoRow(Icons.phone_outlined, 'رقم الهاتف', client.phone.isNotEmpty ? client.phone : 'غير متوفر'),
              const SizedBox(height: 12),
              _buildClientInfoRow(Icons.email_outlined, 'البريد الإلكتروني', client.email),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildClientInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textHint),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textHint)),
            Text(value, style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildArtisanSection(String artisanId) {
    return FutureBuilder<UserModel>(
      future: sl<AuthRepository>().getUserById(artisanId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        if (snapshot.hasError || !snapshot.hasData) return const SizedBox.shrink();
        final artisan = snapshot.data!;

        return AppComponents.card(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الحرفي القائم على العمل',
                    style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Icon(Icons.handyman_rounded, color: AppColors.secondary, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                    child: Center(
                      child: Text(
                        artisan.name[0],
                        style: GoogleFonts.cairo(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artisan.name,
                          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          artisan.specialty,
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  RatingStars(rating: artisan.rating, size: 14),
                ],
              ),
              const SizedBox(height: 20),
              (_post!.status == 'completed')
                  ? AppComponents.primaryButton(
                      label: 'بيانات الحرفي',
                      prefixIcon: Icons.person_outline_rounded,
                      onPressed: () => context.push('/artisan-profile', extra: artisan),
                    )
                  : AppComponents.primaryButton(
                      label: 'تواصل مع الحرفي',
                      prefixIcon: Icons.chat_bubble_outline_rounded,
                      onPressed: () => _startChatFromUser(artisan),
                    ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1, end: 0);
      },
    );
  }

  Future<void> _startChatFromUser(UserModel otherUser) async {
    final chatCubit = context.read<ChatCubit>();
    try {
      final authCubit = context.read<AuthCubit>();
      if (authCubit.state is! AuthAuthenticated) return;
      final currentUser = (authCubit.state as AuthAuthenticated).user;
      
      final convId = await chatCubit.getOrCreateConversation(
        user1Id: currentUser.uid,
        user1Name: currentUser.name,
        user2Id: otherUser.uid,
        user2Name: otherUser.name,
        postId: _post!.id,
        postTitle: _post!.title,
      );
      if (mounted) {
        context.push('/chat-room/$convId', extra: {'name': otherUser.name, 'id': otherUser.uid});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل بدء المحادثة')));
    }
  }
}
