import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/sci_colors.dart';
import '../../models/conversation.dart';
import 'widgets/history_list_item.dart';

/// 历史对话列表页面（真实持久化：搜索 / 打开 / 重命名 / 删除 / 导出）
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<ConversationSummary> _items = [];
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final items = await AppState.instance.conversationRepository
        .getConversations(keyword: _searchCtrl.text.trim());
    if (!mounted || token != _loadToken) return;
    setState(() => _items = items);
  }

  void _onSearchChanged(String _) {
    _load();
  }

  Future<void> _open(ConversationSummary item) async {
    await AppState.instance.openConversation(item.id);
  }

  void _showActions(ConversationSummary item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SciColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '对话操作',
                style: TextStyle(
                  color: SciColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline_rounded,
                  color: SciColors.primary, size: 20),
              title: const Text('打开对话',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _open(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.drive_file_rename_outline_rounded,
                  color: SciColors.primary, size: 20),
              title: const Text('重命名',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _rename(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.ios_share_rounded,
                  color: SciColors.primary, size: 20),
              title: const Text('导出为 Markdown',
                  style: TextStyle(color: SciColors.textPrimary, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _export(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: SciColors.danger, size: 20),
              title: const Text('删除对话',
                  style: TextStyle(color: SciColors.danger, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _delete(item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _rename(ConversationSummary item) {
    final ctrl = TextEditingController(text: item.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: SciColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final title = ctrl.text.trim();
              Navigator.of(ctx).pop();
              if (title.isEmpty) return;
              await AppState.instance.renameConversation(item.id, title);
              await _load();
            },
            child: Text('保存', style: TextStyle(color: SciColors.primary)),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  void _delete(ConversationSummary item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text(
          '确定删除「${item.title}」？此操作不可恢复。',
          style: const TextStyle(color: SciColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: SciColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AppState.instance.deleteConversation(item.id);
              await _load();
            },
            child: const Text('删除', style: TextStyle(color: SciColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _export(ConversationSummary item) async {
    final text = await AppState.instance.conversationRepository
        .exportConversation(item.id);
    if (text == null || !mounted) return;
    try {
      final dir = await getTemporaryDirectory();
      // 清理历史导出的 .md 临时文件，避免缓存累积占用存储
      try {
        await for (final e in dir.list()) {
          if (e is File && e.path.endsWith('.md')) {
            try {
              await e.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}
      final safeTitle = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeTitle.md');
      await file.writeAsString(text);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: item.title),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    if (day == today) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (day == today.subtract(const Duration(days: 1))) return '昨天';
    if (t.year == now.year) return '${t.month}月${t.day}日';
    return '${t.year}年${t.month}月${t.day}日';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SciColors.backgroundOf(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    '历史记录',
                    style: TextStyle(
                      color: SciColors.textPrimaryOf(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  color: SciColors.textPrimaryOf(context),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '搜索标题或内容…',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: SciColors.primary,
                    size: 20,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _items.isEmpty
                  ? _emptyState(context)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: SciColors.danger.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) {
                            _items.removeAt(i);
                            AppState.instance.deleteConversation(item.id);
                            _load();
                          },
                          child: HistoryListItem(
                            title: item.title,
                            subtitle: item.lastMessage ?? '暂无消息',
                            time: _formatTime(item.updatedAt),
                            count: item.messageCount,
                            onTap: () => _open(item),
                            onLongPress: () => _showActions(item),
                            onMenu: () => _showActions(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SciColors.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: SciColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: SciColors.neonShadow(blur: 16),
            ),
            child: Icon(
              Icons.history_rounded,
              color: SciColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无历史对话',
            style: TextStyle(
              color: SciColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '完成对话后，会话会保存在这里\n支持搜索、重命名与导出',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SciColors.textSecondaryOf(context),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
