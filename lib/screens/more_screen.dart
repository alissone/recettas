import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../services/supabase_service.dart';
import 'accelerometer_screen.dart';
import 'bible_screen.dart';
import 'currency_converter_screen.dart';
import 'date_calculator_screen.dart';
import 'gps_tracker_screen.dart';
import 'harpa_screen.dart';
import 'home_shell.dart' show showNoInternetBanner;
import 'profile_screen.dart';
import 'report_screen.dart';
import 'sleep_screen.dart';
import 'time_calculator_screen.dart';
import 'timezone_screen.dart';

/// "Mais" tab: profile header at the top, then a list of utilities,
/// each opening its own screen.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Map<String, dynamic>? _profile;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (_isAuthenticated) _loadProfile();
    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        setState(() {
          if (data.session == null) _profile = null;
        });
        if (data.session != null) _loadProfile();
      }
    }, onError: (error) {
      if (SupabaseService.isNetworkError(error)) showNoInternetBanner();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  bool get _isAuthenticated => SupabaseService.currentUser != null;

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  void _push(Widget screen) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Mais', style: AppTheme.headingLarge),
            const SizedBox(height: 4),
            Text(
              'Perfil e utilidades',
              style:
                  AppTheme.bodyText.copyWith(color: AppTheme.mediumBrown),
            ),
            const SizedBox(height: 20),
            _buildProfileCard(),
            const SizedBox(height: 24),
            _buildUtilityTile(
              icon: Icons.insert_chart_outlined,
              title: 'Relatório de gastos',
              subtitle: 'Gráficos mensais das compras',
              screen: const ReportScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.calendar_month_outlined,
              title: 'Calculadora de datas',
              subtitle: 'Somar dias e diferença entre datas',
              screen: const DateCalculatorScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.timer_outlined,
              title: 'Calculadora de horas',
              subtitle: 'Somar e subtrair hh:mm:ss',
              screen: const TimeCalculatorScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.currency_exchange,
              title: 'Conversor de moedas',
              subtitle: 'BRL, USD e EUR',
              screen: const CurrencyConverterScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.public,
              title: 'Fusos horários',
              subtitle: 'Brasília, Lisboa e EUA',
              screen: const TimezoneScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.vibration,
              title: 'Acelerômetro',
              subtitle: 'Gravar e enviar leituras',
              screen: const AccelerometerScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.gps_fixed,
              title: 'Rastreador GPS',
              subtitle: 'Grave rotas e exporte em GPX',
              screen: const GpsTrackerScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.bedtime_outlined,
              title: 'Sono',
              subtitle: 'Registrar e visualizar seu sono',
              screen: const SleepScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.library_music_outlined,
              title: 'Harpa Cristã',
              subtitle: '640 hinos para ler e pesquisar',
              screen: const HarpaScreen(),
            ),
            _buildUtilityTile(
              icon: Icons.menu_book_outlined,
              title: 'Bíblia',
              subtitle: 'NVI - 66 livros para ler e pesquisar',
              screen: const BibleScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final user = SupabaseService.currentUser;
    final displayName = _profile?['display_name'] ??
        user?.email?.split('@').first ??
        'Visitante';
    final subtitle = _isAuthenticated
        ? (user?.email ?? '')
        : 'Toque para entrar ou criar conta';

    return GestureDetector(
      onTap: () => _push(const ProfileScreen()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.accentShadow,
              ),
              child: Center(
                child: _isAuthenticated
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person,
                        color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAuthenticated ? displayName : 'Perfil',
                    style: AppTheme.sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.mediumBrown),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => _push(screen),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusXSmall),
                  ),
                  child: Icon(icon,
                      color: AppTheme.primaryOrange, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.valueBold),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTheme.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppTheme.mediumBrown),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
