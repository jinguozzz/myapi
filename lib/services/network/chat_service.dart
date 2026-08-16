import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/message.dart';
import '../../models/model_config.dart';
import 'sse_client.dart';

/// 聊天服务异常
class ChatException implements Exception {
  ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 聊天服务：调用 OpenAI 兼容的 `/chat/completions` 接口，
/// 以 SSE 流式方式返回增量文本。
class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 发起流式对话请求，返回增量文本流。
  ///
  /// 消费者取消订阅时自动中断底层 HTTP 请求。
  Stream<String> streamChat({
    required ModelConfig model,
    required List<Message> messages,
  }) async* {
    final base = model.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');

    final headers = <String, String>{
      'Authorization': 'Bearer ${model.apiKey}',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      ...model.headers,
    };

    final body = jsonEncode({
      'model': model.modelId,
      'messages': [for (final m in messages) m.toApiJson()],
      'temperature': model.temperature,
      'max_tokens': model.maxTokens,
      'stream': true,
    });

    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = body;

    http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (e) {
      throw ChatException('网络请求失败：$e');
    }

    if (response.statusCode != 200) {
      var detail = '';
      try {
        detail = await response.stream.bytesToString();
      } catch (_) {}
      throw ChatException('请求失败（HTTP ${response.statusCode}）\n$detail');
    }

    yield* const SseClient().decode(response.stream);
  }
}
