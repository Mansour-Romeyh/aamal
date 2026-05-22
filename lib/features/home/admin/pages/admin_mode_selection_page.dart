import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../notifications/presentation/widgets/notification_bottom_sheet.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../../app/di/injection_container.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../auth/data/repositories/auth_repository.dart';


class AdminModeSelectionPage extends StatelessWidget {
  const AdminModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Logout Button
          Positioned(
            top: 40,
            left: 20,
            child: Row(
              children: [
                // Notification Bell (Combined Mode)
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, authState) {
                    // في شاشة اختيار الوضع، نستخدم التدفق المدمج لإعطاء صورة كاملة عن التنبيهات المعلقة
                    final targetId = authState is AuthAuthenticated ? authState.user.uid : FirebaseConstants.supportId;

                    return StreamBuilder<int>(
                      stream: sl<AuthRepository>().getAdminCombinedNotificationCountStream(targetId),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white, 
                                shape: BoxShape.circle, 
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                              ),
                              child: IconButton(
                                icon: Icon(
                                  unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, 
                                  color: AppColors.primary
                                ),
                                onPressed: () {
                                   NotificationBottomSheet.show(context, targetUserId: targetId);
                                },
                                tooltip: 'التنبيهات المدمجة',
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ).animate().scale().shake(),
                              ),
                          ],
                        );
                      }
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Logout Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                    onPressed: () {
                       sl<AuthCubit>().logout();
                       context.go('/login');
                    },
                    tooltip: 'تسجيل الخروج',
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 1000.ms).slideX(begin: -0.2, end: 0),
          // Background design elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.primary,
                      size: 64,
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'مركز إدارة المنصة',
                    style: GoogleFonts.cairo(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    'مرحباً بك مجدداً. اختر الواجهة التي ترغب\nفي العمل عليها الآن بمنطقية ووضوح.',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 50),
                  
                  // Selection Cards
                  Row(
                    children: [
                      // Admin Card
                      Expanded(
                        child: _SelectionCard(
                          title: 'لوحة الإدارة',
                          subtitle: 'إحصائيات وتحكم كامل',
                          icon: Icons.dashboard_customize_rounded,
                          color: AppColors.primary,
                          onTap: () => context.go('/admin'),
                          delay: 400,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // App Card
                      Expanded(
                        child: _SelectionCard(
                          title: 'واجهة التطبيق',
                          subtitle: 'تصفح كعميل عادي',
                          icon: Icons.phone_android_rounded,
                          color: const Color(0xFF7C3AED), // Premium Purple
                          onTap: () => context.go('/client'),
                          delay: 550,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Exit Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'يمكنك دائماً التبديل بين الواجهات من خلال ملفك الشخصي في أي وقت.',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int delay;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AppComponents.card(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
  }
}
