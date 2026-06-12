#!/usr/bin/env bash
# Apply the iOS square-crop fix to the pub-cache copy of easy_video_editor.
#
# Why: easy_video_editor's iOS cropVideo computes the crop on naturalSize and
# ignores preferredTransform, so portrait videos get a black bar when cropped to
# a square. The fix lives in patches/easy_video_editor_ios_crop.patch.
#
# This patches the cached package in place (the file CocoaPods symlinks into the
# build), so there is no need to vendor the whole package. Idempotent: re-running
# is a no-op once applied. Wired into ios/Podfile post_install to run on each
# `pod install`; the patch persists in the cache across builds afterwards.
#
# Uses only grep/awk/patch (no python) so it works in the minimal PATH that
# CocoaPods' post_install runs under.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$ROOT/patches/easy_video_editor_ios_crop.patch"
REL="ios/easy_video_editor/Sources/easy_video_editor/utils/VideoUtils.swift"
MARKER="Work in DISPLAY space"
PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"

[[ -f "$PATCH" ]] || { echo "[patch-evd] patch file not found: $PATCH"; exit 1; }

# Candidate package dirs: the exact version from pubspec.lock, else any cached version.
candidates=()
if [[ -f "$ROOT/pubspec.lock" ]]; then
  ver="$(awk '/^  easy_video_editor:/{f=1} f&&/^[[:space:]]+version:/{gsub(/[" ]/,"",$2); print $2; exit}' "$ROOT/pubspec.lock")"
  [[ -n "$ver" ]] && candidates+=("$PUB_CACHE_DIR/hosted/pub.dev/easy_video_editor-$ver")
fi
for d in "$PUB_CACHE_DIR"/hosted/pub.dev/easy_video_editor-*; do
  [[ -d "$d" ]] && candidates+=("$d")
done

patched_any=0
seen=""
for pkg in "${candidates[@]}"; do
  case "$seen" in *"|$pkg|"*) continue ;; esac  # skip duplicates
  seen="$seen|$pkg|"
  target="$pkg/$REL"
  [[ -f "$target" ]] || continue

  if grep -q "$MARKER" "$target"; then
    echo "[patch-evd] already patched: $target"
    patched_any=1
    continue
  fi

  # Dry-run first so a context mismatch (version bump) fails loudly instead of
  # leaving a half-applied file.
  if ! patch -p1 --dry-run -d "$pkg" < "$PATCH" >/dev/null 2>&1; then
    echo "[patch-evd] ERROR: patch does not apply cleanly to $pkg"
    echo "[patch-evd] easy_video_editor version likely changed — regenerate patches/easy_video_editor_ios_crop.patch"
    exit 1
  fi
  patch -p1 -d "$pkg" < "$PATCH"
  echo "[patch-evd] applied iOS crop fix to $target"
  patched_any=1
done

if [[ "$patched_any" -eq 0 ]]; then
  echo "[patch-evd] no easy_video_editor package found under $PUB_CACHE_DIR — run 'flutter pub get' first"
  exit 1
fi
