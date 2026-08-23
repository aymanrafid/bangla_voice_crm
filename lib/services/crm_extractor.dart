class CrmFields {
  String leadType;
  String name;
  String phone;
  String address;
  String location;
  String productInterest;

  CrmFields({
    this.leadType = '',
    this.name = '',
    this.phone = '',
    this.address = '',
    this.location = '',
    this.productInterest = '',
  });
}

class CrmExtractor {
  static const Map<String, List<String>> _salesProductMap = {
    'Real Estate - Flat': ['ফ্ল্যাট', 'এপার্টমেন্ট', 'অ্যাপার্টমেন্ট', 'বাসা'],
    'Real Estate - Land': ['জমি', 'প্লট', 'ভূমি'],
    'Vehicle - Car': ['গাড়ি', 'গাড়ি', 'কার'],
    'Vehicle - Bike': ['বাইক', 'মোটরসাইকেল'],
    'Electronics - Laptop': ['ল্যাপটপ', 'ল্যাপটাপ', 'কম্পিউটার'],
    'Electronics - Mobile': ['মোবাইল', 'ফোনসেট', 'স্মার্টফোন'],
    'Finance - Loan': ['লোন', 'ঋণ', 'কিস্তি'],
    'Education - Course': ['কোর্স', 'ভর্তি', 'এডমিশন'],
    'Healthcare - Service': ['হাসপাতাল', 'চিকিৎসা', 'ডাক্তার', 'মেডিকেল'],
  };

  static const Map<String, List<String>> _supportIssueMap = {
    'Technical Issue': ['সমস্যা', 'প্রবলেম', 'কাজ করছে না', 'চলছে না'],
    'Refund Request': ['রিফান্ড', 'ফেরত', 'টাকা ফেরত'],
    'Delivery Issue': ['ডেলিভারি', 'দেরি', 'পাইনি', 'অর্ডার আসেনি'],
    'Account Access': ['লগইন', 'পাসওয়ার্ড', 'পাসওয়ার্ড', 'অ্যাকাউন্ট'],
    'Damaged Product': ['নষ্ট', 'ভাঙা', 'ড্যামেজ', 'খারাপ'],
    'Billing Issue': ['বিল', 'পেমেন্ট', 'চার্জ'],
  };

