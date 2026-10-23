import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../notifications_controller.dart';
import '../../../../core/router/route_paths.dart';

class NotificationBellButton extends ConsumerWidget {
  final Color? color;

  const NotificationBellButton({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF10B981),
        textColor: Colors.white,
        child: Icon(
          LucideIcons.bell,
          size: 20,
          color: color,
        ),
      ),
      onPressed: () => context.push(RoutePaths.notifications),
    );
  }
}
