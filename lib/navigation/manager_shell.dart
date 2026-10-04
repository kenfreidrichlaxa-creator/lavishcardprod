import 'package:flutter/material.dart';
import '../core/theme/admin_colors.dart';
import '../data/services/auth_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/manager/screens/manager_home_screen.dart';
import '../features/manager/screens/manager_staff_screen.dart';
import '../features/manager/screens/manager_card_owners_screen.dart';
import '../features/manager/screens/available_cards_screen.dart';
import '../features/manager/screens/wallet_operations_screen.dart';
import '../features/manager/screens/sales_log_screen.dart';
import '../features/settings/screens/settings_screen.dart';

/// Navigation shell for the Manager role.
/// Restricted nav: Home · Staff · Card Owners · Available Cards ·
///                  Operations · Sales Log · Settings
class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => ManagerShellState();
}

class ManagerShellState extends State<ManagerShell> {
  int _selectedIndex = 0;

  static const List<_NavItem> _items = [
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavItem(Icons.badge_rounded, Icons.badge_outlined, 'Staff'),
    _NavItem(Icons.people_alt_rounded, Icons.people_alt_outlined, 'Card Owners'),
    _NavItem(Icons.nfc_rounded, Icons.nfc_outlined, 'Available Cards'),
    _NavItem(Icons.payments_rounded, Icons.payments_outlined, 'Operations'),
    _NavItem(Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Sales Log'),
    _NavItem(Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
  ];

  // Screens – Operations defaults to tab 0 (Card Sale).
  // Tab deeplinks driven by navigateTo().
  final List<Widget> _screens = const [
    ManagerHomeScreen(),
    ManagerStaffScreen(),
    ManagerCardOwnersScreen(),
    AvailableCardsScreen(),
    WalletOperationsScreen(initialTab: 0),
    SalesLogScreen(),
    SettingsScreen(),
  ];

  /// Navigate to a specific tab (called from ManagerHomeScreen quick actions).
  void navigateTo(int index) =>
      setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) {
      return _DesktopLayout(
          items: _items,
          screens: _screens,
          selected: _selectedIndex,
          onSelect: (i) => setState(() => _selectedIndex = i));
    }
    if (width >= 600) {
      return _TabletLayout(
          items: _items,
          screens: _screens,
          selected: _selectedIndex,
          onSelect: (i) => setState(() => _selectedIndex = i));
    }
    return _MobileLayout(
        items: _items,
        screens: _screens,
        selected: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i));
  }
}

// ── Desktop ───────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout(
      {required this.items,
      required this.screens,
      required this.selected,
      required this.onSelect});
  final List<_NavItem> items;
  final List<Widget> screens;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Row(children: [
        _Sidebar(items: items, selected: selected, onSelect: onSelect),
        Expanded(
          child: Column(children: [
            _TopBar(title: items[selected].label),
            Expanded(child: screens[selected]),
          ]),
        ),
      ]),
    );
  }
}

// ── Tablet ────────────────────────────────────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  const _TabletLayout(
      {required this.items,
      required this.screens,
      required this.selected,
      required this.onSelect});
  final List<_NavItem> items;
  final List<Widget> screens;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Row(children: [
        NavigationRail(
          backgroundColor: AdminColors.sidebarBg,
          selectedIndex: selected,
          onDestinationSelected: onSelect,
          labelType: NavigationRailLabelType.selected,
          selectedIconTheme:
              const IconThemeData(color: AdminColors.gold),
          unselectedIconTheme:
              const IconThemeData(color: AdminColors.sidebarTextMuted),
          selectedLabelTextStyle: const TextStyle(
              color: AdminColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w600),
          unselectedLabelTextStyle: const TextStyle(
              color: AdminColors.sidebarTextMuted, fontSize: 11),
          indicatorColor: AdminColors.sidebarSelected,
          destinations: items
              .map((d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ))
              .toList(),
          leading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: _LogoMark(),
          ),
          trailing: const _RailProfile(),
        ),
        const VerticalDivider(width: 1, color: AdminColors.sidebarSelected),
        Expanded(
          child: Column(children: [
            _TopBar(title: items[selected].label),
            Expanded(child: screens[selected]),
          ]),
        ),
      ]),
    );
  }
}

