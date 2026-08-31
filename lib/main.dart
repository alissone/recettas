import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'screens/home_shell.dart' show HomeShell, homeShellKey;
import 'services/chat_notifier.dart';
import 'services/local_db.dart';
import 'services/todo_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LocalDb.initPlatform();

  await Supabase.initialize(
    url: 'https://jixjuabvprbyupmaqtma.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImppeGp1YWJ2cHJieXVwbWFxdG1hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2NTE1MDgsImV4cCI6MjA5NzIyNzUwOH0.RSCK1BMUSA_6M3THDOVnJQzP9RpcPspCL75R7UcBnbk',
  );

  await TodoRepository.instance.init();

  // Subscribes to the chat inbox for the whole session: the unread
  // badge and the in-app banner have to work before the Chat tab is
  // ever opened. Not awaited - a slow network must not hold up the
  // first frame.
  unawaited(ChatNotifier.instance.init());

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
