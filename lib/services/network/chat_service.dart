import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/attachment.dart';
import '../../models/message.dart';
import '../../models/model_config.dart';
import 'sse_client.dart';

/// 聊天服务异常
class ChatException implements Exception {
  ChatException(this.message, {this.retryable = false});

  final String message;

  /// 是否为可自动重试的瞬时错误（网络异常 / 429 / 5xx）
  final bool retryable;

  @override
  String toString() => message;
}

/// 聊天服务：调用 OpenAI 兼容的 `/chat/completions` 接口，
/// 以 SSE 流式方式返回增量文本，并对瞬时错误自动重试。
class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 最大尝试次数（含首次）
  static const int _maxAttempts = 3;

  /// 发起流式对话请求，返回增量文本流。
  ///
  /// 对瞬时错误（网络异常 / 429 / 5xx）指数退避重试；
  /// 已开始输出或不可重试错误直接抛出。
  /// 消费者取消订阅时自动中断底层 HTTP 请求。
  Stream<String> streamChat({
    required ModelConfig model,
    required List<Message> messages,
  }) async* {
    var attempt = 1;
    while (true) {
      try {
        yield* _streamOnce(model: model, messages: messages);
        return;
      } on ChatException catch (e) {
        if (!e.retryable || attempt >= _maxAttempts) rethrow;
        attempt++;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  Stream<String> _streamOnce({
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
      'messages': await _buildApiMessages(
        messages,
        supportsVision: model.supportsVision,
      ),
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
      throw ChatException('网络请求失败：$e', retryable: true);
    }

    final code = response.statusCode;
    if (code != 200) {
      var detail = '';
      try {
        detail = await response.stream.bytesToString();
      } catch (_) {}
      final retryable = code == 408 || code == 429 || code >= 500;
      throw ChatException(
        '请求失败（HTTP $code）\n$detail',
        retryable: retryable,
      );
    }

    yield* const SseClient().decode(response.stream);
  }

  /// 组装 API 消息：
  /// - 仅当模型支持视觉（[supportsVision]）时，图片附件按 OpenAI 视觉内容格式（base64 data URI）发送；
  /// - 文本模型或文件附件不随请求发送（本地展示），避免 `unknown variant image_url` 类报错。
  Future<List<Map<String, dynamic>>> _buildApiMessages(
    List<Message> messages, {
    required bool supportsVision,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (final m in messages) {
      final images = m.attachments
          .where((a) => a.type == AttachmentType.image)
          .toList();
      if (images.isEmpty || !supportsVision) {
        result.add(m.toApiJson());
        continue;
      }
      final parts = <Map<String, dynamic>>[
        if (m.content.trim().isNotEmpty) {'type': 'text', 'text': m.content},
      ];
      for (final img in images) {
        try {
          final bytes = await File(img.path).readAsBytes();
          final ext = img.path.split('.').last.toLowerCase();
          final mime = ext == 'jpg' ? 'jpeg' : (ext.isEmpty ? 'png' : ext);
          parts.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/$mime;base64,${base64Encode(bytes)}',
            },
          });
        } catch (_) {
          // 图片读取失败时忽略该图
        }
      }
      result.add({'role': m.role, 'content': parts});
    }
    return result;
  }
}
