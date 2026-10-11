import 'dart:io';

import 'package:flutter/material.dart';

import 'brew/brew_client.dart';
import 'state/app_state.dart';
import 'ui/common.dart';
import 'ui/installed_page.dart';
import 'ui/outdated_page.dart';
import 'ui/search_page.dart';
import 'ui/taps_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppState? state;
  final brewPath = BrewClient.locate();
  if (brewPath != null) {
    state = AppState(
      BrewClient(brewPath: brewPath, askpassPath: _writeAskpass()),
    );
    state.refresh();
  }
  runApp(TaproomApp(state: state));
}

/// Writes a SUDO_ASKPASS helper that asks for the password with a native
/// dialog, for casks whose installers need sudo. Returns null if it can't.
String? _writeAskpass() {
  try {
    final f = File('${Directory.systemTemp.path}/taproom-askpass.sh');
    f.writeAsStringSync('''#!/bin/sh
exec /usr/bin/osascript -e 'text returned of (display dialog "Homebrew needs your password to continue." default answer "" with hidden answer with title "Taproom" with icon caution)'
''');
    Process.runSync('chmod', ['700', f.path]);
    return f.path;
  } catch (_) {
    return null;
  }
}

class TaproomApp extends StatelessWidget {
  const TaproomApp({super.key, required this.state});

  /// Null when Homebrew isn't installed.
  final AppState? state;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE0A030),
        brightness: b,
      ),
    );
    final app = MaterialApp(
      title: 'Taproom',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: state == null ? const _NoBrew() : const HomeScreen(),
    );
    // Above MaterialApp so dialogs (which live in the root overlay) see it.
    return state == null ? app : AppScope(state: state!, child: app);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _pages = [
    InstalledPage(),
    OutdatedPage(),
    SearchPage(),
    TapsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final outdated = state.outdated.length;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Icon(Icons.sports_bar, size: 32),
            ),
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Installed'),
              ),
              NavigationRailDestination(
                icon: Badge(
                  isLabelVisible: outdated > 0,
                  label: Text('$outdated'),
                  child: const Icon(Icons.update),
                ),
                label: const Text('Outdated'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.search),
                label: Text('Search'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.water_drop_outlined),
                selectedIcon: Icon(Icons.water_drop),
                label: Text('Taps'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'brew update — fetch the latest package index',
                        icon: const Icon(Icons.cloud_sync_outlined),
                        onPressed: () => runTask(context, state.brew.update()),
                      ),
                      IconButton(
                        tooltip:
                            'brew cleanup — remove old versions and caches',
                        icon: const Icon(Icons.cleaning_services_outlined),
                        onPressed: () => runTask(context, state.brew.cleanup()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
    );
  }
}

class _NoBrew extends StatelessWidget {
  const _NoBrew();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_bar, size: 64),
          const SizedBox(height: 16),
          Text(
            'Homebrew not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Looked in /opt/homebrew and /usr/local.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => openUrl('https://brew.sh'),
            child: const Text('Get Homebrew'),
          ),
        ],
      ),
    ),
  );
}
