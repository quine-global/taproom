import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taproom/brew/brew_client.dart';
import 'package:taproom/main.dart';
import 'package:taproom/state/app_state.dart';

void main() {
  testWidgets('shows installed packages and outdated badge', (tester) async {
    final client = BrewClient(
      brewPath: '/fake/brew',
      runner: (exe, args, env) async {
        final out = switch (args.first) {
          'info' => {
            'formulae': [
              {
                'name': 'jq',
                'desc': 'Lightweight and flexible command-line JSON processor',
                'installed': [
                  {'version': '1.8.1', 'installed_on_request': true},
                ],
                'outdated': true,
              },
              {
                'name': 'oniguruma',
                'installed': [
                  {'version': '6.9.10', 'installed_on_request': false},
                ],
              },
            ],
            'casks': [
              {
                'token': 'firefox',
                'name': ['Mozilla Firefox'],
                'installed': '141.0',
              },
            ],
          },
          'outdated' => {
            'formulae': [
              {
                'name': 'jq',
                'installed_versions': ['1.8.1'],
                'current_version': '1.8.2',
              },
            ],
            'casks': [],
          },
          'tap-info' => [
            {
              'name': 'homebrew/core',
              'official': true,
              'formula_names': ['jq'],
            },
          ],
          _ => throw UnimplementedError('$args'),
        };
        return ProcessResult(0, 0, jsonEncode(out), '');
      },
    );
    final state = AppState(client);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(TaproomApp(state: state));
    await tester.runAsync(state.refresh);
    await tester.pump();

    expect(find.text('jq'), findsOneWidget);
    expect(find.text('oniguruma'), findsOneWidget);
    expect(find.text('Mozilla Firefox'), findsOneWidget);
    expect(find.text('dependency'), findsOneWidget);
    expect(find.text('3 of 3'), findsOneWidget);
    // Badge on the Outdated rail item.
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Requested only'));
    await tester.pump();
    expect(find.text('oniguruma'), findsNothing);
    expect(find.text('2 of 3'), findsOneWidget);
  });
}
