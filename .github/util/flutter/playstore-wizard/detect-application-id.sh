#!/bin/bash

# ===================================================================
# Flutter Application ID 자동 감지 스크립트
# ===================================================================
# build.gradle.kts 또는 build.gradle에서 applicationId를 자동으로 읽어옵니다.
#
# 사용법:
#   ./detect-application-id.sh PROJECT_PATH
#
# 출력:
#   JSON 형식으로 applicationId를 출력합니다.
#   예: {"applicationId": "com.example.app"}
# ===================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 프로젝트 경로 확인
PROJECT_PATH="$1"

if [ -z "$PROJECT_PATH" ]; then
    echo "사용법: $0 PROJECT_PATH" >&2
    exit 1
fi

# 경로 정규화
if [ ! -d "$PROJECT_PATH" ]; then
    echo "오류: 프로젝트 경로가 존재하지 않습니다: $PROJECT_PATH" >&2
    exit 1
fi

# build.gradle.kts 우선 확인
GRADLE_FILE=""
if [ -f "$PROJECT_PATH/android/app/build.gradle.kts" ]; then
    GRADLE_FILE="$PROJECT_PATH/android/app/build.gradle.kts"
elif [ -f "$PROJECT_PATH/android/app/build.gradle" ]; then
    GRADLE_FILE="$PROJECT_PATH/android/app/build.gradle"
else
    echo "오류: build.gradle.kts 또는 build.gradle 파일을 찾을 수 없습니다." >&2
    exit 1
fi

# applicationId 추출
APPLICATION_ID=""

# Kotlin DSL (build.gradle.kts) 형식: applicationId = "com.example.app"
if [[ "$GRADLE_FILE" == *.kts ]]; then
    # applicationId = "..." 형식 정확히 매칭
    APPLICATION_ID=$(grep -E "applicationId\s*=" "$GRADLE_FILE" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
fi

# Groovy (build.gradle) 형식: applicationId "com.example.app"
if [ -z "$APPLICATION_ID" ]; then
    # applicationId "..." 형식 정확히 매칭 (공백만)
    APPLICATION_ID=$(grep -E "applicationId\s+" "$GRADLE_FILE" | grep -v "=" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
fi

# namespace에서 추출 시도 (Kotlin DSL) - applicationId가 없을 때만
if [ -z "$APPLICATION_ID" ]; then
    NAMESPACE=$(grep -E "namespace\s*=" "$GRADLE_FILE" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
    if [ -n "$NAMESPACE" ]; then
        APPLICATION_ID="$NAMESPACE"
    fi
fi

# 결과 출력
if [ -z "$APPLICATION_ID" ]; then
    echo "오류: applicationId를 찾을 수 없습니다." >&2
    exit 1
fi

# JSON 형식으로 출력
echo "{\"applicationId\": \"$APPLICATION_ID\"}"
