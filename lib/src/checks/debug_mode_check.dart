import 'dart:io';

import 'package:path/path.dart' as p;

import '../result.dart';

/// One finding in a single line.
class DebugFinding {
  DebugFinding({
    required this.path,
    required this.line,
    required this.kind,
    required this.snippet,
  });

  final String path;
  final int line;

  /// `debugPrint`, `print`, or `kDebugMode`.
  final String kind;
  final String snippet;
}

/// Scans `lib/**.dart` for debug-only constructs left in production code:
/// - `debugPrint(...)` -> failure
/// - `print(...)`      -> warning (commonly used, easy to miss)
/// - `kDebugMode`      -> warning if used outside an `assert(...)` and not
///   guarding obviously debug-only logic.
class DebugModeCheck implements BaseCheck {
  @override
  String get id => 'debug_mode';

  @override
  String get name => 'Debug Mode';

  /// Pure scan over [files]. Same shape as [HardcodedSecretsCheck.scan].
  static List<DebugFinding> scan({required Iterable<MapEntry<String, String>> files}) {
    final out = <DebugFinding>[];
    final debugPrintRe = RegExp(r'(?<![A-Za-z0-9_.])debugPrint\s*\(');
    final printRe = RegExp(r'(?<![A-Za-z0-9_.])print\s*\(');
    final kDebugRe = RegExp(r'(?<![A-Za-z0-9_])kDebugMode(?![A-Za-z0-9_])');
    final assertLine = RegExp(r'(?<![A-Za-z0-9_])assert\s*\(');

    for (final entry in files) {
      final lines = entry.value.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final stripped = _stripStringsAndComments(line);
        if (stripped.trim().isEmpty) continue;

        if (debugPrintRe.hasMatch(stripped)) {
          out.add(DebugFinding(
            path: entry.key,
            line: i + 1,
            kind: 'debugPrint',
            snippet: _snippet(line),
          ));
        }
        if (printRe.hasMatch(stripped)) {
          out.add(DebugFinding(
            path: entry.key,
            line: i + 1,
            kind: 'print',
            snippet: _snippet(line),
          ));
        }
        if (kDebugRe.hasMatch(stripped) && !assertLine.hasMatch(stripped)) {
          out.add(DebugFinding(
            path: entry.key,
            line: i + 1,
            kind: 'kDebugMode',
            snippet: _snippet(line),
          ));
        }
      }
    }
    return out;
  }

  static final RegExp _commentRe = RegExp(r'//.*$');
  static final RegExp _singleQuoteStringRe =
      RegExp("r?'(?:\\\\.|[^'\\\\])*'");
  static final RegExp _doubleQuoteStringRe =
      RegExp('r?"(?:\\\\.|[^"\\\\])*"');

  static String _stripStringsAndComments(String line) {
    var s = line.replaceAll(_commentRe, '');
    s = s.replaceAll(_singleQuoteStringRe, "''");
    s = s.replaceAll(_doubleQuoteStringRe, '""');
    return s;
  }

  static String _snippet(String line) {
    final t = line.trim();
    return t.length <= 80 ? t : '${t.substring(0, 77)}...';
  }

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) {
      return CheckResult(
        name: 'Debug Mode',
        status: CheckStatus.skipped,
        message: 'lib/ directory not found',
      );
    }

    final files = <MapEntry<String, String>>[];
    for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final rel = p.relative(entity.path, from: projectRoot);
      if (config.excludePaths.any((e) => rel.replaceAll(r'\', '/').startsWith(e.replaceAll(r'\', '/')))) {
        continue;
      }
      files.add(MapEntry(rel, entity.readAsStringSync()));
    }

    final findings = scan(files: files);

    final debugPrints = findings.where((f) => f.kind == 'debugPrint').toList();
    final prints = findings.where((f) => f.kind == 'print').toList();
    final kDebug = findings.where((f) => f.kind == 'kDebugMode').toList();

    if (findings.isEmpty) {
      return CheckResult(
        name: 'Debug Mode',
        status: CheckStatus.passed,
        message: 'no debug constructs found in ${files.length} dart file(s)',
      );
    }

    final lines = <String>[];
    for (final f in [...debugPrints, ...prints, ...kDebug]) {
      lines.add('${f.path}:${f.line} [${f.kind}] — ${f.snippet}');
    }

    if (debugPrints.isNotEmpty) {
      return CheckResult(
        name: 'Debug Mode',
        status: CheckStatus.failed,
        message: 'debugPrint() found in production code\n${lines.join('\n')}',
        fix: 'Remove debugPrint() calls or guard them behind kDebugMode/assert. '
            'Use a real logger for production diagnostics.',
      );
    }

    return CheckResult(
      name: 'Debug Mode',
      status: CheckStatus.warning,
      message: '${findings.length} debug construct(s) found\n${lines.join('\n')}',
    );
  }
}
