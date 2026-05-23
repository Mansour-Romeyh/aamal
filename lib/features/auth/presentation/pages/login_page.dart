import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../bloc/auth_cubit.dart';
import '../../../../app/widgets/app_components.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      final contactValue = _contactController.text.trim();
      final isEmail = contactValue.contains('@');
      
      String loginEmail = '';
      if (isEmail) {
        loginEmail = contactValue;
      } else {
        String phone = contactValue;
        if (phone.startsWith('0')) {
          phone = '+964${phone.substring(1)}'; // افتراض العراق
        } else if (!phone.startsWith('+')) {
          phone = '+$phone';
        }
        loginEmail = '$phone@works.com';
      }

      context.read<AuthCubit>().login(
            email: loginEmail,
            password: _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            if (!state.user.isActive) {
              context.go('/restricted');
              return;
            }
            final role = state.user.role;
            if (role == 'admin') {
              context.go('/client');
            } else if (role == 'artisan') {
              context.go('/artisan');
            } else {
              context.go('/client');
            }
          } else if (state is AuthError) {
            AppComponents.showSnackBar(context, state.message, isError: true);
          }
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Modern Header ───────────────────────────────────────
              _buildHeader(context),

              // ── Form Area ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildLoginForm(),
                    const SizedBox(height: 32),
                    _buildRegisterLink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Stack(
        children: [
          // Subtle Background Pattern
          Positioned(
            right: -50,
            top: -50,
            child: Icon(Icons.handyman_rounded, size: 200, color: Colors.white.withOpacity(0.05)),
          ),
          
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: const Hero(
                      tag: 'logo',
                      child: Icon(Icons.handyman_rounded, size: 60, color: AppColors.primary),
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut).rotate(begin: -0.1, end: 0),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'ووركـرز',
                    style: GoogleFonts.cairo(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                  
                  Text(
                    'خدماتك مـضمونة وبـسرعة',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return AppComponents.card(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تسجيل الدخول',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أدخل بياناتك للوصول إلى حسابك والمتابعة',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            
            AppComponents.textField(
              controller: _contactController,
              hint: 'البريد الإلكتروني أو الهاتف',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الحساب أولاً' : null,
            ),
            
            const SizedBox(height: 16),
            
            AppComponents.textField(
              controller: _passwordController,
              hint: 'كلمة المرور',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور قصيرة جداً' : null,
            ),
            
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _onForgotPassword,
                child: Text(
                  'نسيت كلمة المرور؟',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                return AppComponents.primaryButton(
                  label: 'دخول آمن',
                  onPressed: _login,
                  isLoading: state is AuthLoading,
                );
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك حساب؟',
          style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 14),
        ),
        TextButton(
          onPressed: () => context.push('/register'),
          child: Text(
            'سجل الآن مجاناً',
            style: GoogleFonts.cairo(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms);
  }

  void _onForgotPassword() {
    context.push('/forgot-password');
  }
}
