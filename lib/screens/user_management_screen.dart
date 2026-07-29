import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/company_profile.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _db = DatabaseService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  List<AppUser> _users = [];
  List<CompanyProfile> _companies = [];
  bool _loading = true;
  String _role = 'Employee';
  String? _selectedCompanyExternalId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    try {
      final users = await auth.getUsers();
      final currentUser = auth.currentUser;
      final companies = currentUser?.isSuperAdmin == true
          ? await auth.getCompanies()
          : <CompanyProfile>[];
      if (!mounted) return;
      setState(() {
        _users = users;
        _companies = companies;
        if (_selectedCompanyExternalId == null && companies.isNotEmpty) {
          _selectedCompanyExternalId = companies.first.externalId;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error)),
      );
    }
  }

  Future<void> _createUser() async {
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    final companyExternalId =
        currentUser?.isSuperAdmin == true ? _selectedCompanyExternalId : null;

    if (currentUser?.isSuperAdmin == true &&
        (companyExternalId == null || companyExternalId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a company first.')),
      );
      return;
    }

    final created = await auth.createEmployee(
      username: _usernameController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
      role: _role,
      companyExternalId: companyExternalId,
    );

    if (created == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error)),
      );
      return;
    }

    _usernameController.clear();
    _passwordController.clear();
    _fullNameController.clear();
    await _load();

    if (!mounted) return;
    final companyLabel = created.companyName.isNotEmpty
        ? created.companyName
        : 'current company';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          'User created: ${created.username} (${created.role}) in $companyLabel',
        ),
      ),
    );
  }

  Future<void> _toggleActive(AppUser user) async {
    final auth = context.read<AuthService>();
    if (auth.isRemoteMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remote user activation toggle is not wired yet. Use the backend admin tools for now.',
          ),
        ),
      );
      return;
    }
    await _db.updateUserActiveState(user.id!, !user.isActive);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser;
    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Users & Roles')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isSuperAdmin) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCompanyExternalId,
                            items: _companies
                                .map(
                                  (company) => DropdownMenuItem(
                                    value: company.externalId,
                                    child: Text(
                                      '${company.name} (${company.slug})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(
                                  () => _selectedCompanyExternalId = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Target Company',
                              helperText:
                                  'Super Admin can create users for any company workspace.',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _fullNameController,
                          decoration:
                              const InputDecoration(labelText: 'Full Name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameController,
                          decoration:
                              const InputDecoration(labelText: 'Username'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _role,
                          items: const [
                            DropdownMenuItem(
                              value: 'Employee',
                              child: Text('Employee'),
                            ),
                            DropdownMenuItem(
                              value: 'Manager',
                              child: Text('Manager'),
                            ),
                            DropdownMenuItem(
                              value: 'Admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _role = value);
                            }
                          },
                          decoration: const InputDecoration(labelText: 'Role'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _createUser,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Create User'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._users.map(
                  (user) => Card(
                    child: ListTile(
                      title: Text(user.fullName),
                      subtitle: Text(
                        user.companyName.isNotEmpty
                            ? '${user.username} - ${user.role}\n${user.companyName}'
                            : '${user.username} - ${user.role}',
                      ),
                      isThreeLine: user.companyName.isNotEmpty,
                      trailing: Switch(
                        value: user.isActive,
                        onChanged: (_) => _toggleActive(user),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
