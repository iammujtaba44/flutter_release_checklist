# flutter_release_checklist

A pluggable Dart CLI that runs a pre-release security and quality checklist on
a Flutter project. Use it locally before submitting a build to a store, or in
CI to gate releases.

It is **pure Dart** — it does not depend on Flutter at runtime. The `flutter`
binary is only invoked by checks that need it (`analyze`, `test_coverage`),
and those checks skip gracefully if Flutter is not on `PATH`.

---

## What it does

Runs ten independent checks, prints a colorised pass/warn/fail summary, and
exits non-zero if any check fails. Designed so each check is small, scoped,
and independently testable.

| #   | Check               | Looks at                                                                        | On fail                                                                 |
| --- | ------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| 1   | `android_manifest`  | `android/app/src/main/AndroidManifest.xml`                                      | `android:debuggable="true"` is present                                  |
| 2   | `ios_plist`         | `ios/Runner/Info.plist`                                                         | `NSAllowsArbitraryLoads = true`; warns on wildcard `NSExceptionDomains` |
| 3   | `hardcoded_secrets` | `lib/**.dart`                                                                   | matches a built-in or user-supplied regex (warning, not failure)        |
| 4   | `proguard`          | `android/app/proguard-rules.pro`, `android/app/build.gradle[.kts]`              | rules file missing, or `minifyEnabled true` not set on release          |
| 5   | `debug_mode`        | `lib/**.dart`                                                                   | `debugPrint(` (fail), `print(` (warn), bare `kDebugMode` (warn)         |
| 6   | `analyze`           | invokes `flutter analyze`                                                       | analyzer reports any issues                                             |
| 7   | `version_bump`      | `pubspec.yaml` + `git tag --sort=-v:refname`                                    | pubspec version is not strictly greater than latest semver tag          |
| 8   | `test_coverage`     | runs `flutter test --coverage`, parses `coverage/lcov.info`                     | line coverage below `thresholds.test_coverage_min` (default 70%)        |
| 9   | `app_icon`          | `android/app/src/main/res/mipmap-*`, `ios/.../AppIcon.appiconset/Contents.json` | icons missing for both platforms                                        |
| 10  | `dart_define_leak`  | `.vscode/launch.json`, `.idea/`, root-level `*.sh`/`*.env`                      | `--dart-define KEY=VALUE` with a value that looks like a real secret    |

---

## Installation

```sh
dart pub global activate flutter_release_checklist
```

Make sure `~/.pub-cache/bin` is on your `PATH`.

For local development from a clone:

```sh
dart pub get
dart bin/flutter_release_checklist.dart run --project /path/to/your/flutter_app
```

---

## Usage

```sh
# from your Flutter project root
flutter_release_checklist run

# pick a flavor
flutter_release_checklist run --flavor production

# point at a non-default config file
flutter_release_checklist run --config tooling/release_checklist.yaml

# treat warnings as failures (good for CI)
flutter_release_checklist run --fail-on-warning --no-color

# run against another directory
flutter_release_checklist run --project ../my_other_app
```

### Flags

| Flag                | Default                            | Purpose                                       |
| ------------------- | ---------------------------------- | --------------------------------------------- |
| `--flavor <name>`   | none                               | Sets the flavor; overrides `flavor:` in YAML. |
| `--config <path>`   | `<project>/release_checklist.yaml` | Path to the config file.                      |
| `--project <path>`  | current directory                  | Path to the Flutter project being checked.    |
| `--fail-on-warning` | off                                | Treat any warning as a failure (exit 1).      |
| `--no-color`        | auto-detect                        | Disable ANSI escapes. Use in CI logs.         |

### Exit codes

| Code | Meaning                                                                  |
| ---- | ------------------------------------------------------------------------ |
| 0    | All enabled checks passed (warnings allowed unless `--fail-on-warning`). |
| 1    | One or more checks failed.                                               |
| 64   | CLI usage error (bad arguments).                                         |
| 65   | Config file present but malformed.                                       |

### Sample output

