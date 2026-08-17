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

/// 实时天气服务（wttr.in，免费无需 API Key）
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
    try {
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
    } catch (_) {
      return null;
    }
  }
}
