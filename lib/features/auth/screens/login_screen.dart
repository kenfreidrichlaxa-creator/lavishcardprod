import 'package:flutter/material.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/update_prompt.dart';
import '../../../data/services/admin_auth_repository.dart';
import '../../../navigation/admin_shell.dart';
import '../../../navigation/manager_shell.dart';
import '../../../navigation/super_admin_shell.dart';
import 'branch_picker_screen.dart';

/// Admin panel login screen.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Check for a newer release once at startup (non-blocking, fails silently).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final update = await UpdateService.checkForUpdate();
      if (!mounted) return;
      await UpdatePrompt.maybeShow(context, update);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = await AdminAuthRepository.instance.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      AdminSession.setUser(user);

      if (!mounted) return;
      setState(() => _loading = false);

      // Multi-branch admins (not super admin, not manager) pick their branch
      // before entering the shell so all queries are scoped to one branch.
      final Widget shell;
      if (user.isSuperAdmin) {
        shell = const SuperAdminShell();
      } else if (user.isManager) {
        shell = const ManagerShell();
      } else if (user.branchIds.length > 1) {
        // Show the branch picker — it will navigate to AdminShell itself.
        shell = const BranchPickerScreen();
      } else {
        shell = const AdminShell();
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => shell),
      );
    } on AdminAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not connect. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 960;
    final card = _LoginCard(
      formKey: _formKey,
      emailCtrl: _emailCtrl,
      passwordCtrl: _passwordCtrl,
      loading: _loading,
      errorMessage: _errorMessage,
      onLogin: _handleLogin,
    );

    return Scaffold(
      backgroundColor: AdminColors.sidebarBg,
      body: isWide
          ? _WideLayout(child: card)
          : _NarrowLayout(child: card),
    );
  }
}

// ── Wide layout: split panel ──────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Left brand panel
      Expanded(
        flex: 5,
        child: Container(
          color: AdminColors.sidebarBg,
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AdminColors.gold, width: 1.5),
                  ),
                  child: const Center(
                    child: Text('L',
                        style: TextStyle(
                            color: AdminColors.goldLight,
                            fontSize: 22,
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w300)),
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LAVISH PRIMA',
                        style: TextStyle(
                            color: AdminColors.goldLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3)),
                    Text('Admin Panel',
                        style: TextStyle(
                            color: AdminColors.sidebarTextMuted,
                            fontSize: 11,
                            letterSpacing: 0.5)),
                  ],
                ),
              ]),

              const Spacer(),

              // Brand copy
              const Text(
                'Manage your salon\nwith confidence.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    height: 1.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'Complete control over card owners, cards,\n'
                'staff, services, and transactions.',
                style: TextStyle(
                    color: AdminColors.sidebarTextMuted,
                    fontSize: 14,
                    height: 1.6),
              ),

              const Spacer(),

              // Demo credentials
              _CredCard(
                title: 'Administrator Account',
                titleColor: AdminColors.goldLight,
                borderOpacity: 0.3,
                email: 'admin@lavishprima.com',
                password: 'Admin@2026',
              ),
              const SizedBox(height: 8),
              _CredCard(
                title: 'Manager Account',
                titleColor: AdminColors.sidebarTextMuted,
                borderOpacity: 0.2,
                email: 'manager@lavishprima.com',
                password: 'Manager@2026',
              ),
            ],
          ),
        ),
      ),

      // Right login form
      Expanded(
        flex: 4,
        child: Container(
          color: AdminColors.pageBg,
          child: Center(child: child),
        ),
      ),
    ]);
  }
}

class _CredCard extends StatelessWidget {
  const _CredCard({
    required this.title,
    required this.titleColor,
    required this.borderOpacity,
    required this.email,
    required this.password,
  });

  final String title;
  final Color titleColor;
  final double borderOpacity;
  final String email;
  final String password;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.sidebarSelected,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AdminColors.gold.withValues(alpha: borderOpacity)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: titleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _CredRow('Email', email),
          const SizedBox(height: 4),
          _CredRow('Password', password),
        ],
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  const _CredRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 64,
        child: Text(label,
            style: const TextStyle(
                color: AdminColors.sidebarTextMuted, fontSize: 11)),
      ),
      Text(value,
          style: const TextStyle(
              color: AdminColors.sidebarText,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Narrow layout ─────────────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AdminColors.gold, width: 1.5),
            ),
            child: const Center(
              child: Text('L',
                  style: TextStyle(
                      color: AdminColors.goldLight,
                      fontSize: 24,
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w300)),
            ),
          ),
          const SizedBox(height: 12),
          const Text('LAVISH PRIMA',
              style: TextStyle(
                  color: AdminColors.goldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3)),
          const Text('Admin Panel',
              style: TextStyle(
                  color: AdminColors.sidebarTextMuted, fontSize: 10)),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

// ── Login card (StatefulWidget —Emanages its own obscure toggle) ──────────────

class _LoginCard extends StatefulWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.errorMessage,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onLogin;

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: widget.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text('Sign In', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Access the Lavish Prima admin panel.',
                    style: theme.textTheme.bodyMedium),

                const SizedBox(height: 28),

                // Error banner
                if (widget.errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AdminColors.statusSuspendedBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AdminColors.statusSuspended
                              .withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: AdminColors.statusSuspended),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.errorMessage!,
                            style: const TextStyle(
                                color: AdminColors.statusSuspended,
                                fontSize: 13)),
                      ),
                    ]),
                  ),

                // Email
                TextFormField(
                  controller: widget.emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: widget.passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => widget.onLogin(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                      tooltip:
                          _obscure ? 'Show password' : 'Hide password',
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _AdminForgotPasswordDialog(
                        initialEmail: widget.emailCtrl.text.contains('@')
                            ? widget.emailCtrl.text.trim()
                            : '',
                      ),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),

                const SizedBox(height: 8),

                // Sign in button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: widget.loading ? null : widget.onLogin,
                    child: widget.loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                ),

                const SizedBox(height: 20),

                // Footer
                Center(
                  child: Text(
                    'Lavish Prima  ·  Admin Panel  v1.0',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── Forgot password (admin + super admin) ────────────────────────────────────

class _AdminForgotPasswordDialog extends StatefulWidget {
  const _AdminForgotPasswordDialog({this.initialEmail = ''});
  final String initialEmail;

  @override
  State<_AdminForgotPasswordDialog> createState() =>
      _AdminForgotPasswordDialogState();
}

class _AdminForgotPasswordDialogState
    extends State<_AdminForgotPasswordDialog> {
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    final err =
        await AdminAuthRepository.instance.sendPasswordReset(_emailCtrl.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = err == null;
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AdminColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_sent ? 'Check your email' : 'Forgot Password'),
      content: _sent
          ? Text(
              'If an admin account exists for that email, a 6-digit reset code '
              'has been sent. Open the reset page from the email and enter the '
              'code with your new password.\n\nCheck your inbox and spam folder.',
              style: theme.textTheme.bodyMedium,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your admin email and we\'ll send a reset code.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                    hintText: 'you@email.com',
                  ),
                ),
              ],
            ),
      actions: _sent
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ]
          : [
              TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Send Reset Code'),
              ),
            ],
    );
  }
}
