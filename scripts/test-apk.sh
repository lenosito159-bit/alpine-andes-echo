#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
zivlo_apk=${1:-build/app/outputs/flutter-apk/app-debug.apk}
zivlo_evidence=build/apk-smoke
mkdir -p "$zivlo_evidence"
capture_apk_evidence() {
  adb exec-out screencap -p > "$zivlo_evidence/screen.png" || true
  adb logcat -d > "$zivlo_evidence/logcat.txt" || true
}
trap capture_apk_evidence EXIT
adb install -r "$zivlo_apk"
adb shell svc wifi disable
adb shell svc data disable
adb logcat -c
adb shell am start -W -n com.example.zivlo/.MainActivity
zivlo_verified=0
for zivlo_attempt in $(seq 1 30); do
  rm -f "$zivlo_evidence/window.xml"
  adb shell uiautomator dump /sdcard/zivlo-window.xml >/dev/null 2>&1 || true
  adb pull /sdcard/zivlo-window.xml "$zivlo_evidence/window.xml" >/dev/null 2>&1 || true
  if python3 - "$zivlo_evidence/window.xml" <<'PY'
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
path = Path(sys.argv[1])
if not path.exists():
    sys.exit(1)
root = ET.parse(path).getroot()
text = ' '.join(n.get('text', '') + ' ' + n.get('content-desc', '') for n in root.iter())
sys.exit(0 if 'Tu próxima venta' in text and 'Mi bodega' in text else 1)
PY
  then
    if [ "$zivlo_verified" -eq 0 ]; then
      zivlo_verified=1
      adb shell am force-stop com.example.zivlo
      adb shell am start -W -n com.example.zivlo/.MainActivity
      continue
    fi
    echo '::notice::APK installed and opened offline on Android 10; POS screen verified and application relaunched.'
    exit 0
  fi
  sleep 2
done
echo '::error::The installed Android APK did not show the POS screen offline. See apk-smoke evidence.'
exit 1
