import 'package:flutter/widgets.dart';
import 'package:route_definer/src/default_pages/status_page.dart';

/// Optional view for a location without a matching definition.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.message = 'Page not found'});
  final String message;

  @override
  Widget build(BuildContext context) => StatusPage(message: message);
}
