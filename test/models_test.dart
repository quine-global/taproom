import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taproom/brew/models.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('parses a formula from real brew info output', () {
    final p = Package.listFromInfoJson(fixture('info_jq.json')).single;
    expect(p.name, 'jq');
    expect(p.kind, PackageKind.formula);
    expect(p.tap, 'homebrew/core');
    expect(p.latestVersion, '1.8.2');
    expect(p.dependencies, ['oniguruma']);
    expect(p.isInstalled, isFalse);
  });

  test('parses a cask from real brew info output', () {
    final p = Package.listFromInfoJson(fixture('info_firefox.json')).single;
    expect(p.name, 'firefox');
    expect(p.kind, PackageKind.cask);
    expect(p.displayName, 'Mozilla Firefox');
    expect(p.tap, 'homebrew/cask');
    expect(p.latestVersion, isNotNull);
  });

  test('installed formula uses the newest install and on-request flag', () {
    final p = Package.fromFormulaJson({
      'name': 'git',
      'versions': {'stable': '2.50.0'},
      'installed': [
        {'version': '2.49.0', 'installed_on_request': false},
        {'version': '2.50.0', 'installed_on_request': true},
      ],
      'outdated': false,
      'pinned': true,
    });
    expect(p.installedVersion, '2.50.0');
    expect(p.installedOnRequest, isTrue);
    expect(p.pinned, isTrue);
    expect(p.fullName, 'git');
  });

  test('dependency-only formula is not installed on request', () {
    final p = Package.fromFormulaJson({
      'name': 'oniguruma',
      'installed': [
        {'version': '6.9.10', 'installed_on_request': false},
      ],
    });
    expect(p.isInstalled, isTrue);
    expect(p.installedOnRequest, isFalse);
  });

  test('parses outdated formulae and casks', () {
    final list = OutdatedEntry.listFromJson({
      'formulae': [
        {
          'name': 'node',
          'installed_versions': ['22.1.0'],
          'current_version': '22.2.0',
          'pinned': true,
        },
      ],
      'casks': [
        {
          'name': 'firefox',
          'installed_versions': ['140.0'],
          'current_version': '141.0',
        },
      ],
    });
    expect(list.map((e) => (e.name, e.kind, e.pinned)), [
      ('node', PackageKind.formula, true),
      ('firefox', PackageKind.cask, false),
    ]);
    expect(list.last.installedVersions, ['140.0']);
  });

  test('parses an API-backed tap', () {
    final t = Tap.fromJson({
      'name': 'homebrew/core',
      'path': '/opt/homebrew/Library/Taps/homebrew/homebrew-core',
      'installed': false,
      'official': true,
      'formula_names': ['a', 'b'],
      'cask_tokens': [],
    });
    expect(t.cloned, isFalse);
    expect(t.official, isTrue);
    expect(t.formulaNames, hasLength(2));
    expect(t.remote, isNull);
  });

  test('parses a cloned third-party tap', () {
    // Shape from `brew tap-info --json hashicorp/tap`: custom_remote is a
    // bool, not the URL.
    final t = Tap.fromJson({
      'name': 'hashicorp/tap',
      'path': '/opt/homebrew/Library/Taps/hashicorp/homebrew-tap',
      'installed': true,
      'official': false,
      'remote': 'https://github.com/hashicorp/homebrew-tap',
      'custom_remote': false,
      'last_commit': '2 days ago',
      'branch': 'main',
      'formula_names': ['hashicorp/tap/terraform'],
      'cask_tokens': [],
    });
    expect(t.cloned, isTrue);
    expect(t.remote, 'https://github.com/hashicorp/homebrew-tap');
    expect(t.branch, 'main');
    expect(t.lastCommit, '2 days ago');
  });
}
