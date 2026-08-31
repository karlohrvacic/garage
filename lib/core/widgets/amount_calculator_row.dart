import 'package:flutter/material.dart';

import '../../domain/format/amount_expression.dart';
import '../format/unit_format.dart';
import '../theme/garage_tokens.dart';

/// The operators a decimal number pad does not have, and the running total of
/// whatever they add up to.
///
/// A money field asks for `TextInputType.numberWithOptions(decimal: true)`,
/// whose Android keypad has digits, a separator and nothing else — so an
/// amount field that understands `2*1.50` would be unreachable without this
/// row. Offering the operators here keeps the number pad for the common case,
/// where the amount really is just a number.
class AmountCalculatorRow extends StatelessWidget {
  const AmountCalculatorRow({
    super.key,
    required this.controller,
    required this.format,
  });

  final TextEditingController controller;
  final UnitFormat format;

  /// The glyphs people recognise rather than the ASCII the parser wants;
  /// [evaluateAmount] accepts both.
  static const _operators = ['+', '−', '×', '÷'];

  void _insert(String operator) {
    final value = controller.value;
    final selection = value.selection;
    // A field that was never focused reports no selection at all, in which
    // case the operator belongs after what is already there.
    if (!selection.isValid) {
      controller.value = TextEditingValue(
        text: '${value.text}$operator',
        selection: TextSelection.collapsed(offset: value.text.length + 1),
      );
      return;
    }
    final text =
        selection.textBefore(value.text) +
        operator +
        selection.textAfter(value.text);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        final result = isAmountExpression(text) ? evaluateAmount(text) : null;
        return Padding(
          padding: const EdgeInsets.only(top: GarageTokens.space2),
          child: Row(
            children: [
              for (final operator in _operators)
                Padding(
                  padding: const EdgeInsets.only(right: GarageTokens.space2),
                  child: _OperatorButton(
                    operator: operator,
                    onPressed: () => _insert(operator),
                  ),
                ),
              const Spacer(),
              // Silent for a plain number, and silent again while a sum is
              // half-typed: a total that is briefly wrong is worse than no
              // total at all.
              if (result != null)
                Text(
                  '= ${format.formatMoney(result)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OperatorButton extends StatelessWidget {
  const _OperatorButton({required this.operator, required this.onPressed});

  final String operator;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // A touch target, not a dense toolbar: this sits under a field being
      // typed into with a thumb.
      width: 44,
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          textStyle: Theme.of(context).textTheme.titleMedium,
        ),
        child: Text(operator),
      ),
    );
  }
}
