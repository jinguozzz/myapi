import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

import '../../../core/theme/sci_colors.dart';

/// 轻量 Markdown 渲染。
/// 支持：代码块（语法高亮）/ 标题 / 列表 / 加粗 / 流式光标。
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    super.key,
    required this.data,
    this.streaming = false,
  });

  final String data;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final blocks = _parseBlocks(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...blocks,
        if (streaming) ...[
          const SizedBox(height: 2),
          const _StreamCursor(),
        ],
      ],
    );
  }

  List<Widget> _parseBlocks(String text) {
    final widgets = <Widget>[];
    final parts = text.split('```');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      if (i.isOdd) {
        widgets.add(_CodeBlock(code: part));
      } else {
        widgets.addAll(_parseTextLines(part));
      }
    }
    return widgets;
  }

  List<Widget> _parseTextLines(String text) {
    final widgets = <Widget>[];
    final lines = text.split('\n');
    final para = <String>[];

    void flush() {
      if (para.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _RichParagraph(text: para.join('\n')),
        ),
      );
      para.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        flush();
        continue;
      }
      if (line.startsWith('### ')) {
        flush();
        widgets.add(_Heading(text: line.substring(4), level: 3));
      } else if (line.startsWith('## ')) {
        flush();
        widgets.add(_Heading(text: line.substring(3), level: 2));
      } else if (line.startsWith('# ')) {
        flush();
        widgets.add(_Heading(text: line.substring(2), level: 1));
      } else if (line.startsWith('- ')) {
        flush();
        widgets.add(_Bullet(text: line.substring(2)));
      } else {
        para.add(line);
      }
    }
    flush();
    return widgets;
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.level});

  final String text;
  final int level;

  @override
  Widget build(BuildContext context) {
    final size = level == 1
        ? 18.0
        : level == 2
            ? 16.0
            : 14.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text,
        style: TextStyle(
          color: SciColors.primary,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: SciColors.primary,
                shape: BoxShape.circle,
                boxShadow: SciColors.neonShadow(blur: 5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _RichParagraph(text: text)),
        ],
      ),
    );
  }
}

class _RichParagraph extends StatelessWidget {
  const _RichParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _parseInline(text)),
      style: TextStyle(
        color: SciColors.textPrimaryOf(context),
        fontSize: 15,
        height: 1.5,
      ),
    );
  }

  List<InlineSpan> _parseInline(String text) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: SciColors.primary,
        ),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}

/// 代码块（基于 flutter_highlight 语法高亮）
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  static const _languageMap = <String, String>{
    'dart': 'dart',
    'python': 'python',
    'py': 'python',
    'javascript': 'javascript',
    'js': 'javascript',
    'typescript': 'typescript',
    'ts': 'typescript',
    'json': 'json',
    'xml': 'xml',
    'html': 'xml',
    'bash': 'bash',
    'sh': 'bash',
    'shell': 'bash',
    'java': 'java',
    'cpp': 'cpp',
    'c': 'cpp',
    'css': 'css',
    'sql': 'sql',
    'kotlin': 'kotlin',
    'swift': 'swift',
    'rust': 'rust',
    'go': 'go',
    'text': 'plaintext',
    'plaintext': 'plaintext',
  };

  /// 基于 monokai-sublime，但背景保持代码面板色
  static final Map<String, TextStyle> _theme = () {
    final t = Map<String, TextStyle>.from(monokaiSublimeTheme);
    final root = t['root'];
    if (root != null) {
      t['root'] = root.copyWith(backgroundColor: const Color(0xFF070D18));
    }
    return t;
  }();

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    final rawLang = lines.isNotEmpty ? lines.first.trim().toLowerCase() : '';
    final langName = _languageMap.containsKey(rawLang) ? rawLang : '';
    final codeText = langName.isNotEmpty ? lines.sublist(1).join('\n') : code;
    final highlightLang = _languageMap[langName] ?? 'plaintext';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF070D18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SciColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const _Dot(color: SciColors.danger),
                const SizedBox(width: 6),
                const _Dot(color: SciColors.accent),
                const SizedBox(width: 6),
                const _Dot(color: SciColors.primary),
                const Spacer(),
                Text(
                  langName.isEmpty ? 'code' : langName,
                  style: const TextStyle(
                    color: SciColors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: SciColors.border),
          HighlightView(
            codeText,
            language: highlightLang,
            theme: _theme,
            padding: const EdgeInsets.all(12),
            textStyle: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StreamCursor extends StatefulWidget {
  const _StreamCursor();

  @override
  State<_StreamCursor> createState() => _StreamCursorState();
}

class _StreamCursorState extends State<_StreamCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 14,
        decoration: BoxDecoration(
          color: SciColors.primary,
          borderRadius: BorderRadius.circular(2),
          boxShadow: SciColors.neonShadow(blur: 8),
        ),
      ),
    );
  }
}
