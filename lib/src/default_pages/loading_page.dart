import 'package:flutter/widgets.dart';
import 'package:route_definer/src/default_pages/status_page.dart';

/// Optional loading view with a customizable, accessible message.
class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key, this.message = 'Loading…'});
  final String message;

  @override
  Widget build(BuildContext context) => StatusPage(message: message);
}