  static const Map<String, List<String>> _locationAliases = {
    'ঢাকা': ['ঢাকা', 'ঢাকার'],
    'মিরপুর': ['মিরপুর', 'মিরপুরে'],
    'উত্তরা': ['উত্তরা', 'উত্তরায়', 'উত্তরাতে'],
    'গুলশান': ['গুলশান', 'গুলশানে'],
    'বনানী': ['বনানী', 'বনানীতে'],
    'ধানমন্ডি': ['ধানমন্ডি', 'ধানমন্ডিতে'],
    'মোহাম্মদপুর': ['মোহাম্মদপুর', 'মোহাম্মদপুরে'],
    'সাভার': ['সাভার', 'সাভারে'],
    'কেরানীগঞ্জ': ['কেরানীগঞ্জ', 'কেরানীগঞ্জে'],
    'নারায়ণগঞ্জ': ['নারায়ণগঞ্জ', 'নারায়ণগঞ্জে', 'নারায়নগঞ্জ'],
    'গাজীপুর': ['গাজীপুর', 'গাজীপুরে'],
    'চট্টগ্রাম': ['চট্টগ্রাম', 'চিটাগাং', 'চিটাগং', 'চট্টগ্রামে'],
    'কক্সবাজার': ['কক্সবাজার', 'কক্স বাজার', 'কক্সবাজারে'],
    'কুমিল্লা': ['কুমিল্লা', 'কুমিল্লার', 'কুমিল্লাতে'],
    'নোয়াখালী': ['নোয়াখালী', 'নোয়াখালী', 'নোয়াখালীর', 'নোয়াখালীর'],
    'ফেনী': ['ফেনী', 'ফেনীতে'],
    'সিলেট': ['সিলেট', 'সিলেটে'],
    'মৌলভীবাজার': ['মৌলভীবাজার', 'মৌলভীবাজারে'],
    'হবিগঞ্জ': ['হবিগঞ্জ', 'হবিগঞ্জে'],
    'সুনামগঞ্জ': ['সুনামগঞ্জ', 'সুনামগঞ্জে'],
    'রাজশাহী': ['রাজশাহী', 'রাজশাহীতে'],
    'বগুড়া': ['বগুড়া', 'বগুড়া', 'বগুড়ায়'],
    'পাবনা': ['পাবনা', 'পাবনায়'],
    'রংপুর': ['রংপুর', 'রংপুরে'],
    'দিনাজপুর': ['দিনাজপুর', 'দিনাজপুরে'],
    'ঠাকুরগাঁও': ['ঠাকুরগাঁও', 'ঠাকুরগাঁওয়ে'],
    'খুলনা': ['খুলনা', 'খুলনায়'],
    'যশোর': ['যশোর', 'যশোরে', 'জেসোর'],
    'কুষ্টিয়া': ['কুষ্টিয়া', 'কুষ্টিয়ায়', 'কুষ্টিয়ায়'],
    'বরিশাল': ['বরিশাল', 'বরিশালে'],
    'পটুয়াখালী': ['পটুয়াখালী', 'পটুয়াখালী', 'পটুয়াখালীতে'],
    'ভোলা': ['ভোলা', 'ভোলায়'],
    'ময়মনসিংহ': ['ময়মনসিংহ', 'ময়মনসিংহ', 'ময়মনসিংহে'],
    'জামালপুর': ['জামালপুর', 'জামালপুরে'],
    'কিশোরগঞ্জ': ['কিশোরগঞ্জ', 'কিশোরগঞ্জে'],
    'টাঙ্গাইল': ['টাঙ্গাইল', 'টাঙ্গাইলে'],
    'শরীয়তপুর': ['শরীয়তপুর', 'শরিয়তপুর', 'শরীয়তপুরে'],
    'মুন্সীগঞ্জ': ['মুন্সীগঞ্জ', 'মুন্সিগঞ্জ', 'মুন্সীগঞ্জে'],
    'নরসিংদী': ['নরসিংদী', 'নরসিংদীতে'],
    'বরগুনা': ['বরগুনা', 'বরগুনায়'],
    'লক্ষ্মীপুর': ['লক্ষ্মীপুর', 'লক্ষীপুর', 'লক্ষ্মীপুরে'],
    'চাঁদপুর': ['চাঁদপুর', 'চাঁদপুরে'],
    'ব্রাহ্মণবাড়িয়া': ['ব্রাহ্মণবাড়িয়া', 'ব্রাহ্মণবাড়িয়া', 'ব্রাহ্মণবাড়িয়ায়'],
  };

  static const Map<String, String> _banglaWordToDigit = {
    'শূন্য': '0',
    'শুন্য': '0',
    'সুন্য': '0',
    'জিরো': '0',
    'জির': '0',
    '০': '0',
    'এক': '1',
    'এ্যাক': '1',
    'ওয়ান': '1',
    '১': '1',
    'দুই': '2',
    'দুইই': '2',
    'টু': '2',
    '২': '2',
    'তিন': '3',
    'তীন': '3',
    'থ্রি': '3',
    '৩': '3',
    'চার': '4',
    'চাড়': '4',
    'ফোর': '4',
    '৪': '4',
    'পাঁচ': '5',
    'পাচ': '5',
    'পাস': '5',
    'ফাইভ': '5',
    '৫': '5',
    'ছয়': '6',
    'ছয়': '6',
    'ছই': '6',
    'সিক্স': '6',
    '৬': '6',
    'সাত': '7',
    'সাতো': '7',
    'সেভেন': '7',
    '৭': '7',
    'আট': '8',
    'আটও': '8',
    'এইট': '8',
    '৮': '8',
    'নয়': '9',
    'নয়': '9',
    'নই': '9',
    'নাইন': '9',
    '৯': '9',
  };

