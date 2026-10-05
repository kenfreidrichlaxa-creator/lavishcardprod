import 'package:flutter/material.dart';
import '../core/theme/admin_colors.dart';
import '../core/services/admin_session.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/super_admin/screens/branch_maker_screen.dart';
import '../features/super_admin/screens/branch_groups_screen.dart';
import '../features/super_admin/screens/cards_hub_screen.dart';
import '../features/super_admin/screens/admin_maker_screen.dart';
import '../features/super_admin/screens/audit_viewer_screen.dart';
import '../features/super_admin/screens/category_manager_screen.dart';
import '../features/super_admin/screens/staff_manager_screen.dart';
import '../features/services/screens/services_screen.dart';
import '../features/settings/screens/settings_screen.dart';

/// Shell for the Super Admin: overview + branch maker + admin account maker.
class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _selected = 0;

  static const _items = [
    _Nav(Icons.dashboard_rounded, 'Overview'),
    _Nav(Icons.store_mall_directory_rounded, 'Branches'),
    _Nav(Icons.account_tree_rounded, 'Franchise Groups'),
    _Nav(Icons.credit_card_rounded, 'Cards'),
    _Nav(Icons.content_cut_rounded, 'Services'),
    _Nav(Icons.category_rounded, 'Categories'),
    _Nav(Icons.badge_rounded, 'Staff'),
    _Nav(Icons.admin_panel_settings_rounded, 'Admin Accounts'),
    _Nav(Icons.history_rounded, 'Audit Trail'),
    _Nav(Icons.settings_rounded, 'Settings'),
  ];

  static const _screens = [
    DashboardScreen(),
    BranchMakerScreen(),
    BranchGroupsScreen(),
    CardsHubScreen(),
    ServicesScreen(),
    CategoryManagerScreen(),
    StaffManagerScreen(),
    AdminMakerScreen(),
    AuditViewerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: wide ? null : Drawer(child: _sidebar(context)),
      appBar: wide
          ? null
          : AppBar(
              title: Text(_items[_selected].label),
              backgroundColor: AdminColors.cardBg,
            ),
      body: wide
          ? Row(
              children: [
                SizedBox(width: 240, child: _sidebar(context)),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(context),
                      Expanded(child: _screens[_selected]),
                    ],
                  ),
                ),
              ],
            )
          : _screens[_selected],
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AdminColors.cardBg,
        border: Border(bottom: BorderSide(color: AdminColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(_items[_selected].label,
              style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AdminColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('SUPER ADMIN',
                style: TextStyle(
                    color: AdminColors.goldDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    final name = AdminSession.user?.fullName ?? 'Super Admin';
    return Container(
      color: AdminColors.sidebarBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AdminColors.gold, width: 1.5),
                ),
                child: const Center(
                  child: Text('L',
                      style: TextStyle(
                          color: AdminColors.goldLight,
                          fontSize: 18,
                          fontFamily: 'Georgia')),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LAVISH PRIMA',
                      style: TextStyle(
                          color: AdminColors.goldLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                  Text('Super Admin',
                      style: TextStyle(
                          color: AdminColors.sidebarTextMuted, fontSize: 10)),
                ],
              ),
            ]),
          ),
          const Divider(color: AdminColors.sidebarSelected, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: List.generate(_items.length, (i) {
                final sel = i == _selected;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: sel ? AdminColors.sidebarSelected : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(_items[i].icon,
                        size: 18,
                        color: sel
                            ? AdminColors.gold
                            : AdminColors.sidebarTextMuted),
                    title: Text(_items[i].label,
                        style: TextStyle(
                            color: sel
                                ? AdminColors.sidebarText
                                : AdminColors.sidebarTextMuted,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    dense: true,
                    onTap: () {
                      setState(() => _selected = i);
                      if (Scaffold.of(context).hasDrawer &&
                          Scaffold.of(context).isDrawerOpen) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const Divider(color: AdminColors.sidebarSelected, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AdminColors.sidebarSelected,
                child: Icon(Icons.shield_rounded,
                    size: 16, color: AdminColors.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: AdminColors.sidebarText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded,
                    size: 16, color: AdminColors.sidebarTextMuted),
                onPressed: () => _logout(context),
                tooltip: 'Logout',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    AdminSession.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }
}

class _Nav {
  const _Nav(this.icon, this.label);
  final IconData icon;
  final String label;
}
