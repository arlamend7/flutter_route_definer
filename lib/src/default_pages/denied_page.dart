import 'package:flutter/widgets.dart';
import 'package:route_definer/src/default_pages/status_page.dart';

/// Optional view for a guard's deny decision.
class DeniedPage extends StatelessWidget {
  const DeniedPage({super.key, this.message = 'Access denied'});
  final String message;

  @override
  Widget build(BuildContext context) => StatusPage(message: message);
}
