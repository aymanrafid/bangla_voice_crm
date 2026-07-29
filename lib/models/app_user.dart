class AppUser {
  final int? id;
  final String externalId;
  final String username;
  final String passwordHash;
  final String role;
  final String fullName;
  final bool isActive;
  final String createdAt;
  final String companyExternalId;
  final String companyName;
  final String companySlug;

  const AppUser({
    this.id,
    this.externalId = '',
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.fullName,
    required this.isActive,
    required this.createdAt,
    this.companyExternalId = '',
    this.companyName = '',
    this.companySlug = '',
  });

  bool get isAdmin => role == 'Admin' || role == 'SuperAdmin';
  bool get isSuperAdmin => role == 'SuperAdmin';
  bool get isManager => role == 'Manager';
  bool get isEmployee => role == 'Employee';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'externalId': externalId,
      'username': username,
      'passwordHash': passwordHash,
      'role': role,
      'fullName': fullName,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'companyExternalId': companyExternalId,
      'companyName': companyName,
      'companySlug': companySlug,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int?,
      externalId: map['externalId'] ?? '',
      username: map['username'] ?? '',
      passwordHash: map['passwordHash'] ?? '',
      role: map['role'] ?? 'Employee',
      fullName: map['fullName'] ?? '',
      isActive: (map['isActive'] ?? 0) == 1,
      createdAt: map['createdAt'] ?? '',
      companyExternalId: map['companyExternalId'] ?? '',
      companyName: map['companyName'] ?? '',
      companySlug: map['companySlug'] ?? '',
    );
  }

  factory AppUser.fromApiMap(Map<String, dynamic> map) {
    final isActiveValue = map['is_active'] ?? map['isActive'] ?? true;
    return AppUser(
      id: map['id'] as int?,
      externalId: map['external_id']?.toString() ?? map['externalId'] ?? '',
      username: map['username'] ?? '',
      passwordHash: '',
      role: map['role'] ?? 'Employee',
      fullName: map['full_name'] ?? map['fullName'] ?? '',
      isActive: isActiveValue == true || isActiveValue == 1,
      createdAt: map['created_at'] ?? map['createdAt'] ?? '',
      companyExternalId: map['company_external_id']?.toString() ??
          map['companyExternalId'] ??
          '',
      companyName: map['company_name'] ?? map['companyName'] ?? '',
      companySlug: map['company_slug'] ?? map['companySlug'] ?? '',
    );
  }
}
