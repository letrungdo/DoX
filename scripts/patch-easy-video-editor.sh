#!/usr/bin/env bash
# Apply repository-maintained iOS fixes to the pub-cache copy of
# easy_video_editor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CROP_PATCH="$ROOT/patches/easy_video_editor_ios_crop.patch"
CROP_REL="ios/easy_video_editor/Sources/easy_video_editor/utils/VideoUtils.swift"
IMPORTS_PATCH="$ROOT/patches/easy_video_editor_ios_imports.patch"
IMPORTS_REL="ios/easy_video_editor/Sources/easy_video_editor/utils/OperationManager.swift"
IMPORTS_REL_2="ios/easy_video_editor/Sources/easy_video_editor/handler/CancelOperationCommand.swift"

echo "[patch-evd] ROOT: $ROOT"

apply_fix() {
  pkg="$1"
  patch_file="$2"
  rel="$3"
  label="$4"
  target="$pkg/$rel"

  if [[ ! -f "$target" ]]; then
    return
  fi

  # Check if already patched
  if grep -q "import Dispatch" "$target"; then
    echo "[patch-evd] already patched: $target"
    return
  fi

  echo "[patch-evd] patching: $target"
  # Manual injection for imports as it's the most critical
  if [[ "$rel" == *"OperationManager.swift" ]] || [[ "$rel" == *"CancelOperationCommand.swift" ]]; then
     { printf "import Foundation\nimport Dispatch\n\n"; cat "$target"; } > "$target.tmp" && mv "$target.tmp" "$target"
     echo "[patch-evd] manual injection successful: $target"
     return
  fi

  # Fallback to patch command for others (like crop fix)
  patch -p1 -l -d "$pkg" < "$patch_file" || echo "[patch-evd] Warning: patch failed for $label"
}

# Find easy_video_editor in all possible pub cache locations
candidates=()
search_paths=(
  "${PUB_CACHE:-$HOME/.pub-cache}"
  "$HOME/.pub-cache"
)

# Safely add flutter sdk path if available
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_SDK_PATH=$(flutter sdk-path 2>/dev/null || echo "")
  if [[ -n "$FLUTTER_SDK_PATH" ]]; then
    search_paths+=("$FLUTTER_SDK_PATH/.pub-cache")
  fi
fi

for base in "${search_paths[@]}"; do
  [[ -d "$base" ]] || continue
  for d in "$base"/hosted/*/easy_video_editor-*; do
    [[ -d "$d" ]] && candidates+=("$d")
  done
done

if [[ ${#candidates[@]} -eq 0 ]]; then
  echo "[patch-evd] ERROR: easy_video_editor not found in cache. Run 'flutter pub get' first."
  exit 1
fi

seen=""
for pkg in "${candidates[@]}"; do
  case "$seen" in *"|$pkg|"*) continue ;; esac
  seen="$seen|$pkg|"
  echo "[patch-evd] processing package: $pkg"
  apply_fix "$pkg" "$CROP_PATCH" "$CROP_REL" "iOS crop"
  apply_fix "$pkg" "$IMPORTS_PATCH" "$IMPORTS_REL" "Swift imports (1)"
  apply_fix "$pkg" "$IMPORTS_PATCH" "$IMPORTS_REL_2" "Swift imports (2)"
done
echo "[patch-evd] done."
