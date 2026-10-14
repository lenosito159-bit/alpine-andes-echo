#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/prepare-android.sh
if [[ -f pubspec.lock ]]; then
  flutter pub get --enforce-lockfile
else
  flutter pub get
fi
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --coverage
flutter build apk --debug
