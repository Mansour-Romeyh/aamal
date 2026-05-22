import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';
import '../../../../app/theme/app_colors.dart';
import '../bloc/auth_cubit.dart';
import '../widgets/role_selector.dart';
import '../../../../app/widgets/app_components.dart';
import '../../../../app/widgets/map_location_picker.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _bioController = TextEditingController();
  final _addressController = TextEditingController();
  List<File> _portfolioImages = [];
  File? _profileImage;
  File? _idCardImage;
  File? _selfieImage;
  String _completePhoneNumber = ''; 
  bool _isPhoneRegistration = true;

  String _selectedRole = 'client';
  String _selectedSpecialty = '';
  
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// يفتح Map Picker ويحفظ النتيجة
  Future<void> _openMapPicker() async {
    final result = await MapLocationPicker.show(
      context,
      initialLat: _lat,
      initialLng: _lng,
      initialAddress: _addressController.text.isNotEmpty ? _addressController.text : null,
    );
    if (result != null && mounted) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _addressController.text = result.address;
      });
    }
  }

  void _pickImages() async {
    final source = await AppComponents.showImageSourceSheet(context);
    if (source == null) return;

    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1000,
      );
      if (pickedFile != null) {
        if (_portfolioImages.length < 10) {
          setState(() {
            _portfolioImages.add(File(pickedFile.path));
          });
        }
      }
    } else {
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1000,
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _portfolioImages.addAll(
            pickedFiles
                .map((file) => File(file.path))
                .take(10 - _portfolioImages.length),
          );
        });
      }
    }
  }

  void _pickProfileImage() async {
    final source = await AppComponents.showImageSourceSheet(context);
    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1000,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }
  /// نافذة سفلية مخصّصة لصورة الهوية/الجواز (نصائح + كاميرا خلفية أو معرض).
  Future<ImageSource?> _showIdDocumentSourceBottomSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textHint.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'صورة البطاقة أو جواز السفر',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'يجب أن تكون الصورة واضحة وغير مقطوعة',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withOpacity(0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نصائح للقبول السريع',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _idTipRow(Icons.wb_sunny_outlined, 'إضاءة طبيعية قوية، بدون وهج على البطاقة'),
                  const SizedBox(height: 8),
                  _idTipRow(Icons.crop_free_rounded, 'أظهر الحواف الأربع بالكامل داخل الإطار'),
                  const SizedBox(height: 8),
                  _idTipRow(Icons.straighten_rounded, 'ضع المستند على سطح مستوٍ وأفقياً'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'طريقة الرفع',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _idSourceTile(
              ctx,
              icon: Icons.camera_alt_rounded,
              title: 'التقاط صورة بالكاميرا',
              subtitle: 'يُفضّل الكاميرا الخلفية لرؤية أوضح للمستند',
              color: const Color(0xFF2563EB),
              source: ImageSource.camera,
            ),
            const SizedBox(height: 10),
            _idSourceTile(
              ctx,
              icon: Icons.photo_library_rounded,
              title: 'اختيار من المعرض',
              subtitle: 'إذا كانت لديك صورة جاهزة بجودة عالية',
              color: const Color(0xFF7C3AED),
              source: ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _idTipRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary.withOpacity(0.85)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _idSourceTile(
    BuildContext sheetCtx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required ImageSource source,
  }) {
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => Navigator.pop(sheetCtx, source),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: color.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickIdCardImage() async {
    final source = await _showIdDocumentSourceBottomSheet();
    if (!mounted || source == null) return;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (pickedFile != null && mounted) {
        setState(() => _idCardImage = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        AppComponents.showSnackBar(
          context,
          'تعذر فتح الكاميرا أو المعرض. تحقق من الأذونات.',
          isError: true,
        );
      }
    }
  }

  /// سيلفي: الكاميرا الأمامية فقط (بدون معرض)، للتوافق مع طلب التوثيق.
  Future<void> _pickSelfieImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (pickedFile != null && mounted) {
        setState(() => _selfieImage = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        AppComponents.showSnackBar(
          context,
          'تعذر فتح الكاميرا الأمامية. تحقق من إذن الكاميرا.',
          isError: true,
        );
      }
    }
  }

  void _register() {
    debugPrint('🚀 Registration button clicked');
    if (_formKey.currentState!.validate()) {
      debugPrint('✅ Form Validation Passed');
      if (_selectedRole == 'artisan') {
        if (_selectedSpecialty.isEmpty) {
          AppComponents.showSnackBar(context, 'يرجى اختيار تخصصك أولاً', isError: true);
          return;
        }
        if (_idCardImage == null || _selfieImage == null) {
          AppComponents.showSnackBar(
            context,
            'يرجى رفع صورة الهوية وصورة السيلفي للتوثيق الإجباري',
            isError: true,
          );
          return;
        }
      }
      String email = '';
      String phone = '';

      if (_isPhoneRegistration) {
        // إذا لم يتم تحديث _completePhoneNumber (مثلاً autofill)، نحاول استنتاجه
        String finalPhone = _completePhoneNumber;
        if (finalPhone.isEmpty && _phoneController.text.isNotEmpty) {
          finalPhone = '+20${_phoneController.text}'; // افتراض مصر كدولة افتراضية في التجاوز
        }

        if (finalPhone.length < 10) {
          AppComponents.showSnackBar(context, 'يرجى إدخال رقم هاتف صحيح (يجب أن يبدأ بكود الدولة)', isError: true);
          return;
        }
        phone = finalPhone;
        email = '$phone@works.com';
        debugPrint('📞 Sending phone to Firebase: $phone (length: ${phone.length})');
      } else {
        email = _emailController.text.trim();
        phone = '';
      }

      context.read<AuthCubit>().sendOtpForRegistration(
        name: _nameController.text,
        email: email,
        password: _passwordController.text,
        phone: phone,
        role: _selectedRole,
        specialty: _selectedSpecialty,
        bio: _bioController.text,
        address: _addressController.text,
        latitude: _lat,
        longitude: _lng,
        portfolioImages: _portfolioImages,
        profileImage: _profileImage,
        idCardImage: _idCardImage,
        selfieImage: _selfieImage,
      );
    } else {
      debugPrint('❌ Form Validation Failed');
      AppComponents.showSnackBar(context, 'يرجى إكمال جميع الحقول المطلوبة بشكل صحيح', isError: true);
    }
  }

  void _showOtpDialog(AuthOtpSent state) {
    final otpController = TextEditingController();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Icon Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'تأكيد الحساب',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, 
                    fontSize: 22,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'تم إرسال رمز الأمان (SMS) إلى الرقم:\n${state.phone}\nيرجى إدخاله هنا للتحقق',
                  style: GoogleFonts.cairo(
                    fontSize: 14, 
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Pinput(
                    length: 6,
                    controller: otpController,
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
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'إلغاء', 
                          style: GoogleFonts.cairo(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final enteredOtp = otpController.text.trim();
                          if (enteredOtp.length == 6) {
                            Navigator.pop(context);
                            context.read<AuthCubit>().verifyOtpAndRegister(
                              enteredOtp,
                              state.expectedOtp,
                              state.pendingUserData,
                              state.pendingPortfolioImages,
                              state.pendingProfileImage,
                            );
                          } else {
                            AppComponents.showSnackBar(
                              context, 
                              'يرجى إدخال الرمز المكون من 6 أرقام بشكل صحيح', 
                              isError: true,
                            );
                          }
                        },
                        child: Text(
                          'تأكيد', 
                          style: GoogleFonts.cairo(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthRegistrationSuccess) {
            final isEmail = !_isPhoneRegistration;
            final message = isEmail 
                ? 'تم إنشاء الحساب بنجاح بانتظار التفعيل! يرجى مراجعة بريدك الإلكتروني حالاً (البريد الوارد أو مجلد غير المرغوب فيها/Spam) واضغط على رابط التفعيل.'
                : 'تم تأكيد الهاتف وإنشاء الحساب بنجاح!';
            
            AppComponents.showSnackBar(
              context,
              message,
              duration: const Duration(seconds: 7),
            );
            context.go('/login');
          } else if (state is AuthOtpSent) {
            _showOtpDialog(state);
          } else if (state is AuthError) {
            AppComponents.showSnackBar(context, state.message, isError: true);
          }
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Modern Header ───────────────────────────────────────
              _buildHeader(context),

              // ── Form Content ────────────────────────────────────────
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Selection
                      // _buildSectionHeader('نوع الحساب', Icons.badge_outlined),
                      const SizedBox(height: 16),
                      RoleSelector(
                        selectedRole: _selectedRole,
                        selectedSpecialty: _selectedSpecialty,
                        onRoleChanged: (role) {
                          setState(() {
                            _selectedRole = role;
                            if (role == 'client') _selectedSpecialty = '';
                          });
                        },
                        onSpecialtyChanged: (specialty) =>
                            setState(() => _selectedSpecialty = specialty),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 32),

                      // Basic Info
                      _buildSectionHeader(
                        'المعلومات الأساسية',
                        Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      AppComponents.card(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            AppComponents.textField(
                              controller: _nameController,
                              hint: 'الاسم الكامل',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'يرجى إدخال اسمك'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            
                            // ── Premium Segmented Toggle ──
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isPhoneRegistration = true),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _isPhoneRegistration ? AppColors.primary : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: _isPhoneRegistration
                                              ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                              : [],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.phone_rounded, size: 18, color: _isPhoneRegistration ? Colors.white : AppColors.primary),
                                            const SizedBox(width: 8),
                                            Text(
                                              'رقم الهاتف',
                                              style: GoogleFonts.cairo(
                                                color: _isPhoneRegistration ? Colors.white : AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isPhoneRegistration = false),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: !_isPhoneRegistration ? AppColors.primary : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: !_isPhoneRegistration
                                              ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                              : [],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.email_rounded, size: 18, color: !_isPhoneRegistration ? Colors.white : AppColors.primary),
                                            const SizedBox(width: 8),
                                            Text(
                                              'الإيميل',
                                              style: GoogleFonts.cairo(
                                                color: !_isPhoneRegistration ? Colors.white : AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_isPhoneRegistration)
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: IntlPhoneField(
                                  controller: _phoneController,
                                  decoration: AppComponents.textFieldDecoration(
                                    hint: 'رقم الهاتف',
                                    prefixIcon: Icons.phone_rounded,
                                  ),
                                  initialCountryCode: 'EG',
                                  disableLengthCheck: true,
                                  textAlign: TextAlign.left,
                                  languageCode: "ar",
                                  invalidNumberMessage: "رقم هاتف غير صالح",
                                  onChanged: (phoneRaw) {
                                    setState(() {
                                      _completePhoneNumber = phoneRaw.completeNumber;
                                    });
                                    debugPrint('📱 Phone updated: ${phoneRaw.completeNumber}');
                                  },
                                  onCountryChanged: (country) {
                                    setState(() {
                                      _completePhoneNumber = '+${country.dialCode}${_phoneController.text}';
                                    });
                                    debugPrint('🌍 Country changed: ${country.name} (+${country.dialCode})');
                                  },
                                  validator: (v) {
                                    if (v == null || v.number.isEmpty) {
                                      return 'رقم الهاتف إلزامي';
                                    }
                                    return null;
                                  },
                                ),
                              )
                            else
                              AppComponents.textField(
                                controller: _emailController,
                                hint: 'البريد الإلكتروني',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => (v == null || !v.contains('@'))
                                    ? 'يرجى إدخال بريد إلكتروني صالح'
                                    : null,
                              ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                      const SizedBox(height: 32),

                      // Security
                      _buildSectionHeader(
                        'الأمان والحماية',
                        Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      AppComponents.card(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            AppComponents.textField(
                              controller: _passwordController,
                              hint: 'كلمة المرور',
                              prefixIcon: Icons.lock_outline_rounded,
                              isPassword: true,
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'كلمة المرور ضعيفة'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AppComponents.textField(
                              controller: _confirmPasswordController,
                              hint: 'تأكيد كلمة المرور',
                              prefixIcon: Icons.lock_clock_outlined,
                              isPassword: true,
                              validator: (v) => (v != _passwordController.text)
                                  ? 'كلمات المرور غير متطابقة'
                                  : null,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                      // Artisan Details
                      if (_selectedRole == 'artisan') ...[
                        const SizedBox(height: 32),
                        _buildSectionHeader(
                          'تفاصيل العمل والخبرة',
                          Icons.work_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildArtisanDetails(),
                      ],

                      const SizedBox(height: 48),

                      // Register Button
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          return AppComponents.primaryButton(
                            label: 'إنشاء حسابي الآن',
                            onPressed: _register,
                            isLoading: state is AuthLoading,
                          );
                        },
                      ).animate().fadeIn(delay: 400.ms).scale(),

                      const SizedBox(height: 24),

                      _buildLoginLink(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
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
      height: MediaQuery.of(context).size.height * 0.35,
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
            child: Icon(
              Icons.person_add_rounded,
              size: 200,
              color: Colors.white.withOpacity(0.05),
            ),
          ),

          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
          ),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4), // Space for border
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              image: _profileImage != null
                                  ? DecorationImage(
                                      image: FileImage(_profileImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profileImage == null
                                ? const Hero(
                                    tag: 'logo',
                                    child: Icon(
                                      Icons.handyman_rounded,
                                      size: 50,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut)
                      .rotate(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  Text(
                    'أعـمـال',
                    style: GoogleFonts.cairo(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

                  Text(
                    'إنشاء حساب جديد للبدء',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildArtisanDetails() {
    return AppComponents.card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppComponents.textField(
            controller: _bioController,
            hint: 'تحدث عن خبرتك ومجالات تميزك...',
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          AppComponents.textField(
            controller: _addressController,
            hint: 'المنطقة أو عنوان العمل',
            prefixIcon: Icons.location_on_outlined,
            readOnly: true,
            onTap: _openMapPicker,
            suffixIcon: IconButton(
              icon: const Icon(Icons.map_rounded, color: AppColors.primary),
              onPressed: _openMapPicker,
              tooltip: 'تحديد الموقع على الخريطة',
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'يرجى تحديد الموقع' : null,
          ),
          const SizedBox(height: 24),
          _buildIdentityVerification(),
          const SizedBox(height: 24),
          Text(
            'معرض الأعمال (بحد أقصى 10 صور)',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildPortfolioGrid(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildIdentityVerification() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.primary.withOpacity(0.06),
            AppColors.primary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'توثيق الهوية',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'إلزامي',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'نراجع مستندك وسيلفيك لمطابقة الهوية قبل تفعيل حساب الحرفي.',
            style: GoogleFonts.cairo(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _buildIdentityDocumentCard(),
          const SizedBox(height: 14),
          _buildSelfieIdentityCard(),
        ],
      ),
    );
  }

  Widget _buildIdentityDocumentCard() {
    final done = _idCardImage != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: _pickIdCardImage,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: done ? AppColors.success.withOpacity(0.55) : AppColors.border,
              width: done ? 1.8 : 1,
            ),
          ),
          child: done
              ? Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _idCardImage!,
                        width: 72,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'البطاقة / جواز السفر',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'تم رفع الصورة — اضغط للتغيير',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_rounded, color: AppColors.primary.withOpacity(0.7)),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Icon(
                        Icons.contact_page_rounded,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '١',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'البطاقة أو جواز السفر',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'التقاط أو اختيار صورة — نافذة إرشادات قبل الرفع',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSelfieIdentityCard() {
    final done = _selfieImage != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _pickSelfieImage,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: done ? AppColors.success.withOpacity(0.55) : AppColors.border,
              width: done ? 1.8 : 1,
            ),
          ),
          child: done
              ? Row(
                  children: [
                    ClipOval(
                      child: Image.file(
                        _selfieImage!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السيلفي',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'تم الالتقاط — اضغط لإعادة التصوير',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.photo_camera_front_rounded, color: AppColors.primary.withOpacity(0.7)),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.face_retouching_natural_rounded,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '٢',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'سيلفي بالكاميرا الأمامية',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'يُفتح التصوير مباشرة بالكاميرا الأمامية فقط (بدون المعرض)',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.photo_camera_front_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPortfolioGrid() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _portfolioImages.length + 1,
        itemBuilder: (context, index) {
          if (index == _portfolioImages.length) {
            if (_portfolioImages.length >= 10) return const SizedBox.shrink();
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.primary,
                      size: 30,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'أضف صـور',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(_portfolioImages[index]),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ).animate().scale(),
              Positioned(
                top: 4,
                right: 16,
                child: GestureDetector(
                  onTap: () => setState(() => _portfolioImages.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'لديك حساب بالفعل؟',
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () => context.pop(),
          child: Text(
            'سجل دخولك',
            style: GoogleFonts.cairo(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }
}
