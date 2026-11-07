import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/background/background_tasks.dart';
import 'package:dues/presentation/shell/startup_gate.dart';
import 'package:dues/presentation/providers/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundTasks();
  final container = ProviderContainer();
  try {
    await container.read(themeModeProvider.future);
  } catch (_) {
    // System theme remains the safe default if local settings cannot open.
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const DuesApp()),
  );
}

class DuesApp extends ConsumerWidget {
  const DuesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return MaterialApp(
      title: 'Dues',
      debugShowCheckedModeBanner: false,
      theme: DuesTheme.light,
      darkTheme: DuesTheme.dark,
      themeMode: mode,
      themeAnimationDuration: const Duration(milliseconds: 150),
      themeAnimationCurve: Curves.linear,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final tokens = context.receipt;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: tokens.paper,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const StartupGate(),
    );
  }
}
