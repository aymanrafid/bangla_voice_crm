import '../models/lead.dart';
import '../models/lead_field_change.dart';
import 'crm_extractor.dart';

class VoiceLeadUpdateProposal {
  final String transcript;
  final List<LeadFieldChange> changes;
  final List<String> warnings;

  const VoiceLeadUpdateProposal({
    required this.transcript,
    required this.changes,
    required this.warnings,
  });

  bool get hasChanges => changes.isNotEmpty;

  Lead applyTo(Lead lead) {
    var updatedLead = lead;
    for (final change in changes) {
      switch (change.fieldKey) {
        case 'name':
          updatedLead = updatedLead.copyWith(name: change.newValue);
          break;
        case 'phone':
          updatedLead = updatedLead.copyWith(phone: change.newValue);
          break;
        case 'address':
          updatedLead = updatedLead.copyWith(address: change.newValue);
          break;
        case 'location':
          updatedLead = updatedLead.copyWith(location: change.newValue);
          break;
        case 'productInterest':
          updatedLead = updatedLead.copyWith(productInterest: change.newValue);
          break;
        case 'status':
          updatedLead = updatedLead.copyWith(status: change.newValue);
          break;
        case 'leadType':
          updatedLead = updatedLead.copyWith(leadType: change.newValue);
          break;
      }
    }
    return updatedLead;
  }
}

class LeadVoiceUpdateService {
  static const Map<String, String> _fieldLabels = {
    'name': 'নাম',
    'phone': 'ফোন',
    'address': 'ঠিকানা',
    'location': 'এলাকা',
    'productInterest': 'পণ্য/সেবা',
    'status': 'স্ট্যাটাস',
    'leadType': 'লিড টাইপ',
  };

  static const List<String> _phoneKeywords = ['ফোন', 'নম্বর', 'মোবাইল'];
  static const List<String> _addressKeywords = ['ঠিকানা', 'address'];
  static const List<String> _locationKeywords = ['এলাকা', 'লোকেশন', 'location'];
  static const List<String> _productKeywords = [
    'পণ্য',
    'সার্ভিস',
    'প্রোডাক্ট',
    'আগ্রহ',
  ];

  static VoiceLeadUpdateProposal parseVoiceUpdate({
    required Lead currentLead,
    required String transcript,
  }) {
    final cleanTranscript = transcript.trim();
    if (cleanTranscript.isEmpty) {
      return const VoiceLeadUpdateProposal(
        transcript: '',
        changes: [],
        warnings: ['কোনো ভয়েস ইনপুট পাওয়া যায়নি।'],
      );
    }

    final warnings = <String>[];
    final changes = <String, LeadFieldChange>{};
    final clauses = _splitClauses(cleanTranscript);

    for (final clause in clauses) {
      final normalized = _normalize(clause);

      final phoneChange = _parsePhoneChange(currentLead, clause, normalized);
      if (phoneChange != null) {
        changes[phoneChange.fieldKey] = phoneChange;
      } else if (_containsAny(normalized, _phoneKeywords) &&
          !changes.containsKey('phone')) {
        warnings.add('ফোন আপডেট বোঝা গেছে, কিন্তু নতুন নম্বর পাওয়া যায়নি।');
      }

      final nameChange = _parseNameChange(currentLead, clause, normalized);
      if (nameChange != null) {
        changes[nameChange.fieldKey] = nameChange;
      } else if (normalized.contains('নাম') && !changes.containsKey('name')) {
        warnings.add('নাম আপডেট বোঝা গেছে, কিন্তু নতুন নাম পাওয়া যায়নি।');
      }

      final addressChange =
          _parseSimpleFieldChange(currentLead, clause, normalized, 'address');
      if (addressChange != null) {
        changes[addressChange.fieldKey] = addressChange;
      }

      final locationChange =
          _parseSimpleFieldChange(currentLead, clause, normalized, 'location');
      if (locationChange != null) {
        changes[locationChange.fieldKey] = locationChange;
      }

      final productChange =
          _parseProductChange(currentLead, clause, normalized);
      if (productChange != null) {
        changes[productChange.fieldKey] = productChange;
      }

      final statusChange = _parseStatusChange(currentLead, normalized);
      if (statusChange != null) {
        changes[statusChange.fieldKey] = statusChange;
      }

      final leadTypeChange = _parseLeadTypeChange(currentLead, normalized);
      if (leadTypeChange != null) {
        changes[leadTypeChange.fieldKey] = leadTypeChange;
      }
    }

    final filteredChanges =
        changes.values.where((change) => change.hasMeaningfulChange).toList();
    if (filteredChanges.isEmpty && warnings.isEmpty) {
      warnings.add('আপডেট করার মতো নির্দিষ্ট কোনো পরিবর্তন শনাক্ত হয়নি।');
    }

    return VoiceLeadUpdateProposal(
      transcript: cleanTranscript,
      changes: filteredChanges,
      warnings: warnings,
    );
  }

  static List<String> _splitClauses(String transcript) {
    return transcript
        .split(RegExp(r'[।\n,;]+| এবং '))
        .map((clause) => clause.trim())
        .where((clause) => clause.isNotEmpty)
        .toList();
  }

  static LeadFieldChange? _parsePhoneChange(
    Lead currentLead,
    String clause,
    String normalized,
  ) {
    if (!_containsAny(normalized, _phoneKeywords)) return null;

    final fields = CrmExtractor.extract(clause, leadType: 'auto');
    if (fields.phone.isEmpty) return null;
    return _buildChange(
      fieldKey: 'phone',
      oldValue: currentLead.phone,
      newValue: fields.phone,
    );
  }

