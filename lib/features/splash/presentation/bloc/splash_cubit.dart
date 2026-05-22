import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'splash_state.dart';

/// Cubit للتحكم في شاشة البداية
class SplashCubit extends Cubit<SplashState> {
  SplashCubit() : super(const SplashInitial());

  /// بدء أنيميشن الـ splash
  Future<void> startSplash() async {
    emit(const SplashAnimating());

    // انتظار الأنيميشن (3 ثواني)
    await Future.delayed(const Duration(milliseconds: 3000));

    emit(const SplashCompleted());
  }
}
