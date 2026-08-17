import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme/sci_colors.dart';

/// 完整 Markdown 渲染（基于 flutter_markdown_plus），
/// 代码块使用 flutter_highlight 语法高亮，支持表格等完整语法。
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: data,
          selectable: true,
          builders: {'code': _SciCodeBuilder()},
          styleSheet: _sciStyleSheet(context),
        ),
        if (streaming) ...[
          const SizedBox(height: 2),
          const _StreamCursor(),
        ],
      ],
    );
  }

  MarkdownStyleSheet _sciStyleSheet(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return base.copyWith(
      p: TextStyle(
        color: SciColors.textPrimaryOf(context),
        fontSize: 15,
        height: 1.5,
      ),
      strong: TextStyle(
        color: SciColors.textPrimaryOf(context),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      em: const TextStyle(fontStyle: FontStyle.italic),
      h1: _headingStyle(18),
      h2: _headingStyle(16),
      h3: _headingStyle(14),
      h4: _headingStyle(13),
      listBullet: TextStyle(color: SciColors.primary, fontSize: 15),
      blockquote: TextStyle(
        color: SciColors.textSecondaryOf(context),
        fontSize: 14,
        height: 1.5,
      ),
      blockquoteDecoration: BoxDecoration(
        color: SciColors.primary.withValues(alpha: 0.06),
        border: Border(
          left: BorderSide(color: SciColors.primary, width: 3),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      // 内联代码
      code: const TextStyle(
        color: Color(0xFF9BE9FF),
        fontSize: 13,
        fontFamily: 'monospace',
        backgroundColor: Color(0xFF070D18),
      ),
      // 块级代码由 _SciCodeBuilder 接管，这里去装饰避免双重边框
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(color: Colors.transparent),
    );
  }

  TextStyle _headingStyle(double size) => TextStyle(
        color: SciColors.primary,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );
}

/// 代码块构建器：块级代码渲染为带标题栏与语法高亮的代码面板
class _SciCodeBuilder extends MarkdownElementBuilder {
  _SciCodeBuilder();

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

  static final Map<String, TextStyle> _theme = () {
    final t = Map<String, TextStyle>.from(monokaiSublimeTheme);
    final root = t['root'];
    if (root != null) {
      t['root'] = root.copyWith(backgroundColor: const Color(0xFF070D18));
    }
    return t;
  }();

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final isBlock =
        element.attributes.containsKey('class') ||
            element.textContent.contains('\n');
    final code = element.textContent;
    if (isBlock) {
      final rawLang = _extractLang(element.attributes['class'] ?? '');
      final langName = _languageMap[rawLang] ?? 'plaintext';
      return _CodeBlock(code: code, langName: rawLang, highlightLang: langName);
    }
    // 行内代码
    return Text(
      code,
      style: const TextStyle(
        color: Color(0xFF9BE9FF),
        fontSize: 13,
        fontFamily: 'monospace',
        backgroundColor: Color(0xFF070D18),
      ),
    );
  }

  String _extractLang(String classAttr) {
    final idx = classAttr.indexOf('language-');
    if (idx < 0) return '';
    return classAttr.substring(idx + 9).trim();
  }
}

/// 代码块面板（标题栏 + 语法高亮）
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.code,
    required this.langName,
    required this.highlightLang,
  });

  final String code;
  final String langName;
  final String highlightLang;

  @override
  Widget build(BuildContext context) {
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
                _Dot(color: SciColors.primary),
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
          // 水平滚动防止超长代码行撑爆布局（避免渲染成白色大块）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              code,
              language: highlightLang,
              theme: _SciCodeBuilder._theme,
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(fontSize: 13, height: 1.5),
            ),
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
