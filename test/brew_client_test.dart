import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taproom/brew/brew_client.dart';
import 'package:taproom/brew/models.dart';

/// Records calls and answers each with a canned result chosen by [respond].
class FakeRunner {
  FakeRunner(this.respond);

  final ProcessResult Function(List<String> args) respond;
  final calls = <(List<String>, Map<String, String>)>[];

  Future<ProcessResult> call(
    String exe,
    List<String> args,
    Map<String, String> env,
  ) async {
    calls.add((args, env));
    return respond(args);
  }
}

ProcessResult result(String stdout, {int exitCode = 0, String stderr = ''}) =>
    ProcessResult(0, exitCode, stdout, stderr);

void main() {
  test('search queries formulae and casks and tolerates no matches', () async {
    final runner = FakeRunner(
      (args) => args.contains('--formula')
          ? result('jq\njq-lsp\n')
          // brew exits 1 with a message when nothing matches.
          : result('', exitCode: 1, stderr: 'Error: No casks found for "jq".'),
    );
    final brew = BrewClient(
      brewPath: '/opt/homebrew/bin/brew',
      runner: runner.call,
    );

    final results = await brew.search('jq');

    expect(results.map((r) => (r.name, r.kind)), [
      ('jq', PackageKind.formula),
      ('jq-lsp', PackageKind.formula),
    ]);
    expect(runner.calls.map((c) => c.$1), [
      ['search', '--formula', 'jq'],
      ['search', '--cask', 'jq'],
    ]);
  });

  test('search output parsing skips headers and prose', () {
    final r = BrewClient.parseSearchOutput(
      '==> Formulae\nfoo\n\nIf you meant "foo" specifically:\nbar\n',
      PackageKind.formula,
    );
    expect(r.map((e) => e.name), ['foo', 'bar']);
  });

  test('queries run with a usable PATH and without auto-update', () async {
    final runner = FakeRunner((_) => result('{"formulae": [], "casks": []}'));
    final brew = BrewClient(
      brewPath: '/opt/homebrew/bin/brew',
      runner: runner.call,
    );

    await brew.installed();

    final env = runner.calls.single.$2;
    expect(env['PATH'], startsWith('/opt/homebrew/bin:/usr/bin:'));
    expect(env['HOMEBREW_NO_AUTO_UPDATE'], '1');
    expect(env['HOMEBREW_NO_COLOR'], '1');
  });

  test('a failing query throws BrewException with stderr', () async {
    final runner = FakeRunner(
      (_) => result('', exitCode: 1, stderr: 'Error: No available formula'),
    );
    final brew = BrewClient(
      brewPath: '/opt/homebrew/bin/brew',
      runner: runner.call,
    );

    expect(
      () => brew.info('nope', PackageKind.formula),
      throwsA(
        isA<BrewException>().having(
          (e) => e.stderr,
          'stderr',
          contains('No available formula'),
        ),
      ),
    );
  });

  test(
    'BrewTask streams stdout and stderr and records the exit code',
    () async {
      late Map<String, String> seenEnv;
      final brew = BrewClient(
        brewPath: '/opt/homebrew/bin/brew',
        askpassPath: '/tmp/askpass',
        starter: (exe, args, env) {
          seenEnv = env;
          return Process.start('/bin/sh', [
            '-c',
            'echo installing; echo warning >&2; exit 3',
          ]);
        },
      );
      final task = brew.install('jq', PackageKind.formula);
      var notified = 0;
      task.addListener(() => notified++);

      final code = await task.run();

      expect(code, 3);
      expect(task.succeeded, isFalse);
      expect(task.running, isFalse);
      expect(task.lines.first, r'$ brew install --formula jq');
      expect(task.lines, containsAll(['installing', 'warning']));
      expect(notified, greaterThan(2));
      // Mutations may auto-update and may need sudo via the askpass helper.
      expect(seenEnv.containsKey('HOMEBREW_NO_AUTO_UPDATE'), isFalse);
      expect(seenEnv['SUDO_ASKPASS'], '/tmp/askpass');
    },
  );

  test('upgrade builds the right arguments', () {
    final brew = BrewClient(brewPath: '/b/brew');
    expect(brew.upgrade().args, ['upgrade']);
    expect(brew.upgrade(greedy: true).args, ['upgrade', '--greedy']);
    expect(brew.upgrade(name: 'firefox', kind: PackageKind.cask).args, [
      'upgrade',
      '--cask',
      'firefox',
    ]);
    expect(brew.addTap('a/b', url: '').args, ['tap', 'a/b']);
    expect(brew.addTap('a/b', url: 'https://x/y.git').args, [
      'tap',
      'a/b',
      'https://x/y.git',
    ]);
  });

  // Read-only checks against the real Homebrew on this machine, to catch
  // drift between brew's JSON and the parsers.
  group('real brew', () {
    final path = BrewClient.locate();
    final brew = path == null ? null : BrewClient(brewPath: path);

    test('lists installed packages', () async {
      final installed = await brew!.installed();
      expect(installed, everyElement(isA<Package>()));
      expect(installed.where((p) => !p.isInstalled), isEmpty);
    }, skip: brew == null ? 'Homebrew not installed' : false);

    test('lists taps including homebrew/core', () async {
      final taps = await brew!.taps();
      expect(taps.map((t) => t.name), contains('homebrew/core'));
      final core = taps.firstWhere((t) => t.name == 'homebrew/core');
      expect(core.formulaNames, contains('jq'));
    }, skip: brew == null ? 'Homebrew not installed' : false);

    test('searches', () async {
      final r = await brew!.search('jq');
      expect(r.map((e) => e.name), contains('jq'));
    }, skip: brew == null ? 'Homebrew not installed' : false);

    test('gets cask info', () async {
      final p = await brew!.info('firefox', PackageKind.cask);
      expect(p?.displayName, isNotEmpty);
      expect(jsonEncode(p?.name), '"firefox"');
    }, skip: brew == null ? 'Homebrew not installed' : false);
  });
}
