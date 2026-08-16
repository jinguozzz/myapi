import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/model_config.dart';
import 'secure_storage_service.dart';

/// 模型配置仓库。
///
/// 配置以 JSON 存入 SharedPreferences（不含 API Key），
/// API Key 经 [SecureStorageService] 加密存储。
class ModelConfigRepository {
  ModelConfigRepository({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? const SecureStorageService();

  static const _prefsKey = 'model_configs';

  final SecureStorageService _secureStorage;

  /// 加载全部模型（注入加密存储中的 API Key）
  Future<List<ModelConfig>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final configs = <ModelConfig>[];
      for (final item in list) {
        final config = ModelConfig.fromJson(item as Map<String, dynamic>);
        final apiKey = await _secureStorage.readApiKey(config.id) ?? '';
        configs.add(config.copyWith(apiKey: apiKey));
      }
      return configs;
    } catch (_) {
      return [];
    }
  }

  /// 新增或更新一个模型
  Future<void> save(ModelConfig config) async {
    final list = await loadAll();
    final index = list.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      list[index] = config;
    } else {
      list.add(config);
    }
    await _persist(list);
    await _secureStorage.saveApiKey(config.id, config.apiKey);
  }

  /// 删除模型及其加密的 API Key
  Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((c) => c.id == id);
    await _persist(list);
    await _secureStorage.deleteApiKey(id);
  }

  /// 设置默认模型（同时清除其他模型默认标记）
  Future<void> setDefault(String id) async {
    final list = await loadAll();
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(isDefault: list[i].id == id);
    }
    await _persist(list);
  }

  Future<void> _persist(List<ModelConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final c in configs) c.toJson()]),
    );
  }
}
