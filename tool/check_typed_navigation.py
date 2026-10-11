#!/usr/bin/env python3
"""Check compile-time inference and rejection of incompatible route results."""
import argparse
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dart', default='dart')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
source = """import 'package:route_definer/route_definer.dart';
Future<RESULT?> navigate(RouteDefinerRouter router, RouteDefiner<int> route) {
  return router.pushRoute(route);
}
"""
with tempfile.TemporaryDirectory(prefix='typed_api_', dir=root / 'test') as directory:
    fixture = pathlib.Path(directory) / 'inference.dart'
    for result_type in ['int', 'String']:
        fixture.write_text(source.replace('RESULT', result_type))
        result = subprocess.run([args.dart, 'analyze', '--format=machine', str(fixture)],
                                cwd=root, text=True, capture_output=True)
        errors = [line for line in result.stdout.splitlines() if line.startswith('ERROR|')]
        if result_type == 'int':
            if result.returncode != 0:
                raise SystemExit(result.stdout + result.stderr)
        elif result.returncode == 0 or len(errors) != 1 or not any(
            code in errors[0] for code in ['ARGUMENT_TYPE_NOT_ASSIGNABLE', 'RETURN_OF_INVALID_TYPE']
        ):
            raise SystemExit('Expected exactly one type mismatch:\n' + result.stdout + result.stderr)
print('Typed navigation: int inferred; incompatible String result rejected.')
