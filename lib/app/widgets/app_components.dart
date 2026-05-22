import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class AppComponents {
  AppComponents._();

  // ── PRIMARY BUTTON ──────────────────────────────────────────
  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
    double? width,
    bool isLoading = false,
    Color? backgroundColor,
    IconData? prefixIcon,
    IconData? suffixIcon,
  }) {
    return AnimatedContainer(
      duration: 200.ms,
      width: width ?? double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: backgroundColor ?? Colors.transparent,
          shadowColor: (backgroundColor ?? AppColors.primary).withOpacity(0.3),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: backgroundColor == null
                ? AppColors.primaryGradient
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (prefixIcon != null) ...[
                        Icon(prefixIcon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (suffixIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(suffixIcon, color: Colors.white, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── SECONDARY BUTTON ────────────────────────────────────────
  static Widget secondaryButton({
    required String label,
    required VoidCallback? onPressed,
    double? width,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration textFieldDecoration({
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(prefixIcon, size: 20, color: AppColors.primary),
              ),
            )
          : null,
      suffixIcon: suffixIcon,
      hintStyle: GoogleFonts.cairo(fontSize: 14, color: AppColors.textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  // ── TEXT FIELD ─────────────────────────────────────────────
  static Widget textField({
    required String hint,
    TextEditingController? controller,
    String? Function(String?)? validator,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool isPassword = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    TextAlign textAlign = TextAlign.start,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: isPassword,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      textAlign: textAlign,
      style: GoogleFonts.cairo(fontSize: 15, color: AppColors.textPrimary),
      decoration: textFieldDecoration(hint: hint, prefixIcon: prefixIcon, suffixIcon: suffixIcon),
    );
  }

  // ── CHIP / TAG ─────────────────────────────────────────────
  static Widget chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }

  // ── SECTION HEADER ─────────────────────────────────────────
  static Widget sectionHeader({required String title, VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              'عرض الكل',
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────
  static Widget emptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }

  // ── ERROR STATE ────────────────────────────────────────────
  static Widget errorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            primaryButton(
              label: 'إعادة المحاولة',
              onPressed: onRetry,
              width: 200,
            ),
          ],
        ),
      ),
    );
  }

  // ── CARD WRAPPER ───────────────────────────────────────────
  static Widget card({
    required Widget child,
    EdgeInsets? padding,
    double? radius,
    Color? backgroundColor,
    double? elevation,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(radius ?? 16),
        boxShadow: elevation == 0 ? null : AppColors.shadowLevel2,
      ),
      child: child,
    );
  }

  // ── USER AVATAR ──────────────────────────────────────────
  static Widget userAvatar({
    required String? imageUrl,
    required String name,
    double radius = 24,
    double? fontSize,
    Color? backgroundColor,
    bool showBorder = false,
  }) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Widget content;
    if (hasImage) {
      content = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => shimmerCircle(size: radius * 2),
        errorWidget: (context, url, error) => _buildAvatarFallback(initial, radius, fontSize, backgroundColor),
      );
    } else {
      content = _buildAvatarFallback(initial, radius, fontSize, backgroundColor);
    }

    if (showBorder) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: ClipOval(child: SizedBox(width: radius * 2, height: radius * 2, child: content)),
        ),
      );
    }

    return ClipOval(child: SizedBox(width: radius * 2, height: radius * 2, child: content));
  }

  static Widget _buildAvatarFallback(String initial, double radius, double? fontSize, Color? backgroundColor) {
    return Container(
      alignment: Alignment.center,
      color: backgroundColor ?? AppColors.primary.withOpacity(0.1),
      child: Text(
        initial,
        style: GoogleFonts.cairo(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? (radius * 0.8),
        ),
      ),
    );
  }

  // ── PRESSABLE CARD ─────────────────────────────────────────
  static Widget pressableCard({
    required Widget child,
    required VoidCallback onTap,
    bool isPressed = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: isPressed ? 0.97 : 1.0),
      duration: const Duration(milliseconds: 120),
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card(child: child),
      ),
    );
  }

  static SnackBar _styledSnackBar(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      duration: duration,
    );
  }

  /// عرض رسالة تنبيه سريعة (SnackBar) بتصميم موحد
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final snackBar = _styledSnackBar(message, isError: isError, duration: duration);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// نفس تصميم [showSnackBar] لكن بدون اعتماد على [BuildContext] بعد فجوات async —
  /// مهم عند تحديث Stream يزيل الودجت من الشجرة قبل ظهור الرسالة.
  static void showSnackBarForMessenger(
    ScaffoldMessengerState? messenger,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (messenger == null) return;
    final snackBar = _styledSnackBar(message, isError: isError, duration: duration);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// نافذة تأكيد احترافية (Modern Confirmation Dialog)
  static Future<void> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
    IconData icon = Icons.help_outline_rounded,
    Color? iconColor,
    bool isDanger = false,
  }) async {
    final Color primaryColor = isDanger ? AppColors.error : AppColors.primary;
    final Color accentColor = iconColor ?? primaryColor;

    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 40),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.cairo(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        confirmText,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
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
    );
  }

  /// واجهـة تحميل (Shimmer) لشكل مستطيل/بطاقة
  static Widget shimmerCard({
    double? width,
    double height = 100,
    double borderRadius = 16,
  }) {
    return Container(
          width: width ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.5));
  }

  /// واجهـة تحميل (Shimmer) لشكل دائري (Avatar)
  static Widget shimmerCircle({double size = 50}) {
    return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.5));
  }

  /// قائمة تحميل وهمية (Shimmer List) للعرض أثناء جلب البيانات
  static Widget shimmerList({int count = 5, double height = 100, EdgeInsets? padding}) {
    return ListView.separated(
      padding: padding ?? EdgeInsets.zero,
      itemCount: count,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => shimmerCard(height: height),
    );
  }

  /// هيدر الصفحة الرئيسية (Home Header) بتصميم احترافي متطور
  static Widget homeHeader(
    BuildContext context, {
    required String userName,
    required String? userAvatarUrl,
    required int unreadNotifications,
    VoidCallback? onNotificationTap,
    VoidCallback? onAdminTap,
    Widget? subtitle,
  }) {
    final hour = DateTime.now().hour;
    String greeting = 'مرحباً بك،';
    if (hour >= 5 && hour < 12)
      greeting = 'صباح الخير،';
    else if (hour >= 12 && hour < 17)
      greeting = 'طاب يومك،';
    else if (hour >= 17 && hour < 21)
      greeting = 'مساء الخير،';
    else
      greeting = 'تصبح على خير،';

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.5),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Profile Avatar with Frame
              userAvatar(
                imageUrl: userAvatarUrl,
                name: userName,
                radius: 24,
                showBorder: true,
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

              const SizedBox(width: 12),

              if (onAdminTap != null)
                IconButton(
                  onPressed: onAdminTap,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 20),
                  ),
                  tooltip: 'لوحة الإدارة',
                ).animate().fadeIn().scale(),

              const SizedBox(width: 16),

              // Greeting & Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      userName,
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Notification Icon
              IconButton(
                onPressed: onNotificationTap,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                    if (unreadNotifications > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child:
                            Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadNotifications.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat())
                                .shimmer(duration: 2.seconds),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[const SizedBox(height: 12), subtitle],
        ],
      ),
    );
  }

  /// أببار احترافي (Premium AppBar) للاستخدام في جميع الصفحات
  static PreferredSizeWidget premiumAppBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    bool showBackButton = true,
  }) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black12,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.pop(),
            )
          : null,
      actions: [if (actions != null) ...actions, const SizedBox(width: 8)],
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        side: BorderSide(
          color: AppColors.primary.withOpacity(0.35),
          width: 1.8,
        ),
      ),
    );
  }

  /// عرض خيارات اختيار الصورة (كاميرا أو معرض)
  static Future<ImageSource?> showImageSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إضافة صور',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختر الطريقة التي تفضلها لإضافة الصور',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOption(
                      context,
                      label: 'الكاميرا',
                      icon: Icons.camera_alt_rounded,
                      color: Colors.blue,
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSourceOption(
                      context,
                      label: 'المعرض',
                      icon: Icons.photo_library_rounded,
                      color: Colors.purple,
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSourceOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
