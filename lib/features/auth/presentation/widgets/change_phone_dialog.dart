import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_components.dart';
import '../bloc/auth_cubit.dart';

class ChangePhoneDialog extends StatefulWidget {
  const ChangePhoneDialog({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePhoneDialog()),
    );
  }

  @override
  State<ChangePhoneDialog> createState() => _ChangePhoneDialogState();
}

class _ChangePhoneDialogState extends State<ChangePhoneDialog> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String _completePhoneNumber = '';
  bool _isOtpStep = false;
  String _verificationId = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    String phoneInput = _phoneController.text.trim();
    if (phoneInput.isEmpty) {
      AppComponents.showSnackBar(context, 'يرجى إدخال رقم هاتف', isError: true);
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(phoneInput)) {
      AppComponents.showSnackBar(context, 'رقم الهاتف يجب أن يحتوي على أرقام فقط', isError: true);
      return;
    }
    if (phoneInput.startsWith('0') && phoneInput.length != 11) {
      AppComponents.showSnackBar(context, 'يجب أن يتكون من 11 رقماً', isError: true);
      return;
    }
    if (!phoneInput.startsWith('0') && phoneInput.length != 10) {
      AppComponents.showSnackBar(context, 'يجب أن يتكون من 10 أرقام', isError: true);
      return;
    }
    if (!phoneInput.startsWith('07') && !phoneInput.startsWith('7')) {
      AppComponents.showSnackBar(context, 'يجب أن يبدأ بـ 07 أو 7', isError: true);
      return;
    }
    
    String finalPhone = phoneInput;
    if (finalPhone.startsWith('0')) {
      finalPhone = '+964${finalPhone.substring(1)}';
    } else if (!finalPhone.startsWith('+')) {
      finalPhone = '+964$finalPhone';
    }

    if (finalPhone.length < 10) {
      AppComponents.showSnackBar(context, 'يرجى إدخال رقم هاتف صحيح', isError: true);
      return;
    }
    _completePhoneNumber = finalPhone;
    context.read<AuthCubit>().sendPhoneChangeOtp(_completePhoneNumber);
  }

  void _verifyOtp() {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      AppComponents.showSnackBar(context, 'يرجى إدخال رمز التحقق بشكل صحيح', isError: true);
      return;
    }
    context.read<AuthCubit>().verifyPhoneChangeOtp(otp, _verificationId, _completePhoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'تغيير رقم الهاتف',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthPhoneChangeOtpSent) {
            if (!_isOtpStep) {
              setState(() {
                _isOtpStep = true;
                _verificationId = state.verificationId;
              });
              AppComponents.showSnackBar(context, 'تم إرسال رمز التحقق بنجاح');
            }
          } else if (state is AuthError) {
            AppComponents.showSnackBar(context, state.message, isError: true);
          } else if (state is AuthAuthenticated) {
            if (_isOtpStep) {
              AppComponents.showSnackBar(context, 'تم تغيير رقم الهاتف بنجاح');
              Navigator.pop(context);
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  if (!_isOtpStep) ...[
                    Text(
                      'أدخل رقم الهاتف الجديد',
                      style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الرجاء إدخال رقم الهاتف الجديد لإرسال رمز التحقق.',
                      style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AppComponents.textField(
                      controller: _phoneController,
                      hint: 'رقم الهاتف الجديد (مثال: 07...)',
                      prefixIcon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 32),
                    AppComponents.primaryButton(
                      label: isLoading ? 'جاري الإرسال...' : 'إرسال الرمز',
                      onPressed: isLoading ? () {} : _sendOtp,
                    ),
                  ] else ...[
                    Text(
                      'أدخل رمز التحقق',
                      style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'تم إرسال رمز التحقق إلى الرقم:',
                      style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _completePhoneNumber,
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                        textAlign: TextAlign.center,
                      ),
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
                      label: isLoading ? 'جاري التحقق...' : 'تأكيد',
                      onPressed: isLoading ? () {} : _verifyOtp,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
