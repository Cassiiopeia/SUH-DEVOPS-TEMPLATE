#!/bin/bash

# ===================================================================
# Flutter 환경 검사 + Application ID 자동 감지 스크립트
# ===================================================================
# 1. Android SDK 환경 검사 (없으면 자동 설정)
# 2. keytool 명령어 확인
# 3. build.gradle.kts에서 applicationId 추출
#
# 사용법:
#   bash detect-application-id.sh PROJECT_PATH
#
# 출력:
#   JSON 형식으로 결과 출력
#   예: {"applicationId": "com.example.app", "env": "ok", "keytool": "ok"}
# ===================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_PATH="$1"

# 프로젝트 경로 확인
if [ -z "$PROJECT_PATH" ]; then
    echo '{"error": "프로젝트 경로를 입력하세요", "env": "error"}'
    exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
    echo '{"error": "프로젝트 경로가 존재하지 않습니다", "env": "error"}'
    exit 1
fi

# ===================================================================
# 1. Android SDK 환경 검사 및 자동 설정
# ===================================================================

ENV_STATUS="ok"
ENV_MESSAGE=""

# ANDROID_HOME 확인
if [ -z "$ANDROID_HOME" ]; then
    # 기본 경로에서 Android SDK 찾기
    if [ -d "$HOME/Library/Android/sdk" ]; then
        ANDROID_HOME="$HOME/Library/Android/sdk"
    elif [ -d "$HOME/Android/Sdk" ]; then
        ANDROID_HOME="$HOME/Android/Sdk"
    fi
fi

# ANDROID_HOME이 여전히 없으면 자동 설정 시도
if [ -z "$ANDROID_HOME" ] || [ ! -d "$ANDROID_HOME" ]; then
    # 가능한 경로 확인
    POSSIBLE_PATHS=(
        "$HOME/Library/Android/sdk"
        "$HOME/Android/Sdk"
        "/usr/local/share/android-sdk"
    )

    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ]; then
            ANDROID_HOME="$path"
            break
        fi
    done
fi

# ~/.zshrc에 ANDROID_HOME 추가 (없으면)
if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
    SHELL_RC=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    fi

    if [ -n "$SHELL_RC" ]; then
        # ANDROID_HOME이 설정되어 있는지 확인
        if ! grep -q "export ANDROID_HOME" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Android SDK (자동 추가됨 by playstore-wizard)" >> "$SHELL_RC"
            echo "export ANDROID_HOME=\"$ANDROID_HOME\"" >> "$SHELL_RC"
            echo "export PATH=\"\$PATH:\$ANDROID_HOME/platform-tools\"" >> "$SHELL_RC"
            echo "export PATH=\"\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin\"" >> "$SHELL_RC"
            ENV_MESSAGE="ANDROID_HOME을 $SHELL_RC에 자동 추가했습니다. 터미널을 다시 열거나 source $SHELL_RC 실행"
        fi
    fi

    # 현재 세션에도 적용
    export ANDROID_HOME="$ANDROID_HOME"
    export PATH="$PATH:$ANDROID_HOME/platform-tools"
    export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
else
    ENV_STATUS="warning"
    ENV_MESSAGE="Android SDK를 찾을 수 없습니다. Android Studio에서 SDK Manager를 열어 설치하세요."
fi

# ===================================================================
# 2. keytool 명령어 확인
# ===================================================================

KEYTOOL_STATUS="ok"

if ! command -v keytool &> /dev/null; then
    # Java가 설치되어 있는지 확인
    if ! command -v java &> /dev/null; then
        KEYTOOL_STATUS="error"
        ENV_STATUS="error"
        ENV_MESSAGE="Java가 설치되어 있지 않습니다. JDK를 설치하세요: brew install openjdk"
    else
        KEYTOOL_STATUS="warning"
    fi
fi

# ===================================================================
# 3. Application ID 추출
# ===================================================================

APPLICATION_ID=""
GRADLE_TYPE=""

# build.gradle.kts 우선 확인
if [ -f "$PROJECT_PATH/android/app/build.gradle.kts" ]; then
    GRADLE_FILE="$PROJECT_PATH/android/app/build.gradle.kts"
    GRADLE_TYPE="kts"
elif [ -f "$PROJECT_PATH/android/app/build.gradle" ]; then
    GRADLE_FILE="$PROJECT_PATH/android/app/build.gradle"
    GRADLE_TYPE="groovy"
else
    echo '{"error": "build.gradle 파일을 찾을 수 없습니다", "env": "error"}'
    exit 1
fi

# Kotlin DSL (build.gradle.kts)
if [[ "$GRADLE_TYPE" == "kts" ]]; then
    APPLICATION_ID=$(grep -E "applicationId\s*=" "$GRADLE_FILE" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
fi

# Groovy (build.gradle)
if [ -z "$APPLICATION_ID" ]; then
    APPLICATION_ID=$(grep -E "applicationId\s+" "$GRADLE_FILE" | grep -v "=" | head -1 | sed 's/.*"\([^"]*\)".*/\1/' | sed "s/.*'\([^']*\)'.*/\1/")
fi

# namespace에서 추출 시도
if [ -z "$APPLICATION_ID" ]; then
    APPLICATION_ID=$(grep -E "namespace\s*=" "$GRADLE_FILE" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
fi

if [ -z "$APPLICATION_ID" ]; then
    echo '{"error": "applicationId를 찾을 수 없습니다", "env": "error"}'
    exit 1
fi

# ===================================================================
# 4. 결과 출력 (JSON)
# ===================================================================

if [ -n "$ENV_MESSAGE" ]; then
    echo "{\"applicationId\": \"$APPLICATION_ID\", \"env\": \"$ENV_STATUS\", \"keytool\": \"$KEYTOOL_STATUS\", \"message\": \"$ENV_MESSAGE\", \"gradleType\": \"$GRADLE_TYPE\"}"
else
    echo "{\"applicationId\": \"$APPLICATION_ID\", \"env\": \"$ENV_STATUS\", \"keytool\": \"$KEYTOOL_STATUS\", \"gradleType\": \"$GRADLE_TYPE\"}"
fi
