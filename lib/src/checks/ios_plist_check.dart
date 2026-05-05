import 'dart:io';

import 'package:path/path.dart' as p;

import '../result.dart';

/// Verifies `ios/Runner/Info.plist` does not enable
/// `NSAllowsArbitraryLoads`, and warns about wildcard exception domains.
class IosPlistCheck implements BaseCheck {
  @override
  String get id => 'ios_plist';

  @override
  String get name => 'iOS Plist';

  static const _fix = 'Remove NSAllowsArbitraryLoads or set to false in Info.plist';

  static CheckResult evaluate({String? contents}) {
    if (contents == null) {
      return CheckResult(
        name: 'iOS Plist',
        status: CheckStatus.skipped,
        message: 'Info.plist not found at ios/Runner/Info.plist',
      );
    }

    // Look for: <key>NSAllowsArbitraryLoads</key> followed by <true/> or <false/>.
    final ats = RegExp(
      r'<key>\s*NSAllowsArbitraryLoads\s*</key>\s*<(true|false)\s*/\s*>',
      caseSensitive: false,
    );
    final m = ats.firstMatch(contents);
    final findings = <String>[];

    if (m != null && m.group(1)!.toLowerCase() == 'true') {
      return CheckResult(
        name: 'iOS Plist: NSAllowsArbitraryLoads=true',
        status: CheckStatus.failed,
        message: 'NSAllowsArbitraryLoads is set to true in Info.plist',
        fix: _fix,
      );
    }

    // Bonus: wildcard NSExceptionDomains (e.g. "*.example.com" or just "*").
    final exDomainsBlock = RegExp(
      r'<key>\s*NSExceptionDomains\s*</key>\s*<dict>([\s\S]*?)</dict>',
      caseSensitive: false,
    ).firstMatch(contents);
    if (exDomainsBlock != null) {
      final body = exDomainsBlock.group(1)!;
      final keys = RegExp(r'<key>\s*([^<]+?)\s*</key>').allMatches(body);
      for (final k in keys) {
        final domain = k.group(1)!;
        if (domain.contains('*')) {
          findings.add('wildcard exception domain "$domain" in NSExceptionDomains');
        }
      }
    }

    if (findings.isNotEmpty) {
      return CheckResult(
        name: 'iOS Plist: wildcard exception domain(s)',
        status: CheckStatus.warning,
        message: '${findings.length} wildcard exception domain(s) found\n${findings.join('\n')}',
      );
    }

    return CheckResult(
      name: 'iOS Plist: NSAllowsArbitraryLoads ${m == null ? 'absent' : 'false'}',
      status: CheckStatus.passed,
      message: m == null
          ? 'NSAllowsArbitraryLoads absent from Info.plist'
          : 'NSAllowsArbitraryLoads is false',
    );
  }

  @override
  Future<CheckResult> run(String projectRoot, CheckerConfig config) async {
    final file = File(p.join(projectRoot, 'ios', 'Runner', 'Info.plist'));
    final contents = file.existsSync() ? file.readAsStringSync() : null;
    return evaluate(contents: contents);
  }
}
