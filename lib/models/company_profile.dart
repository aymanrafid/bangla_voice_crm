import 'app_user.dart';

class CompanyProfile {
  final String externalId;
  final String name;
  final String slug;
  final String status;
  final String createdAt;
  final String updatedAt;

  const CompanyProfile({
    required this.externalId,
    required this.name,
    required this.slug,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyProfile.fromApiMap(Map<String, dynamic> map) {
    return CompanyProfile(
      externalId: map['external_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      createdAt: map['created_at']?.toString() ?? '',
      updatedAt: map['updated_at']?.toString() ?? '',
    );
  }
}

class CompanyProvisionResult {
  final CompanyProfile company;
  final AppUser adminUser;

  const CompanyProvisionResult({
    required this.company,
    required this.adminUser,
  });

  factory CompanyProvisionResult.fromApiMap(Map<String, dynamic> map) {
    return CompanyProvisionResult(
      company: CompanyProfile.fromApiMap(
        map['company'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      adminUser: AppUser.fromApiMap(
        map['admin_user'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}
