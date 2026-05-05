import 'dart:io';

import '../result.dart';

/// Runs `flutter analyze` and reports the result. Skips gracefully if
/// `flutter` is not on PATH.
class AnalyzeCheck implements BaseCheck {
  @override
  String get id => 'analyze';

  @override
  String get name => 'Flutter Analyze';

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final flutter = await _which('flutter');
    if (flutter == null) {
      return CheckResult(
        name: 'Flutter Analyze',
        status: CheckStatus.skipped,
        message: 'flutter not found on PATH',
      );
    }

    ProcessResult res;
    try {
      res = await Process.run(
        flutter,
        ['analyze', '--no-pub'],
        workingDirectory: projectRoot,
        runInShell: false,
      );
    } catch (e) {
      return CheckResult(
        name: 'Flutter Analyze',
        status: CheckStatus.skipped,
        message: 'failed to invoke flutter analyze: $e',
      );
    }

    final combined = ((res.stdout?.toString() ?? '') + (res.stderr?.toString() ?? '')).trim();

    if (res.exitCode == 0) {
      return CheckResult(
        name: 'Flutter Analyze',
        status: CheckStatus.passed,
        message: combined.isEmpty ? 'no issues' : 'no issues\n$combined',
      );
    }

    return CheckResult(
      name: 'Flutter Analyze',
      status: CheckStatus.failed,
      message: 'flutter analyze reported issues (exit ${res.exitCode})\n$combined',
      fix: 'Resolve the analyzer warnings/errors above before releasing.',
    );
  }

  Future<String?> _which(String name) async {
    final isWindows = Platform.isWindows;
    final cmd = isWindows ? 'where' : 'which';
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
