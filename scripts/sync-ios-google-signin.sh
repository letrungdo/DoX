#!/bin/bash

# Syncs Google Sign-In config from GoogleService-Info.plist into Info.plist.
# Sets GIDClientID and registers the REVERSED_CLIENT_ID URL scheme,
# which google_sign_in requires on iOS.
# Usage: ./scripts/sync-ios-google-signin.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GOOGLE_PLIST="$PROJECT_ROOT/ios/Runner/GoogleService-Info.plist"
INFO_PLIST="$PROJECT_ROOT/ios/Runner/Info.plist"
PB="/usr/libexec/PlistBuddy"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

CLIENT_ID=$("$PB" -c "Print :CLIENT_ID" "$GOOGLE_PLIST" 2>/dev/null)
REVERSED_CLIENT_ID=$("$PB" -c "Print :REVERSED_CLIENT_ID" "$GOOGLE_PLIST" 2>/dev/null)

if [ -z "$CLIENT_ID" ] || [ -z "$REVERSED_CLIENT_ID" ]; then
    echo -e "${RED}❌ CLIENT_ID / REVERSED_CLIENT_ID not found in ios/Runner/GoogleService-Info.plist${NC}"
    echo "   Create an iOS OAuth client first, then re-download the plist:"
    echo "   1. https://console.cloud.google.com/apis/credentials?project=do-appx"
    echo "      → Create Credentials → OAuth client ID → iOS → bundle ID: vn.dox.app"
    echo "   2. Firebase console → Project settings → iOS app → download GoogleService-Info.plist"
    echo "      → save to envs/dev/ and run ./scripts/restore-env-configs.sh"
    exit 1
fi

if "$PB" -c "Print :GIDClientID" "$INFO_PLIST" &>/dev/null; then
    "$PB" -c "Set :GIDClientID $CLIENT_ID" "$INFO_PLIST"
else
    "$PB" -c "Add :GIDClientID string $CLIENT_ID" "$INFO_PLIST"
fi

# Register the reversed client ID as a URL scheme (idempotent)
if ! grep -q "$REVERSED_CLIENT_ID" "$INFO_PLIST"; then
    if ! "$PB" -c "Print :CFBundleURLTypes" "$INFO_PLIST" &>/dev/null; then
        "$PB" -c "Add :CFBundleURLTypes array" "$INFO_PLIST"
    fi
    IDX=$("$PB" -c "Print :CFBundleURLTypes" "$INFO_PLIST" | grep -c "Dict")
    "$PB" -c "Add :CFBundleURLTypes:$IDX dict" "$INFO_PLIST"
    "$PB" -c "Add :CFBundleURLTypes:$IDX:CFBundleTypeRole string Editor" "$INFO_PLIST"
    "$PB" -c "Add :CFBundleURLTypes:$IDX:CFBundleURLSchemes array" "$INFO_PLIST"
    "$PB" -c "Add :CFBundleURLTypes:$IDX:CFBundleURLSchemes:0 string $REVERSED_CLIENT_ID" "$INFO_PLIST"
fi

echo -e "${GREEN}✅ Info.plist updated: GIDClientID + URL scheme ($REVERSED_CLIENT_ID)${NC}"
