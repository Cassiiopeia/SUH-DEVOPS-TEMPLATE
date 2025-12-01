#!/bin/bash
# =============================================================================
# Flutter Play Store CI/CD - Project Analyzer
# =============================================================================
# This script analyzes a Flutter project and outputs JSON with project info.
# Usage: bash init.sh [project_path]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get project path (default: current directory)
PROJECT_PATH="${1:-.}"

# Change to project directory
cd "$PROJECT_PATH" 2>/dev/null || {
    echo "Error: Cannot access directory $PROJECT_PATH" >&2
    exit 1
}

# Initialize result object
result='{}'

# Function to add to result
add_result() {
    local key=$1
    local value=$2
    result=$(echo "$result" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
}

add_result_bool() {
    local key=$1
    local value=$2
    if [ "$value" = "true" ]; then
        result=$(echo "$result" | jq --arg k "$key" '. + {($k): true}')
    else
        result=$(echo "$result" | jq --arg k "$key" '. + {($k): false}')
    fi
}

add_result_num() {
    local key=$1
    local value=$2
    result=$(echo "$result" | jq --arg k "$key" --argjson v "$value" '. + {($k): $v}')
}

# Check if this is a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo "Error: This is not a Flutter project (pubspec.yaml not found)" >&2
    exit 1
fi

# Check if jq is available, if not use simple parsing
if ! command -v jq &> /dev/null; then
    echo "Warning: jq not installed, using basic parsing" >&2

    # Basic parsing without jq
    APP_ID=""
    VERSION_NAME=""
    VERSION_CODE=""
    GRADLE_TYPE=""

    # Parse build.gradle.kts or build.gradle
    if [ -f "android/app/build.gradle.kts" ]; then
        GRADLE_TYPE="kts"
        APP_ID=$(grep -E "applicationId\s*=" android/app/build.gradle.kts | head -1 | sed 's/.*"\(.*\)".*/\1/')
    elif [ -f "android/app/build.gradle" ]; then
        GRADLE_TYPE="groovy"
        APP_ID=$(grep -E "applicationId\s" android/app/build.gradle | head -1 | sed 's/.*"\(.*\)".*/\1/')
    fi

    # Parse version.yml if exists
    if [ -f "version.yml" ]; then
        VERSION_NAME=$(grep "^version:" version.yml | head -1 | sed 's/version:\s*"\?\([^"]*\)"\?/\1/' | tr -d ' ')
        VERSION_CODE=$(grep "^version_code:" version.yml | head -1 | sed 's/version_code:\s*//' | tr -d ' ')
    fi

    # Fallback to pubspec.yaml
    if [ -z "$VERSION_NAME" ]; then
        VERSION_NAME=$(grep "^version:" pubspec.yaml | head -1 | sed 's/version:\s*//' | cut -d'+' -f1 | tr -d ' ')
    fi

    # Check for Firebase
    HAS_FIREBASE="false"
    if [ -f "android/app/google-services.json" ]; then
        HAS_FIREBASE="true"
    fi

    # Check for existing keystore
    HAS_KEYSTORE="false"
    if [ -d "android/app/keystore" ] && [ "$(ls -A android/app/keystore 2>/dev/null)" ]; then
        HAS_KEYSTORE="true"
    fi

    # Check for fastlane
    HAS_FASTLANE="false"
    if [ -f "android/fastlane/Fastfile" ] || [ -f "android/fastlane/Fastfile.playstore" ]; then
        HAS_FASTLANE="true"
    fi

    # Check for .env
    HAS_ENV="false"
    if [ -f ".env" ]; then
        HAS_ENV="true"
    fi

    # Output JSON manually
    cat << EOF
{
  "applicationId": "$APP_ID",
  "versionName": "$VERSION_NAME",
  "versionCode": ${VERSION_CODE:-1},
  "gradleType": "$GRADLE_TYPE",
  "hasFirebase": $HAS_FIREBASE,
  "hasKeystore": $HAS_KEYSTORE,
  "hasFastlane": $HAS_FASTLANE,
  "hasEnvFile": $HAS_ENV,
  "projectPath": "$(pwd)"
}
EOF
    exit 0
fi

# With jq available, do full parsing
# ============================================

# 1. Parse Application ID from build.gradle.kts or build.gradle
if [ -f "android/app/build.gradle.kts" ]; then
    add_result "gradleType" "kts"
    APP_ID=$(grep -E "applicationId\s*=" android/app/build.gradle.kts | head -1 | sed 's/.*"\(.*\)".*/\1/')
    add_result "applicationId" "$APP_ID"
elif [ -f "android/app/build.gradle" ]; then
    add_result "gradleType" "groovy"
    APP_ID=$(grep -E "applicationId\s" android/app/build.gradle | head -1 | sed 's/.*"\(.*\)".*/\1/')
    add_result "applicationId" "$APP_ID"
else
    add_result "gradleType" "unknown"
    add_result "applicationId" ""
fi

# 2. Parse version from version.yml or pubspec.yaml
if [ -f "version.yml" ]; then
    VERSION_NAME=$(grep "^version:" version.yml | head -1 | sed 's/version:\s*"\?\([^"]*\)"\?/\1/' | tr -d ' ')
    VERSION_CODE=$(grep "^version_code:" version.yml | head -1 | sed 's/version_code:\s*//' | tr -d ' ')
    add_result "versionName" "$VERSION_NAME"
    add_result_num "versionCode" "${VERSION_CODE:-1}"
else
    # Parse from pubspec.yaml
    VERSION_LINE=$(grep "^version:" pubspec.yaml | head -1)
    if [[ "$VERSION_LINE" =~ ([0-9]+\.[0-9]+\.[0-9]+)\+?([0-9]*) ]]; then
        add_result "versionName" "${BASH_REMATCH[1]}"
        add_result_num "versionCode" "${BASH_REMATCH[2]:-1}"
    else
        VERSION_NAME=$(echo "$VERSION_LINE" | sed 's/version:\s*//' | tr -d ' ')
        add_result "versionName" "$VERSION_NAME"
        add_result_num "versionCode" 1
    fi
fi

# 3. Check for Firebase (google-services.json)
if [ -f "android/app/google-services.json" ]; then
    add_result_bool "hasFirebase" "true"
else
    add_result_bool "hasFirebase" "false"
fi

# 4. Check for existing keystore
if [ -d "android/app/keystore" ] && [ "$(ls -A android/app/keystore 2>/dev/null)" ]; then
    add_result_bool "hasKeystore" "true"
    KEYSTORE_FILES=$(ls android/app/keystore/*.jks android/app/keystore/*.keystore 2>/dev/null | head -1)
    add_result "keystorePath" "$KEYSTORE_FILES"
else
    add_result_bool "hasKeystore" "false"
fi

# 5. Check for fastlane setup
if [ -f "android/fastlane/Fastfile" ] || [ -f "android/fastlane/Fastfile.playstore" ]; then
    add_result_bool "hasFastlane" "true"
else
    add_result_bool "hasFastlane" "false"
fi

# 6. Check for .env file
if [ -f ".env" ]; then
    add_result_bool "hasEnvFile" "true"
else
    add_result_bool "hasEnvFile" "false"
fi

# 7. Check for key.properties
if [ -f "android/key.properties" ]; then
    add_result_bool "hasKeyProperties" "true"
else
    add_result_bool "hasKeyProperties" "false"
fi

# 8. Check signing config in build.gradle
if [ -f "android/app/build.gradle.kts" ]; then
    if grep -q "signingConfigs" android/app/build.gradle.kts; then
        add_result_bool "hasSigningConfig" "true"
    else
        add_result_bool "hasSigningConfig" "false"
    fi
elif [ -f "android/app/build.gradle" ]; then
    if grep -q "signingConfigs" android/app/build.gradle; then
        add_result_bool "hasSigningConfig" "true"
    else
        add_result_bool "hasSigningConfig" "false"
    fi
fi

# 9. Get app name from pubspec.yaml
APP_NAME=$(grep "^name:" pubspec.yaml | head -1 | sed 's/name:\s*//' | tr -d ' ')
add_result "appName" "$APP_NAME"

# 10. Project path
add_result "projectPath" "$(pwd)"

# Output the final JSON
echo "$result" | jq .
