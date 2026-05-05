import 'package:flutter_release_checklist/src/checks/hardcoded_secrets_check.dart';
import 'package:test/test.dart';

void main() {
  group('HardcodedSecretsCheck.scan', () {
    test('returns no hits on clean code', () {
      final hits = HardcodedSecretsCheck.scan(files: [
        const MapEntry('lib/main.dart', '''
          void main() {
            final apiKey = readFromEnv("API_KEY");
            print(apiKey);
          }
        '''),
      ]);
      expect(hits, isEmpty);
    });

    test('catches api_key with snake_case assignment', () {
      final hits = HardcodedSecretsCheck.scan(files: [
        const MapEntry(
          'lib/config.dart',
          'const api_key = "abcdef1234567890";',
        ),
      ]);
      expect(hits, hasLength(1));
      expect(hits.first.path, 'lib/config.dart');
      expect(hits.first.line, 1);
    });

    test('catches camelCase apiKey assignments with : or =', () {
      final hits = HardcodedSecretsCheck.scan(files: [
        const MapEntry('lib/a.dart', 'final apiKey = "ZZZZZZZZZZZZZ";'),
        const MapEntry('lib/b.dart', 'fetch(apiKey: "QQQQQQQQQQQQQ");'),
      ]);
      expect(hits, hasLength(2));
    });

    test('catches password and token patterns', () {
      final hits = HardcodedSecretsCheck.scan(files: [
        const MapEntry('lib/x.dart', 'final password = "hunter2x";'),
        const MapEntry('lib/y.dart', 'final token = "tokabcdef1234567890";'),
      ]);
      expect(hits.map((h) => h.path), containsAll(['lib/x.dart', 'lib/y.dart']));
    });

    test('reports correct line numbers across multi-line files', () {
      final hits = HardcodedSecretsCheck.scan(files: [
        const MapEntry('lib/a.dart', '''
          // line 1
          // line 2
          final secret = "supersecretvalue123";
          // line 4
        '''),
      ]);
      expect(hits, hasLength(1));
      expect(hits.first.line, 3);
    });

    test('extra patterns from config are honored', () {
      final hits = HardcodedSecretsCheck.scan(
        files: [
          const MapEntry('lib/a.dart', 'final k = "AKIA1234567890ABCD";'),
        ],
        extraPatterns: ['AKIA[A-Z0-9]{12,}'],
      );
      expect(hits, hasLength(1));
    });

    test('does not double-report a line that matches multiple patterns', () {
      final hits = HardcodedSecretsCheck.scan(files: [
        const MapEntry('lib/a.dart', 'final apiKey = "secretValue1234567";'),
      ]);
      expect(hits, hasLength(1));
    });
  });
}
