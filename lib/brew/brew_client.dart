import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> args,
  Map<String, String> environment,
);

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> args,
  Map<String, String> environment,
);

class BrewException implements Exception {
  BrewException(this.args, this.exitCode, this.stderr);

  final List<String> args;
  final int exitCode;
  final String stderr;

  @override
  String toString() =>
      'brew ${args.join(' ')} exited $exitCode${stderr.isEmpty ? '' : ':\n$stderr'}';
}

/// Thin wrapper over the `brew` CLI. Queries go through [runner] and are
/// parsed from brew's JSON output; mutations (install, tap, ...) are
/// returned as [BrewTask]s that stream their output.
class BrewClient {
  BrewClient({
    required this.brewPath,
    ProcessRunner? runner,
    ProcessStarter? starter,
    this.askpassPath,
  }) : _runner = runner ?? _defaultRunner,
       _starter = starter ?? _defaultStarter;

  final String brewPath;

  /// A SUDO_ASKPASS helper, so casks that run `sudo` (pkg installers) can
  /// prompt for a password without a terminal.
  final String? askpassPath;
  final ProcessRunner _runner;
  final ProcessStarter _starter;

  static const _candidatePaths = [
    '/opt/homebrew/bin/brew', // Apple Silicon
    '/usr/local/bin/brew', // Intel
    '/home/linuxbrew/.linuxbrew/bin/brew',
  ];

  /// GUI apps don't inherit the shell's PATH, so look in brew's standard
  /// install locations rather than relying on `which`.
  static String? locate() {
    for (final p in _candidatePaths) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  static Future<ProcessResult> _defaultRunner(
    String exe,
    List<String> args,
    Map<String, String> env,
  ) => Process.run(exe, args, environment: env);

  static Future<Process> _defaultStarter(
    String exe,
    List<String> args,
    Map<String, String> env,
  ) => Process.start(exe, args, environment: env);

  Map<String, String> _environment({required bool readOnly}) {
    final inherited = Platform.environment;
    final brewBin = File(brewPath).parent.path;
    return {
      ...inherited,
      'PATH':
          '$brewBin:/usr/bin:/bin:/usr/sbin:/sbin'
          '${inherited['PATH'] == null ? '' : ':${inherited['PATH']}'}',
      'HOMEBREW_NO_COLOR': '1',
      'HOMEBREW_NO_EMOJI': '1',
      'HOMEBREW_NO_ENV_HINTS': '1',
      'NONINTERACTIVE': '1',
      // Keep queries snappy; an explicit "brew update" is one click away.
      if (readOnly) 'HOMEBREW_NO_AUTO_UPDATE': '1',
      'SUDO_ASKPASS': ?askpassPath,
    };
  }

  Future<String> _run(List<String> args, {bool allowFailure = false}) async {
    final r = await _runner(brewPath, args, _environment(readOnly: true));
    if (r.exitCode != 0 && !allowFailure) {
      throw BrewException(args, r.exitCode, (r.stderr as String).trim());
    }
    return r.stdout as String;
  }

  Future<Map<String, dynamic>> _runJson(List<String> args) async =>
      jsonDecode(await _run(args)) as Map<String, dynamic>;

  Future<List<Package>> installed() async => Package.listFromInfoJson(
    await _runJson(['info', '--json=v2', '--installed']),
  );

  Future<List<OutdatedEntry>> outdated({bool greedy = false}) async =>
      OutdatedEntry.listFromJson(
        await _runJson(['outdated', '--json=v2', if (greedy) '--greedy']),
      );

  Future<List<Tap>> taps() async {
    final out = await _run(['tap-info', '--json', '--installed']);
    return (jsonDecode(out) as List)
        .map((t) => Tap.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Package?> info(String name, PackageKind kind) async {
    final list = Package.listFromInfoJson(
      await _runJson(['info', '--json=v2', kind.flag, name]),
    );
    return list.isEmpty ? null : list.first;
  }

  /// Searches formulae and casks by name. Like `brew search`, a query
  /// wrapped in slashes is treated as a regex.
  Future<List<SearchResult>> search(String query) async {
    final results = await Future.wait([
      for (final kind in PackageKind.values)
        // brew exits non-zero when nothing matches; that's just no results.
        _run([
          'search',
          kind.flag,
          query,
        ], allowFailure: true).then((out) => parseSearchOutput(out, kind)),
    ]);
    return results.expand((r) => r).toList();
  }

  @visibleForTesting
  static List<SearchResult> parseSearchOutput(String out, PackageKind kind) => [
    for (final line in const LineSplitter().convert(out))
      if (line.trim().isNotEmpty &&
          !line.startsWith('==>') &&
          !line.contains(' '))
        SearchResult(line.trim(), kind),
  ];

  BrewTask install(String name, PackageKind kind) =>
      task('Install $name', ['install', kind.flag, name]);

  BrewTask uninstall(String name, PackageKind kind) =>
      task('Uninstall $name', ['uninstall', kind.flag, name]);

  BrewTask reinstall(String name, PackageKind kind) =>
      task('Reinstall $name', ['reinstall', kind.flag, name]);

  /// Upgrades one package, or everything outdated when [name] is null.
  BrewTask upgrade({String? name, PackageKind? kind, bool greedy = false}) =>
      task(name == null ? 'Upgrade all' : 'Upgrade $name', [
        'upgrade',
        if (kind != null) kind.flag,
        if (greedy) '--greedy',
        ?name,
      ]);

  BrewTask pin(String name, {required bool pinned}) => task(
    '${pinned ? 'Pin' : 'Unpin'} $name',
    [pinned ? 'pin' : 'unpin', name],
  );

  BrewTask update() => task('Update Homebrew', ['update']);

  BrewTask cleanup() => task('Clean up', ['cleanup']);

  BrewTask addTap(String name, {String? url}) =>
      task('Tap $name', ['tap', name, if (url != null && url.isNotEmpty) url]);

  BrewTask removeTap(String name) => task('Untap $name', ['untap', name]);

  BrewTask task(String title, List<String> args) => BrewTask._(
    title: title,
    args: args,
    start: () => _starter(brewPath, args, _environment(readOnly: false)),
  );
}

/// A running (or finished) brew command whose output is streamed into
/// [lines]. Listen to it to rebuild as output arrives.
class BrewTask extends ChangeNotifier {
  BrewTask._({required this.title, required this.args, required this.start});

  final String title;
  final List<String> args;
  final Future<Process> Function() start;

  final List<String> lines = [];
  int? exitCode;
  Process? _process;
  bool _started = false;

  bool get running => _started && exitCode == null;
  bool get succeeded => exitCode == 0;
  String get command => 'brew ${args.join(' ')}';

  /// Starts the command; completes with its exit code.
  Future<int> run() async {
    if (_started) throw StateError('BrewTask already started');
    _started = true;
    lines.add('\$ $command');
    notifyListeners();
    try {
      final p = _process = await start();
      await p.stdin.close();
      Future<void> pump(Stream<List<int>> s) => s
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((l) {
            lines.add(l);
            notifyListeners();
          });
      await Future.wait([pump(p.stdout), pump(p.stderr)]);
      exitCode = await p.exitCode;
    } catch (e) {
      lines.add('Failed to run brew: $e');
      exitCode = -1;
    }
    notifyListeners();
    return exitCode!;
  }

  void cancel() => _process?.kill();
}
