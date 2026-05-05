import 'dart:io';

import 'package:path/path.dart' as p;

import '../result.dart';

/// Verifies that platform launcher icons are present on both Android and iOS.
class AppIconCheck implements BaseCheck {
  @override
  String get id => 'app_icon';

  @override
  String get name => 'App Icons';

  static const _androidDensities = [
    'mipmap-mdpi',
    'mipmap-hdpi',
    'mipmap-xhdpi',
    'mipmap-xxhdpi',
    'mipmap-xxxhdpi',
  ];

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final androidRes = Directory(p.join(projectRoot, 'android', 'app', 'src', 'main', 'res'));
    final iosContents = File(p.join(
      projectRoot,
      'ios',
      'Runner',
      'Assets.xcassets',
      'AppIcon.appiconset',
      'Contents.json',
    ));

    final missing = <String>[];
    final present = <String>[];

    if (!androidRes.existsSync()) {
      missing.add('android/app/src/main/res/ (no Android res dir)');
    } else {
      for (final d in _androidDensities) {
        final f = File(p.join(androidRes.path, d, 'ic_launcher.png'));
        if (f.existsSync()) {
          present.add('android/$d/ic_launcher.png');
        } else {
          missing.add('android/$d/ic_launcher.png');
        }
      }
    }

    if (!iosContents.existsSync() || iosContents.lengthSync() == 0) {
      missing.add('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json');
    } else {
      present.add('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json');
    }

    if (present.isEmpty) {
      return CheckResult(
        name: 'App Icons',
        status: CheckStatus.failed,
        message: 'no launcher icons found for Android or iOS',
        fix: 'Generate launcher icons (e.g. with flutter_launcher_icons).',
      );
    }
    if (missing.isEmpty) {
      return CheckResult(
        name: 'App Icons',
        status: CheckStatus.passed,
        message: 'all required sizes present',
      );
    }
    return CheckResult(
      name: 'App Icons',
      status: CheckStatus.warning,
      message: '${missing.length} icon path(s) missing\n${missing.join('\n')}',
    );
  }
}
