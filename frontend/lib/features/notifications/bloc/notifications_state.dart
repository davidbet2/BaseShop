import 'package:equatable/equatable.dart';

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  final List<Map<String, dynamic>> notifications;
  final int total;
  final int page;
  final int unread;

  const NotificationsLoaded({
    required this.notifications,
    required this.total,
    required this.page,
    required this.unread,
  });

  @override
  List<Object?> get props => [notifications, total, page, unread];
}

class UnreadCountLoaded extends NotificationsState {
  final int unread;

  const UnreadCountLoaded(this.unread);

  @override
  List<Object?> get props => [unread];
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object?> get props => [message];
}

class NotificationActionSuccess extends NotificationsState {
  final String message;

  const NotificationActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
