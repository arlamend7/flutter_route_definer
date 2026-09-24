import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';

/// Application-owned inspection UI. The library provides data, not a debug UI.
class NavigationInspector extends StatelessWidget {
  const NavigationInspector({super.key, required this.router});
  final RouteDefinerRouter router;

  @override
  Widget build(BuildContext context) => StreamBuilder<NavigationEvent>(
        stream: router.events,
        builder: (context, _) {
          final current = router.currentRoute;
          final stack = router.stack;
          final history = router.history;
          return SizedBox(
            height: 420,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Row(children: [
                const Expanded(child: Text('Navigation inspector')),
                IconButton(
                  tooltip: 'Close inspector',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ]),
              Text('Current route: ${current.state.uri}'),
              Text('Definition: ${current.definition?.path ?? 'unmatched'}'),
              Text('Path parameters: ${current.state.uriParams}'),
              Text('Query parameters: ${current.state.queryParamsAll}'),
              Text('Fragment: ${current.state.fragment}'),
              Text('Arguments: ${current.state.arguments}'),
              Text('Custom data: ${current.data}'),
              const Divider(),
              const Text('Stack (bottom to top)'),
              for (var index = 0; index < stack.length; index++)
                Text('${index + 1}. ${stack[index].state.uri}'),
              const Divider(),
              Text('Retained events: ${history.length}/${router.historyLimit}'),
              const Text('Recent events (newest first)'),
              for (final event in history.reversed.take(8))
                Text('${event.sequence}. ${event.action.name}: '
                    '${event.source?.state.path ?? '—'} → '
                    '${event.destination?.state.path ?? '—'}'
                    '${event.guardOutcome == null ? '' : ' (${event.guardOutcome!.name})'}'),
              const Text(
                  'This dialog is temporary UI; the managed page stays current.'),
            ]),
          );
        },
      );
}
