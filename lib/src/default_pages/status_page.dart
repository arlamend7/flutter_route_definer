import 'package:flutter/widgets.dart';

/// Shared presentation for the optional status pages.
class StatusPage extends StatelessWidget {
  const StatusPage({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Center(child: Text(message)),
      );
}
