import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lead.dart';
import '../services/auth_service.dart';
import '../services/crm_extractor.dart';
import '../services/database_service.dart';
import '../services/lead_intelligence_service.dart';
import '../services/lead_remote_service.dart';
import '../theme.dart';
import '../widgets/field_card.dart';
import 'lead_detail_screen.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  final _textCtrl = TextEditingController();
  final _db = DatabaseService();
  final _remote = LeadRemoteService();
  String _leadType = 'Auto Detect';
  CrmFields? _fields;
  LeadIntelligence? _intelligence;
  int _confidence = 0;
  bool _isExtracting = false;
  bool _isSaving = false;

  final List<String> _examples = const [
    'আমার নাম মোহাম্মদ করিম। ফোন ০১৭১২৩৪৫৬৭৮। ঢাকার মিরপুরে থাকি। একটা ফ্ল্যাট কিনতে চাই।',
    'আমি রহিমা বেগম, ০১৯১১২২৩৩৪৪, মিরপুর। আমার ল্যাপটপ নষ্ট হয়ে গেছে। রিফান্ড চাই।',
    'নাম আব্দুল হামিদ। ফোন নম্বর ০১৮১১২২৩৩৪৪। গুলশানে থাকি। গাড়ি কিনতে চাই।',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _extractFields() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Bangla transcript')),
      );
      return;
    }

    setState(() => _isExtracting = true);

    final leadType = _leadType == 'Auto Detect' ? 'auto' : _leadType;
    final fields = CrmExtractor.extract(text, leadType: leadType);
    final confidence = CrmExtractor.computeConfidence(fields);
    final intelligence = LeadIntelligenceService.analyze(
      transcript: text,
      fields: fields,
      confidence: confidence,
    );

    setState(() {
      _fields = fields;
      _intelligence = intelligence;
      _confidence = confidence;
      _isExtracting = false;
    });
  }

  Future<void> _saveLead() async {
    if (_fields == null || _isSaving) return;

    setState(() => _isSaving = true);
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
    try {
      final leadId = await _db.generateLeadId();
      final lead = Lead(
        leadId: leadId,
        dateTime: DateTime.now().toString().substring(0, 19),
        leadType: _fields!.leadType,
        name: _fields!.name,
        phone: _fields!.phone,
        address: _fields!.address,
        location: _fields!.location,
        productInterest: _fields!.productInterest,
        transcript: _textCtrl.text.trim(),
        confidence: _confidence,
      );

      final enrichedLead = LeadIntelligenceService.enrichLead(
        lead: lead,
        fields: _fields!,
      );
      final savedLead = auth.isRemoteMode && await _remote.isConfigured()
          ? await _remote.createLead(enrichedLead)
          : enrichedLead.copyWith(id: await _db.insertLead(enrichedLead));

      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: savedLead)),
      );

      setState(() {
        _textCtrl.clear();
        _fields = null;
        _intelligence = null;
        _confidence = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text Input')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppTheme.accent.withValues(alpha: 0.18)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.keyboard_alt_rounded, color: AppTheme.accent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Paste or type a Bangla conversation here to test CRM extraction without using the microphone.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bangla Transcript',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textCtrl,
                      minLines: 6,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'আমার নাম ... ফোন ... এলাকা ... পণ্য ...',
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Examples',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._examples.map(
                      (example) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _textCtrl.text = example),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notes_rounded,
                                  size: 18, color: AppTheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  example,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.5),
                                ),
                              ),
                            ],
                          ),
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
                      'Lead Type',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ['Auto Detect', 'Sales Lead', 'Customer Support']
                              .map(
                                (type) => ChoiceChip(
                                  label: Text(type),
                                  selected: _leadType == type,
                                  onSelected: (_) =>
                                      setState(() => _leadType = type),
                                  selectedColor:
                                      AppTheme.primary.withValues(alpha: 0.14),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _isExtracting ? null : _extractFields,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text(
                'Extract Fields',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            if (_fields != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Extracted Fields',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          LeadTypeBadge(leadType: _fields!.leadType),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConfidenceBar(confidence: _confidence),
                      const SizedBox(height: 14),
                      FieldCard(
                          icon: 'N',
                          label: 'Name',
                          value: _fields!.name,
                          isRequired: true),
                      const SizedBox(height: 8),
                      FieldCard(
                          icon: 'P',
                          label: 'Phone',
                          value: _fields!.phone,
                          isRequired: true),
                      const SizedBox(height: 8),
                      FieldCard(
                          icon: 'A', label: 'Address', value: _fields!.address),
                      const SizedBox(height: 8),
                      FieldCard(
                          icon: 'L',
                          label: 'Location',
                          value: _fields!.location),
                      const SizedBox(height: 8),
                      FieldCard(
                          icon: 'I',
                          label: 'Product Interest',
                          value: _fields!.productInterest),
                      if (_intelligence != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.14)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI Insight',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _intelligence!.aiSummary,
                                style:
                                    const TextStyle(fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  PriorityBadge(
                                      priority: _intelligence!.priority),
                                  SentimentBadge(
                                      sentiment: _intelligence!.sentiment),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Intent: ${_intelligence!.intent}'),
                              const SizedBox(height: 4),
                              Text('Next Action: ${_intelligence!.nextAction}'),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveLead,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_alt),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Lead',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
