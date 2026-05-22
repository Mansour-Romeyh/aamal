import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/splash_cubit.dart';
import '../widgets/animated_logo.dart';
import '../widgets/shimmer_title.dart';
import '../widgets/pulse_ring.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/firebase_constants.dart';

/// صفحة البداية بتصميم عصري واحترافي
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isSplashDone = false;
  int _logoTapCount = 0;
  bool _isAdminDialogOpen = false;

  void _onLogoTap() {
    _logoTapCount++;
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      setState(() => _isAdminDialogOpen = true);
      _showAdminPasswordDialog();
    }
  }

  void _showAdminPasswordDialog() {
    final passController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // تأكيد منع الإغلاق عند الضغط خارج المربع
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => PopScope(
        canPop: false, // منع الإغلاق عن طريق زر الرجوع أو مفتاح Esc
        child: Center(
          child: SingleChildScrollView(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  // تغيير اللون ليتماشى مع ثيم التطبيق الأزرق الاحترافي
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryDark.withOpacity(0.95),
                      const Color(0xFF003A8C).withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ColorFilter.mode(
                      Colors.blue.withOpacity(0.1),
                      BlendMode.srcATop,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔒 Icon
                        Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 42,
                              ),
                            )
                            .animate()
                            .scale(delay: 200.ms)
                            .shimmer(duration: 2.seconds),

                        const SizedBox(height: 20),

                        Text(
                          'بوابة الأدمن',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'الدخول مقتصر على المصرح لهم فقط',
                          style: GoogleFonts.cairo(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ⌨️ Input
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black38, // لون خلفية غامق جداً وواضح
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            controller: passController,
                            obscureText: true,
                            autofocus: true,
                            cursorColor: AppColors.secondary, // مؤشر كتابة برتقالي واضح
                            style: const TextStyle(
                              color: Colors.white, // النص أبيض صريح وقوي
                              letterSpacing: 10,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.black45, // إجبار الخلفية تكون غامقة لتجاوز ثيم التطبيق الأبيض
                              hintText: '••••',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.2),
                                letterSpacing: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 18,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // 🚀 Actions
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setState(() => _isAdminDialogOpen = false);
                                  Navigator.pop(ctx);
                                  _checkAndNavigate(); // العمل المطلوب: العودة للوجن أو الهوم
                                },
                                child: Text(
                                  'إلغاء',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () {
                                  if (passController.text == 'admin') {
                                    // تسجيل التوكن للحساب المركزي فوراً عند الدخول بالبريد الخلفي
                                    NotificationService.instance.saveTokenToFirestore(FirebaseConstants.supportId);
                                    
                                    Navigator.pop(ctx);
                                    setState(() => _isAdminDialogOpen = false);
                                    context.go('/admin');
                                  } else {
                                    // عند الخطأ، نخرج ونوجه المستخدم كما طلب
                                    Navigator.pop(ctx);
                                    setState(() => _isAdminDialogOpen = false);
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('⚠️ رمز غير صحيح - جاري توجيهك'),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    
                                    _checkAndNavigate();
                                  }
                                },
                                child: Text(
                                  'دخول آمن',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }



  @override
  void initState() {
    super.initState();
    context.read<SplashCubit>().startSplash();
  }

  void _checkAndNavigate() {
    if (!_isSplashDone || _isAdminDialogOpen) return;

    final authCubit = context.read<AuthCubit>();
    if (!authCubit.hasCompletedAuthBootstrap) return;

    final authState = authCubit.state;

    // الانتظار إذا كانت الحالة لا تزال في البداية أو التحميل
    if (authState is AuthInitial || authState is AuthLoading) {
      return;
    }

    if (authState is AuthAuthenticated) {
      if (!authState.user.isActive) {
        context.go('/restricted');
        return;
      }
      final role = authState.user.role;
      if (role == 'admin') {
        context.go('/admin-selection');
      } else if (role == 'artisan') {
        context.go('/artisan');
      } else {
        context.go('/client');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SplashCubit, SplashState>(
          listener: (context, state) {
            if (state is SplashCompleted) {
              setState(() => _isSplashDone = true);
              Future.microtask(_checkAndNavigate);
            }
          },
        ),
        BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            // التنقل فقط إذا انتهى الأنيميشن ووصلنا لحالة نهائية للتوثيق
            if (state is AuthAuthenticated ||
                state is AuthUnauthenticated ||
                state is AuthError) {
              // بعد انتهاء try/finally في checkAuthStatus (hasCompletedAuthBootstrap)
              Future.microtask(_checkAndNavigate);
            }
          },
        ),
      ],
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
                const Color(0xFF003A8C), // Deep primary accent
              ],
            ),
          ),
          child: Stack(
            children: [
              // ── تأثيرات خلفية خفيفة (Mesh Influence) ────────────────
              Positioned(
                top: -100,
                right: -100,
                child:
                    Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          duration: 5.seconds,
                          begin: const Offset(1, 1),
                          end: const Offset(1.2, 1.2),
                        ),
              ),

              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // ── اللوجو والحلقات ──────────────────────
                    GestureDetector(
                      onTap: _onLogoTap,
                      behavior: HitTestBehavior.opaque,
                      child:
                          Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const PulseRing(size: 140),
                                    const AnimatedLogo(
                                      size: 130,
                                      delay: Duration(milliseconds: 300),
                                    ),
                                  ],
                                ),
                              )
                              .animate(target: _logoTapCount > 0 ? 1 : 0)
                              .scale(
                                duration: 100.ms,
                                begin: const Offset(1, 1),
                                end: const Offset(0.95, 0.95),
                              ),
                    ),
                    const SizedBox(height: 50),

                    // ── العنوان والوصف ──────────────────────
                    const ShimmerTitle(
                      text: 'أعمال',
                      delay: Duration(milliseconds: 900),
                    ),
                    const SizedBox(height: 16),

                    Text(
                          'خيارك الأسرع للوصول لأمهر الحرفيين',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
                          textAlign: TextAlign.center,
                        )
                        .animate(delay: 1200.ms)
                        .fadeIn(duration: 800.ms)
                        .slideY(begin: 0.2, end: 0),

                    const Spacer(flex: 3),

                    // ── مؤشر التحميل السفلي ────────────────────
                    Column(
                      children: [
                        Container(
                          width: 200,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: const LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white70,
                              ),
                            ),
                          ),
                        ).animate(delay: 1500.ms).fadeIn(),
                        const SizedBox(height: 16),
                        Text(
                          'لحظات ونبدأ العمل...',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ).animate(delay: 1600.ms).fadeIn(),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
