import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/sci_colors.dart';
import '../chat/chat_page.dart';
import '../history/history_page.dart';
import '../models/model_list_page.dart';
import '../settings/settings_page.dart';
import 'widgets/bottom_nav.dart';

/// 主页面（底部 Tab 栏容器）
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<Widget> _pages = [
    ChatPage(),
    HistoryPage(),
    ModelListPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppState.instance.tabIndex,
      builder: (context, index, _) {
        return Scaffold(
          backgroundColor: SciColors.backgroundOf(context),
          body: IndexedStack(index: index, children: _pages),
          bottomNavigationBar: BottomNav(
            currentIndex: index,
            onTap: (i) => AppState.instance.tabIndex.value = i,
          ),
        );
      },
    );
  }
}
