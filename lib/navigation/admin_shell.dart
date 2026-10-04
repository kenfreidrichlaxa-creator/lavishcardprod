import 'package:flutter/material.dart';
import '../core/theme/admin_colors.dart';
import '../core/services/admin_session.dart';
import '../data/services/admin_notifications_repository.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/card_owners/screens/card_owners_screen.dart';
import '../features/nfc_cards/screens/admin_cards_hub_screen.dart';
import '../features/staff/screens/staff_screen.dart';
import '../features/services/screens/services_screen.dart';
import '../features/transactions/screens/transactions_screen.dart';
import '../features/pos/screens/pos_screen.dart';
import '../features/manager/screens/sales_log_screen.dart';
import '../features/settings/screens/settings_screen.dart';

/// Responsive admin shell.
/// - ≥1100 px  ↁEpersistent sidebar (240 px)
/// - 600—E099  ↁENavigationRail (collapsed)
/// - < 600     ↁEDrawer + BottomNavigationBar
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  static const List<_NavItem> _items = [
    _NavItem(Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    _NavItem(Icons.point_of_sale_rounded, Icons.point_of_sale_outlined, 'Checkout'),
    _NavItem(Icons.people_alt_rounded, Icons.people_alt_outlined, 'Card Owners'),
    _NavItem(Icons.credit_card_rounded, Icons.credit_card_outlined, 'Cards'),
    _NavItem(Icons.badge_rounded, Icons.badge_outlined, 'Staff'),
    _NavItem(Icons.content_cut_rounded, Icons.content_cut_outlined, 'Services'),
    _NavItem(Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Transactions'),
    _NavItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Sales Log'),
    _NavItem(Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    PosScreen(),
    CardOwnersScreen(),
    AdminCardsHubScreen(),
    StaffScreen(),
    ServicesScreen(),
    TransactionsScreen(),
    SalesLogScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) return _DesktopLayout(items: _items, screens: _screens, selected: _selectedIndex, onSelect: (i) => setState(() => _selectedIndex = i));
    if (width >= 600)  return _TabletLayout(items: _items, screens: _screens, selected: _selectedIndex, onSelect: (i) => setState(() => _selectedIndex = i));
    return _MobileLayout(items: _items, screens: _screens, selected: _selectedIndex, onSelect: (i) => setState(() => _selectedIndex = i));
  }
}

// ── Desktop: full sidebar ────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.items,
    required this.screens,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final List<Widget> screens;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Row(
        children: [
          _Sidebar(items: items, selected: selected, onSelect: onSelect),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: items[selected].label),
                Expanded(child: screens[selected]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tablet: NavigationRail ───────────────────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.items,
    required this.screens,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final List<Widget> screens;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AdminColors.sidebarBg,
            selectedIndex: selected,
            onDestinationSelected: onSelect,
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: const IconThemeData(color: AdminColors.gold),
            unselectedIconTheme: const IconThemeData(color: AdminColors.sidebarTextMuted),
            selectedLabelTextStyle: const TextStyle(color: AdminColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelTextStyle: const TextStyle(color: AdminColors.sidebarTextMuted, fontSize: 11),
            indicatorColor: AdminColors.sidebarSelected,
            destinations: items.map((item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: Text(item.label),
            )).toList(),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: _LogoMark(compact: true),
            ),
            trailing: const _RailProfile(),
          ),
          const VerticalDivider(width: 1, color: AdminColors.sidebarSelected),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: items[selected].label),
                Expanded(child: screens[selected]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile: Drawer ───────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.items,
    required this.screens,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final List<Widget> screens;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.pageBg,
      appBar: AppBar(
        title: const Text('Lavish Prima Admin'),
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

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AdminColors.sidebarBg,
      child: Column(
        children: [
          // Brand
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: _LogoMark(compact: false),
          ),
          const Divider(color: AdminColors.sidebarSelected, height: 1),
          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isSelected = i == selected;
                return _SidebarTile(
                  icon: isSelected ? item.selectedIcon : item.icon,
                  label: item.label,
                  selected: isSelected,
                  onTap: () => onSelect(i),
                );
              }),
            ),
          ),

          const Divider(color: AdminColors.sidebarSelected, height: 1),
          // Admin profile footer
          const _AdminProfile(),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AdminColors.sidebarSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
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
            Icon(icon, size: 18,
                color: selected ? AdminColors.gold : AdminColors.sidebarTextMuted),
          ],
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? AdminColors.sidebarText : AdminColors.sidebarTextMuted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        selected: selected,
        selectedTileColor: Colors.transparent,
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Logo ─────────────────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AdminColors.gold, width: 1.5),
        ),
        child: const Center(
          child: Text('L', style: TextStyle(color: AdminColors.goldLight, fontSize: 18, fontFamily: 'Georgia', fontWeight: FontWeight.w300)),
        ),
      );
    }
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AdminColors.gold, width: 1.5),
          ),
          child: const Center(
            child: Text('L', style: TextStyle(color: AdminColors.goldLight, fontSize: 18, fontFamily: 'Georgia', fontWeight: FontWeight.w300)),
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LAVISH PRIMA', style: TextStyle(color: AdminColors.goldLight, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
            Text('Admin Panel', style: TextStyle(color: AdminColors.sidebarTextMuted, fontSize: 10, letterSpacing: 0.5)),
          ],
        ),
      ],
    );
  }
}

