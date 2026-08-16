/// 模型配置数据模型
///
/// API Key 不随配置 JSON 持久化（见 [ModelConfigRepository]），
/// 而是单独加密存储（Flutter Secure Storage），加载后注入内存对象。
class ModelConfig {
  const ModelConfig({
    required this.id,
    required this.displayName,
    required this.modelId,
    required this.baseUrl,
    required this.apiKey,
    this.headers = const {},
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.isDefault = false,
    required this.createdAt,
  });

  /// 唯一标识（UUID）
  final String id;

  /// 显示名称
  final String displayName;

  /// 模型 ID
  final String modelId;

  /// API Base URL（如 https://api.deepseek.com/v1）
  final String baseUrl;

  /// API Key（加密存储，加载后注入内存）
  final String apiKey;

  /// 自定义请求头
  final Map<String, String> headers;

  /// 温度，默认 0.7
  final double temperature;

  /// 最大 Token，默认 4096
  final int maxTokens;

  /// 是否默认
  final bool isDefault;

  /// 创建时间
  final DateTime createdAt;

  ModelConfig copyWith({
    String? id,
    String? displayName,
    String? modelId,
    String? baseUrl,
    String? apiKey,
    Map<String, String>? headers,
    double? temperature,
    int? maxTokens,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return ModelConfig(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      modelId: modelId ?? this.modelId,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      headers: headers ?? this.headers,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'modelId': modelId,
        'baseUrl': baseUrl,
        'headers': headers,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ModelConfig.fromJson(Map<String, dynamic> json) => ModelConfig(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        modelId: json['modelId'] as String,
        baseUrl: json['baseUrl'] as String,
        apiKey: '',
        headers: (json['headers'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            const {},
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 4096,
        isDefault: json['isDefault'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
