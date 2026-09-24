import 'dart:collection';

import 'package:meta/meta.dart' show internal;
import 'package:route_definer/src/routing/route_definer.dart';
import 'package:route_definer/src/routing/route_state.dart';

/// A resolved, context-free snapshot of one router-managed page.
///
/// Collection arguments and metadata are copied recursively into read-only
/// views. Opaque application objects remain references: Dart cannot make an
/// arbitrary model immutable. [definition] is the original registration;
/// inspect [data] for a collection snapshot of its metadata.
class RouteSnapshot {
  @internal
  RouteSnapshot({
    required this.id,
    required RouteState state,
    required this.definition,
  })  : state = RouteState(state.uri,
            uriParams: state.uriParams,
            arguments: _snapshotValue(state.arguments)),
        data = definition?.data == null
            ? null
            : (_snapshotValue(definition!.data) as Map).cast<String, Object>();

  final String id;
  final RouteState state;

  /// Null for an unmatched location. This does not imply access was granted.
  final RouteDefiner<dynamic>? definition;
  final Map<String, Object>? data;
}

Object? _snapshotValue(Object? value) {
  final copies = HashMap<Object, Object>.identity();
  Object? copy(Object? value) {
    if (value == null) return null;
    if (copies.containsKey(value)) return copies[value];
    if (value is List) {
      final items = <Object?>[];
      final result = UnmodifiableListView(items);
      copies[value] = result;
      items.addAll(value.map(copy));
      return result;
    }
    if (value is Map) {
      final Map items = value.keys.every((key) => key is String)
          ? <String, Object?>{}
          : <Object?, Object?>{};
      final result = items is Map<String, Object?>
          ? UnmodifiableMapView<String, Object?>(items)
          : UnmodifiableMapView<Object?, Object?>(items);
      copies[value] = result;
      for (final entry in value.entries) {
        items[entry.key] = copy(entry.value);
      }
      return result;
    }
    if (value is Set) {
      final items = <Object?>{};
      final result = UnmodifiableSetView(items);
      copies[value] = result;
      items.addAll(value.map(copy));
      return result;
    }
    return value;
  }

  return copy(value);
}
