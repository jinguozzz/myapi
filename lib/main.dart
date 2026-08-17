import 'package:flutter/material.dart';

import 'app.dart';
import 'core/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.initSettings();
  await AppState.instance.initModels();
  await AppState.instance.initHistory();
  runApp(const MyAIApp());
}
