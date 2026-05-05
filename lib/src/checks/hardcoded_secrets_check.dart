import 'dart:io';

import 'package:path/path.dart' as p;

import '../result.dart';

/// Match found in a single line of source.
class SecretMatch {
  SecretMatch({required this.path, required this.line, required this.snippet});
  final String path;
  final int line;
  final String snippet;
}

/// Scans `lib/**.dart` for hardcoded credentials. Findings are reported as
/// warnings, not failures, since false positives are common.
class HardcodedSecretsCheck implements BaseCheck {
  @override
  String get id => 'hardcoded_secrets';

  @override
  String get name => 'Hardcoded Secrets';

  /// Default regex set from the spec. Each entry must have a single capture
  /// group covering the matched value (or the whole match itself).
  static const List<String> defaultPatterns = <String>[
    r'''api_key\s*=\s*["'][A-Za-z0-9]{10,}["']''',
    r'''apiKey\s*[:=]\s*["'][A-Za-z0-9]{10,}["']''',
    r'''secret\s*[:=]\s*["'][A-Za-z0-9]{10,}["']''',
    r'''password\s*[:=]\s*["'][^"']{6,}["']''',
    r'''token\s*[:=]\s*["'][A-Za-z0-9]{10,}["']''',
  ];

  /// Pure scan over [files]. Each file is `(relativePath, contents)`. Returns
  /// every match found across all files. [extraPatterns] is appended to the
  /// default set.
  static List<SecretMatch> scan({
    required Iterable<MapEntry<String, String>> files,
    List<String> extraPatterns = const [],
  }) {
    final regexes = <RegExp>[
      for (final p in [...defaultPatterns, ...extraPatterns]) RegExp(p),
    ];
    final hits = <SecretMatch>[];
    for (final entry in files) {
      final lines = entry.value.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final r in regexes) {
          final m = r.firstMatch(line);
          if (m != null) {
            hits.add(SecretMatch(
              path: entry.key,
              line: i + 1,
              snippet: _snippet(line),
            ));
            break;
          }
        }
      }
    }
    return hits;
  }

  static String _snippet(String line) {
    final trimmed = line.trim();
    if (trimmed.length <= 80) return trimmed;
    return '${trimmed.substring(0, 77)}...';
  }

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) {
      return CheckResult(
        name: 'Hardcoded Secrets',
        status: CheckStatus.skipped,
        message: 'lib/ directory not found',
      );
    }

    final excludes = config.excludePaths;
    final files = <MapEntry<String, String>>[];
    for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final rel = p.relative(entity.path, from: projectRoot);
      if (_isExcluded(rel, excludes)) continue;
      files.add(MapEntry(rel, entity.readAsStringSync()));
    }

    final hits = scan(files: files, extraPatterns: config.extraSecretPatterns);

    if (hits.isEmpty) {
      return CheckResult(
        name: 'Hardcoded Secrets',
        status: CheckStatus.passed,
        message: 'no matches in ${files.length} dart file(s) under lib/',
      );
    }

    final detail = hits.map((h) => '${h.path}:${h.line} — ${h.snippet}').join('\n');
    return CheckResult(
      name: 'Hardcoded Secrets',
      status: CheckStatus.warning,
      message: '${hits.length} potential match${hits.length == 1 ? '' : 'es'} found\n$detail',
      fix: 'Move secrets to --dart-define, environment variables, or a '
          'gitignored config file. Review each match — false positives are common.',
    );
  }

  static bool _isExcluded(String relPath, List<String> excludes) {
    final norm = relPath.replaceAll(r'\', '/');
    for (final e in excludes) {
      final eNorm = e.replaceAll(r'\', '/');
      if (norm.startsWith(eNorm)) return true;
    }
    return false;
  }
}
