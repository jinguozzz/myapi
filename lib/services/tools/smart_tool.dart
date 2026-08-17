/// 智能工具：本地计算/单位换算（无需联网、无需 Key）。
///
/// 识别形如「10英寸=?厘米」「68华氏度=多少摄氏度」「123*456=?」的问题，
/// 直接本地计算并返回结果文本，供注入为上下文。
class SmartTool {
  SmartTool();

  /// 尝试解析并计算；非计算/换算问题返回 null
  String? run(String query) {
    final conv = _tryUnitConversion(query);
    if (conv != null) return conv;
    return _tryArithmetic(query);
  }

  // ---------- 单位换算 ----------

  static const _connector =
      r'(?:[=＝]\??|等于|到|换算成|转换成|换成|是多少|多少|\?)';

  static const _lengthAliases = <String, double>{
    '英寸': 2.54, 'inch': 2.54, 'inches': 2.54,
    '厘米': 1, 'cm': 1,
    '米': 100, 'm': 100,
    '公里': 100000, '千米': 100000, 'km': 100000,
    '英里': 160934.4, 'mile': 160934.4,
    '英尺': 30.48, 'foot': 30.48,
    '码': 91.44, 'yard': 91.44,
  };

  static const _weightAliases = <String, double>{
    '克': 1, 'g': 1,
    '千克': 1000, '公斤': 1000, 'kg': 1000,
    '斤': 500,
    '磅': 453.59237, 'lb': 453.59237,
    '盎司': 28.349523, 'oz': 28.349523,
  };

  static const _volumeAliases = <String, double>{
    '毫升': 1, 'ml': 1,
    '升': 1000, 'l': 1000,
    '加仑': 3785.411784, 'gallon': 3785.411784,
  };

  static const _speedAliases = <String, double>{
    '公里每小时': 1, '公里/小时': 1, '千米/小时': 1, 'km/h': 1,
    '英里每小时': 1.609344, '英里/小时': 1.609344, 'mph': 1.609344,
  };

  static const _dataAliases = <String, double>{
    'b': 1 / 1048576,
    'kb': 0.001, 'kb/s': 0.001,
    'mb': 1, 'gb': 1024, 'tb': 1048576,
  };

  static const _tempAliases = <String>{
    '摄氏度', '摄氏', '°C', '℃', '华氏度', '华氏', '°F', '℉', '开尔文', 'K',
  };

  static String _unitPattern() {
    final all = <String>[
      ..._lengthAliases.keys,
      ..._weightAliases.keys,
      ..._volumeAliases.keys,
      ..._speedAliases.keys,
      ..._dataAliases.keys,
      ..._tempAliases,
    ]..sort((a, b) => b.length.compareTo(a.length));
    return all.map(RegExp.escape).join('|');
  }

  String? _tryUnitConversion(String query) {
    final re = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)\s*(' + _unitPattern() + r')\s*' +
          _connector +
          r'\s*(' +
          _unitPattern() +
          r')',
      caseSensitive: false,
    );
    final m = re.firstMatch(query);
    if (m == null) return null;
    final value = double.parse(m.group(1)!);
    final from = m.group(2)!;
    final to = m.group(3)!;

    // 温度特殊处理
    final fromTemp = _tempAliases.contains(from);
    final toTemp = _tempAliases.contains(to);
    if (fromTemp && toTemp) {
      return '换算结果：$value$from = ${_convertTemp(value, from, to)} $to';
    }
    if (fromTemp || toTemp) return null;

    final fromMap = _findMap(from);
    final toMap = _findMap(to);
    if (fromMap == null || toMap == null || fromMap != toMap) return null;
    final fromFactor = fromMap[from]!;
    final toFactor = toMap[to]!;
    final result = value * fromFactor / toFactor;
    return '换算结果：$value$from = ${_fmt(result)} $to';
  }

  Map<String, double>? _findMap(String alias) {
    if (_lengthAliases.containsKey(alias)) return _lengthAliases;
    if (_weightAliases.containsKey(alias)) return _weightAliases;
    if (_volumeAliases.containsKey(alias)) return _volumeAliases;
    if (_speedAliases.containsKey(alias)) return _speedAliases;
    if (_dataAliases.containsKey(alias)) return _dataAliases;
    return null;
  }

  double _convertTemp(double value, String from, String to) {
    double c;
    switch (from) {
      case '华氏度':
      case '华氏':
      case '°F':
      case '℉':
        c = (value - 32) * 5 / 9;
      case '开尔文':
      case 'K':
        c = value - 273.15;
      default:
        c = value;
    }
    switch (to) {
      case '华氏度':
      case '华氏':
      case '°F':
      case '℉':
        return c * 9 / 5 + 32;
      case '开尔文':
      case 'K':
        return c + 273.15;
      default:
        return c;
    }
  }

  // ---------- 算术计算 ----------

  String? _tryArithmetic(String query) {
    var expr = query.trim();
    expr = expr.replaceFirst(RegExp(r'[=＝]\??\s*$'), '').trim();
    expr = expr.replaceFirst(RegExp(r'等于多少$'), '').trim();
    expr = expr.replaceFirst(RegExp(r'是多少$'), '').trim();
    expr = expr.replaceFirst(RegExp(r'\?$'), '').trim();
    expr = expr.replaceAll(' ', '');
    if (expr.isEmpty) return null;
    if (!RegExp(r'^[0-9+\-*/().]+$').hasMatch(expr)) return null;
    if (!RegExp(r'[+\-*/]').hasMatch(expr)) return null;
    try {
      final result = _eval(expr);
      return '计算结果：$expr = ${_fmt(result)}';
    } catch (_) {
      return null;
    }
  }

  int _pos = 0;
  String _src = '';

  double _eval(String expr) {
    _src = expr;
    _pos = 0;
    final v = _addSub();
    if (_pos != _src.length) throw const FormatException();
    return v;
  }

  double _addSub() {
    var v = _mulDiv();
    while (_pos < _src.length) {
      final c = _src[_pos];
      if (c == '+') {
        _pos++;
        v += _mulDiv();
      } else if (c == '-') {
        _pos++;
        v -= _mulDiv();
      } else {
        break;
      }
    }
    return v;
  }

  double _mulDiv() {
    var v = _num();
    while (_pos < _src.length) {
      final c = _src[_pos];
      if (c == '*') {
        _pos++;
        v *= _num();
      } else if (c == '/') {
        _pos++;
        v /= _num();
      } else {
        break;
      }
    }
    return v;
  }

  double _num() {
    if (_pos < _src.length && _src[_pos] == '-') {
      _pos++;
      return -_num();
    }
    if (_pos < _src.length && _src[_pos] == '(') {
      _pos++;
      final v = _addSub();
      if (_pos < _src.length && _src[_pos] == ')') _pos++;
      return v;
    }
    final start = _pos;
    while (_pos < _src.length &&
        (_src[_pos] == '.' || (_src[_pos].codeUnitAt(0) >= 48 && _src[_pos].codeUnitAt(0) <= 57))) {
      _pos++;
    }
    if (start == _pos) throw const FormatException();
    return double.parse(_src.substring(start, _pos));
  }

  /// 数字格式化：整数不带小数点，小数最多保留 4 位并去尾零
  String _fmt(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
