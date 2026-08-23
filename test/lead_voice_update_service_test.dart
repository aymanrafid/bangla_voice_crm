import 'package:bangla_voice_crm/models/lead.dart';
import 'package:bangla_voice_crm/services/lead_voice_update_service.dart';
import 'package:bangla_voice_crm/services/crm_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Lead baseLead() => Lead(
        id: 1,
        leadId: 'LEAD-0001',
        dateTime: '2026-06-22 10:00:00',
        leadType: 'Sales Lead',
        name: 'রহিম',
        phone: '01711111111',
        address: 'মিরপুর, ঢাকা',
        location: 'ঢাকা',
        productInterest: 'Real Estate - Flat',
        transcript: 'base',
        confidence: 85,
        status: 'New',
      );

  test('parses Bangla phone and address updates only', () {
    final proposal = LeadVoiceUpdateService.parseVoiceUpdate(
      currentLead: baseLead(),
      transcript: 'ফোন নম্বর হবে ০১৭১২৩৪৫৬৭৮, ঠিকানা হবে গুলশান ২ ঢাকা',
    );

    expect(proposal.hasChanges, isTrue);
    expect(proposal.changes.length, 2);

    final updated = proposal.applyTo(baseLead());
    expect(updated.phone, '01712345678');
    expect(updated.address, 'গুলশান ২ ঢাকা');
    expect(updated.name, 'রহিম');
  });

  test('extracts a phone number from common ASR Bangla digit spellings', () {
    final fields = CrmExtractor.extract(
      'আমার নাম রহিম। ফোন নম্বর শুন্য এক সাত এক দুইই তীন চাড় পাস ছই সাতো আটও। আমি মিরপুরে থাকি।',
    );

    expect(fields.name, 'রহিম');
    expect(fields.phone, '01712345678');
    expect(fields.location, contains('মিরপুর'));
  });
  test('maps closed status from Bangla command', () {
    final proposal = LeadVoiceUpdateService.parseVoiceUpdate(
      currentLead: baseLead(),
      transcript: 'স্ট্যাটাস ক্লোজড করো',
    );

    expect(proposal.hasChanges, isTrue);
    expect(proposal.changes.single.fieldKey, 'status');
    expect(proposal.changes.single.newValue, 'Closed');
  });
}
