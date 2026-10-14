#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Instala Flutter 3.29.3 y añade su directorio bin al PATH.' >&2
  exit 1
fi
if [[ ! -d android ]]; then
  zivlo_android_tmp=$(mktemp -d)
  trap 'rm -rf "$zivlo_android_tmp"' EXIT
  # Generate only in our temporary directory, preserving all application files.
  # Keep the original application's package ID for compatible upgrades.
  flutter create --platforms=android --project-name=zivlo --org=com.example --no-pub "$zivlo_android_tmp/generated"
  cp -R "$zivlo_android_tmp/generated/android" android
elif [[ ! -f android/build.gradle && ! -f android/build.gradle.kts ]]; then
  echo 'La carpeta android existente está incompleta. Se conservó sin sobrescribirla.' >&2
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
path = Path('android/app/src/main/AndroidManifest.xml')
android = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', android)
root = ET.fromstring(path.read_text())
if not any(e.get(f'{{{android}}}name') == 'android.permission.CAMERA' for e in root.findall('uses-permission')):
    ET.SubElement(root, 'uses-permission', {f'{{{android}}}name': 'android.permission.CAMERA'})
if not any(e.get(f'{{{android}}}name') == 'android.hardware.camera' for e in root.findall('uses-feature')):
    ET.SubElement(root, 'uses-feature', {f'{{{android}}}name': 'android.hardware.camera', f'{{{android}}}required': 'false'})
application = root.find('application')
if application is not None:
    application.set(f'{{{android}}}label', 'Zivlo Perú')
    application.set(f'{{{android}}}allowBackup', 'false')
    application.set(f'{{{android}}}usesCleartextTraffic', 'false')
ET.indent(root)
path.write_text(ET.tostring(root, encoding='unicode') + '\n')
PY
