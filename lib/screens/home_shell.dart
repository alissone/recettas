import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'purchases_screen.dart';
import 'recipes_screen.dart';
import 'todo_screen.dart';
import 'profile_screen.dart';

final homeShellKey = GlobalKey<HomeShellState>();

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _currentIndex = 2;

  // Banner state
  String? _bannerTitle;
  String _bannerBody = '';
  IconData _bannerIcon = Icons.info_outline;
  Color _bannerBgColor = Colors.white;
  Color _bannerTitleColor = AppTheme.darkBrown;
  Color _bannerBodyColor = AppTheme.mediumBrown;
  Color _bannerIconColor = AppTheme.primaryOrange;
  Timer? _bannerTimer;

  final List<Widget> _screens = const [
    TodoScreen(),
    PurchasesScreen(),
    RecipesScreen(),
    ProfileScreen(),
  ];

  void showBanner({
    required String title,
    String body = '',
    IconData icon = Icons.info_outline,
    Color backgroundColor = Colors.white,
    Color titleColor = AppTheme.darkBrown,
    Color bodyColor = AppTheme.mediumBrown,
    Color iconColor = AppTheme.primaryOrange,
    Duration duration = const Duration(seconds: 4),
  }) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerTitle = title;
      _bannerBody = body;
      _bannerIcon = icon;
      _bannerBgColor = backgroundColor;
      _bannerTitleColor = titleColor;
      _bannerBodyColor = bodyColor;
      _bannerIconColor = iconColor;
    });
    _bannerTimer = Timer(duration, dismissBanner);
  }

  void dismissBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    if (mounted) setState(() => _bannerTitle = null);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          _buildBannerOverlay(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              activeIcon: Icon(Icons.check_circle),
              label: 'Afazeres',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag),
              label: 'Compras',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(Icons.restaurant_menu),
              label: 'Receitas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerOverlay() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
            parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _bannerTitle != null
          ? _buildBannerCard()
          : const SizedBox.shrink(key: ValueKey('_banner_empty')),
    );
  }

  Widget _buildBannerCard() {
    return Align(
      key: ValueKey(_bannerTitle),
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            elevation: 6,
            borderRadius:
                BorderRadius.circular(AppTheme.radiusMedium),
            color: _bannerBgColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          _bannerIconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_bannerIcon,
                        color: _bannerIconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _bannerTitle!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _bannerTitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_bannerBody.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _bannerBody,
                            style: TextStyle(
                                fontSize: 13,
                                color: _bannerBodyColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: dismissBanner,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 18, color: _bannerBodyColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
