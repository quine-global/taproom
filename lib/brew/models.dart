enum PackageKind {
  formula,
  cask;

  /// The flag brew uses to disambiguate a name, e.g. `brew info --cask foo`.
  String get flag => this == formula ? '--formula' : '--cask';

  String get label => this == formula ? 'Formula' : 'Cask';
}

/// A formula or cask, as described by `brew info --json=v2`.
class Package {
  const Package({
    required this.name,
    required this.fullName,
    required this.kind,
    this.displayName,
    this.tap,
    this.desc,
    this.homepage,
    this.latestVersion,
    this.installedVersion,
    this.outdated = false,
    this.pinned = false,
    this.installedOnRequest = false,
    this.dependencies = const [],
    this.caveats,
    this.deprecated = false,
  });

  /// Formula name or cask token; what you pass to `brew install`.
  final String name;
  final String fullName;
  final PackageKind kind;

  /// Casks have a human name ("Firefox") separate from their token.
  final String? displayName;
  final String? tap;
  final String? desc;
  final String? homepage;
  final String? latestVersion;
  final String? installedVersion;
  final bool outdated;
  final bool pinned;

  /// False for formulae only present as a dependency of something else.
  final bool installedOnRequest;
  final List<String> dependencies;
  final String? caveats;
  final bool deprecated;

  bool get isInstalled => installedVersion != null;

  factory Package.fromFormulaJson(Map<String, dynamic> j) {
    final installs = (j['installed'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return Package(
      name: j['name'] as String,
      fullName: (j['full_name'] as String?) ?? j['name'] as String,
      kind: PackageKind.formula,
      tap: j['tap'] as String?,
      desc: j['desc'] as String?,
      homepage: j['homepage'] as String?,
      latestVersion: (j['versions'] as Map?)?['stable'] as String?,
      installedVersion: installs.isEmpty
          ? null
          : installs.last['version'] as String?,
      outdated: j['outdated'] == true,
      pinned: j['pinned'] == true,
      installedOnRequest: installs.any(
        (i) => i['installed_on_request'] == true,
      ),
      dependencies: (j['dependencies'] as List? ?? const []).cast<String>(),
      caveats: j['caveats'] as String?,
      deprecated: j['deprecated'] == true,
    );
  }

  factory Package.fromCaskJson(Map<String, dynamic> j) {
    final names = (j['name'] as List? ?? const []).cast<String>();
    final installed = j['installed'] as String?;
    return Package(
      name: j['token'] as String,
      fullName: (j['full_token'] as String?) ?? j['token'] as String,
      kind: PackageKind.cask,
      displayName: names.isEmpty ? null : names.first,
      tap: j['tap'] as String?,
      desc: j['desc'] as String?,
      homepage: j['homepage'] as String?,
      latestVersion: j['version'] as String?,
      installedVersion: installed,
      outdated: j['outdated'] == true,
      pinned: j['pinned'] == true,
      // Casks have no dependency-only installs.
      installedOnRequest: installed != null,
      caveats: j['caveats'] as String?,
      deprecated: j['deprecated'] == true,
    );
  }

  /// Parses the `{"formulae": [...], "casks": [...]}` shape of
  /// `brew info --json=v2`.
  static List<Package> listFromInfoJson(Map<String, dynamic> j) => [
    for (final f in (j['formulae'] as List? ?? const []))
      Package.fromFormulaJson(f as Map<String, dynamic>),
    for (final c in (j['casks'] as List? ?? const []))
      Package.fromCaskJson(c as Map<String, dynamic>),
  ];
}

/// An entry from `brew tap-info --json`.
class Tap {
  const Tap({
    required this.name,
    this.path,
    this.remote,
    this.official = false,
    this.cloned = false,
    this.branch,
    this.lastCommit,
    this.formulaNames = const [],
    this.caskTokens = const [],
  });

  final String name;
  final String? path;
  final String? remote;
  final bool official;

  /// Whether the tap is a local git checkout. homebrew/core and
  /// homebrew/cask are usually served from the JSON API instead, so this is
  /// false for them even though they're always available.
  final bool cloned;

  /// Git details; only present for cloned taps.
  final String? branch;
  final String? lastCommit;
  final List<String> formulaNames;
  final List<String> caskTokens;

  factory Tap.fromJson(Map<String, dynamic> j) => Tap(
    name: j['name'] as String,
    path: j['path'] as String?,
    // `remote` is the URL; `custom_remote` is just a flag for whether
    // it was overridden.
    remote: j['remote'] as String?,
    official: j['official'] == true,
    cloned: j['installed'] == true,
    branch: j['branch'] as String?,
    lastCommit: j['last_commit'] as String?,
    formulaNames: (j['formula_names'] as List? ?? const []).cast<String>(),
    caskTokens: (j['cask_tokens'] as List? ?? const []).cast<String>(),
  );
}

/// An entry from `brew outdated --json=v2`.
class OutdatedEntry {
  const OutdatedEntry({
    required this.name,
    required this.kind,
    required this.installedVersions,
    required this.currentVersion,
    this.pinned = false,
  });

  final String name;
  final PackageKind kind;
  final List<String> installedVersions;
  final String currentVersion;
  final bool pinned;

  factory OutdatedEntry.fromJson(Map<String, dynamic> j, PackageKind kind) =>
      OutdatedEntry(
        name: j['name'] as String,
        kind: kind,
        installedVersions: (j['installed_versions'] as List? ?? const [])
            .cast<String>(),
        currentVersion: j['current_version'] as String? ?? '?',
        pinned: j['pinned'] == true,
      );

  static List<OutdatedEntry> listFromJson(Map<String, dynamic> j) => [
    for (final f in (j['formulae'] as List? ?? const []))
      OutdatedEntry.fromJson(f as Map<String, dynamic>, PackageKind.formula),
    for (final c in (j['casks'] as List? ?? const []))
      OutdatedEntry.fromJson(c as Map<String, dynamic>, PackageKind.cask),
  ];
}

class SearchResult {
  const SearchResult(this.name, this.kind);

  final String name;
  final PackageKind kind;
}
