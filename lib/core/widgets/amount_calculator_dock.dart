import 'package:flutter/material.dart';

import '../format/unit_format.dart';
import 'amount_calculator_row.dart';

/// One amount field of a sheet, paired with the focus node the dock watches.
class AmountField {
  const AmountField(this.controller, this.focusNode);

  final TextEditingController controller;
  final FocusNode focusNode;
}

/// The + − × ÷ row for whichever amount field has focus, docked once above
/// Save rather than under each field.
///
/// A row per field appeared on focus and pushed Save below the fold; holding
/// each row's height instead left two blank bands on a first fill-up that
/// read as a rendering fault. One reserved slot at the bottom is where a
/// keyboard accessory would be, and nothing above it moves.
class AmountCalculatorDock extends StatefulWidget {
  const AmountCalculatorDock({
    required this.fields,
    required this.format,
    this.reserve = true,
    super.key,
  });

  final List<AmountField> fields;
  final UnitFormat format;

  /// Whether the slot is held before any field has been used. A sheet whose
  /// Save sits right below reserves it, so Save never moves; a form with one
  /// amount field inside a fold does not, since a blank band inside the fold
  /// is what a person sees first.
  final bool reserve;

  @override
  State<AmountCalculatorDock> createState() => _AmountCalculatorDockState();
}

class _AmountCalculatorDockState extends State<AmountCalculatorDock> {
  /// The field last typed into: when focus moves to Notes, its running
  /// total stays on screen, since the total describes the value, not the
  /// keyboard.
  AmountField? _last;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        for (final f in widget.fields) f.focusNode,
      ]),
      builder: (context, _) {
        final focused = widget.fields
            .where((f) => f.focusNode.hasFocus)
            .firstOrNull;
        if (focused != null) {
          _last = focused;
        }
        final shown = focused ?? _last;
        if (shown == null && !widget.reserve) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: AmountCalculatorRow.height,
          child: shown == null
              ? null
              : AmountCalculatorRow(
                  controller: shown.controller,
                  format: widget.format,
                  focusNode: shown.focusNode,
                ),
        );
      },
    );
  }
}
