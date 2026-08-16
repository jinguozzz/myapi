import 'dart:async';
import 'dart:convert';

/// SSE（Server-Sent Events）流式响应解析器。
///
/// 从 HTTP 响应字节流中逐行解析 `data:` 事件，抽取 OpenAI 兼容
/// 流式格式中的增量文本内容。
class SseClient {
  const SseClient();

  /// 解析字节流，产出每条增量文本片段
  Stream<String> decode(Stream<List<int>> byteStream) async* {
    await for (final line in byteStream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;

      final data = trimmed.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final delta = choices.first['delta'] as Map<String, dynamic>?;
        final content = delta?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      } catch (_) {
        // 跳过无法解析的行，保证流式容错
      }
    }
  }
}
