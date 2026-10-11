#!/usr/bin/env python3
"""Generate disposable Android/iOS runners without committing SDK boilerplate."""
import argparse
import json
import pathlib
import plistlib
import shutil
import subprocess
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flutter', default='flutter')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
fixture = root / 'build' / 'native_fixture'
subprocess.run([args.flutter, 'create', '--platforms=android,ios', '--project-name=native_fixture',
                '--org=dev.routedefiner', '--no-pub', str(fixture)], check=True)
(fixture / 'pubspec.yaml').write_text(f'''name: native_fixture
publish_to: none
version: 1.0.0+1
environment:
  sdk: ">=3.6.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  route_definer_example:
    path: {json.dumps(str(root / 'example'))}
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
flutter:
  uses-material-design: true
''')
(fixture / 'lib/main.dart').write_text("import 'package:route_definer_example/native_check.dart' as fixture;\nvoid main() => fixture.main();\n")
shutil.rmtree(fixture / 'test', ignore_errors=True)
shutil.copytree(root / 'example/integration_test', fixture / 'integration_test', dirs_exist_ok=True)
manifest = fixture / 'android/app/src/main/AndroidManifest.xml'
android = '{http://schemas.android.com/apk/res/android}'
ET.register_namespace('android', android[1:-1])
tree = ET.parse(manifest)
activity = tree.find('./application/activity')
if not any(data.get(android + 'scheme') == 'routedefiner' for data in activity.findall('./intent-filter/data')):
    intent = ET.SubElement(activity, 'intent-filter')
    ET.SubElement(intent, 'action', {android + 'name': 'android.intent.action.VIEW'})
    for category in ['DEFAULT', 'BROWSABLE']:
        ET.SubElement(intent, 'category', {android + 'name': 'android.intent.category.' + category})
    ET.SubElement(intent, 'data', {android + 'scheme': 'routedefiner', android + 'host': 'example'})
tree.write(manifest, encoding='unicode')
plist = fixture / 'ios/Runner/Info.plist'
with plist.open('rb') as source:
    info = plistlib.load(source)
info['CFBundleURLTypes'] = [{'CFBundleURLSchemes': ['routedefiner'], 'CFBundleURLName': 'dev.routedefiner.fixture'}]
info['FlutterDeepLinkingEnabled'] = True
with plist.open('wb') as output:
    plistlib.dump(info, output)
subprocess.run([args.flutter, 'pub', 'get'], cwd=fixture, check=True)
print(f'Native fixture ready: {fixture}')
