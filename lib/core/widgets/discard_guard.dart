import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

/// Asks before a sheet or form with typed-in fields is dismissed.
///
/// On web, Escape and the browser's Back are reflexes; on Android the back
/// gesture is a swipe from the edge that happens by accident. A fill-up is
/// thirty seconds of data typed at a pump and cannot be re-derived, and
/// every sheet used to discard it in silence.
///
/// "Typed-in" is literal: a controller counts as dirty only when it changed
/// while its own field had focus, so a station or a price the sheet filled
/// in by itself does not make an untouched sheet ask. [alsoDirty] covers
/// what is not a text field (a picked date, a toggle).
///
/// Registers a [PopScope] and draws nothing; put it anywhere in the sheet.
class DiscardGuard extends StatefulWidget {
  const DiscardGuard({required this.controllers, this.alsoDirty, super.key});

  final List<TextEditingController> controllers;
  final bool Function()? alsoDirty;

  @override
  State<DiscardGuard> createState() => _DiscardGuardState();
}

class _DiscardGuardState extends State<DiscardGuard> {
  bool _typed = false;
  final _listeners = <TextEditingController, VoidCallback>{};

  /// What each controller last held: a controller notifies on a selection
  /// change too, and selecting a prefilled price on focus is not typing.
  final _lastText = <TextEditingController, String>{};

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(DiscardGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controllers != widget.controllers) {
      _unlisten();
      _listen();
    }
  }

  void _listen() {
    for (final controller in widget.controllers) {
      _lastText[controller] = controller.text;
      void onChange() {
        final changed = controller.text != _lastText[controller];
        _lastText[controller] = controller.text;
        if (_typed || !changed || !_focusedOn(controller)) {
          return;
        }
        setState(() => _typed = true);
      }

      _listeners[controller] = onChange;
      controller.addListener(onChange);
    }
  }

  void _unlisten() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _listeners.clear();
    _lastText.clear();
  }

  /// Whether [controller] belongs to the field that currently has focus: the
  /// only way a change to it is the person's own.
  static bool _focusedOn(TextEditingController controller) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return false;
    }
    final field = context.findAncestorWidgetOfExactType<EditableText>();
    return field?.controller == controller;
  }

  bool get _dirty => _typed || (widget.alsoDirty?.call() ?? false);

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final navigator = Navigator.of(context);
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(l10n.discardTitle),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.discardKeep),
                ),
                TextButton(
                  key: const Key('discard-confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.discardConfirm),
                ),
              ],
            );
          },
        );
        if (discard == true && mounted) {
          setState(() => _typed = false);
          navigator.pop();
        }
      },
      child: const SizedBox.shrink(),
    );
  }
}
