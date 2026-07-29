import 'dart:async';
import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/company_profile.dart';
import 'api_config_service.dart';
import 'database_service.dart';
import 'offline_report_queue_service.dart';
import 'remote_auth_service.dart';

class AuthService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ApiConfigService _config = ApiConfigService();
  final RemoteAuthService _remoteAuth = RemoteAuthService();
  final OfflineReportQueueService _offlineReportQueue =
      OfflineReportQueueService();

  AppUser? _currentUser;
  bool _initialized = false;
  bool _loading = false;
  String _error = '';
  bool _remoteMode = false;

  AppUser? get currentUser => _currentUser;
  bool get isInitialized => _initialized;
  bool get isLoading => _loading;
  String get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isRemoteMode => _remoteMode;

  Future<AppUser> _syncRemoteUserToLocal(AppUser user) async {
    return _db.upsertUserByIdentity(
      AppUser(
        externalId: user.externalId,
        companyExternalId: user.companyExternalId,
        companyName: user.companyName,
        companySlug: user.companySlug,
        username: user.username,
        passwordHash: user.passwordHash,
        role: user.role,
        fullName: user.fullName,
        isActive: user.isActive,
        createdAt: user.createdAt,
      ),
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();

    try {
      final baseUrl = await _config.getCrmApiBaseUrl();
      _remoteMode = baseUrl.isNotEmpty;

      if (_remoteMode) {
        final token = await _config.getAccessToken();
        final cachedUserJson = await _config.getSessionUserJson();
        if (token.isNotEmpty) {
          try {
            final remoteUser = await _remoteAuth.me(
              baseUrl: baseUrl,
              accessToken: token,
            );
            _currentUser = await _syncRemoteUserToLocal(remoteUser);
            await _config.saveSessionMode('remote');
            await _config
                .saveSessionUserJson(jsonEncode(_currentUser!.toMap()));
            if (_currentUser!.companySlug.isNotEmpty) {
              await _config.saveCompanySlug(_currentUser!.companySlug);
            }
            unawaited(_retryQueuedReports());
          } catch (exc) {
            try {
              if (cachedUserJson.isNotEmpty) {
                _currentUser = AppUser.fromMap(
                  jsonDecode(cachedUserJson) as Map<String, dynamic>,
                );
              } else {
                await _config.clearSession();
                _currentUser = null;
              }
            } catch (_) {
              await _config.clearSession();
              _currentUser = null;
            }
            _error = exc.toString().replaceFirst('Exception: ', '');
          }
        }
      } else {
        await _ensureDefaultAdmin();
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getInt('session_user_id');
        if (savedUserId != null) {
          _currentUser = await _db.getUserById(savedUserId);
        }
      }
    } catch (exc) {
      _currentUser = null;
      _error = exc.toString().replaceFirst('Exception: ', '');
    } finally {
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureDefaultAdmin() async {
    final existing = await _db.getUserByUsername('admin');
    if (existing != null) return;
    final now = DateTime.now().toIso8601String();
    final hash = BCrypt.hashpw('admin123', BCrypt.gensalt());
    await _db.createUser(
      AppUser(
        username: 'admin',
        passwordHash: hash,
        role: 'Admin',
        fullName: 'System Admin',
        companyName: 'Local Demo Company',
        companySlug: 'local-demo-company',
        isActive: true,
        createdAt: now,
      ),
    );
  }

  Future<bool> login({
    required String username,
    required String password,
    String companySlug = '',
  }) async {
    _loading = true;
    _error = '';
    notifyListeners();

    final baseUrl = await _config.getCrmApiBaseUrl();
    _remoteMode = baseUrl.isNotEmpty;

    if (_remoteMode) {
      try {
        final session = await _remoteAuth.login(
          baseUrl: baseUrl,
          username: username,
          password: password,
          companySlug: companySlug,
        );
        _currentUser = await _syncRemoteUserToLocal(session.user);
        await _config.saveAccessToken(session.accessToken);
        await _config.saveSessionMode('remote');
        await _config.saveSessionUserJson(jsonEncode(session.user.toMap()));
        await _config.saveCompanySlug(
          session.user.companySlug.isNotEmpty
              ? session.user.companySlug
              : companySlug,
        );
        _loading = false;
        notifyListeners();
        unawaited(_retryQueuedReports());
        return true;
      } catch (exc) {
        _loading = false;
        _error = exc.toString().replaceFirst('Exception: ', '');
        notifyListeners();
        return false;
      }
    }

    final user = await _db.getUserByUsername(username.trim());
    if (user == null || !user.isActive) {
      _loading = false;
      _error = 'User not found or inactive.';
      notifyListeners();
      return false;
    }

    final ok = BCrypt.checkpw(password, user.passwordHash);
    if (!ok) {
      _loading = false;
      _error = 'Incorrect password.';
      notifyListeners();
      return false;
    }

    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_user_id', user.id!);
    _loading = false;
    notifyListeners();
    return true;
  }

  Future<void> _retryQueuedReports() async {
    final user = _currentUser;
    if (user == null || !_remoteMode) {
      return;
    }
    try {
      await _offlineReportQueue.retryPendingUploads(
        employeeExternalId: user.externalId,
      );
    } catch (_) {
      // Keep login/session resilient even if queued retries fail.
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    await _config.clearSession();
    _currentUser = null;
    _error = '';
    notifyListeners();
  }

  Future<AppUser?> createEmployee({
    required String username,
    required String password,
    required String fullName,
    String role = 'Employee',
    String? companyExternalId,
  }) async {
    final baseUrl = await _config.getCrmApiBaseUrl();
    _remoteMode = baseUrl.isNotEmpty;

    if (_remoteMode) {
      final token = await _config.getAccessToken();
      if (token.isEmpty) {
        _error = 'Please log in again before creating users.';
        notifyListeners();
        return null;
      }
      try {
        final user = await _remoteAuth.createUser(
          baseUrl: baseUrl,
          accessToken: token,
          username: username,
          password: password,
          fullName: fullName,
          role: role,
          companyExternalId: companyExternalId,
        );
        _error = '';
        notifyListeners();
        return user;
      } catch (exc) {
        _error = exc.toString().replaceFirst('Exception: ', '');
        notifyListeners();
        return null;
      }
    }

    final existing = await _db.getUserByUsername(username.trim());
    if (existing != null) {
      _error = 'This username already exists.';
      notifyListeners();
      return null;
    }

    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    final user = AppUser(
      username: username.trim(),
      passwordHash: hash,
      role: role,
      fullName: fullName.trim(),
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    );
    final id = await _db.createUser(user);
    _error = '';
    notifyListeners();
    return AppUser(
      id: id,
      externalId: user.externalId,
      companyExternalId: user.companyExternalId,
      companyName: user.companyName,
      companySlug: user.companySlug,
      username: user.username,
      passwordHash: user.passwordHash,
      role: user.role,
      fullName: user.fullName,
      isActive: user.isActive,
      createdAt: user.createdAt,
    );
  }

  Future<List<AppUser>> getUsers() async {
    final baseUrl = await _config.getCrmApiBaseUrl();
    _remoteMode = baseUrl.isNotEmpty;
    if (_remoteMode) {
      final token = await _config.getAccessToken();
      if (token.isEmpty) return [];
      return _remoteAuth.getUsers(baseUrl: baseUrl, accessToken: token);
    }
    return _db.getUsers();
  }

  Future<List<CompanyProfile>> getCompanies() async {
    final baseUrl = await _config.getCrmApiBaseUrl();
    _remoteMode = baseUrl.isNotEmpty;
    if (!_remoteMode) {
      return [
        const CompanyProfile(
          externalId: 'local-demo-company',
          name: 'Local Demo Company',
          slug: 'local-demo-company',
          status: 'active',
          createdAt: '',
          updatedAt: '',
        ),
      ];
    }
    final token = await _config.getAccessToken();
    if (token.isEmpty) {
      _error = 'Please log in again before loading companies.';
      notifyListeners();
      return [];
    }
    try {
      final companies = await _remoteAuth.getCompanies(
        baseUrl: baseUrl,
        accessToken: token,
      );
      _error = '';
      notifyListeners();
      return companies;
    } catch (exc) {
      _error = exc.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<CompanyProvisionResult?> createCompany({
    required String name,
    required String slug,
    required String adminUsername,
    required String adminPassword,
    required String adminFullName,
  }) async {
    final baseUrl = await _config.getCrmApiBaseUrl();
    _remoteMode = baseUrl.isNotEmpty;
    if (!_remoteMode) {
      _error = 'Company provisioning is only available in remote server mode.';
      notifyListeners();
      return null;
    }
    final token = await _config.getAccessToken();
    if (token.isEmpty) {
      _error = 'Please log in again before creating a company.';
      notifyListeners();
      return null;
    }
    try {
      final result = await _remoteAuth.createCompany(
        baseUrl: baseUrl,
        accessToken: token,
        name: name,
        slug: slug,
        adminUsername: adminUsername,
        adminPassword: adminPassword,
        adminFullName: adminFullName,
      );
      _error = '';
      notifyListeners();
      return result;
    } catch (exc) {
      _error = exc.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshMode() async {
    final baseUrl = await _config.getCrmApiBaseUrl();
    _remoteMode = baseUrl.isNotEmpty;
    notifyListeners();
  }
}
