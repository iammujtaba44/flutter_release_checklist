import 'package:flutter_release_checklist/src/checks/debug_mode_check.dart';
import 'package:test/test.dart';

void main() {
  group('DebugModeCheck.scan', () {
    test('clean code produces no findings', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry('lib/main.dart', '''
          void main() {
            final x = compute();
            useIt(x);
          }
        '''),
      ]);
      expect(hits, isEmpty);
    });

    test('flags debugPrint() calls', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry('lib/a.dart', 'void f() { debugPrint("hi"); }'),
      ]);
      expect(hits, hasLength(1));
      expect(hits.first.kind, 'debugPrint');
    });

    test('flags print() calls', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry('lib/a.dart', 'void f() { print("hi"); }'),
      ]);
      expect(hits, hasLength(1));
      expect(hits.first.kind, 'print');
    });

    test('does not flag method calls named print on objects', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry('lib/a.dart', 'void f() { logger.print("hi"); }'),
      ]);
      expect(hits, isEmpty);
    });

    test('does not flag print or debugPrint inside string literals', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry(
          'lib/a.dart',
          'final s = "this mentions debugPrint(x) but is just a string";',
        ),
      ]);
      expect(hits, isEmpty);
    });

    test('does not flag print/debugPrint inside line comments', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry('lib/a.dart', 'void f() {} // debugPrint("nope")'),
      ]);
      expect(hits, isEmpty);
    });

    test('flags kDebugMode when not inside an assert', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry('lib/a.dart', 'final flag = kDebugMode ? 1 : 0;'),
      ]);
      expect(hits, hasLength(1));
      expect(hits.first.kind, 'kDebugMode');
    });

    test('does not flag kDebugMode used inside an assert call', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry('lib/a.dart', 'void f() { assert(kDebugMode || x); }'),
      ]);
      expect(hits, isEmpty);
    });

    test('reports line numbers correctly', () {
      final hits = DebugModeCheck.scan(files: [
        const MapEntry('lib/a.dart', '''
          void f() {
            doStuff();
            debugPrint("hi");
          }
        '''),
      ]);
      expect(hits, hasLength(1));
      expect(hits.first.line, 3);
    });
  });
}
