import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/admin_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/services/supabase_service.dart';
import 'features/auth/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to the shared Supabase backend (same project as POS + wallet apps).
  await SupabaseService.initialize();

  // Restore the saved dark/light preference.
  await ThemeController.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LavishAdminApp());
}

class LavishAdminApp extends StatelessWidget {
  const LavishAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Lavish Prima Admin',
          debugShowCheckedModeBanner: false,
          theme: AdminTheme.light,
          darkTheme: AdminTheme.dark,
          themeMode: mode,
          home: const AdminLoginScreen(),
        );
      },
    );
  }
}
