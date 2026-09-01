import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_logger.dart';

/// Drop-in replacement for ever rendering a raw exception's `toString()`
/// in the UI (e.g. inside an `AsyncValue.when(error: ...)` branch). Logs
/// [error] via [logError] and shows a localized, human-readable message
/// instead — a distinct one for permission-denied failures, since those
/// are the most common Firestore error users hit and deserve a clearer
/// message than "something went wrong".
class FriendlyErrorState extends StatelessWidget {
  final String logContext;
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  const FriendlyErrorState({
    super.key,
    required this.logContext,
    required this.error,
    this.stackTrace,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    logError(logContext, error, stackTrace);
    final loc = AppLocalizations.of(context);
    final message = isPermissionDeniedError(error)
        ? loc.chatPermissionDeniedMessage
        : loc.chatLoadErrorMessage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.textMuted,
              size: 36,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(height: 1.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: Text(loc.actionRetry)),
            ],
          ],
        ),
      ),
    );
  }
}
