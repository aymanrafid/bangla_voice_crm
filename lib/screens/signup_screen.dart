import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Result handed back to the login screen so it can prefill the new account.
class SignupResult {
  final String username;
  final String companySlug;

  const SignupResult({required this.username, required this.companySlug});
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _companyController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _identityValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Admin email or username is required.';
    if (text.contains(RegExp(r'\s'))) return 'Cannot contain spaces.';
    // Accept a plain username too — the server stores this as User.username.
    if (text.contains('@')) {
      final email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
      if (!email.hasMatch(text)) return 'Enter a valid email address.';
    } else if (text.length < 3) {
      return 'Must be at least 3 characters.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required.';
    // Matches the server's Field(min_length=8) on admin_password.
    if (text.length < 8) return 'Must be at least 8 characters.';
    return null;
  }

  String? _confirmValidator(String? value) {
    if ((value ?? '').isEmpty) return 'Please confirm the password.';
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthService>();
    final slug = await auth.registerAdmin(
      companyName: _companyController.text,
      adminFullName: _fullNameController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (slug == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error.isEmpty ? 'Signup failed.' : auth.error),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      SignupResult(
        username: _usernameController.text.trim(),
        companySlug: slug,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create Admin Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 48,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Register your Company',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Creates your company workspace and its first Admin '
                          'account. You can add employees right after logging in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ModeBanner(isRemote: auth.isRemoteMode),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _companyController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            prefixIcon: Icon(Icons.business_outlined),
                            helperText:
                                'The workspace slug is generated from this.',
                          ),
                          validator: (v) =>
                              _requiredValidator(v, 'Company name'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _fullNameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Admin Full Name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => _requiredValidator(v, 'Full name'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Admin Email (username)',
                            prefixIcon: Icon(Icons.alternate_email),
                            helperText: 'This is what you log in with.',
                          ),
                          validator: _identityValidator,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            helperText: 'At least 8 characters.',
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: _passwordValidator,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!auth.isLoading) _submit();
                          },
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          validator: _confirmValidator,
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          onPressed: auth.isLoading ? null : _submit,
                          icon: auth.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(
                            auth.isLoading
                                ? 'Creating workspace...'
                                : 'Create Account',
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Already have an account? Log in'),
                        ),
                      ],
                    ),
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

class _ModeBanner extends StatelessWidget {
  final bool isRemote;
  const _ModeBanner({required this.isRemote});

  @override
  Widget build(BuildContext context) {
    final color = isRemote ? AppTheme.primary : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRemote ? Icons.cloud_done_outlined : Icons.phone_android_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRemote
                  ? 'Server mode — the workspace is created on your CRM server '
                      'and is available on every device.'
                  : 'Local demo mode — the account is created only on this '
                      'device. Set a CRM server URL in Settings to sync.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
