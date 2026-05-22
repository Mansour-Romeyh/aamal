import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/notification_repository.dart';
import 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository _repository;

  NotificationCubit({required NotificationRepository repository})
      : _repository = repository,
        super(NotificationInitial());

  void loadNotifications(String userId, {bool isAdmin = false}) {
    emit(NotificationLoading());
    _repository.getUserNotifications(userId, isAdmin: isAdmin).listen(
      (notifications) {
        emit(NotificationLoaded(notifications));
      },
      onError: (e) {
        emit(NotificationError('فشل تحميل الإشعارات: $e'));
      },
    );
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _repository.markAsRead(userId, notificationId);
  }

  Future<void> deleteNotification(String userId, String notificationId, bool wasRead) async {
    await _repository.deleteNotification(userId, notificationId, wasRead);
  }
}
