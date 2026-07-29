import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigService {
  static const _crmApiBaseUrlKey = 'crm_api_base_url';
  static const _asrApiUrlKey = 'asr_api_url';
  static const _companySlugKey = 'crm_company_slug';
  static const _accessTokenKey = 'crm_access_token';
  static const _sessionModeKey = 'crm_session_mode';
  static const _sessionUserJsonKey = 'crm_session_user_json';
  static const _secureStorage = FlutterSecureStorage();

  Future<String> getCrmApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_crmApiBaseUrlKey) ?? '').trim();
  }

  Future<void> saveCrmApiBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_crmApiBaseUrlKey, value.trim());
  }

  Future<String> getAsrApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_asrApiUrlKey) ?? '').trim();
  }

  Future<void> saveAsrApiUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_asrApiUrlKey, value.trim());
  }

  Future<String> getCompanySlug() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_companySlugKey) ?? '').trim();
  }

  Future<void> saveCompanySlug(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companySlugKey, value.trim());
  }

  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
  }

  Future<String> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey) ?? '';
  }

  Future<void> clearAccessToken() async {
    await _secureStorage.delete(key: _accessTokenKey);
  }

  Future<void> saveSessionMode(String mode) async {
    await _secureStorage.write(key: _sessionModeKey, value: mode);
  }

  Future<String> getSessionMode() async {
    return await _secureStorage.read(key: _sessionModeKey) ?? 'local';
  }

  Future<void> saveSessionUserJson(String json) async {
    await _secureStorage.write(key: _sessionUserJsonKey, value: json);
  }

  Future<String> getSessionUserJson() async {
    return await _secureStorage.read(key: _sessionUserJsonKey) ?? '';
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _sessionModeKey);
    await _secureStorage.delete(key: _sessionUserJsonKey);
  }
}
