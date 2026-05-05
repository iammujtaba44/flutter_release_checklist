import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_release_checklist/src/config.dart';
import 'package:flutter_release_checklist/src/reporter.dart';
import 'package:flutter_release_checklist/src/runner.dart';
import 'package:path/path.dart' as p;

const String _version = '0.1.0';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'flutter_release_checklist',
    'Run pre-release security and quality checks on a Flutter project.',
  )
    ..argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the tool version and exit.',
    )
    ..addCommand(_RunCommand());

  // Handle --version at the top level.
  try {
    final topLevel = runner.argParser.parse(args);
    if (topLevel['version'] == true) {
      stdout.writeln('flutter_release_checklist $_version');
      exit(0);
    }
  } on ArgParserException {
    // Fall through; CommandRunner will produce a better error.
  }

  try {
    final code = await runner.run(args);
    exit(code ?? 0);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}

class _RunCommand extends Command<int> {
  _RunCommand() {
    argParser
      ..addOption(
        'flavor',
        help: 'Flavor name to run against (overrides flavor in YAML).',
      )
      ..addOption(
        'config',
        help: 'Path to release_checklist.yaml (defaults to <project>/release_checklist.yaml).',
      )
      ..addOption(
        'project',
        help: 'Path to the Flutter project to check (defaults to the current directory).',
      )
      ..addFlag(
        'fail-on-warning',
        negatable: false,
        help: 'Treat warnings as failures (exit code 1).',
      )
      ..addFlag(
        'color',
        defaultsTo: stdout.supportsAnsiEscapes,
        help: 'Use ANSI colors in output. Use --no-color in CI.',
      );
  }

  @override
  String get name => 'run';

  @override
  String get description => 'Run all enabled checks and print a summary.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final projectRoot = p.normalize(p.absolute(args['project'] as String? ?? Directory.current.path));
    if (!Directory(projectRoot).existsSync()) {
      stderr.writeln('Project directory not found: $projectRoot');
      return 64;
    }

    Config config;
    try {
      config = Config.load(projectRoot: projectRoot, configPath: args['config'] as String?);
    } on FormatException catch (e) {
      stderr.writeln('Failed to load config: ${e.message}');
      return 65;
    }

    final reporter = Reporter(useColor: args['color'] as bool);
    final r = Runner(
      projectRoot: projectRoot,
      config: config,
      reporter: reporter,
      failOnWarning: args['fail-on-warning'] as bool,
      flavorOverride: args['flavor'] as String?,
      version: _version,
    );
    return r.run();
  }
}
