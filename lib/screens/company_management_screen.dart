import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/company_profile.dart';
import '../services/auth_service.dart';

class CompanyManagementScreen extends StatefulWidget {
  const CompanyManagementScreen({super.key});

  @override
  State<CompanyManagementScreen> createState() =>
      _CompanyManagementScreenState();
}

class _CompanyManagementScreenState extends State<CompanyManagementScreen> {
  final _companyNameController = TextEditingController();
  final _companySlugController = TextEditingController();
  final _adminFullNameController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  List<CompanyProfile> _companies = [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companySlugController.dispose();
    _adminFullNameController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    try {
      final companies = await auth.getCompanies();
      if (!mounted) return;
      setState(() {
        _companies = companies;
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

  Future<void> _createCompany() async {
    if (_companyNameController.text.trim().isEmpty ||
        _adminFullNameController.text.trim().isEmpty ||
        _adminUsernameController.text.trim().isEmpty ||
        _adminPasswordController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter company name, admin name, admin username, and a password with at least 8 characters.',
          ),
        ),
      );
      return;
    }

    setState(() => _creating = true);
    final auth = context.read<AuthService>();
    final result = await auth.createCompany(
      name: _companyNameController.text,
      slug: _companySlugController.text,
      adminUsername: _adminUsernameController.text,
      adminPassword: _adminPasswordController.text,
      adminFullName: _adminFullNameController.text,
    );
    if (!mounted) return;
    setState(() => _creating = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error)),
      );
      return;
    }

    _companyNameController.clear();
    _companySlugController.clear();
    _adminFullNameController.clear();
    _adminUsernameController.clear();
    _adminPasswordController.clear();
    await _loadCompanies();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          'Company created: ${result.company.name} (${result.company.slug})\nAdmin: ${result.adminUser.username}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser;
    final isAllowed = currentUser?.isSuperAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Company Management')),
      body: !isAllowed
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only Super Admin can provision new companies from the app.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _loading
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
                              'Provision New Company',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This creates a company workspace and its first admin account. That admin can then manage only their own company data.',
                              style: TextStyle(height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _companyNameController,
                              decoration: const InputDecoration(
                                labelText: 'Company Name',
                                prefixIcon: Icon(Icons.business_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _companySlugController,
                              decoration: const InputDecoration(
                                labelText: 'Company Slug (optional)',
                                prefixIcon: Icon(Icons.tag_outlined),
                                helperText:
                                    'If left empty, the server can derive it from the company name.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _adminFullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Admin Full Name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _adminUsernameController,
                              decoration: const InputDecoration(
                                labelText: 'Admin Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _adminPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Admin Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _creating ? null : _createCompany,
                                icon: _creating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add_business_outlined),
                                label: Text(
                                  _creating
                                      ? 'Creating company...'
                                      : 'Create Company Workspace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Existing Companies',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_companies.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No companies found yet.'),
                        ),
                      ),
                    ..._companies.map(
                      (company) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.apartment_outlined),
                          ),
                          title: Text(company.name),
                          subtitle: Text(
                            'Slug: ${company.slug}\nStatus: ${company.status}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
