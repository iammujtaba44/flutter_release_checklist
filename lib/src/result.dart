/// Status of a single check after it runs.
enum CheckStatus { passed, failed, warning, skipped }

/// Outcome of running one [BaseCheck].
class CheckResult {
  CheckResult({
    required this.name,
    required this.status,
    required this.message,
    this.fix,
  });

  /// Human-readable label, e.g. `Android Manifest: debuggable=false`.
  final String name;
  final CheckStatus status;

  /// Detail shown under the line in console output. May be multi-line — each
  /// extra line will be indented as a sub-bullet by the reporter.
  final String message;

  /// Optional remediation hint shown when the check fails.
  final String? fix;
}

/// Subset of [Config] passed to each check at run time, so checks don't need
/// to know about YAML loading.
class CheckerConfig {
  CheckerConfig({
    required this.flavor,
    required this.coverageMin,
    required this.extraSecretPatterns,
    required this.excludePaths,
    required this.failOnWarning,
    required this.useColor,
  });

  /// Optional flavor name (e.g. "production"), from `--flavor` or YAML.
  final String? flavor;

  /// Minimum acceptable test coverage percentage (0-100).
  final int coverageMin;

  /// Additional regex patterns from YAML to scan for in secret check.
  final List<String> extraSecretPatterns;

  /// Path prefixes (relative to project root) to skip in file scans.
  final List<String> excludePaths;

  /// If true, warnings are treated as failures for exit code purposes.
  final bool failOnWarning;

  /// If false, the reporter must emit no ANSI escape codes.
  final bool useColor;
}

/// Common interface every check implements. Each check is independently
/// runnable and produces exactly one [CheckResult].
abstract class BaseCheck {
  /// Stable id matching the key used in `release_checklist.yaml`'s
  /// `checks:` map (e.g. `android_manifest`).
  String get id;

  /// Human-readable category name shown in output.
  String get name;

  Future<CheckResult> run(String projectRoot, CheckerConfig config);
}
