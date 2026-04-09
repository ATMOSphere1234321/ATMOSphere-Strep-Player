# CLAUDE.md - ATMOSphere StereoPlayer (Strep)

Flutter-based audio player for ATMOSphere firmware on Orange Pi 5 Max (RK3588). Provides stereo audio playback with a modern UI.

## Project Overview

- **Package**: `atmosphere.strep.app`
- **Language**: Dart (Flutter) + Kotlin (Android platform)
- **Build**: Flutter (`flutter build apk --release`) + Gradle KTS (Android)
- **SDK**: Flutter 3.9.0+, Dart 3.9.0+
- **Repo**: `git@github.com:ATMOSphere1234321/ATMOSphere-Strep-Player.git`
- **Parent repo path**: `device/rockchip/atmosphere/strep-player`

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `lib/` | Dart source (main.dart, models, providers, screens, services, theme, utils, widgets) |
| `android/` | Android platform project (Gradle KTS) |
| `assets/` | App assets |
| `test/` | Dart unit tests |

### ATMOSphere Integration

- Listed in `AUDIO_ONLY_PACKAGES` -- excluded from video routing to secondary display
- Uses Flutter audio plugins for playback
- Audio output routed through ES8388 HAL (headphone/speaker) and BT A2DP
- CPU2 audio isolation applies to audioserver serving this app

## MANDATORY DEVELOPMENT PRINCIPLES

1. **Solutions MUST NOT be error-prone** -- every fix must be robust, not introduce new failure modes
2. **No blocking operations inside synchronized blocks** -- Thread.sleep(), network calls, or long computations inside `synchronized` WILL cause deadlocks
3. **Always consider concurrent callers** -- multiple media sessions can be active simultaneously
4. **Test the fix, not just the symptom** -- verify the fix works AND does not break anything else

## MANDATORY API KEY & SECRETS CONSTRAINTS

1. **NEVER commit `.env` files** -- they contain API keys and credentials
2. **NEVER add API keys to source code** -- use environment variables or `.env` files only
3. **ALWAYS verify `.gitignore` protects `.env`** before committing

## MANDATORY COMMIT & PUSH CONSTRAINTS

1. **ONLY use the official commit script from the PARENT repo**: `bash scripts/commit_all.sh "message"`
2. **NEVER use `git add`, `git commit`, or `git push` directly** in this submodule
3. The parent script handles staging, committing, and pushing to ALL remotes

## MANDATORY SUBMODULE SYNC CONSTRAINTS

1. **ALWAYS fetch and pull latest from upstream** before pushing our committed changes
2. **Analyze all new features/APIs** from upstream and incorporate them properly
3. **Merge conflicts** must be resolved carefully -- never discard upstream changes blindly

## MANDATORY TAGGING CONSTRAINTS

1. **Tags are NEVER created before flashing and validating** on BOTH ATMOSphere devices
2. **Tags MUST be applied to ALL owned submodules** when tagging the main repo
3. **Tag naming**: `<major>.<minor>.<patch>-dev[-<sub-version>]`

## Project Context

- Part of ATMOSphere Android 15 firmware for Orange Pi 5 Max (RK3588)
- Parent repo at `/run/media/milosvasic/DATA4TB/Projects/Android_15/` handles build, flash, and test
- Build via parent: `bash scripts/build.sh --skip-pull --skip-tests --skip-ota`
- Tests via parent: `bash device/rockchip/rk3588/tests/pre_build_verification.sh`
- Flutter build produces APK that is then included as prebuilt in the AOSP system image
