import 'package:flutter/foundation.dart';

import '../brew/brew_client.dart';
import '../brew/models.dart';

/// Everything the app knows about the local Homebrew install. Pages read
/// from here; anything that changes the install calls [refresh] afterwards.
class AppState extends ChangeNotifier {
  AppState(this.brew);

  final BrewClient brew;

  List<Package> installed = const [];
  List<OutdatedEntry> outdated = const [];
  List<Tap> taps = const [];

  /// Also report casks that update themselves or have version :latest.
  bool greedy = false;
  bool loading = false;
  Object? error;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        brew.installed(),
        brew.outdated(greedy: greedy),
        brew.taps(),
      ]);
      installed = results[0] as List<Package>;
      outdated = results[1] as List<OutdatedEntry>;
      taps = results[2] as List<Tap>;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setGreedy(bool value) async {
    greedy = value;
    await refresh();
  }

  Package? installedPackage(String name, PackageKind kind) {
    for (final p in installed) {
      if (p.kind == kind && (p.name == name || p.fullName == name)) return p;
    }
    return null;
  }
}
