import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:baseshop/features/notifications/bloc/notifications_bloc.dart';
import 'package:baseshop/features/notifications/bloc/notifications_event.dart';
import 'package:baseshop/features/notifications/bloc/notifications_state.dart';
import 'package:baseshop/features/notifications/repository/notifications_repository.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

void main() {
  late MockNotificationsRepository mockRepo;

  setUp(() {
    mockRepo = MockNotificationsRepository();
  });

  group('NotificationsBloc', () {
    // ── LoadNotifications ──
    group('LoadNotifications', () {
      blocTest<NotificationsBloc, NotificationsState>(
        'emits [NotificationsLoading, NotificationsLoaded] on success',
        build: () {
          when(() => mockRepo.getMyNotifications(page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [
                      {
                        'id': 'n1',
                        'title': 'Pedido actualizado',
                        'is_read': 0
                      },
                      {'id': 'n2', 'title': 'Pedido enviado', 'is_read': 1},
                    ],
                    'total': 2,
                    'page': 1,
                    'unread': 1,
                  });
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadNotifications()),
        expect: () => [
          isA<NotificationsLoading>(),
          isA<NotificationsLoaded>()
              .having((s) => s.notifications.length, 'count', 2)
              .having((s) => s.total, 'total', 2)
              .having((s) => s.unread, 'unread', 1),
        ],
      );

      blocTest<NotificationsBloc, NotificationsState>(
        'emits [NotificationsLoading, NotificationsError] on failure',
        build: () {
          when(() => mockRepo.getMyNotifications(page: any(named: 'page')))
              .thenThrow(Exception('Network error'));
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadNotifications()),
        expect: () => [
          isA<NotificationsLoading>(),
          isA<NotificationsError>(),
        ],
      );
    });

    // ── LoadUnreadCount ──
    group('LoadUnreadCount', () {
      blocTest<NotificationsBloc, NotificationsState>(
        'emits [UnreadCountLoaded] on success',
        build: () {
          when(() => mockRepo.getUnreadCount())
              .thenAnswer((_) async => 5);
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadUnreadCount()),
        expect: () => [
          isA<UnreadCountLoaded>().having((s) => s.unread, 'unread', 5),
        ],
      );

      blocTest<NotificationsBloc, NotificationsState>(
        'silently fails on error',
        build: () {
          when(() => mockRepo.getUnreadCount())
              .thenThrow(Exception('Error'));
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadUnreadCount()),
        expect: () => [],
      );
    });

    // ── MarkAllNotificationsRead ──
    group('MarkAllNotificationsRead', () {
      blocTest<NotificationsBloc, NotificationsState>(
        'marks all read then reloads',
        build: () {
          when(() => mockRepo.markAllRead()).thenAnswer((_) async {});
          when(() => mockRepo.getMyNotifications(page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [
                      {'id': 'n1', 'is_read': 1}
                    ],
                    'total': 1,
                    'page': 1,
                    'unread': 0,
                  });
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const MarkAllNotificationsRead()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // Reload is triggered: Loading -> Loaded
          isA<NotificationsLoading>(),
          isA<NotificationsLoaded>()
              .having((s) => s.unread, 'unread', 0),
        ],
      );

      blocTest<NotificationsBloc, NotificationsState>(
        'emits error when markAllRead fails',
        build: () {
          when(() => mockRepo.markAllRead())
              .thenThrow(Exception('Failed'));
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const MarkAllNotificationsRead()),
        expect: () => [isA<NotificationsError>()],
      );
    });

    // ── MarkNotificationRead ──
    group('MarkNotificationRead', () {
      blocTest<NotificationsBloc, NotificationsState>(
        'marks single notification read then reloads',
        build: () {
          when(() => mockRepo.markAsRead('n1')).thenAnswer((_) async {});
          when(() => mockRepo.getMyNotifications(page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [
                      {'id': 'n1', 'is_read': 1}
                    ],
                    'total': 1,
                    'page': 1,
                    'unread': 0,
                  });
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) =>
            bloc.add(const MarkNotificationRead(notificationId: 'n1')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<NotificationsLoading>(),
          isA<NotificationsLoaded>(),
        ],
      );
    });

    // ── DeleteNotification ──
    group('DeleteNotification', () {
      blocTest<NotificationsBloc, NotificationsState>(
        'deletes notification and reloads',
        build: () {
          when(() => mockRepo.deleteNotification('n1'))
              .thenAnswer((_) async {});
          when(() => mockRepo.getMyNotifications(page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [],
                    'total': 0,
                    'page': 1,
                    'unread': 0,
                  });
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) =>
            bloc.add(const DeleteNotification(notificationId: 'n1')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<NotificationActionSuccess>()
              .having((s) => s.message, 'msg', 'Notificación eliminada'),
          isA<NotificationsLoading>(),
          isA<NotificationsLoaded>()
              .having((s) => s.notifications.isEmpty, 'empty', true),
        ],
      );

      blocTest<NotificationsBloc, NotificationsState>(
        'emits error when delete fails',
        build: () {
          when(() => mockRepo.deleteNotification(any()))
              .thenThrow(Exception('Failed'));
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) =>
            bloc.add(const DeleteNotification(notificationId: 'bad')),
        expect: () => [isA<NotificationsError>()],
      );
    });

    // ── DeleteAllNotifications ──
    group('DeleteAllNotifications', () {
      blocTest<NotificationsBloc, NotificationsState>(
        'deletes all and reloads',
        build: () {
          when(() => mockRepo.deleteAll()).thenAnswer((_) async {});
          when(() => mockRepo.getMyNotifications(page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [],
                    'total': 0,
                    'page': 1,
                    'unread': 0,
                  });
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const DeleteAllNotifications()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<NotificationActionSuccess>().having(
              (s) => s.message, 'msg', 'Todas las notificaciones eliminadas'),
          isA<NotificationsLoading>(),
          isA<NotificationsLoaded>(),
        ],
      );

      blocTest<NotificationsBloc, NotificationsState>(
        'emits error when deleteAll fails',
        build: () {
          when(() => mockRepo.deleteAll())
              .thenThrow(Exception('Failed'));
          return NotificationsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const DeleteAllNotifications()),
        expect: () => [isA<NotificationsError>()],
      );
    });
  });
}
