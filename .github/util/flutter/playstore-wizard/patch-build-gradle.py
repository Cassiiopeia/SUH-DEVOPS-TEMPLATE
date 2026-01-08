#!/usr/bin/env python3
"""
build.gradle.kts 자동 패치 스크립트
- key.properties 로드 코드 추가
- signingConfigs 블록 추가/업데이트
- buildTypes.release에 signingConfig 설정
"""

import re
import sys
import os
from pathlib import Path

def patch_build_gradle(gradle_file_path):
    """build.gradle.kts 파일을 자동으로 패치합니다."""

    # 1. 파일 읽기
    try:
        with open(gradle_file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"❌ 파일을 찾을 수 없습니다: {gradle_file_path}")
        return False
    except Exception as e:
        print(f"❌ 파일 읽기 오류: {e}")
        return False

    # 백업 생성
    backup_path = f"{gradle_file_path}.bak"
    try:
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ 백업 생성: {backup_path}")
    except Exception as e:
        print(f"⚠️  백업 생성 실패 (계속 진행): {e}")

    original_content = content

    # 2. key.properties 로드 코드 추가 (없는 경우)
    if 'keystorePropertiesFile' not in content:
        key_properties_code = '''
// Load key.properties file
import java.util.Properties
import java.io.FileInputStream
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
'''
        # plugins { ... } 다음에 추가
        pattern = r'(plugins\s*\{[^}]*\})'
        replacement = r'\1\n' + key_properties_code
        content = re.sub(pattern, replacement, content, count=1, flags=re.DOTALL)
        print("✅ key.properties 로드 코드 추가")
    else:
        print("ℹ️  key.properties 로드 코드 이미 존재")

    # 3. signingConfigs 블록 추가/업데이트
    if 'signingConfigs {' not in content and 'signingConfigs{' not in content:
        # signingConfigs 블록 추가
        signing_configs_code = '''
    // Signing Configurations
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }
'''
        # android { 다음에 추가
        pattern = r'(android\s*\{)'
        replacement = r'\1\n' + signing_configs_code
        content = re.sub(pattern, replacement, content, count=1)
        print("✅ signingConfigs 블록 추가")
    else:
        print("ℹ️  signingConfigs 블록 이미 존재")
        # 기존 storeFile 경로 수정 (file(it) → rootProject.file(it))
        if 'storeFile = keystoreProperties["storeFile"]?.let { file(it) }' in content:
            content = content.replace(
                'storeFile = keystoreProperties["storeFile"]?.let { file(it) }',
                'storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }'
            )
            print("✅ 기존 storeFile 경로 수정 (file(it) → rootProject.file(it))")

    # 4. buildTypes.release에 signingConfig 설정
    # 기존 debug signingConfig 제거
    content = re.sub(
        r'\s*signingConfig\s*=\s*signingConfigs\.getByName\(["\']debug["\']\)',
        '',
        content
    )

    # release { } 블록에 signingConfig 추가 (없는 경우)
    if 'signingConfig = signingConfigs.getByName("release")' not in content and \
       "signingConfig = signingConfigs.getByName('release')" not in content:
        # release { 다음에 추가 (중복 방지)
        # buildTypes 블록 내부의 release 블록 찾기
        pattern = r'(buildTypes\s*\{[^}]*release\s*\{)'
        if re.search(pattern, content, re.DOTALL):
            replacement = r'\1\n            signingConfig = signingConfigs.getByName("release")'
            content = re.sub(pattern, replacement, content, count=1, flags=re.DOTALL)
            print("✅ release buildType에 signingConfig 추가")
        else:
            print("⚠️  release buildType 블록을 찾을 수 없습니다")
    else:
        print("ℹ️  release buildType에 signingConfig 이미 존재")

    # 5. flutter.source 설정 추가/수정
    if 'flutter {' in content or 'flutter{' in content:
        # source = "../.." 확인
        if not re.search(r'flutter\s*\{[^}]*source\s*=\s*"\.\.\/\.\."', content, re.DOTALL):
            # source = "." → "../.." 변경
            if re.search(r'flutter\s*\{[^}]*source\s*=\s*"\."', content, re.DOTALL):
                content = re.sub(
                    r'(flutter\s*\{[^}]*source\s*=\s*)"\."',
                    r'\1"../.."',
                    content,
                    count=1,
                    flags=re.DOTALL
                )
                print("✅ flutter.source updated to '../..' (project root)")
            # flutter 블록은 있지만 source가 없는 경우
            elif re.search(r'flutter\s*\{', content):
                content = re.sub(
                    r'(flutter\s*\{)',
                    r'\1\n    source = "../.."',
                    content,
                    count=1
                )
                print("✅ flutter.source added as '../..' (project root)")
        else:
            print("ℹ️  flutter.source already set to '../..'")
    else:
        print("ℹ️  flutter 블록이 없습니다 (추가 필요 시 수동으로 추가하세요)")

    # 6. 파일 저장 (변경사항이 있는 경우에만)
    if content != original_content:
        try:
            with open(gradle_file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print("✅ build.gradle.kts 패치 완료!")
            return True
        except Exception as e:
            print(f"❌ 파일 저장 오류: {e}")
            # 백업에서 복원 시도
            if os.path.exists(backup_path):
                try:
                    with open(backup_path, 'r', encoding='utf-8') as f:
                        original = f.read()
                    with open(gradle_file_path, 'w', encoding='utf-8') as f:
                        f.write(original)
                    print("✅ 백업에서 복원 완료")
                except:
                    pass
            return False
    else:
        print("ℹ️  변경사항 없음 (이미 설정되어 있습니다)")
        return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("❌ 사용법: python3 patch-build-gradle.py <gradle_file_path>")
        sys.exit(1)

    gradle_file = sys.argv[1]

    if not os.path.exists(gradle_file):
        print(f"❌ 파일을 찾을 수 없습니다: {gradle_file}")
        sys.exit(1)

    try:
        success = patch_build_gradle(gradle_file)
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
