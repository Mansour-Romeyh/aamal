part of 'splash_cubit.dart';

/// حالات شاشة البداية
sealed class SplashState extends Equatable {
  const SplashState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class SplashInitial extends SplashState {
  const SplashInitial();
}

/// الأنيميشن جاري
class SplashAnimating extends SplashState {
  const SplashAnimating();
}

/// الأنيميشن انتهى – جاهز للانتقال
class SplashCompleted extends SplashState {
  const SplashCompleted();
}
