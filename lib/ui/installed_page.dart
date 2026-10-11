import 'package:flutter/material.dart';

import '../brew/models.dart';
import 'common.dart';
import 'package_details.dart';

class InstalledPage extends StatefulWidget {
  const InstalledPage({super.key});

  @override
  State<InstalledPage> createState() => _InstalledPageState();
}

class _InstalledPageState extends State<InstalledPage> {
  String _filter = '';
  PackageKind? _kind;

  /// Hide formulae that were only pulled in as dependencies.
  bool _requestedOnly = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _filter.toLowerCase();
    final packages =
        state.installed
            .where((p) => _kind == null || p.kind == _kind)
            .where((p) => !_requestedOnly || p.installedOnRequest)
            .where(
              (p) =>
                  q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  (p.displayName?.toLowerCase().contains(q) ?? false) ||
                  (p.desc?.toLowerCase().contains(q) ?? false),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Installed',
          bottom: Row(
            children: [
              Expanded(
                child: FilterField(
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<PackageKind?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(
                    value: PackageKind.formula,
                    label: Text('Formulae'),
                  ),
                  ButtonSegment(value: PackageKind.cask, label: Text('Casks')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Requested only'),
                tooltip: 'Hide formulae installed only as dependencies',
                selected: _requestedOnly,
                onSelected: (v) => setState(() => _requestedOnly = v),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '${packages.length} of ${state.installed.length}',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        Expanded(
          child: packages.isEmpty
              ? EmptyState(
                  state.loading ? 'Loading…' : 'Nothing installed matches.',
                )
              : ListView.builder(
                  itemCount: packages.length,
                  itemBuilder: (context, i) =>
                      PackageTile(package: packages[i]),
                ),
        ),
      ],
    );
  }
}

class PackageTile extends StatelessWidget {
  const PackageTile({super.key, required this.package});

  final Package package;

  @override
  Widget build(BuildContext context) {
    final p = package;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(kindIcon(p.kind)),
      title: Row(
        children: [
          Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
          if (p.displayName != null && p.displayName != p.name)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                p.displayName!,
                style: TextStyle(color: scheme.outline),
              ),
            ),
          if (p.outdated) Tag('outdated', color: scheme.tertiary),
          if (p.pinned) const Tag('pinned'),
          if (p.kind == PackageKind.formula && !p.installedOnRequest)
            Tag('dependency', color: scheme.outline),
        ],
      ),
      subtitle: p.desc == null
          ? null
          : Text(p.desc!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        p.installedVersion ?? '',
        style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
      ),
      onTap: () => showPackageDetails(context, p.fullName, p.kind),
    );
  }
}
