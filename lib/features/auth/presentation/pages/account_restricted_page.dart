import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../bloc/auth_cubit.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../app/di/injection_container.dart';

class AccountRestrictedPage extends StatelessWidget {
  const AccountRestrictedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background: Professional Blue Gradient ────────────────
          _buildBackground(),

          // ── Glassmorphism Content ────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main Restriction Card
                    _buildRestrictedCard(context),
                    
                    const SizedBox(height: 32),
                    
                    // Fallback Channels
                    _buildSecondaryActions(context),
                    
                    const SizedBox(height: 48),
                    
                    // Exit Option
                    _buildLogoutAction(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Very Dark Blue
            Color(0xFF1E293B),
            AppColors.primaryDark,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: _buildBlurCircle(AppColors.primary.withOpacity(0.2), 350),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: _buildBlurCircle(AppColors.secondary.withOpacity(0.15), 300),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(duration: 6.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
     .blur(begin: const Offset(70, 70), end: const Offset(90, 90));
  }

  Widget _buildRestrictedCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: -10,
              )
            ],
          ),
          child: Column(
            children: [
              // Icon with Theme Colors
              _buildModernLockIcon(),
              
              const SizedBox(height: 28),
              
              Text(
                'تم تقييد نشاط الحساب',
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 16),
              
              Text(
                'لقد تلاحظ وجود نشاط غير اعتيادي على حسابك. لحمايتك وحماية مجتمع التطبيق، قمنا بتقييد الوصول مؤقتاً حتى يتم التواصل مع الإدارة.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.7,
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 32),
              
              // Unique Support Identifier
              _buildSupportIdBadge(context),

              const SizedBox(height: 32),

              // CTA: The Primary Support Button
              _buildPrimaryActionButton(context),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 700.ms).scale(begin: const Offset(0.97, 0.97), end: const Offset(1, 1));
  }

  Widget _buildModernLockIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing Ring
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ).animate(onPlay: (c) => c.repeat())
         .scale(duration: 2.5.seconds, begin: const Offset(1, 1), end: const Offset(1.6, 1.6))
         .fadeOut(duration: 2.5.seconds),
        
        // Main Circle
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.secondary, Color(0xFFE65100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: const Icon(
            Icons.security_rounded,
            size: 40,
            color: Colors.white,
          ),
        ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
      ],
    );
  }

  Widget _buildSupportIdBadge(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    String displayId = 'CHECKING...';
    if (authState is AuthAuthenticated) {
      displayId = '#${authState.user.uid.substring(0, 8).toUpperCase()}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'معرف الدعم الخاص بك: ',
            style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: displayId));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ المعرف لنقله للدعم')));
            },
            child: Text(
              displayId,
              style: GoogleFonts.cairo(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.copy_rounded, size: 14, color: Colors.white24),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildPrimaryActionButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _handleContactSupport(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent_rounded, size: 24),
            const SizedBox(width: 12),
            Text(
              'فتح جلسة تواصل مع الإدارة',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSecondaryActions(BuildContext context) {
    return Column(
      children: [
        Text(
          'أو استخدم طرق التواصل الرسمية',
          style: GoogleFonts.cairo(color: Colors.white30, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIconAction(Icons.email_outlined, () {
               Clipboard.setData(const ClipboardData(text: 'support@works.com'));
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ بريد الدعم المباشر')));
            }),
            const SizedBox(width: 24),
            _buildIconAction(Icons.help_outline_rounded, () {}),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 1.seconds);
  }

  Widget _buildIconAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white60, size: 22),
      ),
    );
  }

  Widget _buildLogoutAction(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        context.read<AuthCubit>().logout();
        context.go('/login');
      },
      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white24, size: 18),
      label: Text(
        'تسجيل الخروج والعودة للرئيسية',
        style: GoogleFonts.cairo(
          color: Colors.white24,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ).animate().fadeIn(delay: 1.3.seconds);
  }

  Future<void> _handleContactSupport(BuildContext context) async {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      final user = authState.user;
      
      // Loading Indicator
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent accidental dismissal
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const CircularProgressIndicator(color: AppColors.secondary),
          ),
        ),
      );

      try {
        // Initialize Secure Chat with centralized Support
        final conversation = await sl<ChatRepository>().getOrCreateConversation(
          user1Id: user.uid,
          user1Name: user.name,
          user2Id: FirebaseConstants.supportId,
          user2Name: 'الدعم الفني',
          postId: 'support', 
          postTitle: 'مراجعة أمنية - حساب #${user.uid.substring(0, 4)}',
        );

        if (context.mounted) {
          context.push('/chat-room/${conversation.id}', extra: {
            'name': 'الدعم الفني',
            'id': FirebaseConstants.supportId,
          });
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading if error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل بدء الدردشة: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
