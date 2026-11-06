import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/background/background_tasks.dart';
import 'package:dues/presentation/shell/startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: DuesColors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await initializeBackgroundTasks();
  runApp(const DuesApp());
}

class DuesApp extends StatelessWidget {
  const DuesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Dues',
        debugShowCheckedModeBanner: false,
        theme: DuesTheme.dark,
        home: const StartupGate(),
      ),
    );
  }
}
