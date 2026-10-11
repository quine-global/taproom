import 'package:flutter/material.dart';

import '../brew/models.dart';
import 'common.dart';

Future<void> showPackageDetails(
  BuildContext context,
  String name,
  PackageKind kind,
) => showDialog<void>(
  context: context,
  builder: (_) => PackageDetailsDialog(name: name, kind: kind),
);

/// Full `brew info` for one package, with the actions that apply to it.
class PackageDetailsDialog extends StatefulWidget {
  const PackageDetailsDialog({
    super.key,
    required this.name,
    required this.kind,
  });

  final String name;
  final PackageKind kind;

  @override
  State<PackageDetailsDialog> createState() => _PackageDetailsDialogState();
}

class _PackageDetailsDialogState extends State<PackageDetailsDialog> {
  late Future<Package?> _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _info = AppScope.read(context).brew.info(widget.name, widget.kind);

  Future<void> _act(Future<bool> Function() action) async {
    await action();
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 600,
        child: FutureBuilder<Package?>(
          future: _info,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) return ErrorBanner(snap.error!);
            final p = snap.data;
            if (p == null) return Text('No information for ${widget.name}.');
            return _Details(package: p);
          },
        ),
      ),
      actions: [
        FutureBuilder<Package?>(
          future: _info,
          builder: (context, snap) => snap.data == null
              ? const SizedBox.shrink()
              : Wrap(spacing: 8, children: _actions(snap.data!)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  List<Widget> _actions(Package p) {
    final brew = AppScope.read(context).brew;
    if (!p.isInstalled) {
      return [
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Install'),
          onPressed: () =>
              _act(() => runTask(context, brew.install(p.fullName, p.kind))),
        ),
      ];
    }
    return [
      if (p.outdated && !p.pinned)
        FilledButton.icon(
          icon: const Icon(Icons.upgrade),
          label: const Text('Upgrade'),
          onPressed: () => _act(
            () =>
                runTask(context, brew.upgrade(name: p.fullName, kind: p.kind)),
          ),
        ),
      if (p.kind == PackageKind.formula)
        OutlinedButton.icon(
          icon: Icon(p.pinned ? Icons.push_pin_outlined : Icons.push_pin),
          label: Text(p.pinned ? 'Unpin' : 'Pin'),
          onPressed: () => _act(
            () => runTask(context, brew.pin(p.fullName, pinned: !p.pinned)),
          ),
        ),
      OutlinedButton(
        onPressed: () =>
            _act(() => runTask(context, brew.reinstall(p.fullName, p.kind))),
        child: const Text('Reinstall'),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Uninstall'),
        onPressed: () => _act(() async {
          final ok = await confirm(
            context,
            title: 'Uninstall ${p.name}?',
            message: p.kind == PackageKind.formula
                ? 'Homebrew will refuse if other installed formulae '
                      'depend on it.'
                : 'This removes the app and its Homebrew-managed files.',
            action: 'Uninstall',
          );
          if (!ok || !mounted) return false;
          return runTask(context, brew.uninstall(p.fullName, p.kind));
        }),
      ),
    ];
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.package});

  final Package package;

  @override
  Widget build(BuildContext context) {
    final p = package;
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.outline);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(kindIcon(p.kind)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  p.displayName ?? p.name,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Tag(p.kind.label),
              if (p.isInstalled)
                Tag('installed', color: theme.colorScheme.primary),
              if (p.outdated)
                Tag('outdated', color: theme.colorScheme.tertiary),
              if (p.pinned) const Tag('pinned'),
              if (p.deprecated)
                Tag('deprecated', color: theme.colorScheme.error),
            ],
          ),
          if (p.displayName != null) Text(p.fullName, style: muted),
          const SizedBox(height: 12),
          if (p.desc != null) Text(p.desc!, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          _field('Tap', p.tap ?? '—'),
          _field('Latest', p.latestVersion ?? '—'),
          _field('Installed', p.installedVersion ?? 'not installed'),
          if (p.homepage != null)
            Row(
              children: [
                const SizedBox(width: 90, child: Text('Homepage')),
                Flexible(
                  child: InkWell(
                    onTap: () => openUrl(p.homepage!),
                    child: Text(
                      p.homepage!,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          if (p.dependencies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Dependencies', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in p.dependencies)
                  ActionChip(
                    label: Text(d),
                    onPressed: () =>
                        showPackageDetails(context, d, PackageKind.formula),
                  ),
              ],
            ),
          ],
          if (p.caveats != null && p.caveats!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Caveats', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SelectableText(
              p.caveats!.trim(),
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Flexible(child: SelectableText(value)),
      ],
    ),
  );
}
