import 'dart:io';

import 'package:path/path.dart' as p;

import '../result.dart';

/// Runs `flutter test --coverage`, parses `coverage/lcov.info`, and compares
/// the resulting line-coverage percent against the configured minimum.
class TestCoverageCheck implements BaseCheck {
  @override
  String get id => 'test_coverage';

  @override
  String get name => 'Test Coverage';

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final testDir = Directory(p.join(projectRoot, 'test'));
    if (!testDir.existsSync()) {
      return CheckResult(
        name: 'Test Coverage',
        status: CheckStatus.skipped,
        message: 'no test/ directory found',
      );
    }

    final flutter = await _which('flutter');
    if (flutter == null) {
      return CheckResult(
        name: 'Test Coverage',
        status: CheckStatus.skipped,
        message: 'flutter not found on PATH',
      );
    }

    try {
      await Process.run(
        flutter,
        ['test', '--coverage'],
        workingDirectory: projectRoot,
      );
    } catch (e) {
      return CheckResult(
        name: 'Test Coverage',
        status: CheckStatus.skipped,
        message: 'failed to invoke flutter test: $e',
      );
    }

    final lcov = File(p.join(projectRoot, 'coverage', 'lcov.info'));
    if (!lcov.existsSync()) {
      return CheckResult(
        name: 'Test Coverage',
        status: CheckStatus.skipped,
        message: 'coverage/lcov.info was not generated',
      );
    }

    final pct = parseLcovPercent(lcov.readAsStringSync());
    if (pct == null) {
      return CheckResult(
        name: 'Test Coverage',
        status: CheckStatus.skipped,
        message: 'coverage/lcov.info contained no LF/LH counters',
      );
    }

    final min = config.coverageMin;
    final pctRounded = pct.round();
    if (pct >= min) {
      return CheckResult(
        name: 'Test Coverage',
        status: CheckStatus.passed,
        message: '$pctRounded% (minimum: $min%)',
      );
    }
    if (pct >= min - 10) {
      return CheckResult(
        name: 'Test Coverage',
        status: CheckStatus.warning,
        message: '$pctRounded% (minimum: $min%, within 10% grace)',
      );
    }
    return CheckResult(
      name: 'Test Coverage',
      status: CheckStatus.failed,
      message: '$pctRounded% (minimum: $min%)',
      fix: 'Add tests until coverage reaches at least $min%.',
    );
  }

  /// Sums LF (lines found) and LH (lines hit) across an lcov info file and
  /// returns the percentage. Returns null if no counters are present.
  static double? parseLcovPercent(String lcovContents) {
    var lf = 0;
    var lh = 0;
    for (final line in lcovContents.split('\n')) {
      final t = line.trim();
      if (t.startsWith('LF:')) {
        lf += int.tryParse(t.substring(3).trim()) ?? 0;
      } else if (t.startsWith('LH:')) {
        lh += int.tryParse(t.substring(3).trim()) ?? 0;
      }
    }
    if (lf == 0) return null;
    return (lh / lf) * 100;
  }

  Future<String?> _which(String name) async {
    final cmd = Platform.isWindows ? 'where' : 'which';
    try {
      final r = await Process.run(cmd, [name]);
      if (r.exitCode != 0) return null;
      final out = r.stdout.toString().trim().split('\n').first.trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }
}
