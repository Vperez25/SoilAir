#!/bin/bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk apks/
echo "✓ APK listo en apks/"
