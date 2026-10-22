import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Contextual error banner for authentication feedback (invalid OTPs, timeouts, rate limits)
class AuthErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AuthErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(25),
        border: Border.all(color: Colors.red.withAlpha(128)),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.small.copyWith(color: Colors.redAccent),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: theme.textTheme.small.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
