#!/bin/bash

# Script to restore environment configuration files
# Usage: ./scripts/restore-env-configs.sh [env]
# Default environment is 'dev'

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔄 Restoring configuration files for environment: $ENV"

# Check if environment directory exists
if [ ! -d "$PROJECT_ROOT/envs/$ENV" ]; then
    echo -e "${RED}❌ Environment directory not found: envs/$ENV${NC}"
    exit 1
fi

# Android google-services.json
ANDROID_SOURCE="$PROJECT_ROOT/envs/$ENV/google-services.json"
ANDROID_DEST="$PROJECT_ROOT/android/app/google-services.json"

if [ -f "$ANDROID_SOURCE" ]; then
    cp "$ANDROID_SOURCE" "$ANDROID_DEST"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Restored: android/app/google-services.json${NC}"
    else
        echo -e "${RED}❌ Failed to restore: android/app/google-services.json${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Source file not found: $ANDROID_SOURCE${NC}"
fi

# iOS GoogleService-Info.plist
IOS_SOURCE="$PROJECT_ROOT/envs/$ENV/GoogleService-Info.plist"
IOS_DEST="$PROJECT_ROOT/ios/Runner/GoogleService-Info.plist"

if [ -f "$IOS_SOURCE" ]; then
    cp "$IOS_SOURCE" "$IOS_DEST"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Restored: ios/Runner/GoogleService-Info.plist${NC}"
    else
        echo -e "${RED}❌ Failed to restore: ios/Runner/GoogleService-Info.plist${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Source file not found: $IOS_SOURCE${NC}"
fi

echo -e "${GREEN}✨ Configuration files restored successfully for environment: $ENV${NC}"
