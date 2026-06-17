import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'screens/home_shell.dart' show HomeShell, homeShellKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jixjuabvprbyupmaqtma.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImppeGp1YWJ2cHJieXVwbWFxdG1hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2NTE1MDgsImV4cCI6MjA5NzIyNzUwOH0.RSCK1BMUSA_6M3THDOVnJQzP9RpcPspCL75R7UcBnbk',
  );

  runApp(const RecettasApp());
}

class RecettasApp extends StatelessWidget {
  const RecettasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recettas',
      theme: AppTheme.themeData,
      home: HomeShell(key: homeShellKey),
      debugShowCheckedModeBanner: false,
    );
  }
}
