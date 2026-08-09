import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_config_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _config = ApiConfigService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companySlugController = TextEditingController();
  String _crmUrl = '';
  String _asrUrl = '';
  bool _showWakingUp = false;
  Timer? _wakingUpTimer;

  @override
  void initState() {
    super.initState();
    _loadUrls();
  }

  Future<void> _loadUrls() async {
    final crmUrl = await _config.getCrmApiBaseUrl();
    final asrUrl = await _config.getAsrApiUrl();
    final companySlug = await _config.getCompanySlug();
    if (!mounted) return;
    setState(() {
      _crmUrl = crmUrl;
      _asrUrl = asrUrl;
      _companySlugController.text = companySlug;
    });
  }

  @override
  void dispose() {
    _wakingUpTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _companySlugController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthService>();
    await _config.saveCompanySlug(_companySlugController.text.trim());

    // After 5 s, show "server waking up" hint (Render cold start)
    _wakingUpTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showWakingUp = true);
    });

    final ok = await auth.login(
      username: _usernameController.text,
      password: _passwordController.text,
      companySlug: _companySlugController.text,
    );

    _wakingUpTimer?.cancel();
    if (mounted) setState(() => _showWakingUp = false);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _loadUrls();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: auth.isLoading ? null : _openSettings,
                            icon: const Icon(Icons.settings, size: 18),
                            label: const Text('Server Settings'),
                          ),
                        ],
                      ),
                      if (_showWakingUp) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Server is waking up… This may take up to 60 seconds on the free Render plan.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade900,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const Icon(
                        Icons.mic_rounded,
                        size: 54,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bangla Voice CRM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        auth.isRemoteMode
                            ? 'Use your company CRM account to access leads, meetings, field monitoring, and reports.'
                            : 'Local demo mode is active. You can use the seeded admin account for offline testing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current server setup',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'CRM: ${_crmUrl.isEmpty ? 'Not set' : _crmUrl}',
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ASR: ${_asrUrl.isEmpty ? 'Not set' : _asrUrl}',
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (auth.isRemoteMode) ...[
                        TextField(
                          controller: _companySlugController,
                          decoration: const InputDecoration(
                            labelText: 'Company Slug',
                            prefixIcon: Icon(Icons.apartment_outlined),
                            helperText:
                                'Use the company slug created by the Super Admin. Leave blank only for single-company fallback.',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: auth.isLoading ? null : _login,
                        icon: auth.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(auth.isLoading ? 'Logging in...' : 'Login'),
                      ),
                      if (auth.isRemoteMode) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Multi-company mode\nExample flow: company slug + username + password.\nEach company only sees its own users, leads, reports, and tracking data.',
                            style: TextStyle(height: 1.5),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Demo Admin\nUsername: admin\nPassword: admin123',
                            style: TextStyle(height: 1.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
