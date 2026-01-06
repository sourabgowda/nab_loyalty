import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/theme/app_theme.dart';

class ErrorHandler {
  static String getUserFriendlyMessage(Object error) {
    String message = error.toString();

    if (error is FirebaseException) {
      if (error.code == 'network-request-failed') {
        return 'Network error. Please check your internet connection.';
      } else if (error.code == 'permission-denied') {
        return 'You do not have permission to perform this action.';
      } else if (error.code == 'not-found') {
        return 'The requested resource was not found.';
      } else if (error.message != null) {
        return error.message!;
      }
    } else if (error is PlatformException) {
      if (error.message != null) {
        return error.message!;
      }
    }

    // Clean up generic "Exception:" prefix
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    } else if (message.startsWith('Error: ')) {
      message = message.substring(7);
    }

    return message;
  }

  static void showError(BuildContext context, Object error) {
    // Check if context is valid/mounted
    if (!context.mounted) return;

    final message = getUserFriendlyMessage(error);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          },
        ),
      ),
    );
  }
}
