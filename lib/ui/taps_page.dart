import 'package:flutter/material.dart';

import '../brew/models.dart';
import 'common.dart';
import 'package_details.dart';

/// Lists taps on the left; the selected tap's formulae and casks on the right.
class TapsPage extends StatefulWidget {
  const TapsPage({super.key});

  @override
  State<TapsPage> createState() => _TapsPageState();
}

class _TapsPageState extends State<TapsPage> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final taps = state.taps;
    final selected =
        taps.where((t) => t.name == _selected).firstOrNull ?? taps.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Taps',
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add tap'),
              onPressed: () => _addTap(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 280,
                child: ListView(
                  children: [
                    for (final t in taps)
                      ListTile(
                        selected: t.name == selected?.name,
                        leading: Icon(
                          t.official ? Icons.verified : Icons.source,
                        ),
                        title: Text(t.name),
                        subtitle: Text(_counts(t)),
                        onTap: () => setState(() => _selected = t.name),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const EmptyState('No taps.')
                    // Keyed so filter/tab state resets when switching taps.
                    : _TapContents(key: ValueKey(selected.name), tap: selected),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _counts(Tap t) => [
    if (t.formulaNames.isNotEmpty) '${t.formulaNames.length} formulae',
    if (t.caskTokens.isNotEmpty) '${t.caskTokens.length} casks',
    if (t.formulaNames.isEmpty && t.caskTokens.isEmpty) 'empty',
  ].join(' · ');

  Future<void> _addTap(BuildContext context) async {
    final name = TextEditingController();
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add tap'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'user/repo',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'Git URL (optional)',
                  hintText: 'Defaults to github.com/user/homebrew-repo',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tap'),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    final u = url.text.trim();
    name.dispose();
    url.dispose();
    if (ok != true || n.isEmpty || !context.mounted) return;
    await runTask(context, AppScope.read(context).brew.addTap(n, url: u));
    if (mounted) setState(() => _selected = n);
  }
}

class _TapContents extends StatefulWidget {
  const _TapContents({super.key, required this.tap});

  final Tap tap;

  @override
  State<_TapContents> createState() => _TapContentsState();
}

class _TapContentsState extends State<_TapContents> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final t = widget.tap;
    final muted = TextStyle(color: Theme.of(context).colorScheme.outline);
    final hasBoth = t.formulaNames.isNotEmpty && t.caskTokens.isNotEmpty;
    final kinds = [
      // An empty tap still gets one (empty) list.
      if (t.formulaNames.isNotEmpty || t.caskTokens.isEmpty)
        PackageKind.formula,
      if (t.caskTokens.isNotEmpty) PackageKind.cask,
    ];

    return DefaultTabController(
      length: kinds.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            t.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (t.official) const Tag('official'),
                          if (!t.cloned) Tag('via API', color: muted.color),
                        ],
                      ),
                      if (t.remote != null)
                        SelectableText(t.remote!, style: muted),
                      if (t.path != null && t.cloned)
                        SelectableText(t.path!, style: muted),
                      if (t.branch != null || t.lastCommit != null)
                        Text(
                          [
                            if (t.branch != null) 'branch ${t.branch}',
                            if (t.lastCommit != null)
                              'last commit ${t.lastCommit}',
                          ].join(' · '),
                          style: muted,
                        ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.link_off),
                  label: const Text('Untap'),
                  // homebrew/core and homebrew/cask come from the JSON API
                  // unless cloned; there's nothing local to untap.
                  onPressed: !t.cloned
                      ? null
                      : () async {
                          final ok = await confirm(
                            context,
                            title: 'Untap ${t.name}?',
                            message:
                                'Homebrew refuses if you have packages '
                                'installed from this tap.',
                            action: 'Untap',
                          );
                          if (ok && context.mounted) {
                            await runTask(
                              context,
                              AppScope.read(context).brew.removeTap(t.name),
                            );
                          }
                        },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FilterField(onChanged: (v) => setState(() => _filter = v)),
          ),
          if (hasBoth)
            TabBar(
              tabs: [
                Tab(text: 'Formulae (${t.formulaNames.length})'),
                Tab(text: 'Casks (${t.caskTokens.length})'),
              ],
            ),
          Expanded(
            child: TabBarView(
              children: [
                for (final k in kinds)
                  _NameList(
                    names: k == PackageKind.formula
                        ? t.formulaNames
                        : t.caskTokens,
                    kind: k,
                    filter: _filter,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NameList extends StatelessWidget {
  const _NameList({
    required this.names,
    required this.kind,
    required this.filter,
  });

  final List<String> names;
  final PackageKind kind;
  final String filter;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = filter.toLowerCase();
    final shown = q.isEmpty
        ? names
        : names.where((n) => n.toLowerCase().contains(q)).toList();
    if (shown.isEmpty) return const EmptyState('No matches.');
    return ListView.builder(
      itemCount: shown.length,
      itemExtent: 40,
      itemBuilder: (context, i) {
        final name = shown[i];
        final installed = state.installedPackage(name, kind) != null;
        return ListTile(
          dense: true,
          leading: Icon(kindIcon(kind), size: 18),
          title: Text(name),
          trailing: installed
              ? Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          onTap: () => showPackageDetails(context, name, kind),
        );
      },
    );
  }
}
