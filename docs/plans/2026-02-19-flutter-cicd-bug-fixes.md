# Flutter CI/CD Fastlane Bundler 방식 전환 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 5개 Flutter 워크플로우의 Fastlane 설치 방식을 `gem install fastlane --force` → Bundler 방식(`bundle install`)으로 전환하여 gem 충돌 문제를 원천 차단

**Architecture:** 각 워크플로우의 Install Fastlane 스텝에서 `printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile && bundle install` 패턴으로 교체하고, 이후 모든 `fastlane ...` 호출을 `bundle exec fastlane ...`으로 변경. Android는 `android/` 디렉토리에, iOS는 `ios/` 디렉토리에 Gemfile을 생성.

**Tech Stack:** GitHub Actions YAML, Ruby Bundler, Fastlane

**이미 완료된 것:**
- iOS 빌드 완료 댓글 타이밍 수정 (#198) - line 570 이미 `✅ iOS 빌드 완료`
- `gem install fastlane --force` 적용 (#197) - 5개 파일 모두 적용됨

---

## Task 1: PROJECT-FLUTTER-ANDROID-TEST-APK.yaml 수정

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`

**Step 1: Install Fastlane 스텝을 Bundler 방식으로 교체**

파일: `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` (lines 446-451)

변경 전:
```yaml
      # Fastlane 설치
      - name: Install Fastlane
        run: |
          gem install fastlane --force
          echo "✅ Fastlane installed"
          fastlane --version
```

변경 후:
```yaml
      # Fastlane 설치 (Bundler 방식 - gem 충돌 방지)
      - name: Install Fastlane
        working-directory: android
        run: |
          printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile
          bundle install
          echo "✅ Fastlane installed (Bundler)"
          bundle exec fastlane --version
```

**Step 2: Build APK 스텝의 fastlane 호출을 bundle exec으로 변경**

파일: `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` (lines 463-476)

변경 전:
```yaml
          cd android
          fastlane build --verbose || flutter build apk --release
```

변경 후:
```yaml
          cd android
          bundle exec fastlane build --verbose || flutter build apk --release
```

**Step 3: 변경 확인**
```bash
grep -n "fastlane" .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml
```
예상: `bundle install`, `bundle exec fastlane` 확인, `gem install fastlane` 없음

---

## Task 2: PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml 수정

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`

**Step 1: Install Fastlane 스텝을 Bundler 방식으로 교체**

파일: `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` (lines 707-708)

변경 전:
```yaml
      - name: Install Fastlane
        run: gem install fastlane --force
```

변경 후:
```yaml
      - name: Install Fastlane
        working-directory: ios
        run: |
          printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile
          bundle install
          echo "✅ Fastlane installed (Bundler)"
```

**Step 2: Upload to TestFlight 스텝의 fastlane 호출을 bundle exec으로 변경**

파일: `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` (line 746)

변경 전:
```bash
          cd ios
          fastlane upload_testflight
```

변경 후:
```bash
          cd ios
          bundle exec fastlane upload_testflight
```

**Step 3: 변경 확인**
```bash
grep -n "fastlane" .github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml | grep -v "##\|#.*fastlane"
```

---

## Task 3: PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml 수정

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`

**Step 1: Install Fastlane 스텝을 Bundler 방식으로 교체**

파일: `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` (lines 371-372)

변경 전:
```yaml
      - name: Install Fastlane
        run: gem install fastlane --force
```

변경 후:
```yaml
      - name: Install Fastlane
        working-directory: ios
        run: |
          printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile
          bundle install
          echo "✅ Fastlane installed (Bundler)"
```

**Step 2: Upload to TestFlight 스텝의 fastlane 호출을 bundle exec으로 변경**

파일: `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` (line 412)

변경 전:
```bash
          cd ios
          fastlane upload_testflight
```

변경 후:
```bash
          cd ios
          bundle exec fastlane upload_testflight
```

---

## Task 4: PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml 수정

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`

**Step 1: Install Fastlane 스텝을 Bundler 방식으로 교체**

파일: `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` (lines 530-534)

변경 전:
```yaml
      - name: Install Fastlane
        run: |
          gem install fastlane --force
          echo "✅ Fastlane 설치 완료"
          fastlane --version
```

변경 후:
```yaml
      - name: Install Fastlane
        working-directory: android
        run: |
          printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile
          bundle install
          echo "✅ Fastlane 설치 완료 (Bundler)"
          bundle exec fastlane --version
```

**Step 2: fastlane deploy_internal 호출을 bundle exec으로 변경**

파일: `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` (lines 652-653)

변경 전:
```bash
          cd android
          fastlane deploy_internal
```

변경 후:
```bash
          cd android
          bundle exec fastlane deploy_internal
```

---

## Task 5: synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml 수정

**Files:**
- Modify: `.github/workflows/project-types/flutter/synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml`

**Step 1: Install Fastlane 스텝을 Bundler 방식으로 교체**

파일: `synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml` (lines 172-176)

변경 전:
```yaml
      # Fastlane 설치
      - name: Install Fastlane
        run: |
          gem install fastlane --force
          echo "Fastlane installed"
          fastlane --version
```

변경 후:
```yaml
      # Fastlane 설치 (Bundler 방식 - gem 충돌 방지)
      - name: Install Fastlane
        working-directory: android
        run: |
          printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile
          bundle install
          echo "Fastlane installed (Bundler)"
          bundle exec fastlane --version
```

**Step 2: Build APK with Fastlane 스텝의 fastlane 호출을 bundle exec으로 변경**

파일: `synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml` (lines 196-200)

변경 전:
```bash
          cd android
          fastlane build --verbose
```

변경 후:
```bash
          cd android
          bundle exec fastlane build --verbose
```

---

## Task 6: 전체 검증

**Step 1: gem install fastlane 잔여 여부 확인**
```bash
grep -rn "gem install fastlane" .github/workflows/project-types/flutter/
```
예상: 아무것도 없음

**Step 2: bundle exec fastlane 적용 여부 확인**
```bash
grep -rn "bundle exec fastlane" .github/workflows/project-types/flutter/
```
예상: 7개 이상 라인 출력

**Step 3: YAML 문법 검증**
```bash
python3 -c "
import yaml
files = [
    '.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml',
    '.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml',
    '.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml',
    '.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml',
    '.github/workflows/project-types/flutter/synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml',
]
for f in files:
    with open(f) as fp:
        yaml.safe_load(fp)
    print(f'✅ {f}')
print('모든 파일 YAML 유효')
"
```
예상: `✅` 5개 + `모든 파일 YAML 유효`
