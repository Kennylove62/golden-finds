import 'package:flutter/material.dart';

import '../../core/theme/golden_dark.dart';

import '../../models/app_notification.dart';

class NotificationCenterDialog extends StatelessWidget {
  const NotificationCenterDialog({
    super.key,
    required this.title,
    required this.notifications,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onOpenOrder,
  });

  final String title;
  final List<AppNotification> notifications;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Future<void> Function(AppNotification notification) onMarkRead;
  final Future<void> Function() onMarkAllRead;
  final VoidCallback onOpenOrder;

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_order':
        return Icons.shopping_bag_outlined;
      case 'order_accepted':
        return Icons.check_circle_outline_rounded;
      case 'order_cancelled':
        return Icons.cancel_outlined;
      case 'order_completed':
        return Icons.task_alt_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications
        .where((notification) => !notification.read)
        .length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(
        constraints: BoxConstraints(maxWidth: 650, maxHeight: 680),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          unreadCount == 0
                              ? 'You are all caught up.'
                              : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                          style: TextStyle(color: Colors.black45, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Flexible(
              child: notifications.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: accentColor,
                            size: 46,
                          ),
                          SizedBox(height: 13),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Important order activity will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(14),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) => SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];

                        return Material(
                          color: notification.read
                              ? Colors.white
                              : accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              await onMarkRead(notification);

                              if (!context.mounted) {
                                return;
                              }

                              Navigator.pop(context);

                              onOpenOrder();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      _iconFor(notification.type),
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notification.title,
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontSize: 13,
                                                  fontWeight: notification.read
                                                      ? FontWeight.w700
                                                      : FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            if (!notification.read)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: accentColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          notification.message,
                                          style: TextStyle(
                                            color: GoldenDark.muted(context),
                                            fontSize: 11,
                                            height: 1.4,
                                          ),
                                        ),
                                        SizedBox(height: 7),
                                        Text(
                                          notification.timeLabel,
                                          style: TextStyle(
                                            color: GoldenDark.subtle(context),
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (notifications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (unreadCount > 0)
                      TextButton.icon(
                        onPressed: () async {
                          await onMarkAllRead();

                          if (!context.mounted) {
                            return;
                          }

                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.done_all_rounded),
                        label: Text('Mark all read'),
                      ),
                    SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('Close'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
