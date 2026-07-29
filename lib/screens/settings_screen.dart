import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_config_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _config = ApiConfigService();
  final _apiUrlCtrl = TextEditingController();
  final _crmApiCtrl = TextEditingController();
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final asrSaved = await _config.getAsrApiUrl();
    final crmSaved = await _config.getCrmApiBaseUrl();
    _apiUrlCtrl.text = asrSaved;
    _crmApiCtrl.text = crmSaved;
    setState(() {
      _loading = false;
      _saved = asrSaved.isNotEmpty || crmSaved.isNotEmpty;
    });
  }

  Future<void> _saveUrl() async {
    final asrUrl = _apiUrlCtrl.text.trim();
    final crmUrl = _crmApiCtrl.text.trim();
    if (asrUrl.isEmpty && crmUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one URL first')),
      );
      return;
    }
    if (asrUrl.isNotEmpty) {
      await _config.saveAsrApiUrl(asrUrl);
    }
    await _config.saveCrmApiBaseUrl(crmUrl);
    if (mounted) {
      await context.read<AuthService>().refreshMode();
    }
    setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server settings saved.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _crmApiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_saved)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CRM: ${_crmApiCtrl.text.isEmpty ? 'not set' : _crmApiCtrl.text}\nASR: ${_apiUrlCtrl.text.isEmpty ? 'not set' : _apiUrlCtrl.text}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Production CRM API',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Set the cloud FastAPI base URL for JWT login, users, leads, tracking, and reports.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _crmApiCtrl,
                            onChanged: (_) => setState(() => _saved = false),
                            decoration: const InputDecoration(
                              hintText: 'https://api.yourdomain.com',
                              prefixIcon: Icon(Icons.cloud_outlined, size: 18),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'BanglaASR Server URL',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Paste your self-hosted BanglaASR /transcribe URL here.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _apiUrlCtrl,
                            onChanged: (_) => setState(() => _saved = false),
                            decoration: const InputDecoration(
                              hintText: 'http://192.168.0.113:8001/transcribe',
                              prefixIcon: Icon(Icons.link, size: 18),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveUrl,
                              icon: const Icon(Icons.save),
                              label: const Text(
                                'SAVE SETTINGS',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Steps to connect',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _step('1',
                              'Run the production CRM API with python -m uvicorn backend.crm_server:app --host 0.0.0.0 --port 9000.'),
                          _step('2',
                              'Run the BanglaASR server with python -m uvicorn asr_server:app --host 0.0.0.0 --port 8001 from the backend folder.'),
                          _step('3',
                              'Use an HTTPS domain for the CRM API in production, such as https://api.yourdomain.com.'),
                          _step('4', 'Your ASR URL must end with /transcribe.'),
                          _step('5',
                              'For Play Store release, keep CRM in cloud and remove local-network dependency for login and data sync.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
