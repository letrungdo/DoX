#!/usr/bin/env bash
# Apply repository-maintained iOS fixes to the pub-cache copy of
# easy_video_editor.
#
# Why: easy_video_editor's iOS cropVideo computes the crop on naturalSize and
# ignores preferredTransform, so portrait videos get a black bar when cropped to
# a square. Version 0.1.6 also omits Foundation/Dispatch imports from its
# operation manager, which fails with the Swift compiler bundled in Xcode 16.4.
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
CROP_PATCH="$ROOT/patches/easy_video_editor_ios_crop.patch"
CROP_REL="ios/easy_video_editor/Sources/easy_video_editor/utils/VideoUtils.swift"
CROP_MARKER="Work in DISPLAY space"
IMPORTS_PATCH="$ROOT/patches/easy_video_editor_ios_imports.patch"
IMPORTS_REL="ios/easy_video_editor/Sources/easy_video_editor/utils/OperationManager.swift"
IMPORTS_MARKER="import Dispatch"
PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"

for patch_file in "$CROP_PATCH" "$IMPORTS_PATCH"; do
  [[ -f "$patch_file" ]] || { echo "[patch-evd] patch file not found: $patch_file"; exit 1; }
done

apply_fix() {
  pkg="$1"
  patch_file="$2"
  rel="$3"
  marker="$4"
  label="$5"
  target="$pkg/$rel"

  [[ -f "$target" ]] || {
    echo "[patch-evd] ERROR: expected source file not found: $target"
    exit 1
  }

  if grep -q "$marker" "$target"; then
    echo "[patch-evd] already patched ($label): $target"
    return
  fi

  # Dry-run first so a context mismatch (version bump) fails loudly instead of
  # leaving a partially modified source file.
  if ! patch -p1 --dry-run -d "$pkg" < "$patch_file" >/dev/null 2>&1; then
    echo "[patch-evd] ERROR: $label patch does not apply cleanly to $pkg"
    echo "[patch-evd] easy_video_editor version likely changed — regenerate $patch_file"
    exit 1
  fi

  patch -p1 -d "$pkg" < "$patch_file"
  echo "[patch-evd] applied $label fix to $target"
}

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
  [[ -f "$pkg/$CROP_REL" ]] || continue

  apply_fix "$pkg" "$CROP_PATCH" "$CROP_REL" "$CROP_MARKER" "iOS crop"
  apply_fix "$pkg" "$IMPORTS_PATCH" "$IMPORTS_REL" "$IMPORTS_MARKER" "Xcode 16 Swift imports"
  patched_any=1
done

if [[ "$patched_any" -eq 0 ]]; then
  echo "[patch-evd] no easy_video_editor package found under $PUB_CACHE_DIR — run 'flutter pub get' first"
  exit 1
fi
