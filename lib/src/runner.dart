import 'checks/analyze_check.dart';
import 'checks/android_manifest_check.dart';
import 'checks/app_icon_check.dart';
import 'checks/dart_define_leak_check.dart';
import 'checks/debug_mode_check.dart';
import 'checks/hardcoded_secrets_check.dart';
import 'checks/ios_plist_check.dart';
import 'checks/proguard_check.dart';
import 'checks/test_coverage_check.dart';
import 'checks/version_bump_check.dart';
import 'config.dart';
import 'reporter.dart';
import 'result.dart';

/// Holds the canonical ordered list of all available checks.
List<BaseCheck> allChecks() => [
      AndroidManifestCheck(),
      IosPlistCheck(),
      HardcodedSecretsCheck(),
      ProguardCheck(),
      DebugModeCheck(),
      AnalyzeCheck(),
      VersionBumpCheck(),
      TestCoverageCheck(),
      AppIconCheck(),
      DartDefineLeakCheck(),
    ];

/// Orchestrates check execution and reporting. Returns the process exit code.
class Runner {
  Runner({
    required this.projectRoot,
    required this.config,
    required this.reporter,
    required this.failOnWarning,
    required this.flavorOverride,
    required this.version,
  });

  final String projectRoot;
  final Config config;
  final Reporter reporter;
  final bool failOnWarning;
  final String? flavorOverride;
  final String version;

  Future<int> run() async {
    final checks = allChecks().where((c) => config.isEnabled(c.id)).toList();

    reporter.header(
      version: version,
      checkCount: checks.length,
      projectRoot: projectRoot,
    );

    final checkerConfig = CheckerConfig(
      flavor: flavorOverride ?? config.flavor,
      coverageMin: config.coverageMin,
      extraSecretPatterns: config.secretPatterns,
      excludePaths: config.excludePaths,
      failOnWarning: failOnWarning,
      useColor: reporter.useColor,
    );

    final results = <CheckResult>[];
    for (final c in checks) {
      late CheckResult r;
      try {
        r = await c.run(projectRoot, checkerConfig);
      } catch (e, st) {
        r = CheckResult(
          name: c.name,
          status: CheckStatus.failed,
          message: 'check threw: $e',
          fix: 'This is likely a bug in flutter_release_checklist. '
              'Please report it with the project structure that triggered it.\n$st',
        );
      }
      results.add(r);
      reporter.result(r);
    }

    return reporter.summary(results: results, failOnWarning: failOnWarning);
  }
}