```
flutter_release_checklist v0.1.0
Running 10 checks on: /Users/me/code/my_app
─────────────────────────────────────────
✅  Android Manifest: debuggable=false: android:debuggable absent from manifest
✅  iOS Plist: NSAllowsArbitraryLoads absent: NSAllowsArbitraryLoads absent from Info.plist
⚠️   Hardcoded Secrets: 2 potential matches found
     → lib/config/constants.dart:12 — token = "abc123def456ghi789"
     → lib/api/client.dart:34 — apiKey = "xyzAAABBBCCC"
✅  ProGuard: rules file present, minifyEnabled=true: proguard-rules.pro present and release minifyEnabled true
❌  Debug Mode: debugPrint() found in production code
     → lib/services/auth_service.dart:88 [debugPrint] — debugPrint("auth ok");
     fix: Remove debugPrint() calls or guard them behind kDebugMode/assert.
⚠️   Flutter Analyze: 3 warnings found
✅  Version Bump: 1.2.0 > last tag v1.1.0
❌  Test Coverage: 54% (minimum: 70%)
✅  App Icons: all required sizes present
✅  Dart Define Leak: no secrets found in committed files
─────────────────────────────────────────
Results: 6 passed · 2 failed · 2 warnings
❌ Release blocked — resolve failures before submitting.
```

---

## Configuration

Drop a `release_checklist.yaml` file at the root of your Flutter project. A
fully-annotated example lives in [`example/release_checklist.yaml`](example/release_checklist.yaml).

```yaml
flavor: production # optional; --flavor on the CLI overrides

checks:
  android_manifest: true
  ios_plist: true
  hardcoded_secrets: true
  proguard: true
  debug_mode: true
  analyze: true
  version_bump: true
  test_coverage: true
  app_icon: true
  dart_define_leak: true

thresholds:
  test_coverage_min: 70

secret_patterns:
  - "sk_live_[A-Za-z0-9]{16,}"
  - "AKIA[0-9A-Z]{16}"
  - "Bearer\\s+[A-Za-z0-9_\\-\\.]{20,}"

exclude_paths:
  - "lib/generated/"
  - ".dart_tool/"
```

### Config keys

- **`flavor`** — informational; passed through to checks via `CheckerConfig`.
- **`checks.<id>`** — `true`/`false` to toggle a single check. Missing means
  enabled.
- **`thresholds.test_coverage_min`** — integer percent (0–100). Default 70.
  Coverage in `[min - 10, min)` is a warning; below `min - 10` is a failure.
- **`secret_patterns`** — extra Dart `RegExp` patterns appended to the
  built-in set used by `hardcoded_secrets`.
- **`exclude_paths`** — path prefixes (relative to project root) skipped in
  the `lib/`-scanning checks.

---

## CI/CD integration

### GitHub Actions

```yaml
- uses: subosito/flutter-action@v2
  with:
    channel: stable

- name: Pre-release checks
  run: |
    dart pub global activate flutter_release_checklist
    flutter_release_checklist run --fail-on-warning --no-color
```

### Codemagic

```yaml
scripts:
  - name: Pre-release checks
    script: |
      dart pub global activate flutter_release_checklist
      flutter_release_checklist run --no-color
```

### Fastlane

```ruby
lane :pre_release do
  sh "dart pub global activate flutter_release_checklist"
  sh "flutter_release_checklist run --fail-on-warning --no-color"
end
```

### GitLab CI

```yaml
release_checks:
  stage: validate
  script:
    - dart pub global activate flutter_release_checklist
    - flutter_release_checklist run --fail-on-warning --no-color
```

---

## All checks, in detail

### 1. `android_manifest`

Reads `android/app/src/main/AndroidManifest.xml`. Fails if `android:debuggable`
is set to any truthy value. Skipped if the manifest is missing.

### 2. `ios_plist`

Reads `ios/Runner/Info.plist`. Fails if `<key>NSAllowsArbitraryLoads</key>`
is followed by `<true/>`. Warns if `NSAppTransportSecurity.NSExceptionDomains`
contains any domain key with `*` in it.

### 3. `hardcoded_secrets`

Scans every `.dart` file under `lib/`. Default patterns:

```
api_key\s*=\s*["'][A-Za-z0-9]{10,}["']
apiKey\s*[:=]\s*["'][A-Za-z0-9]{10,}["']
secret\s*[:=]\s*["'][A-Za-z0-9]{10,}["']
password\s*[:=]\s*["'][^"']{6,}["']
token\s*[:=]\s*["'][A-Za-z0-9]{10,}["']
```

