import 'dart:io';

import 'package:path/path.dart' as p;

import '../result.dart';

/// Verifies `android/app/src/main/AndroidManifest.xml` does not enable
/// `android:debuggable="true"`.
class AndroidManifestCheck implements BaseCheck {
  @override
  String get id => 'android_manifest';

  @override
  String get name => 'Android Manifest';

  static const _fix =
      'Set android:debuggable="false" in your release manifest or remove it entirely';

  /// Pure function form usable from tests — operates on a manifest string.
  /// Returns the [CheckResult] you'd get from running against a project where
  /// the manifest contains [contents].
  static CheckResult evaluate({String? contents}) {
    if (contents == null) {
      return CheckResult(
        name: 'Android Manifest',
        status: CheckStatus.skipped,
        message: 'AndroidManifest.xml not found at android/app/src/main/AndroidManifest.xml',
      );
    }

    final debuggable = RegExp(r'''android:debuggable\s*=\s*["']([^"']+)["']''');
    final m = debuggable.firstMatch(contents);
    if (m == null) {
      return CheckResult(
        name: 'Android Manifest: debuggable=false',
        status: CheckStatus.passed,
        message: 'android:debuggable absent from manifest',
      );
    }
    final value = m.group(1)?.toLowerCase();
    if (value == 'true') {
      return CheckResult(
        name: 'Android Manifest: debuggable=true',
        status: CheckStatus.failed,
        message: 'android:debuggable="true" found in AndroidManifest.xml',
        fix: _fix,
      );
    }
    return CheckResult(
      name: 'Android Manifest: debuggable=$value',
      status: CheckStatus.passed,
      message: 'android:debuggable="$value"',
    );
  }

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final file = File(p.join(projectRoot, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'));
    final contents = file.existsSync() ? file.readAsStringSync() : null;
    return evaluate(contents: contents);
  }
}
