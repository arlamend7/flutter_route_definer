// Run: flutter test tool/benchmark_test.dart --reporter expanded
// Measurements are VM/JIT host microbenchmarks, not device frame budgets.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/default_pages.dart' as default_router;

void main() {
  test('matching latency and construction for representative tables', () {
    final results = <Map<String, Object>>[];
    for (final size in [10, 100, 1000]) {
      final watch = Stopwatch()..start();
      final router = RouteDefinerRouter(
        loadingBuilder: (_) => const default_router.LoadingPage(),
        deniedBuilder: (_, __) => const default_router.DeniedPage(),
        notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
        errorBuilder: (_, failure, retry) =>
            default_router.ErrorPage(onRetry: retry),
        routes: [
          for (var i = 0; i < size; i++)
            RouteDefiner<void>(
                path: i.isEven ? '/static/$i' : '/dynamic/$i/:id',
                builder: (_, __) => const SizedBox())
        ],
      );
      watch.stop();
      final initialization = watch.elapsedMicroseconds;
      final paths = {
        'first': '/static/0',
        'last': '/dynamic/${size - 1}/42',
        'miss': '/missing',
        'partial': '/dynamic/${size - 1}'
      };
      for (final entry in paths.entries) {
        for (var i = 0; i < 2000; i++) {
          router.match(entry.value);
        }
        final samples = <double>[];
        for (var sample = 0; sample < 31; sample++) {
          watch
            ..reset()
            ..start();
          for (var i = 0; i < 100; i++) {
            router.match(entry.value);
          }
          watch.stop();
          samples.add(watch.elapsedMicroseconds / 100);
        }
        samples.sort();
        results.add({
          'routes': size,
          'case': entry.key,
          'median_us': samples[15],
          'p95_us': samples[29],
          'initialization_us': initialization
        });
      }
      router.dispose();
    }
    stdout.writeln('ROUTE_DEFINER_BENCHMARK ${jsonEncode(results)}');
  });
}
