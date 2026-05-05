import 'package:flutter_release_checklist/src/checks/android_manifest_check.dart';
import 'package:flutter_release_checklist/src/result.dart';
import 'package:test/test.dart';

void main() {
  group('AndroidManifestCheck.evaluate', () {
    test('skipped when manifest is missing', () {
      final r = AndroidManifestCheck.evaluate(contents: null);
      expect(r.status, CheckStatus.skipped);
    });

    test('passes when android:debuggable is absent', () {
      final r = AndroidManifestCheck.evaluate(contents: '''
        <manifest xmlns:android="http://schemas.android.com/apk/res/android">
          <application android:label="example" />
        </manifest>
      ''');
      expect(r.status, CheckStatus.passed);
    });

    test('passes when android:debuggable is explicitly false', () {
      final r = AndroidManifestCheck.evaluate(contents: '''
        <application android:label="x" android:debuggable="false" />
      ''');
      expect(r.status, CheckStatus.passed);
    });

    test('fails when android:debuggable is true (double quotes)', () {
      final r = AndroidManifestCheck.evaluate(contents: '''
        <application android:label="x" android:debuggable="true" />
      ''');
      expect(r.status, CheckStatus.failed);
      expect(r.fix, contains('debuggable'));
    });

    test('fails when android:debuggable is true (single quotes)', () {
      final r = AndroidManifestCheck.evaluate(
        contents: "<application android:debuggable='true' />",
      );
      expect(r.status, CheckStatus.failed);
    });

    test('fails when android:debuggable is TRUE (case insensitive value)', () {
      final r = AndroidManifestCheck.evaluate(
        contents: '<application android:debuggable="TRUE" />',
      );
      expect(r.status, CheckStatus.failed);
    });

    test('handles whitespace around the equals', () {
      final r = AndroidManifestCheck.evaluate(
        contents: '<application android:debuggable  =  "true" />',
      );
      expect(r.status, CheckStatus.failed);
    });
  });
}
