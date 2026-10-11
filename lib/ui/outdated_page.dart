import 'package:flutter/material.dart';

import 'common.dart';
import 'package_details.dart';

class OutdatedPage extends StatelessWidget {
  const OutdatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final upgradable = state.outdated.where((e) => !e.pinned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Outdated',
          actions: [
            Tooltip(
              message:
                  'Include casks that update themselves or use '
                  'version :latest (brew outdated --greedy)',
              child: Row(
                children: [
                  const Text('Greedy'),
                  Switch(
                    value: state.greedy,
                    onChanged: state.loading ? null : state.setGreedy,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.upgrade),
              label: Text('Upgrade all ($upgradable)'),
              onPressed: upgradable == 0
                  ? null
                  : () => runTask(
                      context,
                      state.brew.upgrade(greedy: state.greedy),
                    ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        Expanded(
          child: state.outdated.isEmpty
              ? EmptyState(
                  state.loading ? 'Checking…' : 'Everything is up to date.',
                  icon: Icons.check_circle_outline,
                )
              : ListView(
                  children: [
                    for (final e in state.outdated)
                      ListTile(
                        leading: Icon(kindIcon(e.kind)),
                        title: Row(
                          children: [
                            Text(e.name),
                            if (e.pinned) const Tag('pinned'),
                          ],
                        ),
                        subtitle: Text(
                          '${e.installedVersions.join(', ')}  →  ${e.currentVersion}',
                          style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 12,
                          ),
                        ),
                        trailing: OutlinedButton(
                          onPressed: e.pinned
                              ? null
                              : () => runTask(
                                  context,
                                  state.brew.upgrade(
                                    name: e.name,
                                    kind: e.kind,
                                    greedy: state.greedy,
                                  ),
                                ),
                          child: const Text('Upgrade'),
                        ),
                        onTap: () =>
                            showPackageDetails(context, e.name, e.kind),
                      ),
                    if (state.outdated.any((e) => e.pinned))
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Pinned formulae are skipped by upgrades; unpin them '
                          'from their details to upgrade.',
                          style: TextStyle(color: scheme.outline),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
