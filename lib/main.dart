import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/presentation/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: DuesColors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
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
        home: const AppShell(),
      ),
    );
  }
}
