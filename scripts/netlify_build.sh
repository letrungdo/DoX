#!/usr/bin/env bash
set -euo pipefail

# Netlify build script for Flutter web.
# Flutter SDK version is read from pubspec.yaml (environment: flutter: "x.y.z")
# and the SDK is cached in Netlify's persistent cache dir between builds.

FLUTTER_VERSION="$(sed -n -E 's/^[[:space:]]*flutter:[[:space:]]*"?([0-9]+\.[0-9]+\.[0-9]+)"?[[:space:]]*$/\1/p' pubspec.yaml | head -1)"

if [ -z "$FLUTTER_VERSION" ]; then
  echo "ERROR: could not read flutter version from pubspec.yaml (environment.flutter)" >&2
  exit 1
fi

echo "Flutter version from pubspec.yaml: $FLUTTER_VERSION"

CACHE_DIR="${NETLIFY_BUILD_BASE:-/opt/build}/cache"
FLUTTER_ROOT="$CACHE_DIR/flutter-$FLUTTER_VERSION"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION into $FLUTTER_ROOT"
  rm -rf "$FLUTTER_ROOT"
  mkdir -p "$CACHE_DIR"
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
else
  echo "Reusing cached Flutter $FLUTTER_VERSION"
fi

export FLUTTER_ROOT
export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$PATH"
export PUB_CACHE="$CACHE_DIR/.pub-cache"

git config --global --add safe.directory "$FLUTTER_ROOT"

flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true

mkdir -p envs
{
  printf 'FLAVOR="%s"\n' "${FLAVOR:-}"
  printf 'ML_API_KEY="%s"\n' "${ML_API_KEY:-}"
  printf 'ML_API_URL="%s"\n' "${ML_API_URL:-}"
  printf 'ML_BUNDLE_ID="%s"\n' "${ML_BUNDLE_ID:-}"
  printf 'ML_STORAGE_URL="%s"\n' "${ML_STORAGE_URL:-}"
  printf 'FIREBASE_API_KEY_IOS="%s"\n' "${FIREBASE_API_KEY_IOS:-}"
  printf 'FIREBASE_API_KEY_ANDROID="%s"\n' "${FIREBASE_API_KEY_ANDROID:-}"
  printf 'FIREBASE_API_KEY_WEB="%s"\n' "${FIREBASE_API_KEY_WEB:-}"
  printf 'MARKET_API_URL="%s"\n' "${MARKET_API_URL:-}"
  printf 'MARKET_WS_URL="%s"\n' "${MARKET_WS_URL:-}"
  printf 'SUPABASE_URL="%s"\n' "${SUPABASE_URL:-}"
  printf 'SUPABASE_KEY="%s"\n' "${SUPABASE_KEY:-}"
  printf 'ELECTRIC_API_URL="%s"\n' "${ELECTRIC_API_URL:-}"
} > envs/dart-define.env

flutter pub get
flutter build web --release --dart-define-from-file envs/dart-define.env
