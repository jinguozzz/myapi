import 'dart:convert';

import 'package:http/http.dart' as http;

/// 实时天气信息
class WeatherInfo {
  const WeatherInfo({
    required this.city,
    required this.tempC,
    required this.desc,
    required this.feelsLike,
    required this.humidity,
    required this.windKmph,
  });

  final String city;
  final String tempC;
  final String desc;
  final String feelsLike;
  final String humidity;
  final String windKmph;

  @override
  String toString() =>
      '城市：$city\n天气：$desc\n温度：$tempC°C（体感 $feelsLike°C）'
      '\n湿度：$humidity%\n风速：$windKmph km/h';
}

/// 实时天气服务。
/// 主用 Open-Meteo（先按地名查坐标，再取实时天气，免费无需 Key），
/// wttr.in 作兜底。
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// 常用城市清单（用于从问题中识别城市）
  static const _cities = <String>[
    '北京', '上海', '天津', '重庆',
    '石家庄', '太原', '沈阳', '长春', '哈尔滨', '南京', '杭州', '合肥',
    '福州', '南昌', '济南', '郑州', '武汉', '长沙', '广州', '南宁',
    '海口', '成都', '贵阳', '昆明', '拉萨', '西安', '兰州', '西宁',
    '银川', '乌鲁木齐', '呼和浩特', '台北', '香港', '澳门',
    '深圳', '苏州', '青岛', '大连', '厦门', '宁波', '无锡', '东莞',
    '佛山', '温州', '珠海', '三亚', '洛阳', '桂林', '扬州', '徐州',
  ];

  /// 天气相关关键词
  static const _weatherKeywords = <String>[
    '天气', '气温', '温度', '下雨', '下雪', '降雨', '湿度', '台风',
  ];

  /// 从问题文本中识别地名；未命中返回 null
  String? extractCity(String query) {
    // 1) 内置城市清单（含"市"后缀）
    final known =
        RegExp('(?:${_cities.join('|')})市?').firstMatch(query);
    if (known != null) return known.group(0)!.replaceAll('市', '');

    // 2) 行政区后缀：X县 / X区 / X镇（覆盖小县城）
    final suffix =
        RegExp(r'[\u4e00-\u9fa5]{1,5}(?:县|区|镇)').firstMatch(query);
    if (suffix != null) return suffix.group(0)!;

    // 3) 兜底：取天气相关词前面的文字（去掉常见时间/语气词）
    var idx = -1;
    for (final k in _weatherKeywords) {
      final i = query.indexOf(k);
      if (i >= 0 && (idx < 0 || i < idx)) idx = i;
    }
    if (idx > 0) {
      var candidate = query.substring(0, idx);
      for (final w in const [
        '今天', '现在', '明天', '后天', '昨天', '昨日', '实时', '天气预报',
        '请问', '帮我', '查一下', '看看', '想知道', '搜索', '查询',
      ]) {
        candidate = candidate.replaceAll(w, '');
      }
      candidate = candidate.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
      if (candidate.isNotEmpty && candidate.length <= 8) return candidate;
    }
    return null;
  }

  /// 查询指定城市实时天气；失败返回 null
  Future<WeatherInfo?> fetch(String city) async {
    // 1) Open-Meteo：先地理编码再取实时天气（可靠）
    try {
      final geo = await _geocode(city);
      if (geo != null) {
        final info = await _openMeteo(geo.lat, geo.lon, geo.name);
        if (info != null) return info;
      }
    } catch (_) {}
    // 2) wttr.in 兜底
    try {
      return await _wttrIn(city);
    } catch (_) {
      return null;
    }
  }

  /// Open-Meteo 地理编码
  Future<({double lat, double lon, String name})?> _geocode(String city) async {
    final uri = Uri.parse('https://geocoding-api.open-meteo.com/v1/search')
        .replace(queryParameters: {
      'name': city,
      'count': '1',
      'language': 'zh',
      'format': 'json',
    });
    final resp = await _client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    final r = results.first as Map<String, dynamic>;
    return (
      lat: (r['latitude'] as num).toDouble(),
      lon: (r['longitude'] as num).toDouble(),
      name: (r['name'] as String?) ?? city,
    );
  }

  /// Open-Meteo 实时天气
  Future<WeatherInfo?> _openMeteo(
    double lat,
    double lon,
    String name,
  ) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast').replace(
      queryParameters: {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'current':
            'temperature_2m,apparent_temperature,relative_humidity_2m,'
            'wind_speed_10m,weather_code',
        'timezone': 'auto',
      },
    );
    final resp = await _client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return null;

    String v(String key) =>
        current[key] == null ? '?' : current[key].toString();

    return WeatherInfo(
      city: name,
      tempC: v('temperature_2m'),
      desc: _weatherCodeToText(current['weather_code']),
      feelsLike: v('apparent_temperature'),
      humidity: v('relative_humidity_2m'),
      windKmph: v('wind_speed_10m'),
    );
  }

  /// WMO 天气代码 → 中文描述
  String _weatherCodeToText(dynamic code) {
    const map = <int, String>{
      0: '晴',
      1: '大致晴朗',
      2: '局部多云',
      3: '阴',
      45: '雾',
      48: '雾凇',
      51: '毛毛雨',
      53: '毛毛雨',
      55: '毛毛雨',
      61: '小雨',
      63: '中雨',
      65: '大雨',
      71: '小雪',
      73: '中雪',
      75: '大雪',
      80: '阵雨',
      81: '强阵雨',
      82: '暴雨',
      95: '雷暴',
      96: '雷暴伴冰雹',
      99: '强雷暴伴冰雹',
    };
    final c = (code as num?)?.toInt() ?? -1;
    return map[c] ?? '多云';
  }

  /// wttr.in 兜底
  Future<WeatherInfo?> _wttrIn(String city) async {
    final uri = Uri.parse(
      'https://wttr.in/${Uri.encodeComponent(city)}?format=j1&lang=zh',
    );
    final resp = await _client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;

    final current = (json['current_condition'] as List<dynamic>?)?[0]
        as Map<String, dynamic>?;
    if (current == null) return null;

    final area = (json['nearest_area'] as List<dynamic>?)?[0]
        as Map<String, dynamic>?;
    final areaName = ((area?['areaName'] as List<dynamic>?)?[0]
        as Map<String, dynamic>?)?['value'] as String?;

    String desc(String key) =>
        ((current[key] as List<dynamic>?)?[0] as Map<String, dynamic>?)
                ?['value'] as String? ??
        '';

    return WeatherInfo(
      city: areaName ?? city,
      tempC: (current['temp_C'] as String?) ?? '?',
      desc: desc('weatherDesc'),
      feelsLike: (current['FeelsLikeC'] as String?) ?? '?',
      humidity: (current['humidity'] as String?) ?? '?',
      windKmph: (current['windspeedKmph'] as String?) ?? '?',
    );
  }
}
