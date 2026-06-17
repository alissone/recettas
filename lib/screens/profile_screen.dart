import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../services/supabase_service.dart';
import 'home_shell.dart' show homeShellKey;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _profile;
  StreamSubscription<AuthState>? _authSubscription;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_isAuthenticated) _loadProfile();

    _authSubscription =
        SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        setState(() {});
        if (data.session != null) _loadProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _isAuthenticated => SupabaseService.currentUser != null;

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        final response = await SupabaseService.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );

        if (response.session == null) {
          homeShellKey.currentState?.showBanner(
            title: 'Account created!',
            body: 'Please check your email to confirm your account.',
            icon: Icons.mark_email_read_outlined,
            iconColor: Colors.green.shade600,
            backgroundColor: const Color(0xFFF1F8E9),
            titleColor: Colors.green.shade700,
            bodyColor: Colors.green.shade600,
          );
        }
      } else {
        await SupabaseService.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );

        homeShellKey.currentState?.showBanner(
          title: 'Welcome back!',
          icon: Icons.check_circle_outline,
          iconColor: AppTheme.primaryOrange,
        );
      }
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    await SupabaseService.signOut();
    if (mounted) setState(() => _profile = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _isAuthenticated ? _buildProfile() : _buildAuthForm(),
        ),
      ),
    );
  }

  Widget _buildProfile() {
    final user = SupabaseService.currentUser!;
    final displayName = _profile?['display_name'] ??
        user.email?.split('@').first ??
        'User';
    final email = user.email ?? '';

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppTheme.accentShadow,
          ),
          child: Center(
            child: Text(
              displayName.isNotEmpty
                  ? displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(displayName, style: AppTheme.headingMedium),
        const SizedBox(height: 4),
        Text(email, style: AppTheme.caption),
        const SizedBox(height: 40),
        _buildProfileCard(Icons.email_outlined, 'Email', email),
        _buildProfileCard(
          Icons.calendar_today,
          'Member since',
          user.createdAt.isNotEmpty
              ? _formatDate(DateTime.parse(user.createdAt))
              : 'Unknown',
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _handleSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryOrange,
              side: const BorderSide(color: AppTheme.primaryOrange),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(
      IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusXSmall),
            ),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.caption),
                const SizedBox(height: 2),
                Text(value, style: AppTheme.valueBold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildAuthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.accentShadow,
            ),
            child:
                const Icon(Icons.person, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            _isSignUp ? 'Create Account' : 'Welcome Back',
            style: AppTheme.headingLarge,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isSignUp
                ? 'Sign up to save your tasks'
                : 'Sign in to your account',
            style:
                AppTheme.bodyText.copyWith(color: AppTheme.mediumBrown),
          ),
        ),
        const SizedBox(height: 32),
        if (_error != null) _buildErrorBanner(),
        if (_isSignUp)
          _buildTextField(
              _nameController, 'Display Name', Icons.person_outline),
        _buildTextField(
            _emailController, 'Email', Icons.email_outlined),
        _buildTextField(
            _passwordController, 'Password', Icons.lock_outline,
            isPassword: true),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: AppTheme.white,
              disabledBackgroundColor:
                  AppTheme.primaryOrange.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    _isSignUp ? 'Sign Up' : 'Sign In',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _isSignUp = !_isSignUp;
              _error = null;
            }),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
              style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Colors.red.shade400, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: TextStyle(
                    color: Colors.red.shade700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: AppTheme.mediumBrown.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: AppTheme.primaryOrange),
          filled: true,
          fillColor: AppTheme.white,
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppTheme.radiusSmall),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppTheme.radiusSmall),
            borderSide: const BorderSide(
                color: AppTheme.primaryOrange, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
