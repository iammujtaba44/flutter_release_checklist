import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../result.dart';

/// Compares `version:` in pubspec.yaml against the most recent git tag and
/// fails if the project version is not strictly greater.
class VersionBumpCheck implements BaseCheck {
  @override
  String get id => 'version_bump';

  @override
  String get name => 'Version Bump';

  static const _fix = 'Bump version in pubspec.yaml before releasing';

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.skipped,
        message: 'pubspec.yaml not found',
      );
    }

    String? versionStr;
    try {
      final yaml = loadYaml(pubspec.readAsStringSync());
      if (yaml is YamlMap) versionStr = yaml['version']?.toString();
    } catch (e) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.failed,
        message: 'could not parse pubspec.yaml: $e',
      );
    }
    if (versionStr == null || versionStr.trim().isEmpty) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.failed,
        message: 'no version: field in pubspec.yaml',
        fix: _fix,
      );
    }
    final current = parseSemver(versionStr);
    if (current == null) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.failed,
        message: 'invalid version "$versionStr" — expected MAJOR.MINOR.PATCH[+BUILD]',
        fix: _fix,
      );
    }

    // git tag --sort=-v:refname
    if (!Directory(p.join(projectRoot, '.git')).existsSync()) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.warning,
        message: 'no .git directory found — cannot compare against tags '
            '(current version: $versionStr)',
      );
    }

    ProcessResult res;
    try {
      res = await Process.run(
        'git',
        ['tag', '--sort=-v:refname'],
        workingDirectory: projectRoot,
      );
    } catch (e) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.skipped,
        message: 'git not available: $e',
      );
    }
    if (res.exitCode != 0) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.skipped,
        message: 'git tag failed: ${res.stderr}',
      );
    }
    final tags = res.stdout
        .toString()
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    SemVer? latest;
    String? latestRaw;
    for (final t in tags) {
      final stripped = t.startsWith('v') ? t.substring(1) : t;
      final v = parseSemver(stripped);
      if (v != null) {
        latest = v;
        latestRaw = t;
        break;
      }
    }

    if (latest == null) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.warning,
        message: 'no semver-shaped git tags found (current: $versionStr)',
      );
    }

    final cmp = current.compareTo(latest);
    if (cmp > 0) {
      return CheckResult(
        name: 'Version Bump',
        status: CheckStatus.passed,
        message: '$versionStr > last tag $latestRaw',
      );
    }
    return CheckResult(
      name: 'Version Bump',
      status: CheckStatus.failed,
      message: 'pubspec version $versionStr is not greater than last tag $latestRaw',
      fix: _fix,
    );
  }

  /// Parses `MAJOR.MINOR.PATCH` or `MAJOR.MINOR.PATCH+BUILD`. Returns null
  /// if [s] doesn't match.
  static SemVer? parseSemver(String s) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$').firstMatch(s.trim());
    if (m == null) return null;
    return SemVer(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      m.group(4) == null ? null : int.parse(m.group(4)!),
    );
  }
}

class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, [this.build]);
  final int major;
  final int minor;
  final int patch;
  final int? build;

  @override
  int compareTo(SemVer o) {
    if (major != o.major) return major.compareTo(o.major);
    if (minor != o.minor) return minor.compareTo(o.minor);
    if (patch != o.patch) return patch.compareTo(o.patch);
    final a = build ?? 0;
    final b = o.build ?? 0;
    return a.compareTo(b);
  }

  @override
  String toString() => build == null ? '$major.$minor.$patch' : '$major.$minor.$patch+$build';
}
