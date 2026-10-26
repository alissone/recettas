// Web entry point: login, then simplified Afazeres / Compras / Gastos
// (lib/web/) plus the chat.
//
// Build with: flutter build web -t lib/main_chat.dart
//
// Deliberately skips LocalDb / TodoRepository (no sqlite wasm; the web
// todo screen talks to Supabase directly) and never imports HomeShell or
// the app's full screens, so the rest of the app is tree-shaken out of
// the bundle.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'screens/chat_list_screen.dart';
import 'services/chat_notifier.dart';
import 'services/supabase_service.dart';
import 'web/web_common.dart';
import 'web/web_purchases_screen.dart';
import 'web/web_shopping_screen.dart';
import 'web/web_todo_screen.dart';

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
      title: 'Recettas',
      theme: AppTheme.themeData,
      home: const _AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Shows the login form until there is a session, then the tabs.
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
    final user = SupabaseService.currentUser;
    if (user == null) return const _LoginScreen();
    // Keyed by user so switching accounts starts every tab from scratch.
    return _WebShell(key: ValueKey(user.id));
  }
}

/// Bottom-nav shell, same tab order as the app's HomeShell.
class _WebShell extends StatefulWidget {
  const _WebShell({super.key});

  @override
  State<_WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<_WebShell> {
  int _index = 0;

  /// Bumped when Compras registers a gasto, so Gastos reloads.
  final _purchasesChanged = ValueNotifier(0);

  late final List<Widget> _tabs = [
    const WebTodoScreen(),
    WebShoppingScreen(onPurchaseAdded: () => _purchasesChanged.value++),
    WebPurchasesScreen(reload: _purchasesChanged),
    const ChatListScreen(headerActions: [SignOutButton()]),
  ];

  @override
  void dispose() {
    _purchasesChanged.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.white,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: 'Afazeres',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Compras',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments),
            label: 'Gastos',
          ),
          BottomNavigationBarItem(
            icon: _ChatNavIcon(icon: Icons.chat_bubble_outline),
            activeIcon: _ChatNavIcon(icon: Icons.chat_bubble),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}

/// Chat icon with the unread-conversations badge (mirrors the private
/// one in HomeShell, which this entry point can't import).
class _ChatNavIcon extends StatelessWidget {
  final IconData icon;

  const _ChatNavIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatNotifier.instance.unreadRooms,
      builder: (context, unread, child) {
        if (unread == 0) return child!;
        return Badge(
          label: Text(unread > 9 ? '9+' : '$unread'),
          backgroundColor: AppTheme.primaryOrange,
          child: child,
        );
      },
      child: Icon(icon),
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
