import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 加密存储服务（基于 Flutter Secure Storage）
///
/// 用于保存 API Key 等敏感信息，密钥以模型 ID 为键隔离存储。
class SecureStorageService {
  const SecureStorageService();

  static const _storage = FlutterSecureStorage();

  String _key(String modelId) => 'api_key_$modelId';

  Future<void> saveApiKey(String modelId, String apiKey) =>
      _storage.write(key: _key(modelId), value: apiKey);

  Future<String?> readApiKey(String modelId) => _storage.read(key: _key(modelId));

  Future<void> deleteApiKey(String modelId) => _storage.delete(key: _key(modelId));
}
