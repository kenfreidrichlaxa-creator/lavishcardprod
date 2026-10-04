import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/services/admin_session.dart';
import '../../../data/models/branch_model.dart';
import '../../../data/services/admin_auth_repository.dart';
import '../../../navigation/admin_shell.dart';

/// Shown after login when an admin manages 2 or more branches.
/// The admin picks which branch they are working in for this session.
class BranchPickerScreen extends StatefulWidget {
  const BranchPickerScreen({super.key});

  @override
  State<BranchPickerScreen> createState() => _BranchPickerScreenState();
}

class _BranchPickerScreenState extends State<BranchPickerScreen> {
  List<BranchModel> _branches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await AdminAuthRepository.instance.listBranches();
      // Filter to only the branches this admin is assigned to.
      final assignedIds = AdminSession.branchIds.toSet();
      final assigned = all
          .where((b) => assignedIds.contains(b.id) && b.isActive)
          .toList();

      if (!mounted) return;

      // Safety: if somehow only 1 active branch remains, skip picker.
      if (assigned.length <= 1) {
        final fallback = assigned.isNotEmpty ? assigned.first : all.first;
        AdminSession.setActiveBranch(fallback);
        _goToShell();
        return;
      }

      setState(() {
        _branches = assigned;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load branches. Please try again.';
      });
    }
  }

  void _pick(BranchModel branch) {
    AdminSession.setActiveBranch(branch);
    _goToShell();
  }

  void _goToShell() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = AdminSession.user?.fullName ?? 'Admin';

    return Scaffold(
      backgroundColor: AdminColors.sidebarBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Brand mark ───────────────────────────────────────────
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AdminColors.gold, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        'L',
                        style: TextStyle(
                          color: AdminColors.goldLight,
                          fontSize: 24,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Title ────────────────────────────────────────────────
                Text(
                  'Select Branch',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AdminColors.sidebarText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back, $name.\nWhich branch are you working in today?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminColors.sidebarTextMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Body ─────────────────────────────────────────────────
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(color: AdminColors.gold),
                  )
                else if (_error != null)
                  _ErrorState(error: _error!, onRetry: _loadBranches)
                else
                  ..._branches.map((b) => _BranchCard(
                        branch: b,
                        onTap: () => _pick(b),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Branch card ───────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch, required this.onTap});

  final BranchModel branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdminColors.cream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_rounded,
                    color: AdminColors.gold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: const TextStyle(
                          color: AdminColors.sidebarText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (branch.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          branch.address,
                          style: const TextStyle(
                            color: AdminColors.sidebarTextMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (branch.code.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            branch.code,
                            style: const TextStyle(
                              color: AdminColors.goldDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AdminColors.sidebarTextMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AdminColors.error, size: 40),
        const SizedBox(height: 12),
        Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AdminColors.sidebarTextMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminColors.gold,
            side: const BorderSide(color: AdminColors.gold),
          ),
        ),
      ],
    );
  }
}
