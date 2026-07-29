class Lead {
  final int? id;
  final String leadId;
  final String dateTime;
  final String leadType;
  final String name;
  final String phone;
  final String address;
  final String location;
  final String productInterest;
  final String transcript;
  final String status;
  final int confidence;
  final String intent;
  final String sentiment;
  final String priority;
  final int leadScore;
  final String aiSummary;
  final String nextAction;
  final double? latitude;
  final double? longitude;
  final String surveyStatus;
  final String surveyStartedAt;
  final String surveyArrivedAt;
  final double? surveyDistanceMeters;
  final String surveyNote;
  final int? assignedEmployeeId;
  final String assignedEmployeeName;
  final String assignedEmployeeExternalId;
  final int version;

  Lead({
    this.id,
    required this.leadId,
    required this.dateTime,
    required this.leadType,
    required this.name,
    required this.phone,
    required this.address,
    required this.location,
    required this.productInterest,
    required this.transcript,
    this.status = 'New',
    required this.confidence,
    this.intent = 'General Inquiry',
    this.sentiment = 'Neutral',
    this.priority = 'Normal',
    this.leadScore = 50,
    this.aiSummary = '',
    this.nextAction = '',
    this.latitude,
    this.longitude,
    this.surveyStatus = 'Not Started',
    this.surveyStartedAt = '',
    this.surveyArrivedAt = '',
    this.surveyDistanceMeters,
    this.surveyNote = '',
    this.assignedEmployeeId,
    this.assignedEmployeeName = '',
    this.assignedEmployeeExternalId = '',
    this.version = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leadId': leadId,
      'dateTime': dateTime,
      'leadType': leadType,
      'name': name,
      'phone': phone,
      'address': address,
      'location': location,
      'productInterest': productInterest,
      'transcript': transcript,
      'status': status,
      'confidence': confidence,
      'intent': intent,
      'sentiment': sentiment,
      'priority': priority,
      'leadScore': leadScore,
      'aiSummary': aiSummary,
      'nextAction': nextAction,
      'latitude': latitude,
      'longitude': longitude,
      'surveyStatus': surveyStatus,
      'surveyStartedAt': surveyStartedAt,
      'surveyArrivedAt': surveyArrivedAt,
      'surveyDistanceMeters': surveyDistanceMeters,
      'surveyNote': surveyNote,
      'assignedEmployeeId': assignedEmployeeId,
      'assignedEmployeeName': assignedEmployeeName,
      'assignedEmployeeExternalId': assignedEmployeeExternalId,
      'version': version,
    };
  }

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: map['id'],
      leadId: map['leadId'] ?? '',
      dateTime: map['dateTime'] ?? '',
      leadType: map['leadType'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      location: map['location'] ?? '',
      productInterest: map['productInterest'] ?? '',
      transcript: map['transcript'] ?? '',
      status: map['status'] ?? 'New',
      confidence: map['confidence'] ?? 0,
      intent: map['intent'] ?? 'General Inquiry',
      sentiment: map['sentiment'] ?? 'Neutral',
      priority: map['priority'] ?? 'Normal',
      leadScore: map['leadScore'] ?? 50,
      aiSummary: map['aiSummary'] ?? '',
      nextAction: map['nextAction'] ?? '',
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      surveyStatus: map['surveyStatus'] ?? 'Not Started',
      surveyStartedAt: map['surveyStartedAt'] ?? '',
      surveyArrivedAt: map['surveyArrivedAt'] ?? '',
      surveyDistanceMeters: _toDouble(map['surveyDistanceMeters']),
      surveyNote: map['surveyNote'] ?? '',
      assignedEmployeeId: map['assignedEmployeeId'] as int?,
      assignedEmployeeName: map['assignedEmployeeName'] ?? '',
      assignedEmployeeExternalId: map['assignedEmployeeExternalId'] ?? '',
      version: map['version'] ?? 1,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Lead copyWith({
    int? id,
    String? leadId,
    String? dateTime,
    String? leadType,
    String? name,
    String? phone,
    String? address,
    String? location,
    String? productInterest,
    String? transcript,
    String? status,
    int? confidence,
    String? intent,
    String? sentiment,
    String? priority,
    int? leadScore,
    String? aiSummary,
    String? nextAction,
    double? latitude,
    double? longitude,
    String? surveyStatus,
    String? surveyStartedAt,
    String? surveyArrivedAt,
    double? surveyDistanceMeters,
    String? surveyNote,
    int? assignedEmployeeId,
    String? assignedEmployeeName,
    String? assignedEmployeeExternalId,
    int? version,
  }) {
    return Lead(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      dateTime: dateTime ?? this.dateTime,
      leadType: leadType ?? this.leadType,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      location: location ?? this.location,
      productInterest: productInterest ?? this.productInterest,
      transcript: transcript ?? this.transcript,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      intent: intent ?? this.intent,
      sentiment: sentiment ?? this.sentiment,
      priority: priority ?? this.priority,
      leadScore: leadScore ?? this.leadScore,
      aiSummary: aiSummary ?? this.aiSummary,
      nextAction: nextAction ?? this.nextAction,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      surveyStatus: surveyStatus ?? this.surveyStatus,
      surveyStartedAt: surveyStartedAt ?? this.surveyStartedAt,
      surveyArrivedAt: surveyArrivedAt ?? this.surveyArrivedAt,
      surveyDistanceMeters: surveyDistanceMeters ?? this.surveyDistanceMeters,
      surveyNote: surveyNote ?? this.surveyNote,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      assignedEmployeeExternalId:
          assignedEmployeeExternalId ?? this.assignedEmployeeExternalId,
      version: version ?? this.version,
    );
  }
}
