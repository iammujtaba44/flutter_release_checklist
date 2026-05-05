import 'dart:io';

import 'package:path/path.dart' as p;

import '../result.dart';

class DartDefineHit {
  DartDefineHit({
    required this.path,
    required this.line,
    required this.key,
    required this.value,
  });
  final String path;
  final int line;
  final String key;
  final String value;
}

/// Scans `.vscode/launch.json`, files under `.idea/`, and any `*.sh` / `*.env`
/// files at the repo root for `--dart-define KEY=VALUE` entries that look
/// like real secrets (long, non-placeholder values).
class DartDefineLeakCheck implements BaseCheck {
  @override
  String get id => 'dart_define_leak';

  @override
  String get name => 'Dart Define Leak';

  static const _fix =
      'Move dart-define secrets to CI/CD environment variables, not local config files';

  /// Pure scan over [files]. Returns hits whose value looks like a real
  /// secret (length > 8 and not a placeholder/env-var ref).
  static List<DartDefineHit> scan({required Iterable<MapEntry<String, String>> files}) {
    // Match either `--dart-define=KEY=VALUE` or `--dart-define KEY=VALUE`.
    // VALUE may be quoted or unquoted up to whitespace.
    final re = RegExp(
      r'''--dart-define[=\s]+([A-Za-z_][A-Za-z0-9_]*)=(?:"([^"]*)"|'([^']*)'|([^\s"',]+))''',
    );
    final hits = <DartDefineHit>[];
    for (final entry in files) {
      final lines = entry.value.split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final m in re.allMatches(lines[i])) {
          final key = m.group(1)!;
          final value = m.group(2) ?? m.group(3) ?? m.group(4) ?? '';
          if (_looksReal(value)) {
            hits.add(DartDefineHit(path: entry.key, line: i + 1, key: key, value: value));
          }
        }
      }
    }
    return hits;
  }

  static bool _looksReal(String value) {
    final v = value.trim();
    if (v.length <= 8) return false;
    final lower = v.toLowerCase();
    if (lower == 'true' || lower == 'false') return false;
    // Env var refs, e.g. $FOO, ${FOO}, %FOO%
    if (RegExp(r'^\$\{?[A-Z_][A-Z0-9_]*\}?$').hasMatch(v)) return false;
    if (RegExp(r'^%[A-Z_][A-Z0-9_]*%$').hasMatch(v)) return false;
    // Obvious placeholders.
    final placeholderTokens = <String>[
      'placeholder', 'changeme', 'todo', 'example', 'your_', 'replace_', 'xxxxxxxx',
    ];
    for (final t in placeholderTokens) {
      if (lower.contains(t)) return false;
    }
    return true;
  }

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final scanned = <MapEntry<String, String>>[];

    void addIfFile(String relPath) {
      final f = File(p.join(projectRoot, relPath));
      if (f.existsSync()) {
        try {
          scanned.add(MapEntry(relPath, f.readAsStringSync()));
        } catch (_) {/* skip unreadable */}
      }
    }

    addIfFile(p.join('.vscode', 'launch.json'));

    final ideaDir = Directory(p.join(projectRoot, '.idea'));
    if (ideaDir.existsSync()) {
      for (final entity in ideaDir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (!(lower.endsWith('.xml') || lower.endsWith('.iml') || lower.endsWith('.json'))) continue;
        try {
          scanned.add(MapEntry(p.relative(entity.path, from: projectRoot), entity.readAsStringSync()));
        } catch (_) {}
      }
    }

    final root = Directory(projectRoot);
    if (root.existsSync()) {
      for (final entity in root.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final lower = name.toLowerCase();
        if (lower.endsWith('.sh') || lower.endsWith('.env') || lower == '.env') {
          try {
            scanned.add(MapEntry(name, entity.readAsStringSync()));
          } catch (_) {}
        }
      }
    }

    if (scanned.isEmpty) {
      return CheckResult(
        name: 'Dart Define Leak',
        status: CheckStatus.passed,
        message: 'no candidate config files found',
      );
    }

    final hits = scan(files: scanned);
    if (hits.isEmpty) {
      return CheckResult(
        name: 'Dart Define Leak',
        status: CheckStatus.passed,
        message: 'no secrets found in committed files (scanned ${scanned.length} file(s))',
      );
    }

    final lines = hits
        .map((h) => '${h.path}:${h.line} — --dart-define ${h.key}=${_redact(h.value)}')
        .join('\n');
    return CheckResult(
      name: 'Dart Define Leak',
      status: CheckStatus.warning,
      message: '${hits.length} potential dart-define secret(s) in committed files\n$lines',
      fix: _fix,
    );
  }

  static String _redact(String v) {
    if (v.length <= 6) return '***';
    return '${v.substring(0, 3)}***${v.substring(v.length - 2)}';
  }
}
