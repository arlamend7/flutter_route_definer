import 'package:web/web.dart' as html;

/// Updates the browser tab's title when running on the web platform.
void updateBrowserTitle(String title) {
  html.document.title = title;
}