  static const List<String> _phoneKeywords = [
    'ফোন',
    'নম্বর',
    'নাম্বার',
    'মোবাইল',
    'মোবাইল নম্বর',
    'ফোন নম্বর',
  ];

  static const List<String> _phoneFillerWords = [
    'আমার',
    'হলো',
    'হল',
    'এই',
    'এইটা',
    'নম্বর',
    'নাম্বার',
    'মোবাইল',
    'ফোন',
    'হচ্ছে',
    'হইলো',
    'আর',
    'এবং',
  ];

  static const List<String> _phoneBoundaryWords = [
    'আমি',
    'আমরা',
    'থাকি',
    'আছি',
    'ঠিকানা',
    'এলাকা',
    'চাই',
    'লাগবে',
    'দরকার',
    'সমস্যা',
    'রিফান্ড',
  ];

  static const List<String> _addressKeywords = [
    'ঠিকানা',
    'থাকি',
    'বাসা',
    'বাড়ি',
    'বাড়ি',
    'রোড',
    'রোডে',
    'সড়ক',
    'সড়ক',
    'এলাকা',
    'উপজেলা',
    'থানা',
    'গ্রাম',
    'পোস্ট',
  ];

  static const List<String> _nameStopWords = [
    'ফোন',
    'নম্বর',
    'নাম্বার',
    'মোবাইল',
    'ঠিকানা',
    'থাকি',
    'আছি',
    'থেকে',
    'লাগবে',
    'চাই',
    'কিনতে',
    'সমস্যা',
    'আমার',
  ];

  static const List<String> _intentStopPhrases = [
    'কিনতে চাই',
    'চাই',
    'লাগবে',
    'দরকার',
    'নিতে চাই',
    'সমস্যা হয়েছে',
    'সমস্যা হয়েছে',
    'নষ্ট হয়ে গেছে',
    'নষ্ট হয়ে গেছে',
  ];

  static CrmFields extract(String transcript, {String leadType = 'auto'}) {
    final text = transcript.trim();
    final normalized = _normalizeText(text);

    final productInterest = _extractProductOrIssue(normalized, leadType);
    final detectedLeadType =
        _detectLeadType(normalized, leadType, productInterest);
    final phone = _extractPhone(text);
    final name = _extractName(text);
    final locations = _extractLocations(normalized);
    final location = locations.isNotEmpty ? locations.join(', ') : '';
    final address = _extractAddress(text, locations);

    return CrmFields(
      leadType: detectedLeadType,
      name: name,
      phone: phone,
      address: address,
      location: location,
      productInterest: productInterest,
    );
  }

  static int computeConfidence(CrmFields fields) {
    int score = 20;
    if (fields.name.isNotEmpty) score += 15;
    if (fields.phone.isNotEmpty) score += 25;
    if (fields.address.isNotEmpty) score += 15;
    if (fields.location.isNotEmpty) score += 10;
    if (fields.productInterest.isNotEmpty) score += 15;
    if (fields.leadType.isNotEmpty) score += 10;
    return score.clamp(0, 100);
  }

  static String normalizeBanglaDigits(String input) {
    const map = {
      '০': '0',
      '১': '1',
      '২': '2',
      '৩': '3',
      '৪': '4',
      '৫': '5',
      '৬': '6',
      '৭': '7',
      '৮': '8',
      '৯': '9',
    };

    var output = input;
    map.forEach((key, value) {
      output = output.replaceAll(key, value);
    });
    return output;
  }