  static LeadFieldChange? _parseNameChange(
    Lead currentLead,
    String clause,
    String normalized,
  ) {
    if (!normalized.contains('নাম')) return null;

    var value = clause;
    value = value.replaceFirst(
      RegExp(r'.*?নাম(\s+হবে|\s+করো|\s+আপডেট করো|\s+পরিবর্তন করো)?\s*'),
      '',
    );
    value = value.replaceAll(
      RegExp(r'\b(করো|করে দাও|আপডেট|পরিবর্তন)\b'),
      '',
    );
    value = value.trim();

    if (value.isEmpty) {
      value = CrmExtractor.extract(clause, leadType: 'auto').name;
    }

    return value.isEmpty
        ? null
        : _buildChange(
            fieldKey: 'name',
            oldValue: currentLead.name,
            newValue: value,
          );
  }

  static LeadFieldChange? _parseSimpleFieldChange(
    Lead currentLead,
    String clause,
    String normalized,
    String fieldKey,
  ) {
    final keywords = switch (fieldKey) {
      'address' => _addressKeywords,
      'location' => _locationKeywords,
      _ => const <String>[],
    };
    if (!_containsAny(normalized, keywords)) return null;

    final value = _extractValueAfterKeywords(clause, keywords);
    if (value.isEmpty) return null;

    final oldValue = switch (fieldKey) {
      'address' => currentLead.address,
      'location' => currentLead.location,
      _ => '',
    };

    return _buildChange(
      fieldKey: fieldKey,
      oldValue: oldValue,
      newValue: value,
    );
  }

  static LeadFieldChange? _parseProductChange(
    Lead currentLead,
    String clause,
    String normalized,
  ) {
    if (!_containsAny(normalized, _productKeywords)) return null;

    final extracted = CrmExtractor.extract(clause, leadType: 'auto');
    var value = extracted.productInterest;
    if (value.isEmpty) {
      value = _extractValueAfterKeywords(clause, _productKeywords);
    }
    if (value.isEmpty) return null;

    return _buildChange(
      fieldKey: 'productInterest',
      oldValue: currentLead.productInterest,
      newValue: value,
    );
  }

  static LeadFieldChange? _parseStatusChange(
    Lead currentLead,
    String normalized,
  ) {
    final mappedStatus = _mapStatus(normalized);
    if (mappedStatus == null) return null;
    return _buildChange(
      fieldKey: 'status',
      oldValue: currentLead.status,
      newValue: mappedStatus,
    );
  }

  static LeadFieldChange? _parseLeadTypeChange(
    Lead currentLead,
    String normalized,
  ) {
    if (!normalized.contains('লিড টাইপ') &&
        !normalized.contains('lead type') &&
        !normalized.contains('সাপোর্ট') &&
        !normalized.contains('সেলস')) {
      return null;
    }

    String? mappedLeadType;
    if (normalized.contains('সাপোর্ট') || normalized.contains('support')) {
      mappedLeadType = 'Customer Support';
    } else if (normalized.contains('সেলস') || normalized.contains('sales')) {
      mappedLeadType = 'Sales Lead';
    }

    if (mappedLeadType == null) return null;
    return _buildChange(
      fieldKey: 'leadType',
      oldValue: currentLead.leadType,
      newValue: mappedLeadType,
    );
  }

  static LeadFieldChange _buildChange({
    required String fieldKey,
    required String oldValue,
    required String newValue,
  }) {
    return LeadFieldChange(
      fieldKey: fieldKey,
      label: _fieldLabels[fieldKey] ?? fieldKey,
      oldValue: oldValue,
      newValue: _cleanValue(newValue),
    );
  }

  static String _extractValueAfterKeywords(
    String clause,
    List<String> keywords,
  ) {
    var value = clause;
    for (final keyword in keywords) {
      value = value.replaceFirst(
        RegExp(
          '.*?${RegExp.escape(keyword)}(\\s+হবে|\\s+করো|\\s+আপডেট করো|\\s+পরিবর্তন করো|\\s+দাও|\\s+to)?\\s*',
          caseSensitive: false,
        ),
        '',
      );
    }
    value = value
        .replaceAll(RegExp(r'\b(করো|করে দাও|আপডেট|পরিবর্তন|হবে|দাও)\b'), '')
        .trim();
    return _cleanValue(value);
  }

  static String _normalize(String text) {
    return CrmExtractor.normalizeBanglaDigits(text.toLowerCase())
        .replaceAll(RegExp(r'[,:;!?()\[\]{}]'), ' ')
        .replaceAll('।', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _containsAny(String normalized, List<String> keywords) {
    for (final keyword in keywords) {
      if (normalized.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  static String _cleanValue(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^(হবে|করো|দাও)\s+'), '')
        .trim();
  }

  static String? _mapStatus(String normalized) {
    if (normalized.contains('স্ট্যাটাস') ||
        normalized.contains('status') ||
        normalized.contains('ক্লোজড') ||
        normalized.contains('converted') ||
        normalized.contains('contacted')) {
      if (normalized.contains('ক্লোজড') ||
          normalized.contains('closed') ||
          normalized.contains('বন্ধ')) {
        return 'Closed';
      }
      if (normalized.contains('কনভার্টেড') ||
          normalized.contains('converted') ||
          normalized.contains('সম্পন্ন')) {
        return 'Converted';
      }
      if (normalized.contains('কন্টাক্টেড') ||
          normalized.contains('contacted') ||
          normalized.contains('যোগাযোগ')) {
        return 'Contacted';
      }
      if (normalized.contains('নিউ') ||
          normalized.contains('new') ||
          normalized.contains('নতুন')) {
        return 'New';
      }
    }
    return null;
  }
}
