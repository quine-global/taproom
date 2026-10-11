import 'package:flutter/material.dart';

import '../brew/models.dart';
import 'common.dart';
import 'package_details.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Future<List<SearchResult>>? _results;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _query = q;
      _results = AppScope.read(context).brew.search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Search',
          bottom: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Formula or cask name — /regex/ also works',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _search, child: const Text('Search')),
            ],
          ),
        ),
        Expanded(
          child: _results == null
              ? const EmptyState(
                  'Search all formulae and casks in your taps.',
                  icon: Icons.search,
                )
              : FutureBuilder<List<SearchResult>>(
                  future: _results,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: ErrorBanner(snap.error!),
                      );
                    }
                    final results = snap.data!;
                    if (results.isEmpty) {
                      return EmptyState('No matches for "$_query".');
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final r = results[i];
                        final installed = state.installedPackage(
                          r.name,
                          r.kind,
                        );
                        return ListTile(
                          leading: Icon(kindIcon(r.kind)),
                          title: Row(
                            children: [
                              Text(r.name),
                              Tag(r.kind.label),
                              if (installed != null)
                                Tag(
                                  'installed',
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            ],
                          ),
                          trailing: installed != null
                              ? null
                              : OutlinedButton(
                                  onPressed: () => runTask(
                                    context,
                                    state.brew.install(r.name, r.kind),
                                  ),
                                  child: const Text('Install'),
                                ),
                          onTap: () =>
                              showPackageDetails(context, r.name, r.kind),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
