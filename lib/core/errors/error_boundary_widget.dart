import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// ErrorBoundaryWidget presents a clean, user-friendly failure state
/// with contextual recovery actions and offline indicators.
class ErrorBoundaryWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String? title;

  const ErrorBoundaryWidget({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ShadCard(
          title: Text(title ?? 'Something Went Wrong', style: theme.textTheme.h4),
          description: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              error.toString(),
              style: theme.textTheme.muted,
            ),
          ),
          footer: onRetry != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ShadButton(
                    onPressed: onRetry,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.refreshCw, size: 16),
                        SizedBox(width: 8),
                        Text('Try Again'),
                      ],
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
