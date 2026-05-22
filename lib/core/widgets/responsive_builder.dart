import 'package:flutter/material.dart';

/// نقاط التوقف للتصميم المتجاوب
class Breakpoints {
  Breakpoints._();
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// حجم الشاشة الحالي
enum ScreenSize { mobile, tablet, desktop }

/// ويدجت تتيح بناء تصميم متجاوب حسب حجم الشاشة
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < Breakpoints.mobile) return ScreenSize.mobile;
    if (width < Breakpoints.tablet) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  static bool isMobile(BuildContext context) =>
      getScreenSize(context) == ScreenSize.mobile;

  static bool isTablet(BuildContext context) =>
      getScreenSize(context) == ScreenSize.tablet;

  static bool isDesktop(BuildContext context) =>
      getScreenSize(context) == ScreenSize.desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = getScreenSize(context);
        return builder(context, screenSize);
      },
    );
  }
}

/// Extension لسهولة الاستخدام
extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize => ResponsiveBuilder.getScreenSize(this);
  bool get isMobile => ResponsiveBuilder.isMobile(this);
  bool get isTablet => ResponsiveBuilder.isTablet(this);
  bool get isDesktop => ResponsiveBuilder.isDesktop(this);

  /// يرجع قيمة محددة حسب حجم الشاشة
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    switch (screenSize) {
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.mobile:
        return mobile;
    }
  }
}
