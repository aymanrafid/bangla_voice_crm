import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/admin_shell_screen.dart';
import 'screens/employee_shell_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BanglaVoiceCRMApp());
}

class BanglaVoiceCRMApp extends StatelessWidget {
  const BanglaVoiceCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService()..initialize(),
      child: MaterialApp(
        title: 'Bangla Voice CRM',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const AppBootstrapScreen(),
      ),
    );
  }
}

class AppBootstrapScreen extends StatelessWidget {
  const AppBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isInitialized || auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final user = auth.currentUser;
    if (user == null) {
      return const LoginScreen();
    }
    if (user.isAdmin) {
      return const AdminShellScreen();
    }
    return const EmployeeShellScreen();
  }
}
