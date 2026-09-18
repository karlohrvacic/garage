import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Three ways to be modal, and no fourth (`docs/architecture/12-navigation.md`,
/// "Screens, sheets and dialogs").
///
/// - a form is an adaptive entry sheet (`showAdaptiveEntrySheet`),
/// - a choice is an adaptive choice (`showAdaptiveChoice`, `showPickOne`),
/// - a confirmation, a notice or a one-line prompt is a dialog, through
///   `confirmDestructive`, `confirmAction`, `showNotice` or `showTextPrompt`.
///
/// The rule was practised and written down nowhere, and about fifteen surfaces
/// had drifted from it: six bare bottom sheets that never adapted to a wide
/// window, two lists in a `SimpleDialog`, a form in an `AlertDialog`, and seven
/// confirmations built by hand beside the helper that already did it.
void main() {
  /// Where the helpers live, and so where the primitives are meant to be.
  const helpers = {
    'lib/core/widgets/adaptive.dart',
    'lib/core/widgets/confirm_delete.dart',
    'lib/core/widgets/discard_guard.dart',
    'lib/core/widgets/text_prompt.dart',
  };

  /// Everything else that may call a primitive, and why. A new entry has to
  /// say why none of the helpers will do.
  const allowed = {
    'lib/main.dart':
        'a password-recovery link lands before any screen exists, so the '
        'root navigator is all there is, and a password is not the field a '
        'text prompt draws',
    'lib/features/settings/data/fuelio_import_action.dart':
        'the spinner that bars the screen while an import runs: nothing to '
        'choose, type or confirm, and nothing to dismiss it with',
  };

  final primitive = RegExp(
    r'\b(showModalBottomSheet|showDialog|showGeneralDialog|'
    r'showCupertinoModalPopup|showCupertinoDialog|AlertDialog|SimpleDialog)\b',
  );

  /// The file with its comments taken out: a doc comment that names
  /// `showDialog` to explain why it is not used is not a call.
  String code(File file) => file
      .readAsLinesSync()
      .map((line) => line.replaceFirst(RegExp(r'//.*$'), ''))
      .join('\n');

  final sources = [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.contains('/l10n/'))
        entity,
  ];

  test('nothing is modal except through the shared helpers', () {
    final offenders = [
      for (final file in sources)
        if (!helpers.contains(file.path) &&
            !allowed.containsKey(file.path) &&
            primitive.hasMatch(code(file)))
          file.path,
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'these open a sheet or dialog of their own: $offenders. Use the '
          'helper for what it is (a form, a choice, a confirmation, a notice '
          'or a prompt), or add it to `allowed` with the reason none fits.',
    );
  });

  test('the allowance is still needed', () {
    // An entry whose file no longer does the thing is a reason nobody will
    // reread, and a place for the next exception to hide.
    for (final path in allowed.keys) {
      expect(primitive.hasMatch(code(File(path))), isTrue, reason: path);
    }
  });

  test('every form that takes typing asks before throwing it away', () {
    // Decision 79: a sheet dismissed by a stray Back or Escape used to drop
    // whatever was typed into it, and ten sheets asked while eight did not.
    final typing = RegExp(r'\b(TextField|TextFormField)\(');
    final unguarded = [
      for (final file in sources)
        if (!helpers.contains(file.path) &&
            file.path != 'lib/core/widgets/entry_sheet_body.dart')
          if (code(file) case final text
              when text.contains('showAdaptiveEntrySheet') &&
                  typing.hasMatch(text) &&
                  !text.contains('DiscardGuard('))
            file.path,
    ];

    expect(
      unguarded,
      isEmpty,
      reason:
          'these open an entry sheet with a text field and no DiscardGuard: '
          '$unguarded',
    );
  });
}
