import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/home/client/pages/client_home_page.dart';
import '../../features/home/artisan/pages/artisan_home_page.dart';
import '../../features/home/admin/pages/admin_panel_page.dart';
import '../../features/home/admin/pages/admin_mode_selection_page.dart';
import '../../features/posts/presentation/pages/create_post_page.dart';
import '../../features/posts/presentation/pages/post_details_page.dart';
import '../../features/posts/presentation/pages/edit_post_page.dart';
import '../../features/posts/data/models/post_model.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/ratings/presentation/pages/artisan_ratings_page.dart';
import '../../features/home/artisan/pages/artisan_profile_page.dart';
import '../../features/requests/presentation/pages/create_direct_request_page.dart';
import '../../features/auth/presentation/pages/pending_approval_page.dart';
import '../../features/auth/presentation/pages/account_restricted_page.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../app/di/injection_container.dart';
import '../../features/auth/data/models/user_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';

/// إعداد GoRouter مع كل المسارات
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(sl<AuthCubit>().stream),
    redirect: (context, state) {
      final authState = sl<AuthCubit>().state;
      final currentLocation = state.matchedLocation;

      // 1. إذا كان المستخدم غير مسجل دخول كلياً (Logout)
      if (authState is AuthUnauthenticated) {
        // نسمح له بالبقاء في الصفحات العامة (بما فيها لوحة التحكم المركزية)
        final isPublicPage = currentLocation == '/login' || 
                            currentLocation == '/register' || currentLocation == '/forgot-password' || 
                            currentLocation == '/' ||
                            currentLocation == '/admin' ||
                            currentLocation == '/admin-selection' ||
                            currentLocation.startsWith('/chat-room/');
        if (!isPublicPage) {
          return '/login';
        }
      }

      // 2. إذا كان المستخدم مسجل دخول
      if (authState is AuthAuthenticated) {
        final user = authState.user;
        
        // أ. حالة الحساب المقيد (المحضور بقرار إداري)
        if (!user.isActive) {
          final isRestrictedPage = currentLocation == '/restricted';
          final isChatPage = currentLocation.startsWith('/chat-room/');
          
          if (!isRestrictedPage && !isChatPage) {
            return '/restricted';
          }
          return null;
        }

        // ب. حالة الحساب بانتظار الموافقة (للحرفيين الجدد)
        if (user.role == 'artisan' && user.approvalStatus == 'pending') {
          final isPendingPage = currentLocation == '/pending';
          if (!isPendingPage) {
            return '/pending';
          }
          return null;
        }

        // ج. إذا حاول مستخدم نشط ومقبول الدخول لشاشات الانتظار أو التقييد، يتم توجيهه لصفحة البداية
        if (currentLocation == '/restricted' || currentLocation == '/pending') {
           return user.role == 'admin' ? '/admin' : (user.role == 'artisan' ? '/artisan' : '/client');
        }
      }
      return null;
    },
    routes: [
      // ── Splash ────────────────────────────────────────────────
      GoRoute(
        path: '/',
        name: 'splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ),

      // ── Auth ──────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(
              position: slideAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Client Home ───────────────────────────────────────────
      GoRoute(
        path: '/client',
        name: 'clientHome',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ClientHomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Artisan Home ──────────────────────────────────────────
      GoRoute(
        path: '/artisan',
        name: 'artisanHome',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ArtisanHomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Admin Panel ───────────────────────────────────────────
      GoRoute(
        path: '/admin',
        name: 'adminPanel',
        pageBuilder: (context, state) {
          final tabIndexStr = state.uri.queryParameters['tab'];
          final initialTabIndex = int.tryParse(tabIndexStr ?? '') ?? 0;
          return CustomTransitionPage(
            key: state.pageKey,
            child: AdminPanelPage(initialTabIndex: initialTabIndex),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      // ── Admin Mode Selection ──────────────────────────────────
      GoRoute(
        path: '/admin-selection',
        name: 'adminSelection',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AdminModeSelectionPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Create Post ───────────────────────────────────────────
      GoRoute(
        path: '/create-post',
        name: 'createPost',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CreatePostPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(
              position: slideAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),

      // ── Edit Post ───────────────────────────────────────────
      GoRoute(
        path: '/edit-post',
        name: 'editPost',
        pageBuilder: (context, state) {
          final post = state.extra as PostModel;
          return CustomTransitionPage(
            key: state.pageKey,
            child: EditPostPage(post: post),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      // ── Post Details ──────────────────────────────────────────
      GoRoute(
        path: '/post-details',
        name: 'postDetails',
        pageBuilder: (context, state) {
          // جلب البيانات من الـ extra (للـ UI) أو الـ query parameters (للإشعارات)
          final post = state.extra as PostModel?;
          final postId = state.uri.queryParameters['postId'] ?? post?.id ?? '';
          final isDirectRequest = state.uri.queryParameters['isDirectRequest'] == 'true';
          
          return CustomTransitionPage(
            key: state.pageKey,
            child: BlocProvider<ChatCubit>(
              create: (context) => sl<ChatCubit>(),
              child: PostDetailsPage(
                post: post,
                postId: postId,
                isDirectRequest: isDirectRequest,
              ),
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      // ── Conversations ─────────────────────────────────────────
      GoRoute(
        path: '/conversations',
        name: 'conversations',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ConversationsPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Chat Room ─────────────────────────────────────────────
      GoRoute(
        path: '/chat-room/:conversationId',
        name: 'chatRoom',
        pageBuilder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final extraData = state.extra as Map<String, dynamic>? ?? {};
          final otherUserName = extraData['name'] as String? ?? 'مستخدم';
          final otherUserId = extraData['id'] as String? ?? '';
          final isAdminView = extraData['isAdminView'] as bool? ?? false;
          final isSupportView = extraData['isSupportView'] as bool? ?? false;
          
          return MaterialPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (context) => sl<ChatCubit>(),
              child: ChatPage(
                conversationId: conversationId,
                otherUserName: otherUserName,
                otherUserId: otherUserId,
                isAdminView: isAdminView,
                isSupportView: isSupportView,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationsPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/artisan-ratings',
        name: 'artisanRatings',
        pageBuilder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          final artisanId = data['id'] as String;
          final artisanName = data['name'] as String;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ArtisanRatingsPage(
              artisanId: artisanId,
              artisanName: artisanName,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/artisan-profile',
        name: 'artisanProfile',
        pageBuilder: (context, state) {
          final artisan = state.extra as UserModel?;
          if (artisan == null) {
            return const MaterialPage(child: Scaffold(body: Center(child: Text('حدث خطأ في عرض الملف الشخصي'))));
          }
          return CustomTransitionPage(
            key: state.pageKey,
            child: ArtisanProfilePage(artisan: artisan),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/direct-request',
        name: 'directRequest',
        pageBuilder: (context, state) {
          final artisan = state.extra as UserModel?;
          if (artisan == null) {
            return const MaterialPage(child: Scaffold(body: Center(child: Text('حدث خطأ: بيانات الحرفي غير متوفرة'))));
          }
          return CustomTransitionPage(
            key: state.pageKey,
            child: CreateDirectRequestPage(artisan: artisan),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          );
        },
      ),
      GoRoute(
        path: '/pending',
        name: 'pending',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PendingApprovalPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/restricted',
        name: 'restricted',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AccountRestrictedPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    ],

    // ── صفحة الخطأ ──────────────────────────────────────────────
    errorPageBuilder: (context, state) => MaterialPage(
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'الصفحة غير موجودة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('العودة للرئيسية'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// فئة مساعدة لتحديث المسارات بناءً على Stream (مثل Bloc)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
