import '../models/app_user.dart';
import '../models/lead.dart';
import 'crm_api_client.dart';

class LeadRemoteService {
  final CrmApiClient _client = CrmApiClient();

  Future<bool> isConfigured() => _client.isConfigured();

  Future<Lead> createLead(Lead lead) async {
    final remoteLead = lead.copyWith(
      leadId: _ensureRemoteLeadId(lead.leadId),
      version: lead.version <= 0 ? 1 : lead.version,
    );
    final data = await _client.post('/leads', _leadPayload(remoteLead));
    return _leadFromApi(data as Map<String, dynamic>);
  }

  Future<List<Lead>> getLeads({String? assignedUserExternalId}) async {
    final data = await _client.get(
      '/leads',
      query: assignedUserExternalId == null || assignedUserExternalId.isEmpty
          ? null
          : {'assigned_user_external_id': assignedUserExternalId},
    );
    return (data as List<dynamic>)
        .map((item) => _leadFromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<Lead> updateLead(Lead lead) async {
    final data = await _client.put('/leads/${lead.leadId}', _leadPayload(lead));
    return _leadFromApi(data as Map<String, dynamic>);
  }

  Future<Lead> assignLead(Lead lead, AppUser employee) {
    return updateLead(
      lead.copyWith(
        assignedEmployeeExternalId: employee.externalId,
        assignedEmployeeName: employee.fullName,
      ),
    );
  }

  Future<Lead> updateStatus(Lead lead, String status) {
    return updateLead(lead.copyWith(status: status));
  }

  Future<void> deleteLead(String leadId) async {
    await _client.delete('/leads/$leadId');
  }

  String _ensureRemoteLeadId(String leadId) {
    if (leadId.isEmpty || RegExp(r'^LEAD-\d{4}$').hasMatch(leadId)) {
      return 'LEAD-${DateTime.now().millisecondsSinceEpoch}';
    }
    return leadId;
  }

  Map<String, dynamic> _leadPayload(Lead lead) {
    return {
      'external_id': lead.leadId,
      'lead_type': lead.leadType,
      'name': lead.name,
      'phone': lead.phone,
      'address': lead.address,
      'location': lead.location,
      'product_interest': lead.productInterest,
      'transcript': lead.transcript,
      'status': lead.status,
      'confidence': lead.confidence,
      'intent': lead.intent,
      'sentiment': lead.sentiment,
      'priority': lead.priority,
      'lead_score': lead.leadScore,
      'ai_summary': lead.aiSummary,
      'next_action': lead.nextAction,
      'assigned_user_external_id': lead.assignedEmployeeExternalId.isEmpty
          ? null
          : lead.assignedEmployeeExternalId,
      'version': lead.version <= 0 ? 1 : lead.version,
    };
  }

  Lead _leadFromApi(Map<String, dynamic> map) {
    return Lead(
      leadId: map['external_id']?.toString() ?? '',
      dateTime: (map['created_at'] ?? '').toString().replaceFirst('T', ' '),
      leadType: map['lead_type'] ?? 'Sales Lead',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      location: map['location'] ?? '',
      productInterest: map['product_interest'] ?? '',
      transcript: map['transcript'] ?? '',
      status: map['status'] ?? 'New',
      confidence: map['confidence'] ?? 0,
      intent: map['intent'] ?? 'General Inquiry',
      sentiment: map['sentiment'] ?? 'Neutral',
      priority: map['priority'] ?? 'Normal',
      leadScore: map['lead_score'] ?? 50,
      aiSummary: map['ai_summary'] ?? '',
      nextAction: map['next_action'] ?? '',
      assignedEmployeeExternalId:
          map['assigned_user_external_id']?.toString() ?? '',
      version: map['version'] ?? 1,
    );
  }
}
