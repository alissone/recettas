// Web entry point with only login and chat.
//
// Build with: flutter build web -t lib/main_chat.dart
//
// Deliberately skips LocalDb / TodoRepository (no sqlite wasm) and never
// imports HomeShell or any other screen, so the rest of the app is
// tree-shaken out of the bundle.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'screens/chat_list_screen.dart';
import 'services/chat_notifier.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jixjuabvprbyupmaqtma.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImppeGp1YWJ2cHJieXVwbWFxdG1hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2NTE1MDgsImV4cCI6MjA5NzIyNzUwOH0.RSCK1BMUSA_6M3THDOVnJQzP9RpcPspCL75R7UcBnbk',
  );

  unawaited(ChatNotifier.instance.init());

  runApp(const ChatWebApp());
}

class ChatWebApp extends StatelessWidget {
  const ChatWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recettas Chat',
      theme: AppTheme.themeData,
      home: const _AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Shows the login form until there is a session, then the chat inbox.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SupabaseService.authDataChanges.listen(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SupabaseService.currentUser == null) return const _LoginScreen();
    return Stack(
      children: [
        const ChatListScreen(),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              color: AppTheme.mediumBrown,
              onPressed: SupabaseService.signOut,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_isSignUp) {
        final res = await SupabaseService.signUp(
          _email.text.trim(),
          _password.text,
          _name.text.trim(),
        );
        if (res.session == null) {
          setState(() => _info = 'Conta criada! Confirme seu e-mail para entrar.');
        }
      } else {
        await SupabaseService.signIn(_email.text.trim(), _password.text);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isSignUp ? 'Criar conta' : 'Entrar',
                      style: AppTheme.headingLarge,
                    ),
                    const SizedBox(height: 24),
                    if (_isSignUp) ...[
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _loading ? null : _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(_info!,
                          style: TextStyle(color: Colors.green.shade700)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'Criar conta' : 'Entrar'),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                                _info = null;
                              }),
                      child: Text(_isSignUp
                          ? 'Já tenho conta'
                          : 'Não tenho conta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