// ── Mobile ────────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout(
      {required this.items,
      required this.screens,
      required this.selected,
      required this.onSelect});
  final List<_NavItem> items;
  final List<Widget> screens;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      appBar: AppBar(
        title: const Text('Lavish Prima Manager'),
        backgroundColor: AdminColors.cardBg,
      ),
      drawer: Drawer(
        backgroundColor: AdminColors.sidebarBg,
        child: _Sidebar(
          items: items,
          selected: selected,
          onSelect: (i) {
            onSelect(i);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: screens[selected],
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar(
      {required this.items,
      required this.selected,
      required this.onSelect});
  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AdminColors.sidebarBg,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Row(children: [
            const _LogoMark(),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('LAVISH PRIMA',
                    style: TextStyle(
                        color: AdminColors.goldLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2)),
                Text('Manager Panel',
                    style: TextStyle(
                        color: AdminColors.sidebarTextMuted,
                        fontSize: 10,
                        letterSpacing: 0.5)),
              ],
            ),
          ]),
        ),
        const Divider(color: AdminColors.sidebarSelected, height: 1),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSel = i == selected;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: isSel
                      ? AdminColors.sidebarSelected
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSel)
                        Container(
                          width: 3,
                          height: 20,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AdminColors.gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        const SizedBox(width: 13),
                      Icon(
                          isSel ? item.selectedIcon : item.icon,
                          size: 18,
                          color: isSel
                              ? AdminColors.gold
                              : AdminColors.sidebarTextMuted),
                    ],
                  ),
                  title: Text(item.label,
                      style: TextStyle(
                          color: isSel
                              ? AdminColors.sidebarText
                              : AdminColors.sidebarTextMuted,
                          fontSize: 13,
                          fontWeight: isSel
                              ? FontWeight.w600
                              : FontWeight.w400)),
                  onTap: () => onSelect(i),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            }),
          ),
        ),
        const Divider(color: AdminColors.sidebarSelected, height: 1),
        _AdminProfile(),
      ]),
    );
  }
}

// ── Profile footer ────────────────────────────────────────────────────────────

class _AdminProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AdminColors.sidebarSelected,
          child: Text(user?.avatarInitials ?? 'M',
              style: const TextStyle(
                  color: AdminColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user?.fullName ?? 'Manager',
                  style: const TextStyle(
                      color: AdminColors.sidebarText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(user?.role ?? 'Manager',
                  style: const TextStyle(
                      color: AdminColors.sidebarTextMuted,
                      fontSize: 10)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded,
              size: 16, color: AdminColors.sidebarTextMuted),
          onPressed: () => _confirmLogout(context),
          tooltip: 'Logout',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
            'Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AuthService.instance.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const AdminLoginScreen()),
                (_) => false,
              );
            },
            style: FilledButton.styleFrom(
                backgroundColor: AdminColors.statusSuspended),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AdminColors.cardBg,
        border: Border(bottom: BorderSide(color: AdminColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        // Manager role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AdminColors.statusPendingBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Manager',
              style: TextStyle(
                  color: AdminColors.statusPending,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 16,
          backgroundColor: AdminColors.cream,
          child: Text(user?.avatarInitials ?? 'M',
              style: const TextStyle(
                  color: AdminColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 11)),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AdminColors.gold, width: 1.5),
      ),
      child: const Center(
        child: Text('L',
            style: TextStyle(
                color: AdminColors.goldLight,
                fontSize: 18,
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w300)),
      ),
    );
  }
}

class _RailProfile extends StatelessWidget {
  const _RailProfile();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AdminColors.sidebarSelected,
        child: Text(user?.avatarInitials ?? 'M',
            style: const TextStyle(
                color: AdminColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 11)),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.selectedIcon, this.icon, this.label);
  final IconData selectedIcon;
  final IconData icon;
  final String label;
}
