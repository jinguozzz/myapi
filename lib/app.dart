import 'package:flutter/material.dart';

import 'core/state/app_state.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/sci_colors.dart';
import 'pages/home/home_page.dart';

/// 应用根组件
class MyAIApp extends StatelessWidget {
  const MyAIApp({super.key});

  /// 应用级合并监听器（仅创建一次，避免每次 build 重建）
  static final Listenable _appListenable = Listenable.merge([
    AppState.instance.themeMode,
    AppState.instance.fontScale,
    AppState.instance.accentColor,
  ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appListenable,
      builder: (context, _) {
        // 主题色变化时先应用主色，再重建 UI（必须放在 builder 内）
        SciColors.applyAccent(AppState.instance.accentColor.value);
        return MaterialApp(
          title: 'MyAI Companion',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: AppState.instance.themeMode.value,
          builder: (context, child) {
            final scale = AppState.instance.fontScale.value;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            );
          },
          home: HomePage(
            // 主题色变化时强制重建整棵 UI，使新的主色生效（状态由 AppState 保存）
            key: ValueKey(AppState.instance.accentColor.value),
          ),
        );
      },
    );
  }
}