Plus anything in `secret_patterns`. Matches are reported as **warnings**, not
failures, since false positives are common. Each match shows file path, line
number, and the offending line snippet.

### 4. `proguard`

Verifies `android/app/proguard-rules.pro` exists. Then parses
`android/app/build.gradle` (or `.kts`), finds the `release { ... }` block,
and confirms `minifyEnabled true` (Groovy) or `isMinifyEnabled = true`
(Kotlin DSL) is set. Missing rules file → fail. File present but minify not
confirmed → warning.

### 5. `debug_mode`

Scans `lib/**.dart` after stripping line comments and string literals so
matches inside text are ignored.

- `debugPrint(` → **fail**
- `print(` → **warning**
- `kDebugMode` outside an `assert(...)` line → **warning**

### 6. `analyze`

Runs `flutter analyze --no-pub`. Skipped if `flutter` is not on `PATH`.
Forwards the analyzer's combined output to the report.

### 7. `version_bump`

Parses `version:` from `pubspec.yaml` (must be `MAJOR.MINOR.PATCH` or
`MAJOR.MINOR.PATCH+BUILD`). Reads `git tag --sort=-v:refname`, strips a
leading `v` if present, finds the most recent semver-shaped tag, and
compares. Skipped if no `.git` directory; warns if no semver tags exist.

### 8. `test_coverage`

Runs `flutter test --coverage`, parses `coverage/lcov.info`, sums all `LF`
and `LH` counters across files, and compares the resulting percent against
`thresholds.test_coverage_min`. Skipped if there is no `test/` directory or
lcov isn't generated.

### 9. `app_icon`

For Android, checks that each of `mipmap-mdpi`, `mipmap-hdpi`, `mipmap-xhdpi`,
`mipmap-xxhdpi`, `mipmap-xxxhdpi` contains an `ic_launcher.png`. For iOS,
checks that `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
exists and is non-empty.

### 10. `dart_define_leak`

Scans `.vscode/launch.json`, all `.xml`/`.iml`/`.json` files under `.idea/`,
and any root-level `*.sh` / `*.env` files. Flags `--dart-define KEY=VALUE`
entries where the value:

- is longer than 8 characters,
- is not `true`/`false`,
- is not an environment-variable reference (`$FOO`, `${FOO}`, `%FOO%`),
- and does not contain placeholder tokens (`placeholder`, `changeme`,
  `your_`, `replace_`, `xxxxxxxx`, etc.).

Output is redacted (`abc***fg`) so the report itself doesn't leak the secret.

---

## Contributing / adding a custom check

Each check is a class implementing `BaseCheck`:

```dart
abstract class BaseCheck {
  String get id;        // matches the YAML config key
  String get name;      // shown in output
  Future<CheckResult> run(String projectRoot, CheckerConfig config);
}
```

Returning `CheckResult` is straightforward:

```dart
return CheckResult(
  name: 'My Check: succinct one-liner',
  status: CheckStatus.failed,
  message: 'what went wrong, optionally with\n→ multi-line detail',
  fix: 'how to fix it',
);
```

Then register it in `lib/src/runner.dart`:

```dart
List<BaseCheck> allChecks() => [
  // ...existing...
  MyCustomCheck(),
];
```

For testability, prefer a pure static `evaluate` / `scan` method that takes
file contents (not file paths) so unit tests can pass strings directly. See
[`android_manifest_check.dart`](lib/src/checks/android_manifest_check.dart)
and [`hardcoded_secrets_check.dart`](lib/src/checks/hardcoded_secrets_check.dart)
as templates.

Run the test suite with:

```sh
dart pub get
dart test
```

---

## Related Packages

- [flutter_netwatch](https://pub.dev/packages/flutter_netwatch) — HTTP inspector with sensitive data masking

## Author

Built by **Muhammad Mujtaba** — [mujtaba.cc](https://www.mujtaba.cc/)

## Support

If this package saves your team time, consider sponsoring:

[![GitHub Sponsors](https://img.shields.io/github/sponsors/iammujtaba44?style=flat&logo=github&label=Sponsor)](https://github.com/sponsors/iammujtaba44)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-yellow)](https://buymeacoffee.com/immujtaba9h)

## License

MIT.
