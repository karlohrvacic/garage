/// Reads what someone typed into a money field, which is usually a number and
/// sometimes a sum.
///
/// The motivating case is a parking ticket extended by an hour: the amount is
/// no longer 1.50 but `2*1.50`, and doing that arithmetic in your head at a
/// parking meter is exactly the kind of small tax an app should absorb.
///
/// Deliberately not a general expression language:
///
///   * No parentheses. `*` and `/` binding tighter than `+` and `-` covers
///     every amount anyone has typed into a receipt; brackets would buy a
///     grammar and a class of confusing errors for nothing.
///   * A comma is a decimal mark, never a separator. Croatian writes 12,50 and
///     that reading has to survive multiplication — `2*1,50` is three euros,
///     not a list.
///   * Division by zero is a refusal, not infinity. An `Infinity` reaching the
///     amount column would be a number the rest of the app has no story for.
library;

/// The value of [input], or null if it is empty or not something this reads.
///
/// Null is the same answer a bare `double.tryParse` gave before, so callers
/// keep the invalid-amount state they already have.
double? evaluateAmount(String input) {
  final tokens = _tokenize(input);
  if (tokens == null || tokens.isEmpty) {
    return null;
  }
  return _evaluate(tokens);
}

/// Whether [input] is arithmetic rather than a plain number, and so worth
/// echoing the result of back to the person typing it.
///
/// True for a half-typed `2*` as well: the field is being used as a
/// calculator, and the result line saying nothing yet is the honest display of
/// an unfinished sum.
bool isAmountExpression(String input) {
  final normalized = _normalize(input);
  // Skip the first character, where a `-` is a sign rather than an operation.
  for (var i = 1; i < normalized.length; i++) {
    if (_operators.containsKey(normalized[i])) {
      return true;
    }
  }
  return false;
}

const _operators = <String, _Operator>{
  '+': _Operator.add,
  '-': _Operator.subtract,
  '*': _Operator.multiply,
  '/': _Operator.divide,
};

enum _Operator {
  add(precedence: 1),
  subtract(precedence: 1),
  multiply(precedence: 2),
  divide(precedence: 2);

  const _Operator({required this.precedence});

  final int precedence;

  double? apply(double left, double right) {
    return switch (this) {
      _Operator.add => left + right,
      _Operator.subtract => left - right,
      _Operator.multiply => left * right,
      // Refused rather than returned as infinity, and `-0.0 == 0` covers the
      // negative zero a subtraction can produce.
      _Operator.divide => right == 0 ? null : left / right,
    };
  }
}

/// The keypad row inserts the glyphs people recognise; the parser wants ASCII.
/// Whitespace goes with them, so `2 * 1,50` and `2*1.50` are the same input.
String _normalize(String input) {
  return input
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'\s'), '');
}

/// Numbers and operators in the order they were typed, or null if [input]
/// contains anything else — a letter, a stray bracket, two decimal points in
/// one number, an operator with nothing to work on.
List<Object>? _tokenize(String input) {
  final normalized = _normalize(input);
  if (normalized.isEmpty) {
    return const [];
  }

  final tokens = <Object>[];
  final number = StringBuffer();

  /// False when the characters read so far are not a number after all —
  /// `1.2.3` is the case that gets this far, having only legal characters in
  /// an illegal order.
  bool flushNumber() {
    if (number.isEmpty) {
      return true;
    }
    final value = double.tryParse(number.toString());
    if (value == null) {
      return false;
    }
    tokens.add(value);
    number.clear();
    return true;
  }

  for (var i = 0; i < normalized.length; i++) {
    final character = normalized[i];
    final operator = _operators[character];

    if (operator == null) {
      if (!_isNumeric(character)) {
        return null;
      }
      number.write(character);
      continue;
    }

    // A `-` with no left operand is a sign, and belongs to the number being
    // read rather than to the tokens.
    final startsANumber = number.isEmpty && tokens.lastOrNull is! double;
    if (startsANumber) {
      if (operator != _Operator.subtract) {
        return null;
      }
      number.write('-');
      continue;
    }
    if (number.isEmpty && tokens.lastOrNull is! double) {
      return null;
    }

    if (!flushNumber()) {
      return null;
    }
    tokens.add(operator);
  }

  // A trailing operator has no right operand; the sum is unfinished.
  if (number.isEmpty || !flushNumber()) {
    return null;
  }
  return tokens;
}

bool _isNumeric(String character) {
  if (character == '.') {
    return true;
  }
  final code = character.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}

/// Two passes over the token list: the tighter-binding operators collapse
/// first, then what is left evaluates left to right.
double? _evaluate(List<Object> tokens) {
  final collapsed = <Object>[];
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token is _Operator && token.precedence == 2) {
      final left = collapsed.removeLast() as double;
      final right = tokens[++i] as double;
      final value = token.apply(left, right);
      if (value == null) {
        return null;
      }
      collapsed.add(value);
      continue;
    }
    collapsed.add(token);
  }

  var total = collapsed.first as double;
  for (var i = 1; i < collapsed.length; i += 2) {
    final operator = collapsed[i] as _Operator;
    final value = operator.apply(total, collapsed[i + 1] as double);
    if (value == null) {
      return null;
    }
    total = value;
  }
  return total;
}
