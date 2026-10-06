// BRIXTA_FIELD_APP_CONTRACT_V2
//
// The phone's copy of the shared field-app rules: when a question is shown
// and how a calculated answer is worked out. It mirrors
// salesapp_backend/src/platform/fieldAppContract.ts (the server re-checks
// everything on save, so the server always has the final word).

class FieldCondition {
  const FieldCondition({
    required this.field,
    required this.op,
    required this.values,
  });

  static FieldCondition? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final field = raw['field']?.toString() ?? '';
    if (field.isEmpty) return null;
    final rawValues = raw['values'];
    final values = rawValues is List
        ? rawValues
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList()
        : raw['equals'] != null
        ? [raw['equals'].toString()]
        : <String>[];
    final op = raw['op']?.toString() ??
        (raw['equals'] != null ? 'is' : 'filled');
    return FieldCondition(field: field, op: op, values: values);
  }

  final String field;

  /// is · is_not · any_of · filled · empty
  final String op;
  final List<String> values;
}

String _plain(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

List<String> answerTokens(Object? value) {
  if (value == null) return const [];
  if (value is bool) return [value ? 'Yes' : 'No'];
  if (value is num) return [_plain(value)];
  if (value is List) {
    return value
        .map((e) => e is num ? _plain(e) : (e?.toString().trim() ?? ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is Map) return const ['(set)'];
  final text = value.toString().trim();
  return text.isEmpty ? const [] : [text];
}

bool conditionMet(FieldCondition condition, Map<String, dynamic> values) {
  final tokens = answerTokens(
    values[condition.field],
  ).map((e) => e.toLowerCase()).toList();
  final wanted = condition.values.map((e) => e.toLowerCase()).toList();
  switch (condition.op) {
    case 'filled':
      return tokens.isNotEmpty;
    case 'empty':
      return tokens.isEmpty;
    case 'is':
      return wanted.isNotEmpty && tokens.contains(wanted.first);
    case 'is_not':
      return wanted.isNotEmpty && !tokens.contains(wanted.first);
    case 'any_of':
      return wanted.any(tokens.contains);
    default:
      return true;
  }
}

bool fieldVisible(FieldCondition? showWhen, Map<String, dynamic> values) =>
    showWhen == null || conditionMet(showWhen, values);

double? toNumber(Object? value) {
  if (value is num) return value.isFinite ? value.toDouble() : null;
  if (value is! String) return null;
  final cleaned = value.replaceAll(RegExp(r'[,\s₹$€£]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

// ---------------------------------------------------------------------------
// Formulas: numbers, question keys, + - * / and brackets.

class _Token {
  const _Token(this.kind, {this.number, this.text});

  /// num · ref · op · open · close
  final String kind;
  final double? number;
  final String? text;
}

List<_Token>? _tokenize(String formula) {
  final tokens = <_Token>[];
  var i = 0;
  final digit = RegExp(r'[0-9.]');
  final letter = RegExp(r'[a-z]');
  final word = RegExp(r'[a-z0-9_]');
  while (i < formula.length) {
    final ch = formula[i];
    if (ch == ' ' || ch == '\t') {
      i++;
    } else if (digit.hasMatch(ch)) {
      var j = i;
      while (j < formula.length && digit.hasMatch(formula[j])) {
        j++;
      }
      final value = double.tryParse(formula.substring(i, j));
      if (value == null) return null;
      tokens.add(_Token('num', number: value));
      i = j;
    } else if (letter.hasMatch(ch)) {
      var j = i;
      while (j < formula.length && word.hasMatch(formula[j])) {
        j++;
      }
      tokens.add(_Token('ref', text: formula.substring(i, j)));
      i = j;
    } else if (ch == '+' || ch == '-' || ch == '*' || ch == '/') {
      tokens.add(_Token('op', text: ch));
      i++;
    } else if (ch == '×') {
      tokens.add(const _Token('op', text: '*'));
      i++;
    } else if (ch == '(') {
      tokens.add(const _Token('open'));
      i++;
    } else if (ch == ')') {
      tokens.add(const _Token('close'));
      i++;
    } else {
      return null;
    }
  }
  return tokens;
}

class _Parser {
  _Parser(this.tokens, this.values);

  final List<_Token> tokens;
  final Map<String, dynamic> values;
  int position = 0;
  bool failed = false;
  bool missing = false;

  _Token? get _peek => position < tokens.length ? tokens[position] : null;

  double _primary() {
    final token = _peek;
    if (token == null) {
      failed = true;
      return 0;
    }
    if (token.kind == 'op' && token.text == '-') {
      position++;
      return -_primary();
    }
    if (token.kind == 'num') {
      position++;
      return token.number!;
    }
    if (token.kind == 'ref') {
      position++;
      final value = toNumber(values[token.text]);
      if (value == null) missing = true;
      return value ?? 0;
    }
    if (token.kind == 'open') {
      position++;
      final inner = _sum();
      if (_peek?.kind != 'close') {
        failed = true;
        return 0;
      }
      position++;
      return inner;
    }
    failed = true;
    return 0;
  }

  double _product() {
    var left = _primary();
    while (!failed) {
      final token = _peek;
      if (token == null ||
          token.kind != 'op' ||
          (token.text != '*' && token.text != '/')) {
        break;
      }
      position++;
      final right = _primary();
      if (token.text == '*') {
        left = left * right;
      } else if (right == 0) {
        missing = true;
        left = 0;
      } else {
        left = left / right;
      }
    }
    return left;
  }

  double _sum() {
    var left = _product();
    while (!failed) {
      final token = _peek;
      if (token == null ||
          token.kind != 'op' ||
          (token.text != '+' && token.text != '-')) {
        break;
      }
      position++;
      final right = _product();
      left = token.text == '+' ? left + right : left - right;
    }
    return left;
  }
}

/// Null when an input is missing or the maths is impossible (÷ 0).
double? evaluateFormula(
  String? formula,
  Map<String, dynamic> values, {
  int decimals = 2,
}) {
  if (formula == null || formula.trim().isEmpty) return null;
  final tokens = _tokenize(formula.trim());
  if (tokens == null || tokens.isEmpty) return null;
  final parser = _Parser(tokens, values);
  final result = parser._sum();
  if (parser.failed ||
      parser.missing ||
      parser.position < tokens.length ||
      !result.isFinite) {
    return null;
  }
  final places = decimals < 0 ? 0 : (decimals > 4 ? 4 : decimals);
  var factor = 1.0;
  for (var i = 0; i < places; i++) {
    factor *= 10;
  }
  return (result * factor).round() / factor;
}

String formatNumber(double value, {String? unit, bool currency = false}) {
  final whole = value == value.roundToDouble();
  final text = whole ? _withCommas(value.toInt()) : value.toString();
  if (currency) return '${unit ?? '₹'} $text';
  return unit == null || unit.isEmpty ? text : '$text $unit';
}

/// Indian grouping: 1,25,000
String _withCommas(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  if (digits.length <= 3) return negative ? '-$digits' : digits;
  final last = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${negative ? '-' : ''}${groups.join(',')},$last';
}
