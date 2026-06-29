/// Evalúa expresiones matemáticas simples: "50+30", "3*12", "100-25/2"
/// Soporta +  -  *  /  con precedencia correcta (* / antes que + -)
/// Retorna null si la expresión es inválida.
double? parseAmountExpression(String raw) {
  final input = raw.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (input.isEmpty) return null;
  if (!input.contains(RegExp(r'[+\-*/]'))) return double.tryParse(input);
  try {
    return _Parser(input).parse();
  } catch (_) {
    return null;
  }
}

/// Devuelve true si el texto contiene algún operador matemático.
bool isExpression(String raw) =>
    raw.replaceAll(',', '.').contains(RegExp(r'[+\-*/]'));

// ── Parser recursivo descendente ─────────────────────────────────────────────

class _Parser {
  final List<String> _tokens;
  int _pos = 0;

  _Parser(String input) : _tokens = _tokenize(input);

  double parse() => _expr();

  double _expr() {
    var left = _term();
    while (_pos < _tokens.length &&
        (_tokens[_pos] == '+' || _tokens[_pos] == '-')) {
      final op = _tokens[_pos++];
      final right = _term();
      left = op == '+' ? left + right : left - right;
    }
    return left;
  }

  double _term() {
    var left = _factor();
    while (_pos < _tokens.length &&
        (_tokens[_pos] == '*' || _tokens[_pos] == '/')) {
      final op = _tokens[_pos++];
      final right = _factor();
      if (op == '/' && right == 0) throw Exception('div0');
      left = op == '*' ? left * right : left / right;
    }
    return left;
  }

  double _factor() => double.parse(_tokens[_pos++]);

  static List<String> _tokenize(String s) {
    final tokens = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '-' && i == 0) {
        buf.write(c);
      } else if ('+-*/'.contains(c)) {
        if (buf.isNotEmpty) { tokens.add(buf.toString()); buf.clear(); }
        tokens.add(c);
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }
}
