import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:works/firebase_options.dart';
import 'package:works/app/di/injection_container.dart';
import 'package:works/app/router/app_router.dart';
import 'package:works/app/theme/app_theme.dart';
import 'package:works/core/services/notification_service.dart';
import 'package:works/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:works/features/posts/presentation/bloc/post_cubit.dart';
import 'package:works/features/chat/presentation/bloc/conversations_cubit.dart';
import 'package:works/features/notifications/presentation/bloc/notification_cubit.dart';
import 'package:works/features/requests/presentation/bloc/service_request_cubit.dart';
import 'package:works/features/splash/presentation/bloc/splash_cubit.dart';
import 'package:works/features/home/client/presentation/bloc/client_posts_cubit.dart';

import 'package:works/features/auth/data/repositories/auth_repository.dart';

/// أندرويد: أحياناً يظل FirebaseAuth.instance.currentUser = null لفترة قصيرة
/// بعد cold start قبل أن يُحمَّل JWT من القرص. نمهّد قبل بناء الواجهة لتفادي
/// checkAuthStatus() يعتبر المستخدم خارج ثم Splash يذهب للوجين.
Future<void> _primeFirebaseAuthFromDisk() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return;

  for (var i = 0; i < 30; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    if (auth.currentUser != null) {
      debugPrint('✅ FirebaseAuth hydrated from disk (${(i + 1) * 100}ms)');
      return;
    }
  }

  debugPrint(
    'ℹ️ FirebaseAuth still null after ${_primeAuthWaitMs.round()}ms '
    '(مسجّل خروج فعلاً أو تأخير نادر جداً؛ نكمل وفق checkAuthStatus).',
  );
}

const double _primeAuthWaitMs = 3000;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ──────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // تفعيل App Check للتحقق الصامت من هوية التطبيق (بدون reCAPTCHA)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  await _primeFirebaseAuthFromDisk();

  // ── Background message handler ────────────────────────────────
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ── Dependency Injection ──────────────────────────────────────
  await initDependencies();

  // لا نعلّق إقلاع التطبيق؛ استعلام Firestore الأول قد يتصارع مع Auth على الشبكة
  unawaited(sl<AuthRepository>().migrateGeoHashes());

  // ── Initialize Notification Service (Non-blocking) ────────────
  NotificationService.instance.initialize();

  // ── Status Bar Style ──────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ── Preferred Orientations ────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AppLifecycleObserver(child: WorkersApp()));
}

/// مراقب لحالة التطبيق لتحديث حالة "متصل الآن"
class AppLifecycleObserver extends StatefulWidget {
  final Widget child;
  const AppLifecycleObserver({super.key, required this.child});

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // تم حذف الاشتراك في AuthCubit من هنا لمنع الـ Infinite Loop مع تحديث الـ Online Status
    // تحديث الحالة سيتم فقط من خلال الـ Lifecycle (Resumed/Paused) أو عند تسجيل الدخول الأول
    _updateStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _updateStatus(false);
    }
  }

  void _updateStatus(bool isOnline) {
    final authState = sl<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      sl<AuthRepository>().updateUserOnlineStatus(authState.user.uid, isOnline);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// التطبيق الرئيسي
///
/// ⚠️ AuthCubit مسجَّل كـ singleton في GetIt؛ استخدام BlocProvider(create) يُغلق الـ Cubit
/// عند dispose ويبطل الجلسة/التيار. نستخدم [BlocProvider.value] فلا يُستدعى close().
class WorkersApp extends StatefulWidget {
  const WorkersApp({super.key});

  @override
  State<WorkersApp> createState() => _WorkersAppState();
}

class _WorkersAppState extends State<WorkersApp> {
  @override
  void initState() {
    super.initState();
    sl<AuthCubit>().checkAuthStatus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: sl<AuthCubit>(),
      child: MultiBlocProvider(
        providers: [
        BlocProvider<PostCubit>(
          create: (_) => sl<PostCubit>(),
        ),
        BlocProvider<ConversationsCubit>(
          create: (_) => sl<ConversationsCubit>(),
        ),
        BlocProvider<NotificationCubit>(
          create: (_) => sl<NotificationCubit>(),
        ),
        BlocProvider<ServiceRequestCubit>(
          create: (_) => sl<ServiceRequestCubit>(),
        ),
        BlocProvider<SplashCubit>(
          create: (_) => sl<SplashCubit>(),
        ),
        BlocProvider<ClientPostsCubit>(
          create: (_) => sl<ClientPostsCubit>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'وركرز',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        routerConfig: AppRouter.router,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    ),
    );
  }
}
