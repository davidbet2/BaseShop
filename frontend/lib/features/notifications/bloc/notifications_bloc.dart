import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:baseshop/features/notifications/repository/notifications_repository.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationsRepository _repository;

  NotificationsBloc(this._repository) : super(NotificationsInitial()) {
    on<LoadNotifications>(_onLoad);
    on<LoadUnreadCount>(_onLoadUnreadCount);
    on<MarkAllNotificationsRead>(_onMarkAllRead);
    on<DeleteNotification>(_onDelete);
    on<DeleteAllNotifications>(_onDeleteAll);
  }

  Future<void> _onLoad(
    LoadNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(NotificationsLoading());
    try {
      final result = await _repository.getMyNotifications(page: event.page);
      final notifications = (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      emit(NotificationsLoaded(
        notifications: notifications,
        total: result['total'] as int? ?? 0,
        page: result['page'] as int? ?? event.page,
        unread: result['unread'] as int? ?? 0,
      ));
    } catch (e) {
      emit(NotificationsError('Error al cargar notificaciones: $e'));
    }
  }

  Future<void> _onLoadUnreadCount(
    LoadUnreadCount event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      final unread = await _repository.getUnreadCount();
      emit(UnreadCountLoaded(unread));
    } catch (_) {
      // Silently fail – badge just won't update
    }
  }

  Future<void> _onMarkAllRead(
    MarkAllNotificationsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _repository.markAllRead();
      add(const LoadNotifications());
    } catch (e) {
      emit(NotificationsError('Error: $e'));
    }
  }

  Future<void> _onDelete(
    DeleteNotification event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _repository.deleteNotification(event.notificationId);
      emit(const NotificationActionSuccess('Notificación eliminada'));
      add(const LoadNotifications());
    } catch (e) {
      emit(NotificationsError('Error al eliminar: $e'));
    }
  }

  Future<void> _onDeleteAll(
    DeleteAllNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _repository.deleteAll();
      emit(const NotificationActionSuccess('Todas las notificaciones eliminadas'));
      add(const LoadNotifications());
    } catch (e) {
      emit(NotificationsError('Error al eliminar: $e'));
    }
  }
}
