import 'package:flutter/material.dart';

SnackBar _buildSnackBar(
  BuildContext context, {
  required String message,
  Color? backgroundColor,
  VoidCallback? onRetry,
}) {
  return SnackBar(
    content: Text(message),
    backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.error,
    action: onRetry != null
        ? SnackBarAction(
            label: 'Retry',
            textColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: onRetry,
          )
        : null,
    behavior: SnackBarBehavior.floating,
  );
}

void showErrorSnackBar(
  BuildContext context,
  String message, {
  VoidCallback? onRetry,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    _buildSnackBar(
      context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.error,
      onRetry: onRetry,
    ),
  );
}

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    _buildSnackBar(
      context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.primary,
    ),
  );
}
