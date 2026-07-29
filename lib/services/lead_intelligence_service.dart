import '../models/lead.dart';
import 'crm_extractor.dart';

class LeadIntelligence {
  final String intent;
  final String sentiment;
  final String priority;
  final int leadScore;
  final String aiSummary;
  final String nextAction;

  const LeadIntelligence({
    required this.intent,
    required this.sentiment,
    required this.priority,
    required this.leadScore,
    required this.aiSummary,
    required this.nextAction,
  });
}

class LeadIntelligenceService {
  static const Map<String, List<String>> _intentKeywords = {
    'Purchase Intent': [
      'ফ্ল্যাট',
      'অ্যাপার্টমেন্ট',
      'জমি',
      'প্লট',
      'গাড়ি',
      'বাইক',
      'কিনতে',
      'চাই'
    ],
    'Pricing Inquiry': ['দাম', 'মূল্য', 'price', 'cost', 'quotation', 'কোটেশন'],
    'Support Complaint': [
      'সমস্যা',
      'অভিযোগ',
      'নষ্ট',
      'কাজ করছে না',
      'কাজ করে না',
      'রিফান্ড'
    ],
    'Delivery Follow-up': ['ডেলিভারি', 'দেরি', 'কবে পাব', 'অর্ডার', 'shipment'],
    'Callback Request': [
      'ফিরে কল',
      'callback',
      'পরে কথা',
      'যোগাযোগ',
      'কল করবেন'
    ],
  };

  static const List<String> _negativeWords = [
    'সমস্যা',
    'অভিযোগ',
    'নষ্ট',
    'দেরি',
    'রিফান্ড',
    'খারাপ',
    'urgent',
    'জরুরি',
  ];

  static const List<String> _positiveWords = [
    'চাই',
    'ভালো',
    'পছন্দ',
    'কিনবো',
    'book',
    'confirm',
    'আগামীকাল',
  ];

  static LeadIntelligence analyze({
    required String transcript,
    required CrmFields fields,
    required int confidence,
  }) {
    final text = transcript.toLowerCase();
    final intent = _detectIntent(text, fields);
    final sentiment = _detectSentiment(text, fields);
    final priority = _detectPriority(
      text: text,
      fields: fields,
      confidence: confidence,
      intent: intent,
      sentiment: sentiment,
    );
    final leadScore = _computeLeadScore(
      fields: fields,
      confidence: confidence,
      intent: intent,
      sentiment: sentiment,
      priority: priority,
    );
    final aiSummary =
        _buildSummary(fields: fields, intent: intent, sentiment: sentiment);
    final nextAction = _recommendNextAction(
      fields: fields,
      intent: intent,
      sentiment: sentiment,
      priority: priority,
      leadScore: leadScore,
    );

    return LeadIntelligence(
      intent: intent,
      sentiment: sentiment,
      priority: priority,
      leadScore: leadScore,
      aiSummary: aiSummary,
      nextAction: nextAction,
    );
  }

  static Lead enrichLead({
    required Lead lead,
    required CrmFields fields,
  }) {
    final intelligence = analyze(
      transcript: lead.transcript,
      fields: fields,
      confidence: lead.confidence,
    );

    return lead.copyWith(
      intent: intelligence.intent,
      sentiment: intelligence.sentiment,
      priority: intelligence.priority,
      leadScore: intelligence.leadScore,
      aiSummary: intelligence.aiSummary,
      nextAction: intelligence.nextAction,
    );
  }

  static String _detectIntent(String text, CrmFields fields) {
    for (final entry in _intentKeywords.entries) {
      if (entry.value.any(text.contains)) {
        return entry.key;
      }
    }

    if (fields.leadType == 'Customer Support') {
      return 'Support Follow-up';
    }
    if (fields.productInterest.isNotEmpty) {
      return 'Product Inquiry';
    }
    return 'General Inquiry';
  }

  static String _detectSentiment(String text, CrmFields fields) {
    final negativeHits = _negativeWords.where(text.contains).length;
    final positiveHits = _positiveWords.where(text.contains).length;

    if (fields.leadType == 'Customer Support' && negativeHits >= positiveHits) {
      return negativeHits > 1 ? 'Frustrated' : 'Concerned';
    }
    if (positiveHits > negativeHits) {
      return 'Positive';
    }
    if (negativeHits > positiveHits) {
      return 'Negative';
    }
    return 'Neutral';
  }

  static String _detectPriority({
    required String text,
    required CrmFields fields,
    required int confidence,
    required String intent,
    required String sentiment,
  }) {
    final hasPhone = fields.phone.isNotEmpty;
    final hasLocation = fields.location.isNotEmpty || fields.address.isNotEmpty;
    final hasUrgentWord = text.contains('জরুরি') || text.contains('urgent');

    if (hasUrgentWord ||
        intent == 'Support Complaint' ||
        sentiment == 'Frustrated') {
      return 'High';
    }
    if (fields.leadType == 'Sales Lead' &&
        fields.productInterest.isNotEmpty &&
        hasPhone &&
        hasLocation &&
        confidence >= 75) {
      return 'High';
    }
    if (hasPhone || confidence >= 55) {
      return 'Medium';
    }
    return 'Normal';
  }

  static int _computeLeadScore({
    required CrmFields fields,
    required int confidence,
    required String intent,
    required String sentiment,
    required String priority,
  }) {
    int score = confidence;
    if (fields.phone.isNotEmpty) score += 10;
    if (fields.location.isNotEmpty || fields.address.isNotEmpty) score += 8;
    if (fields.productInterest.isNotEmpty) score += 8;
    if (intent == 'Purchase Intent') score += 12;
    if (priority == 'High') score += 10;
    if (sentiment == 'Positive') score += 5;
    if (sentiment == 'Frustrated') score -= 3;
    return score.clamp(0, 100);
  }

  static String _buildSummary({
    required CrmFields fields,
    required String intent,
    required String sentiment,
  }) {
    final subject = fields.name.isNotEmpty ? fields.name : 'Unknown customer';
    final location = fields.location.isNotEmpty
        ? ' from ${fields.location}'
        : fields.address.isNotEmpty
            ? ' from ${fields.address}'
            : '';
    final interest = fields.productInterest.isNotEmpty
        ? ' regarding ${fields.productInterest}'
        : '';
    return '$subject$location shows $intent$interest with $sentiment sentiment.';
  }

  static String _recommendNextAction({
    required CrmFields fields,
    required String intent,
    required String sentiment,
    required String priority,
    required int leadScore,
  }) {
    if (priority == 'High' && intent == 'Support Complaint') {
      return 'Escalate to support and call back within 30 minutes.';
    }
    if (priority == 'High' && fields.phone.isNotEmpty) {
      return 'Assign to agent for same-day follow-up call.';
    }
    if (intent == 'Purchase Intent' && leadScore >= 70) {
      return 'Share pricing, verify budget, and schedule a follow-up.';
    }
    if (sentiment == 'Negative' || sentiment == 'Concerned') {
      return 'Respond carefully, confirm the issue, and log a resolution note.';
    }
    if (fields.phone.isEmpty) {
      return 'Request a verified phone number before moving this lead forward.';
    }
    return 'Review details, qualify the lead, and plan the next contact.';
  }
}
