import 'dart:io';

import 'package:path/path.dart' as p;

import '../result.dart';

/// Verifies `android/app/proguard-rules.pro` exists and that
/// `android/app/build.gradle` (or its `.kts` form) enables `minifyEnabled true`
/// for the release build type.
class ProguardCheck implements BaseCheck {
  @override
  String get id => 'proguard';

  @override
  String get name => 'ProGuard';

  static const _fix =
      'Add proguard-rules.pro and enable minifyEnabled in your release build config';

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final androidApp = Directory(p.join(projectRoot, 'android', 'app'));
    if (!androidApp.existsSync()) {
      return CheckResult(
        name: 'ProGuard',
        status: CheckStatus.skipped,
        message: 'android/app/ not found — not an Android-enabled Flutter project?',
      );
    }

    final rules = File(p.join(androidApp.path, 'proguard-rules.pro'));
    final gradleGroovy = File(p.join(androidApp.path, 'build.gradle'));
    final gradleKts = File(p.join(androidApp.path, 'build.gradle.kts'));

    final gradle = gradleGroovy.existsSync()
        ? gradleGroovy
        : (gradleKts.existsSync() ? gradleKts : null);

    if (!rules.existsSync()) {
      return CheckResult(
        name: 'ProGuard: rules file missing',
        status: CheckStatus.failed,
        message: 'android/app/proguard-rules.pro is missing',
        fix: _fix,
      );
    }

    if (gradle == null) {
      return CheckResult(
        name: 'ProGuard: rules present, gradle not found',
        status: CheckStatus.warning,
        message: 'proguard-rules.pro exists but build.gradle(.kts) not found — '
            'cannot confirm minifyEnabled',
      );
    }

    final gradleSrc = gradle.readAsStringSync();
    final minifyConfirmed = _hasReleaseMinify(gradleSrc);

    if (!minifyConfirmed) {
      return CheckResult(
        name: 'ProGuard: minifyEnabled not confirmed',
        status: CheckStatus.warning,
        message: 'proguard-rules.pro exists but minifyEnabled true was not '
            'detected in the release build type of ${p.basename(gradle.path)}',
        fix: _fix,
      );
    }

    return CheckResult(
      name: 'ProGuard: rules file present, minifyEnabled=true',
      status: CheckStatus.passed,
      message: 'proguard-rules.pro present and release minifyEnabled true',
    );
  }

  /// Looks for either Groovy `release { ... minifyEnabled true ... }` or
  /// Kotlin DSL `release { ... isMinifyEnabled = true ... }`.
  static bool _hasReleaseMinify(String gradleSrc) {
    final stripped = _stripComments(gradleSrc);
    final releaseBlock = _extractBlock(stripped, 'release');
    if (releaseBlock == null) return false;
    final groovy = RegExp(r'minifyEnabled\s+true').hasMatch(releaseBlock);
    final kts = RegExp(r'isMinifyEnabled\s*=\s*true').hasMatch(releaseBlock);
    return groovy || kts;
  }

  static String _stripComments(String src) {
    return src
        .replaceAll(RegExp(r'//[^\n]*'), '')
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  }

  /// Returns the contents of the first `<name> { ... }` block in [src],
  /// matching nested braces. Returns null if not found.
  static String? _extractBlock(String src, String name) {
    final start = RegExp('\\b$name\\s*\\{').firstMatch(src);
    if (start == null) return null;
    var depth = 1;
    final i0 = start.end;
    for (var i = i0; i < src.length; i++) {
      final ch = src[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return src.substring(i0, i);
      }
    }
    return null;
  }
}
