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

---

## MANDATORY: ATMOSphere Constitution compliance (appended 2026-04-19 — ATMOSphere 1.1.3-dev-0.0.6)

Every change in this submodule MUST comply with the canonical
Constitution at `docs/guides/ATMOSPHERE_CONSTITUTION.md` in the parent
repo. In summary:

1. **Test coverage for every change** — pre-build gate (CM-MC*),
   post-build gate, on-device test, and a mutation entry in
   `scripts/testing/meta_test_false_positive_proof.sh` proving the
   gate catches regressions.
2. **Device validation before any tag** — both D1 and D2 flashed and
   green on every relevant suite.
3. **Commit + push via `bash scripts/commit_all.sh "…"` from the
   parent repo root.** Submodule source changes are committed in the
   submodule itself first, pushed to every remote of that submodule,
   and then the parent's `commit_all.sh` captures the updated
   pointer.
4. **Tags cascade.** Every version tag on the main repo is mirrored
   on this submodule at its current HEAD, across every remote this
   submodule publishes to. Use
   `scripts/testing/release_tag.sh <tag>` from the parent repo.
5. **Changelog discipline.** `docs/changelogs/<tag>.{md,html,json,txt}`
   on the parent repo documents every release; exported via
   `scripts/testing/export_changelog.sh`.
6. **No false-success results.** Tests that are always-PASS are
   immediately rewritten. Meta-test mutations catch bluff gates.
7. **Flock.** `commit_all.sh` and `push_all.sh` are serialised via
   `.git/.commit_all.lock` / `.git/.push_all.lock`. Never bypass.

Non-compliance is a blocker regardless of context.
