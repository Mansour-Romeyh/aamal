import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_components.dart';
import '../bloc/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration/Icon Container
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        size: 80,
                        color: AppColors.primary,
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .scale(duration: 2.seconds, curve: Curves.easeInOut)
                       .rotate(begin: -0.05, end: 0.05),
                    ),
                    
                    const SizedBox(height: 80),
                    
                    Text(
                      'حسابك قيد المراجعة',
                      style: GoogleFonts.cairo(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),
                    
                    
                    const SizedBox(height: 48),
                    
                    // Info Cards
                    _buildInfoCard(
                      icon: Icons.timer_outlined,
                      text: 'المراجعة تستغرق عادةً أقل من 24 ساعة عمل',
                    ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.2, end: 0),
                    
                    const SizedBox(height: 12),
                    
                    _buildInfoCard(
                      icon: Icons.notifications_active_outlined,
                      text: 'ستصلك رسالة تنبيه بمجرد تفعيل الحساب',
                    ).animate().fadeIn(delay: 900.ms).slideX(begin: 0.2, end: 0),
                    
                    
                    const SizedBox(height: 48),
                    
                    
                    
                    const Spacer(),
                    
                    // Logout/Refresh Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionCircle(
                          icon: Icons.refresh_rounded,
                          label: 'تحديث',
                          onTap: () => context.read<AuthCubit>().checkAuthStatus(),
                        ),
                        const SizedBox(width: 40),
                        _buildActionCircle(
                          icon: Icons.logout_rounded,
                          label: 'خروج',
                          onTap: () => context.read<AuthCubit>().logout(),
                          isDanger: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          
          // Back Button (Optional)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.read<AuthCubit>().logout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String text}) {
    return AppComponents.card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? AppColors.error : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

}
