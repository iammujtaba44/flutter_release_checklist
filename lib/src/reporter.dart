import 'dart:io';

import 'result.dart';

/// Renders [CheckResult]s to stdout in the format described in the spec.
///
/// Honors `useColor=false` for CI logs (no ANSI escapes emitted).
class Reporter {
  Reporter({required this.useColor});

  final bool useColor;

  static const _esc = '\x1B[';
  String _green(String s) => useColor ? '$_esc${32}m$s$_esc${0}m' : s;
  String _red(String s) => useColor ? '$_esc${31}m$s$_esc${0}m' : s;
  String _yellow(String s) => useColor ? '$_esc${33}m$s$_esc${0}m' : s;
  String _gray(String s) => useColor ? '$_esc${90}m$s$_esc${0}m' : s;
  String _bold(String s) => useColor ? '$_esc${1}m$s$_esc${0}m' : s;

  /// Prints the header that appears before any check output.
  void header({
    required String version,
    required int checkCount,
    required String projectRoot,
  }) {
    stdout.writeln('flutter_release_checklist v$version');
    stdout.writeln('Running $checkCount checks on: $projectRoot');
    stdout.writeln(_divider());
  }

  /// Prints a single check's outcome.
  void result(CheckResult r) {
    final icon = switch (r.status) {
      CheckStatus.passed => _green('✅'),
      CheckStatus.failed => _red('❌'),
      CheckStatus.warning => _yellow('⚠️ '),
      CheckStatus.skipped => _gray('⏭ '),
    };
    final lines = r.message.split('\n');
    final firstLine = lines.first;
    stdout.writeln('$icon  ${r.name}${firstLine.isEmpty ? '' : ': $firstLine'}');
    for (final extra in lines.skip(1)) {
      if (extra.trim().isEmpty) continue;
      stdout.writeln('     → $extra');
    }
    if (r.status == CheckStatus.failed && r.fix != null) {
      stdout.writeln(_gray('     fix: ${r.fix}'));
    }
  }

  /// Prints the trailing summary line(s) and returns the exit code.
  int summary({required List<CheckResult> results, required bool failOnWarning}) {
    final passed = results.where((r) => r.status == CheckStatus.passed).length;
    final failed = results.where((r) => r.status == CheckStatus.failed).length;
    final warnings = results.where((r) => r.status == CheckStatus.warning).length;
    final skipped = results.where((r) => r.status == CheckStatus.skipped).length;

    stdout.writeln(_divider());
    final parts = <String>[
      _green('$passed passed'),
      _red('$failed failed'),
      _yellow('$warnings warnings'),
    ];
    if (skipped > 0) parts.add(_gray('$skipped skipped'));
    stdout.writeln('Results: ${parts.join(' · ')}');

    final blocked = failed > 0 || (failOnWarning && warnings > 0);
    if (blocked) {
      stdout.writeln(_red(_bold('❌ Release blocked — resolve failures before submitting.')));
      return 1;
    }
    stdout.writeln(_green(_bold('✅ All checks passed — ready to ship.')));
    return 0;
  }

  String _divider() => '─────────────────────────────────────────';
}
