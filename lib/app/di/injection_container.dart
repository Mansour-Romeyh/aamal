import 'package:get_it/get_it.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/posts/data/repositories/post_repository.dart';
import '../../features/posts/presentation/bloc/post_cubit.dart';
import '../../features/home/artisan/presentation/bloc/artisan_posts_cubit.dart';
import '../../features/home/artisan/presentation/bloc/artisan_jobs_cubit.dart';
import '../../features/home/client/presentation/bloc/client_posts_cubit.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';
import '../../features/chat/presentation/bloc/conversations_cubit.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';
import '../../features/notifications/presentation/bloc/notification_cubit.dart';
import '../../features/splash/presentation/bloc/splash_cubit.dart';
import '../../core/services/cloudinary_service.dart';
import '../../features/ratings/data/repositories/rating_repository.dart';
import '../../features/reports/data/repositories/report_repository.dart';
import '../../features/requests/data/repositories/service_request_repository.dart';
import '../../features/requests/presentation/bloc/service_request_cubit.dart';
import '../../features/home/admin/data/repositories/specialty_repository.dart';

/// حاوية حقن التبعيات (Dependency Injection)
final GetIt sl = GetIt.instance;

/// تهيئة كل التبعيات
Future<void> initDependencies() async {
  // ── Repositories ──────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  sl.registerLazySingleton<PostRepository>(() => PostRepository());
  sl.registerLazySingleton<ChatRepository>(() => ChatRepository());
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepository(),
  );
  sl.registerLazySingleton<CloudinaryService>(() => CloudinaryService());
  sl.registerLazySingleton<RatingRepository>(() => RatingRepository());
  sl.registerLazySingleton<ReportRepository>(() => ReportRepository());
  sl.registerLazySingleton<ServiceRequestRepository>(
    () => ServiceRequestRepository(),
  );
  sl.registerLazySingleton<SpecialtyRepository>(() => SpecialtyRepository());

  // ── Cubits ────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthCubit>(
    () => AuthCubit(
      authRepository: sl<AuthRepository>(),
      cloudinaryService: sl<CloudinaryService>(),
    ),
  );
  sl.registerFactory<PostCubit>(
    () => PostCubit(
      postRepository: sl<PostRepository>(),
      chatRepository: sl<ChatRepository>(),
    ),
  );
  sl.registerFactory<ArtisanPostsCubit>(
    () => ArtisanPostsCubit(postRepository: sl<PostRepository>()),
  );
  sl.registerFactory<ArtisanJobsCubit>(
    () => ArtisanJobsCubit(postRepository: sl<PostRepository>()),
  );
  sl.registerFactory<ClientPostsCubit>(
    () => ClientPostsCubit(postRepository: sl<PostRepository>()),
  );
  sl.registerFactory<ChatCubit>(
    () => ChatCubit(chatRepository: sl<ChatRepository>()),
  );
  sl.registerLazySingleton<ConversationsCubit>(
    () => ConversationsCubit(chatRepository: sl<ChatRepository>()),
  );
  sl.registerLazySingleton<NotificationCubit>(
    () => NotificationCubit(repository: sl<NotificationRepository>()),
  );
  sl.registerFactory<ServiceRequestCubit>(
    () => ServiceRequestCubit(sl<ServiceRequestRepository>()),
  );
  sl.registerFactory<SplashCubit>(() => SplashCubit());
}