// ── Admin Profile Footer ──────────────────────────────────────────────────────

class _AdminProfile extends StatelessWidget {
  const _AdminProfile();

  @override
  Widget build(BuildContext context) {
    final user = AdminSession.user;
    final initials = user?.avatarInitials ?? 'AU';
    final name = user?.fullName ?? 'Admin User';
    final role = user?.isManager == true ? 'Manager' : 'Administrator';
    final branchName = AdminSession.activeBranch?.name ?? user?.branch ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AdminColors.sidebarSelected,
            child: Text(initials,
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
                Text(name,
                    style: const TextStyle(
                        color: AdminColors.sidebarText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  branchName.isNotEmpty ? '$role · $branchName' : role,
                  style: const TextStyle(
                      color: AdminColors.sidebarTextMuted,
                      fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
            'Are you sure you want to log out of the admin panel?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AdminSession.clear();
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

// ── Rail Profile ──────────────────────────────────────────────────────────────

class _RailProfile extends StatelessWidget {
  const _RailProfile();

  @override
  Widget build(BuildContext context) {
    final user = AdminSession.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AdminColors.sidebarSelected,
        child: Text(
          user?.avatarInitials ?? 'AU',
          style: const TextStyle(
              color: AdminColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 11),
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final user = AdminSession.user;
    final initials = user?.avatarInitials ?? 'AU';
    final activeBranch = AdminSession.activeBranch;

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AdminColors.cardBg,
        border: Border(bottom: BorderSide(color: AdminColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          // Active branch badge — only shown for multi-branch admins who picked
          if (activeBranch != null) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_mall_directory_rounded,
                      size: 12, color: AdminColors.goldDark),
                  const SizedBox(width: 4),
                  Text(
                    activeBranch.name,
                    style: const TextStyle(
                        color: AdminColors.goldDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          const _NotificationBell(),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 16,
            backgroundColor: AdminColors.cream,
            child: Text(initials,
                style: const TextStyle(
                    color: AdminColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Notification bell (client reports: lost cards, etc.) ─────────────────────

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  final _repo = AdminNotificationsRepository.instance;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final n = await _repo.unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {/* ignore */}
  }

  Future<void> _openPanel() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _NotificationsDialog(),
    );
    _refresh(); // update the badge after the panel closes
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AdminColors.brownMedium),
          onPressed: _openPanel,
          tooltip: 'Notifications',
        ),
        if (_unread > 0)
          Positioned(
            top: 6, right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AdminColors.statusSuspended,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationsDialog extends StatefulWidget {
  const _NotificationsDialog();

  @override
  State<_NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<_NotificationsDialog> {
  final _repo = AdminNotificationsRepository.instance;
  bool _loading = true;
  List<AdminNotification> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _repo.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AdminNotification n) async {
    if (n.isRead) return;
    await _repo.markRead(id: n.id);
    await _load();
  }

  Future<void> _delete(AdminNotification n) async {
    await _repo.delete(id: n.id);
    await _load();
  }

  Future<void> _clearRead() async {
    await _repo.delete(); // deletes all read notifications in scope
    await _load();
  }

  Future<void> _markAllRead() async {
    await _repo.markRead();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = _items.any((n) => !n.isRead);
    final hasRead = _items.any((n) => n.isRead);
    return Dialog(
      alignment: Alignment.topRight,
      insetPadding:
          const EdgeInsets.only(top: 60, right: 24, left: 24, bottom: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.notifications_rounded,
                    color: AdminColors.gold, size: 20),
                const SizedBox(width: 8),
                Text('Notifications', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ]),
              if (hasUnread || hasRead)
                Row(children: [
                  if (hasUnread)
                    TextButton.icon(
                      onPressed: _markAllRead,
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text('Mark all read'),
                    ),
                  const Spacer(),
                  if (hasRead)
                    TextButton.icon(
                      onPressed: _clearRead,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Clear read'),
                      style: TextButton.styleFrom(
                          foregroundColor: AdminColors.statusSuspended),
                    ),
                ]),
              const Divider(height: 12),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AdminColors.gold)),
                      )
                    : _items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.notifications_none_rounded,
                                      size: 40, color: AdminColors.brownLight),
                                  const SizedBox(height: 8),
                                  Text('No notifications.',
                                      style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final n = _items[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: n.isRead
                                      ? AdminColors.cream
                                      : AdminColors.statusSuspendedBg,
                                  child: Icon(
                                    _iconFor(n.type),
                                    size: 16,
                                    color: n.isRead
                                        ? AdminColors.brownLight
                                        : AdminColors.statusSuspended,
                                  ),
                                ),
                                title: Text(n.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: n.isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700)),
                                subtitle: Text(n.body,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!n.isRead)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.circle,
                                            size: 8,
                                            color:
                                                AdminColors.statusSuspended),
                                      ),
                                    IconButton(
                                      tooltip: 'Dismiss',
                                      onPressed: () => _delete(n),
                                      icon: const Icon(Icons.close_rounded,
                                          size: 16,
                                          color: AdminColors.brownLight),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                onTap: () => _markRead(n),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'CARD_LOST':
        return Icons.credit_card_off_rounded;
      case 'CONTACT':
        return Icons.mail_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

// ── Nav item data ─────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem(this.selectedIcon, this.icon, this.label);
  final IconData selectedIcon;
  final IconData icon;
  final String label;
}
