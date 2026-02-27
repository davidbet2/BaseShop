import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/notifications/bloc/notifications_bloc.dart';
import 'package:baseshop/features/notifications/bloc/notifications_event.dart';
import 'package:baseshop/features/notifications/bloc/notifications_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsBloc _bloc;
  int _page = 1;
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<NotificationsBloc>();
    _bloc.add(const LoadNotifications());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _loadPage() {
    _bloc.add(LoadNotifications(page: _page));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          actions: [
            BlocBuilder<NotificationsBloc, NotificationsState>(
              builder: (context, state) {
                final hasNotifications = state is NotificationsLoaded &&
                    state.notifications.isNotEmpty;
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  enabled: hasNotifications,
                  onSelected: (value) {
                    switch (value) {
                      case 'read_all':
                        _bloc.add(const MarkAllNotificationsRead());
                        break;
                      case 'delete_all':
                        _confirmDeleteAll();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'read_all',
                      child: Row(
                        children: [
                          Icon(Icons.done_all, size: 20),
                          SizedBox(width: 8),
                          Text('Marcar todas como leídas'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep, size: 20, color: AppTheme.errorColor),
                          const SizedBox(width: 8),
                          Text('Eliminar todas',
                              style: TextStyle(color: AppTheme.errorColor)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<NotificationsBloc, NotificationsState>(
          listener: (context, state) {
            if (state is NotificationActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
            if (state is NotificationsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is NotificationsLoading) return _buildShimmer();
            if (state is NotificationsLoaded) {
              if (state.notifications.isEmpty) return _buildEmpty();
              return _buildList(state);
            }
            if (state is NotificationsError) return _buildError(state.message);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildList(NotificationsLoaded state) {
    final totalPages = (state.total / _limit).ceil().clamp(1, 999);

    return Column(
      children: [
        if (state.unread > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            child: Text(
              '${state.unread} notificación${state.unread != 1 ? 'es' : ''} sin leer',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _loadPage();
              await _bloc.stream.firstWhere((s) => s is! NotificationsLoading);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: state.notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(state.notifications[index]);
              },
            ),
          ),
        ),
        if (totalPages > 1) _buildPaginationBar(totalPages),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final id = (notification['id'] ?? '').toString();
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final isRead = notification['is_read'] == 1 || notification['is_read'] == true;
    final orderId = notification['order_id'] as String?;
    final createdAt = notification['created_at'] as String?;

    String dateStr = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        final now = DateTime.now();
        final diff = now.difference(date);
        if (diff.inMinutes < 60) {
          dateStr = 'Hace ${diff.inMinutes} min';
        } else if (diff.inHours < 24) {
          dateStr = 'Hace ${diff.inHours}h';
        } else if (diff.inDays < 7) {
          dateStr = 'Hace ${diff.inDays}d';
        } else {
          dateStr = DateFormat('dd/MM/yy HH:mm').format(date);
        }
      } catch (_) {}
    }

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        _bloc.add(DeleteNotification(notificationId: id));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isRead ? Colors.grey.shade200 : Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        color: isRead ? null : Theme.of(context).colorScheme.primary.withOpacity(0.04),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Mark as read when tapped
            if (!isRead) {
              _bloc.add(MarkNotificationRead(notificationId: id));
            }
            // Navigate to order if applicable
            if (orderId != null && orderId.isNotEmpty) {
              context.push('/orders/$orderId');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.grey.shade100
                        : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    size: 20,
                    color: isRead
                        ? Colors.grey.shade500
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: Colors.grey.shade400),
                  onPressed: () =>
                      _bloc.add(DeleteNotification(notificationId: id)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _loadPage();
                  }
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            'Página $_page de $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < totalPages
                ? () {
                    setState(() => _page++);
                    _loadPage();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar notificaciones'),
        content: const Text(
            '¿Estás seguro de eliminar todas las notificaciones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _bloc.add(const DeleteAllNotifications());
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Eliminar todas'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No tienes notificaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las notificaciones de tus pedidos\naparecerán aquí',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPage,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
