import 'package:material_ui/material_ui.dart';

import 'screens/app_shell.dart';
import 'services/finance_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = FinanceController()..initialize();
  runApp(SakuProApp(controller: controller));
}

class SakuProApp extends StatelessWidget {
  const SakuProApp({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'SakuProWann',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: controller.themeMode,
          home: AppShell(controller: controller),
        );
      },
    );
  }
}
