import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Optional error view with pointer, keyboard and semantic retry actions.
///
/// Exception details are deliberately left to the application's error reporting.
class ErrorPage extends StatelessWidget {
  const ErrorPage({
    super.key,
    required this.onRetry,
    this.message = 'Unable to open this page',
    this.retryLabel = 'Retry',
  });
  final VoidCallback onRetry;
  final String message;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Semantics(liveRegion: true, child: Text(message)),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): onRetry,
              const SingleActivator(LogicalKeyboardKey.space): onRetry,
            },
            child: Focus(
              child: Semantics(
                button: true,
                label: retryLabel,
                excludeSemantics: true,
                onTap: onRetry,
                child: GestureDetector(
                  onTap: onRetry,
                  excludeFromSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(retryLabel),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}
