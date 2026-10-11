import 'dart:io';

import 'package:flutter/material.dart';

import '../brew/brew_client.dart';
import '../brew/models.dart';
import '../state/app_state.dart';
import 'task_dialog.dart';

/// Makes the [AppState] available to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  /// Reads the state and rebuilds the caller when it changes.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without subscribing, for use in callbacks.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Runs [task] in a dialog showing its live output, then refreshes the app
/// state. Returns whether the command succeeded.
Future<bool> runTask(BuildContext context, BrewTask task) async {
  final state = AppScope.read(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TaskDialog(task: task),
  );
  // Not awaited: the lists update in place once brew answers.
  state.refresh();
  return task.succeeded;
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'OK',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void openUrl(String url) => Process.run('open', [url]);

IconData kindIcon(PackageKind kind) =>
    kind == PackageKind.formula ? Icons.terminal : Icons.apps;

/// Title row + optional controls shown at the top of every page.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 12),
              if (state.loading)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              ...actions,
              IconButton(
                tooltip: 'Reload',
                onPressed: state.loading ? null : state.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            ErrorBanner(state.error!),
          ],
          if (bottom != null) ...[const SizedBox(height: 12), bottom!],
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.error, {super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        '$error',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

/// A search box used to filter lists.
class FilterField extends StatelessWidget {
  const FilterField({super.key, required this.onChanged, this.hint = 'Filter'});

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      isDense: true,
      prefixIcon: const Icon(Icons.filter_list),
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );
}
