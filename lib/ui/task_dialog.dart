import 'package:flutter/material.dart';

import '../brew/brew_client.dart';

/// Runs a [BrewTask] and shows its output as it streams in.
class TaskDialog extends StatefulWidget {
  const TaskDialog({super.key, required this.task});

  final BrewTask task;

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.task.addListener(_onOutput);
    widget.task.run();
  }

  @override
  void dispose() {
    widget.task.removeListener(_onOutput);
    _scroll.dispose();
    super.dispose();
  }

  void _onOutput() {
    if (!mounted) return;
    // Follow the output, unless the user scrolled up to read something.
    final follow =
        !_scroll.hasClients ||
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 40;
    setState(() {});
    if (follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final scheme = Theme.of(context).colorScheme;
    final Widget status = task.running
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : task.succeeded
        ? Icon(Icons.check_circle, color: scheme.primary)
        : Icon(Icons.error, color: scheme.error);

    return AlertDialog(
      title: Row(
        children: [
          status,
          const SizedBox(width: 12),
          Expanded(child: Text(task.title)),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 420,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            controller: _scroll,
            child: SelectableText(
              task.lines.join('\n'),
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
            ),
          ),
        ),
      ),
      actions: [
        if (!task.running && !task.succeeded)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Exited with code ${task.exitCode}',
              style: TextStyle(color: scheme.error),
            ),
          ),
        if (task.running)
          TextButton(onPressed: task.cancel, child: const Text('Cancel'))
        else
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
      ],
    );
  }
}
