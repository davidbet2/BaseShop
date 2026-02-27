import 'package:equatable/equatable.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotifications extends NotificationsEvent {
  final int page;

  const LoadNotifications({this.page = 1});

  @override
  List<Object?> get props => [page];
}

class LoadUnreadCount extends NotificationsEvent {
  const LoadUnreadCount();
}

class MarkAllNotificationsRead extends NotificationsEvent {
  const MarkAllNotificationsRead();
}

class DeleteNotification extends NotificationsEvent {
  final String notificationId;

  const DeleteNotification({required this.notificationId});

  @override
  List<Object?> get props => [notificationId];
}

class DeleteAllNotifications extends NotificationsEvent {
  const DeleteAllNotifications();
}