  /// Matching-only normalisation. Callers return slices of the *raw* text, so
  /// nothing here reaches the values shown to the user.
  ///
  /// Two of the transformations exist purely to absorb known ASR error modes:
  /// the model sprinkles spurious chandrabindu (ঁ) onto words, turning
  /// থাকি into থাঁকি, and it breaks case endings off with a hyphen,
  /// turning মিরপুরে into মিরপুর-এ. Both silently defeated
  /// keyword and gazetteer matching.
  static String _normalizeText(String input) {
    return normalizeBanglaDigits(input.toLowerCase())
        .replaceAll('ঁ', '')
        .replaceAll(RegExp(r'[-‐-―]'), ' ')
        .replaceAll(RegExp(r'[,:;!?()\[\]{}]'), ' ')
        .replaceAll('।', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _extractPhone(String text) {
    final digitNormalized = normalizeBanglaDigits(text);

    final strictMatch = RegExp(r'(?<!\d)(?:\+?880|0)?1[3-9]\d{8}(?!\d)')
        .allMatches(digitNormalized)
        .map((m) => _normalizeBangladeshMobile(m.group(0)!))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (strictMatch.isNotEmpty) return strictMatch;

    final keywordPhone = _extractPhoneNearKeywords(text);
    if (keywordPhone.isNotEmpty) return keywordPhone;

    final wholeTextPhone = _extractFromDigitTokens(text);
    if (wholeTextPhone.isNotEmpty) return wholeTextPhone;

    return '';
  }

  static String _extractPhoneNearKeywords(String text) {
    final normalized = _normalizeText(text);
    for (final keyword in _phoneKeywords) {
      final idx = normalized.indexOf(keyword);
      if (idx == -1) continue;
      final tail = normalized.substring(idx + keyword.length).trim();
      final phone = _extractFromDigitTokens(tail);
      if (phone.isNotEmpty) return phone;
    }
    return '';
  }

  static String _extractFromDigitTokens(String text) {
    final tokens = _tokenizeForPhone(text);
    final collected = <String>[];
    bool started = false;
    int noiseCount = 0;

    for (final token in tokens) {
      final digit = _digitToken(token);
      if (digit != null) {
        started = true;
        noiseCount = 0;
        collected.add(digit);
        final candidate = _extractValidPhoneFromStream(collected.join());
        if (candidate.isNotEmpty) {
          return candidate;
        }
        continue;
      }

      if (!started) {
        continue;
      }

      if (_phoneFillerWords.contains(token)) {
        continue;
      }

      if (_phoneBoundaryWords.contains(token)) {
        final candidate = _extractValidPhoneFromStream(collected.join());
        if (candidate.isNotEmpty) {
          return candidate;
        }
        break;
      }

      noiseCount += 1;
      if (noiseCount >= 2) {
        final candidate = _extractValidPhoneFromStream(collected.join());
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
    }

    return _extractValidPhoneFromStream(collected.join());
  }

  static String? _digitToken(String token) {
    if (token.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(token)) {
      return token;
    }
    final directWordDigit = _banglaWordToDigit[token];
    if (directWordDigit != null) {
      return directWordDigit;
    }
    final numeric = token.replaceAll(RegExp(r'[^0-9+]'), '');
    if (numeric.isNotEmpty) {
      return numeric;
    }
    return null;
  }

  static List<String> _tokenizeForPhone(String text) {
    final normalized = _normalizeText(text);
    final rawTokens = normalized.split(' ');
    final tokens = <String>[];

    for (final raw in rawTokens) {
      final digit = _digitToken(raw);
      if (digit != null) {
        tokens.add(digit);
        continue;
      }
      tokens.add(raw);
    }

    return tokens;
  }

  static String _extractValidPhoneFromStream(String stream) {
    final cleaned = stream.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return '';

    final direct = _normalizeBangladeshMobile(cleaned);
    if (direct.isNotEmpty) return direct;

    for (int start = 0; start < cleaned.length; start++) {
      for (final length in [11, 13, 14]) {
        final end = start + length;
        if (end > cleaned.length) continue;
        final candidate = cleaned.substring(start, end);
        final normalized = _normalizeBangladeshMobile(candidate);
        if (normalized.isNotEmpty) return normalized;
      }
    }

    return '';
  }

  static String _normalizeBangladeshMobile(String input) {
    var digits = input.replaceAll('+', '');
    digits = digits.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('8801') && digits.length >= 13) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('1') && digits.length == 10) {
      digits = '0$digits';
    }

    if (RegExp(r'^01[3-9]\d{8}$').hasMatch(digits)) {
      return digits;
    }
    return '';
  }

  static String _extractName(String text) {
    final candidates = <String>[];
    final patterns = [
      RegExp(r'আমার নাম\s+([^।,\n]+)'),
      RegExp(r'নাম\s+([^।,\n]+)'),
      RegExp(r'আমি\s+([^।,\n]+?)\s+বলছি'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        candidates.add(match.group(1)?.trim() ?? '');
      }
    }

    for (final candidate in candidates) {
      final cleaned = _cleanNameCandidate(candidate);
      if (cleaned.isNotEmpty) return cleaned;
    }

    return '';
  }

  static String _cleanNameCandidate(String candidate) {
    if (candidate.isEmpty) return '';

    var cleaned = candidate
        .replaceAll(RegExp(r'[,:;!?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = cleaned.split(' ');
    final kept = <String>[];

    for (final word in words) {
      if (_nameStopWords.contains(word)) break;
      if (_banglaWordToDigit.containsKey(word) ||
          RegExp(r'^\d+$').hasMatch(word)) {
        break;
      }
      kept.add(word);
      if (kept.length >= 4) break;
    }

    cleaned = kept.join(' ').trim();
    if (cleaned.length < 2) return '';
    return cleaned;
  }

  static List<String> _extractLocations(String normalizedText) {
    final matches = <String>{};

    for (final entry in _locationAliases.entries) {
      for (final alias in entry.value) {
        final aliasNorm = _normalizeText(alias);
        if (aliasNorm.isEmpty) continue;
        if (_containsWholePhrase(normalizedText, aliasNorm)) {
          matches.add(entry.key);
          break;
        }
      }
      if (matches.length >= 3) break;
    }

    return matches.toList();
  }

  static bool _containsWholePhrase(String haystack, String needle) {
    final pattern = RegExp('(^| )${RegExp.escape(needle)}( |\$)');
    return pattern.hasMatch(haystack);
  }

  static String _extractAddress(String text, List<String> locations) {
    final clauses = text
        .split(RegExp(r'[।,\n]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    String bestClause = '';
    int bestScore = -1;

    for (final clause in clauses) {
      final score = _scoreAddressClause(clause, locations);
      if (score > bestScore) {
        bestScore = score;
        bestClause = clause;
      }
    }

    var cleaned = _cleanAddressClause(bestClause);
    if (cleaned.isEmpty && locations.isNotEmpty) {
      cleaned = locations.first;
    }
    return cleaned;
  }

  static int _scoreAddressClause(String clause, List<String> locations) {
    final normalized = _normalizeText(clause);
    int score = 0;

    for (final keyword in _addressKeywords) {
      if (_containsWholePhrase(normalized, _normalizeText(keyword))) {
        score += 3;
      }
    }

    for (final location in locations) {
      if (_containsWholePhrase(normalized, _normalizeText(location))) {
        score += 4;
      }
    }

    if (normalized.contains('থাকি') || normalized.contains('ঠিকানা')) {
      score += 3;
    }
    if (normalized.contains('রোড') ||
        normalized.contains('সড়ক') ||
        normalized.contains('সড়ক') ||
        normalized.contains('উপজেলা') ||
        normalized.contains('থানা') ||
        normalized.contains('গ্রাম')) {
      score += 2;
    }

    if (normalized.contains('কিনতে চাই') ||
        normalized.contains('লাগবে') ||
        normalized.contains('সমস্যা') ||
        normalized.contains('রিফান্ড')) {
      score -= 3;
    }

    return score;
  }

  static String _cleanAddressClause(String clause) {
    if (clause.isEmpty) return '';

    var cleaned = clause.trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^(আমার|আমি)\s+'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^ঠিকানা\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^(আমার\s+)?ঠিকানা\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^(আমি\s+)?'), '');

    cleaned = cleaned.replaceAll(RegExp(r'\b(আমি|আমরা)\b'), '').trim();

    for (final phrase in _intentStopPhrases) {
      final idx = cleaned.indexOf(phrase);
      if (idx > 0) {
        cleaned = cleaned.substring(0, idx).trim();
      }
    }

    for (final boundary in ['থাকি', 'আছি']) {
      final idx = cleaned.indexOf(boundary);
      if (idx > 0) {
        final before = cleaned.substring(0, idx).trim();
        if (before.isNotEmpty) {
          cleaned = before;
        }
      }
    }

    cleaned = cleaned.replaceFirst(RegExp(r'^(থাকি|আছি)\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'(থাকি|আছি)\s*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length < 2) return '';
    return cleaned;
  }

  static String _extractProductOrIssue(String normalizedText, String leadType) {
    if (leadType.toLowerCase().contains('support')) {
      return _extractBestCategory(normalizedText, _supportIssueMap);
    }
    if (leadType.toLowerCase().contains('sales')) {
      return _extractBestCategory(normalizedText, _salesProductMap);
    }

    final support = _extractBestCategory(normalizedText, _supportIssueMap);
    final sales = _extractBestCategory(normalizedText, _salesProductMap);

    if (support.isEmpty) return sales;
    if (sales.isEmpty) return support;

    final supportScore =
        _categoryScore(normalizedText, _supportIssueMap[support]!);
    final salesScore = _categoryScore(normalizedText, _salesProductMap[sales]!);
    return supportScore > salesScore ? support : sales;
  }

  static String _extractBestCategory(
      String normalizedText, Map<String, List<String>> map) {
    String bestCategory = '';
    int bestScore = 0;

    for (final entry in map.entries) {
      final score = _categoryScore(normalizedText, entry.value);
      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
      }
    }

    return bestCategory;
  }

  static int _categoryScore(String normalizedText, List<String> aliases) {
    int score = 0;
    for (final alias in aliases) {
      final aliasNorm = _normalizeText(alias);
      if (_containsWholePhrase(normalizedText, aliasNorm)) {
        score += aliasNorm.split(' ').length * 2;
      }
    }
    return score;
  }

  static String _detectLeadType(
      String normalizedText, String requestedLeadType, String productInterest) {
    if (requestedLeadType.toLowerCase().contains('support')) {
      return 'Customer Support';
    }
    if (requestedLeadType.toLowerCase().contains('sales')) {
      return 'Sales Lead';
    }

    final supportScore = _mapMatchScore(normalizedText, _supportIssueMap);
    final salesScore = _mapMatchScore(normalizedText, _salesProductMap);

    if (supportScore > salesScore) return 'Customer Support';
    if (salesScore > supportScore) return 'Sales Lead';
    if (productInterest.startsWith('Real Estate') ||
        productInterest.startsWith('Vehicle') ||
        productInterest.startsWith('Electronics') ||
        productInterest.startsWith('Finance')) {
      return 'Sales Lead';
    }
    if (productInterest.isNotEmpty) {
      return 'Customer Support';
    }
    return 'Sales Lead';
  }

  static int _mapMatchScore(
      String normalizedText, Map<String, List<String>> map) {
    int score = 0;
    for (final aliases in map.values) {
      score += _categoryScore(normalizedText, aliases);
    }
    return score;
  }
}
