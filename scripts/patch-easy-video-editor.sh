#!/usr/bin/env bash
# Apply repository-maintained iOS fixes to the pub-cache copy of
# easy_video_editor.
#
# Why: easy_video_editor's iOS cropVideo computes the crop on naturalSize and
# ignores preferredTransform, so portrait videos get a black bar when cropped to
# a square. Version 0.1.6 also omits Foundation/Dispatch imports from its
# operation manager, which fails with the Swift compiler bundled in Xcode 26.3.
#
# This patches the cached package in place. Idempotent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CROP_PATCH="$ROOT/patches/easy_video_editor_ios_crop.patch"
CROP_REL="ios/easy_video_editor/Sources/easy_video_editor/utils/VideoUtils.swift"
IMPORTS_PATCH="$ROOT/patches/easy_video_editor_ios_imports.patch"
IMPORTS_REL="ios/easy_video_editor/Sources/easy_video_editor/utils/OperationManager.swift"
PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"

echo "[patch-evd] ROOT: $ROOT"
echo "[patch-evd] PUB_CACHE_DIR: $PUB_CACHE_DIR"

for patch_file in "$CROP_PATCH" "$IMPORTS_PATCH"; do
  [[ -f "$patch_file" ]] || { echo "[patch-evd] patch file not found: $patch_file"; exit 1; }
done

apply_fix() {
  pkg="$1"
  patch_file="$2"
  rel="$3"
  label="$4"
  target="$pkg/$rel"

  if [[ ! -f "$target" ]]; then
    # Some versions might have different structure (e.g. 0.1.3 vs 0.1.6)
    # If the file is not there, we just skip this specific fix for this package dir
    return
  fi

  # Check if already patched
  if [[ "$label" == *"Swift imports"* ]]; then
    if grep -q "import Dispatch" "$target"; then
      echo "[patch-evd] already patched ($label): $target"
      return
    fi
  fi

  # Reverse dry-run check
  if patch -R -p1 -l --dry-run -d "$pkg" < "$patch_file" >/dev/null 2>&1; then
    echo "[patch-evd] already patched ($label): $target"
    return
  fi

  echo "[patch-evd] applying $label to $target..."

  # Dry-run first. Use -l to ignore whitespace differences (common with line endings)
  if ! patch -p1 -l --dry-run -d "$pkg" < "$patch_file" >/dev/null 2>&1; then
    if [[ "$label" == *"Swift imports"* ]]; then
       echo "[patch-evd] patch -p1 failed for imports, attempting manual injection..."
       # Manual injection as fallback for imports
       # Add import Foundation and Dispatch if they are missing
       if ! grep -q "import Dispatch" "$target"; then
         # Prepend to the file safely
         { printf "import Foundation\nimport Dispatch\n\n"; cat "$target"; } > "$target.tmp" && mv "$target.tmp" "$target"
         echo "[patch-evd] manual injection successful for $target"
         return
       fi
    fi
    echo "[patch-evd] WARNING: $label patch does not apply cleanly to $pkg"
    return
  fi

  patch -p1 -l -d "$pkg" < "$patch_file"
  echo "[patch-evd] applied $label fix successfully"
}

# Find all easy_video_editor versions in the pub cache
candidates=()
# Look in all possible hosted directories (pub.dev, pub.dartlang.org, etc.)
for d in "$PUB_CACHE_DIR"/hosted/*/easy_video_editor-*; do
  if [[ -d "$d" ]]; then
    candidates+=("$d")
  fi
done

if [[ ${#candidates[@]} -eq 0 ]]; then
  echo "[patch-evd] ERROR: no easy_video_editor package found under $PUB_CACHE_DIR"
  echo "[patch-evd] Make sure 'flutter pub get' has been run."
  exit 1
fi

patched_count=0
seen=""
for pkg in "${candidates[@]}"; do
  case "$seen" in *"|$pkg|"*) continue ;; esac
  seen="$seen|$pkg|"

  echo "[patch-evd] processing: $pkg"
  apply_fix "$pkg" "$CROP_PATCH" "$CROP_REL" "iOS crop"
  apply_fix "$pkg" "$IMPORTS_PATCH" "$IMPORTS_REL" "Xcode 16 Swift imports"
  patched_count=$((patched_count + 1))
done

echo "[patch-evd] done. Processed $patched_count package(s)."
