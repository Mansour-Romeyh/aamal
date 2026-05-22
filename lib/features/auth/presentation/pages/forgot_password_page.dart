import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_components.dart';
import '../bloc/forgot_password/forgot_password_cubit.dart';
import '../bloc/forgot_password/forgot_password_state.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _completePhoneNumber = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSendOtp(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      String phone = _completePhoneNumber;
      if (phone.isEmpty && _phoneController.text.isNotEmpty) {
        phone = '+20${_phoneController.text}';
      }
      if (phone.length < 10) {
        AppComponents.showSnackBar(context, 'يرجى إدخال رقم هاتف صحيح', isError: true);
        return;
      }
      context.read<ForgotPasswordCubit>().sendOtpToPhone(phone);
    }
  }

  void _onVerifyOtp(BuildContext context) {
    if (_otpController.text.length == 6) {
      context.read<ForgotPasswordCubit>().verifyOtp(_otpController.text);
    } else {
      AppComponents.showSnackBar(context, 'يرجى إدخال رمز التحقق المكون من 6 أرقام', isError: true);
    }
  }

  void _onUpdatePassword(BuildContext context) {
    if (_passwordController.text.length >= 6) {
      context.read<ForgotPasswordCubit>().updatePassword(_passwordController.text);
    } else {
      AppComponents.showSnackBar(context, 'كلمة المرور يجب أن تكون 6 أحرف على الأقل', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForgotPasswordCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'استعادة كلمة المرور',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
          listener: (context, state) {
            if (state is ForgotPasswordError) {
              AppComponents.showSnackBar(context, state.message, isError: true);
            } else if (state is ForgotPasswordSuccess) {
              AppComponents.showSnackBar(context, 'تم تغيير كلمة المرور بنجاح!');
              context.pop(); // العودة لصفحة تسجيل الدخول
            }
          },
          builder: (context, state) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Icon(
                        Icons.lock_reset_rounded,
                        size: 80,
                        color: AppColors.primary,
                      ).animate().scale(delay: 200.ms, duration: 400.ms),
                      const SizedBox(height: 24),
                      
                      if (state is ForgotPasswordInitial || state is ForgotPasswordLoading && _otpController.text.isEmpty && _passwordController.text.isEmpty)
                        _buildStep1Phone(context, state)
                      else if (state is ForgotPasswordOtpSent || state is ForgotPasswordLoading && _passwordController.text.isEmpty)
                        _buildStep2Otp(context, state)
                      else if (state is ForgotPasswordOtpVerified || state is ForgotPasswordLoading)
                        _buildStep3NewPassword(context, state)
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStep1Phone(BuildContext context, ForgotPasswordState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أدخل رقم الهاتف',
          style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'الرجاء إدخال رقم هاتفك المسجل لدينا لنرسل لك رمز التحقق.',
          style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Directionality(
          textDirection: TextDirection.ltr,
          child: IntlPhoneField(
            controller: _phoneController,
            decoration: AppComponents.textFieldDecoration(
              hint: 'رقم الهاتف',
              prefixIcon: Icons.phone_android_rounded,
            ),
            initialCountryCode: 'EG',
            textAlign: TextAlign.left,
            languageCode: "ar",
            invalidNumberMessage: "رقم هاتف غير صالح",
            onChanged: (phoneRaw) {
              setState(() {
                _completePhoneNumber = phoneRaw.completeNumber;
              });
            },
            onCountryChanged: (country) {
              setState(() {
                _completePhoneNumber = '+${country.dialCode}${_phoneController.text}';
              });
            },
            validator: (v) {
              if (v == null || v.number.isEmpty) {
                return 'رقم الهاتف إلزامي';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 32),
        AppComponents.primaryButton(
          label: 'إرسال الرمز',
          onPressed: () => _onSendOtp(context),
          isLoading: state is ForgotPasswordLoading,
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildStep2Otp(BuildContext context, ForgotPasswordState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أدخل رمز التحقق',
          style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'قمنا بإرسال رسالة نصية قصيرة تحتوي على رمز التحقق إلى الرقم\n$_completePhoneNumber',
          style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Pinput(
            length: 6,
            controller: _otpController,
            defaultPinTheme: PinTheme(
              width: 50,
              height: 56,
              textStyle: GoogleFonts.cairo(
                fontSize: 22,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
            ),
            focusedPinTheme: PinTheme(
              width: 50,
              height: 56,
              textStyle: GoogleFonts.cairo(
                fontSize: 22,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
            ),
            showCursor: true,
          ),
        ),
        const SizedBox(height: 32),
        AppComponents.primaryButton(
          label: 'تحقق',
          onPressed: () => _onVerifyOtp(context),
          isLoading: state is ForgotPasswordLoading,
        ),
      ],
    ).animate().fadeIn().slideX();
  }

  Widget _buildStep3NewPassword(BuildContext context, ForgotPasswordState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'كلمة مرور جديدة',
          style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'تم التحقق بنجاح! الرجاء إدخال كلمة المرور الجديدة لحسابك.',
          style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        AppComponents.textField(
          controller: _passwordController,
          hint: 'كلمة المرور الجديدة',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          validator: (value) {
            if (value == null || value.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
            return null;
          },
        ),
        const SizedBox(height: 32),
        AppComponents.primaryButton(
          label: 'حفظ والتسجيل',
          onPressed: () => _onUpdatePassword(context),
          isLoading: state is ForgotPasswordLoading,
        ),
      ],
    ).animate().fadeIn().slideX();
  }
}
