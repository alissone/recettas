import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/chat.dart';
import '../services/chat_notifier.dart';
import '../services/supabase_service.dart';
import 'chat_list_screen.dart';
import 'chat_room_screen.dart';
import 'habits_screen.dart';
import 'purchases_screen.dart';
import 'shopping_screen.dart';
import 'todo_screen.dart';
import 'more_screen.dart';

final homeShellKey = GlobalKey<HomeShellState>();

/// Current bottom-nav tab. Screens kept alive in the IndexedStack can
/// listen to this to react when the user switches tabs.
final ValueNotifier<int> homeTabIndex = ValueNotifier(0);

/// Shown by screens when a background auth token refresh fails because
/// the device has no internet connection (see SupabaseService.isNetworkError).
void showNoInternetBanner() {
  homeShellKey.currentState?.showBanner(
    title: 'Sem conexão com a internet',
    body: 'Não foi possível renovar sua sessão. Verifique sua rede.',
    icon: Icons.wifi_off,
    iconColor: Colors.red,
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  // Banner state
  String? _bannerTitle;
  String _bannerBody = '';
  IconData _bannerIcon = Icons.info_outline;
  Color _bannerBgColor = Colors.white;
  Color _bannerTitleColor = AppTheme.darkBrown;
  Color _bannerBodyColor = AppTheme.mediumBrown;
  Color _bannerIconColor = AppTheme.primaryOrange;
  VoidCallback? _bannerTap;
  Timer? _bannerTimer;

  final List<Widget> _screens = const [
    TodoScreen(),
    ShoppingScreen(),
    PurchasesScreen(),
    ChatListScreen(),
    HabitsScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // The chat subscription is global (see ChatNotifier), so a message
    // arriving while the user is on any other tab still surfaces here.
    ChatNotifier.instance.incoming.addListener(_onIncomingMessage);
  }

  void _onIncomingMessage() {
    final room = ChatNotifier.instance.incoming.value;
    if (room == null || !mounted) return;
    ChatNotifier.instance.dismissIncoming();
    final myEmail = SupabaseService.currentEmail ?? '';
    showBanner(
      title: room.partnerLabel(myEmail),
      body: room.lastMessage ?? 'Nova mensagem',
      icon: Icons.chat_bubble_outline,
      onTap: () => _openChat(room),
    );
  }

  void _openChat(ChatRoom room) {
    dismissBanner();
    setState(() => _currentIndex = ChatListScreen.tabIndex);
    homeTabIndex.value = ChatListScreen.tabIndex;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)),
    );
  }

  void showBanner({
    required String title,
    String body = '',
    IconData icon = Icons.info_outline,
    Color backgroundColor = Colors.white,
    Color titleColor = AppTheme.darkBrown,
    Color bodyColor = AppTheme.mediumBrown,
    Color iconColor = AppTheme.primaryOrange,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerTap = onTap;
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
    _bannerTap = null;
    if (mounted) setState(() => _bannerTitle = null);
  }

  @override
  void dispose() {
    ChatNotifier.instance.incoming.removeListener(_onIncomingMessage);
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
          // Six fixed items: the default 14/12 pt sizing ellipsizes
          // "Afazeres" and "Compras" on narrow screens.
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) {
            setState(() => _currentIndex = index);
            homeTabIndex.value = index;
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              activeIcon: Icon(Icons.check_circle),
              label: 'Afazeres',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Compras',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.payments_outlined),
              activeIcon: Icon(Icons.payments),
              label: 'Gastos',
            ),
            const BottomNavigationBarItem(
              icon: _ChatNavIcon(icon: Icons.chat_bubble_outline),
              activeIcon: _ChatNavIcon(icon: Icons.chat_bubble),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.self_improvement_outlined),
              activeIcon: Icon(Icons.self_improvement),
              label: 'Eu',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Mais',
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
            child: InkWell(
              // Null for the plain notices; a chat banner opens the
              // conversation it announced.
              onTap: _bannerTap,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMedium),
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
      ),
    );
  }
}

/// Chat icon carrying the count of conversations with messages the user
/// hasn't opened. Lives on the nav bar rather than inside the Chat tab
/// so the count is visible from wherever the user happens to be.
class _ChatNavIcon extends StatelessWidget {
  final IconData icon;

  const _ChatNavIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatNotifier.instance.unreadRooms,
      builder: (context, unread, child) {
        if (unread == 0) return child!;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            Positioned(
              right: -6,
              top: -3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppTheme.white, width: 1.5),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: Icon(icon),
    );
  }
}
