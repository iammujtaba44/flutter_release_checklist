import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Parsed `release_checklist.yaml` plus CLI overrides.
class Config {
  Config({
    required this.flavor,
    required this.enabledChecks,
    required this.coverageMin,
    required this.secretPatterns,
    required this.excludePaths,
  });

  /// Flavor from YAML (may be overridden by CLI `--flavor`).
  final String? flavor;

  /// Map of check id -> enabled. Missing entries are treated as enabled.
  final Map<String, bool> enabledChecks;

  /// Minimum acceptable test coverage percent (defaults to 70).
  final int coverageMin;

  /// User-supplied regex patterns for the hardcoded-secrets check.
  final List<String> secretPatterns;

  /// Path prefixes to exclude from secret/debug scans.
  final List<String> excludePaths;

  bool isEnabled(String checkId) => enabledChecks[checkId] ?? true;

  /// Loads config from [configPath] if given, otherwise from
  /// `<projectRoot>/release_checklist.yaml`. Returns sensible defaults if
  /// the file is absent.
  static Config load({required String projectRoot, String? configPath}) {
    final path = configPath ?? p.join(projectRoot, 'release_checklist.yaml');
    final file = File(path);
    if (!file.existsSync()) {
      return Config(
        flavor: null,
        enabledChecks: const {},
        coverageMin: 70,
        secretPatterns: const [],
        excludePaths: const [],
      );
    }
    final raw = loadYaml(file.readAsStringSync());
    if (raw is! YamlMap) {
      throw const FormatException('release_checklist.yaml must be a YAML map at the top level');
    }

    final flavor = raw['flavor']?.toString();

    final enabled = <String, bool>{};
    final checksNode = raw['checks'];
    if (checksNode is YamlMap) {
      for (final entry in checksNode.entries) {
        final id = entry.key.toString();
        final v = entry.value;
        if (v is bool) {
          enabled[id] = v;
        } else if (v == null) {
          enabled[id] = true;
        } else {
          throw FormatException('Invalid value for checks.$id: expected bool, got "$v"');
        }
      }
    }

    var coverageMin = 70;
    final thresholds = raw['thresholds'];
    if (thresholds is YamlMap) {
      final tc = thresholds['test_coverage_min'];
      if (tc is int) {
        coverageMin = tc;
      } else if (tc != null) {
        final parsed = int.tryParse(tc.toString());
        if (parsed != null) coverageMin = parsed;
      }
    }

    final secretPatterns = <String>[];
    final sp = raw['secret_patterns'];
    if (sp is YamlList) {
      for (final v in sp) {
        secretPatterns.add(v.toString());
      }
    }

    final excludePaths = <String>[];
    final ep = raw['exclude_paths'];
    if (ep is YamlList) {
      for (final v in ep) {
        excludePaths.add(v.toString());
      }
    }

    return Config(
      flavor: flavor,
      enabledChecks: enabled,
      coverageMin: coverageMin,
      secretPatterns: secretPatterns,
      excludePaths: excludePaths,
    );
  }
}
