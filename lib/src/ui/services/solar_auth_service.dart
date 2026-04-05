import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/robot_events_models.dart';
import '../models/app_account.dart';
import 'account_repository.dart';

enum SolarAuthEvent { signedIn, signedOut, passwordRecovery, userUpdated }

class SolarAuthStateChange {
  const SolarAuthStateChange({required this.event, this.account});

  final SolarAuthEvent event;
  final AppAccount? account;
}

abstract class SolarAuthService {
  Stream<SolarAuthStateChange> get authStateChanges;

  Future<AppAccount?> restoreCurrentAccount({
    required String? cachedEmail,
    AppAccount? cachedAccount,
  });

  Future<AppAccount> signIn({
    required String email,
    required String password,
    AppAccount? cachedAccount,
  });

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required TeamSummary team,
  });

  Future<void> sendResetPassword({required String email});

  Future<AppAccount> saveAccount(AppAccount account);

  Future<void> updatePassword({
    required AppAccount account,
    required String currentPassword,
    required String newPassword,
  });

  Future<void> updateRecoveryPassword({required String newPassword});

  Future<void> signOut();

  Future<void> dispose();
}

class LocalSolarAuthService implements SolarAuthService {
  LocalSolarAuthService({required AccountRepository repository})
    : _repository = repository;

  final AccountRepository _repository;
  final StreamController<SolarAuthStateChange> _changes =
      StreamController<SolarAuthStateChange>.broadcast();

  @override
  Stream<SolarAuthStateChange> get authStateChanges => _changes.stream;

  @override
  Future<void> dispose() {
    return _changes.close();
  }

  @override
  Future<AppAccount?> restoreCurrentAccount({
    required String? cachedEmail,
    AppAccount? cachedAccount,
  }) async {
    if (cachedAccount != null) {
      return cachedAccount;
    }
    if (cachedEmail == null) {
      return null;
    }
    return _repository.findByEmail(cachedEmail);
  }

  @override
  Future<AppAccount> signIn({
    required String email,
    required String password,
    AppAccount? cachedAccount,
  }) async {
    final account = await _repository.findByEmail(email.trim().toLowerCase());
    if (account == null || account.password != password) {
      throw const FormatException(
        'We could not find an account with that email and password.',
      );
    }
    _changes.add(SolarAuthStateChange(event: SolarAuthEvent.signedIn));
    return account;
  }

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required TeamSummary team,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final existingAccount = await _repository.findByEmail(normalizedEmail);
    if (existingAccount != null) {
      throw const FormatException('An account with that email already exists.');
    }

    await _repository.saveAccount(
      AppAccount(
        fullName: fullName.trim(),
        email: normalizedEmail,
        password: password,
        team: team,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> sendResetPassword({required String email}) async {
    final account = await _repository.findByEmail(email.trim().toLowerCase());
    if (account == null) {
      throw const FormatException(
        'We could not find an account with that email.',
      );
    }
  }

  @override
  Future<AppAccount> saveAccount(AppAccount account) async {
    await _repository.saveAccount(account);
    return account;
  }

  @override
  Future<void> updatePassword({
    required AppAccount account,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword != account.password) {
      throw const FormatException('Your current password does not match.');
    }

    await _repository.saveAccount(account.copyWith(password: newPassword));
  }

  @override
  Future<void> updateRecoveryPassword({required String newPassword}) async {
    throw const FormatException(
      'Password recovery requires Supabase to be configured.',
    );
  }

  @override
  Future<void> signOut() async {
    _changes.add(SolarAuthStateChange(event: SolarAuthEvent.signedOut));
  }
}

class SupabaseSolarAuthService implements SolarAuthService {
  SupabaseSolarAuthService({
    required SupabaseClient client,
    required String redirectUrl,
  }) : _client = client,
       _redirectUrl = redirectUrl {
    _authSubscription = _client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (_) {},
    );
  }

  static const _fullNameKey = 'fullName';
  static const _teamKey = 'team';

  final SupabaseClient _client;
  final String _redirectUrl;
  final StreamController<SolarAuthStateChange> _changes =
      StreamController<SolarAuthStateChange>.broadcast();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  Stream<SolarAuthStateChange> get authStateChanges => _changes.stream;

  @override
  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _changes.close();
  }

  @override
  Future<AppAccount?> restoreCurrentAccount({
    required String? cachedEmail,
    AppAccount? cachedAccount,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return _accountFromUser(user, cachedAccount: cachedAccount);
  }

  @override
  Future<AppAccount> signIn({
    required String email,
    required String password,
    AppAccount? cachedAccount,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user ?? _client.auth.currentUser;
      if (user == null) {
        throw const FormatException(
          'Supabase did not return a user for this sign-in.',
        );
      }
      return _accountFromUser(user, cachedAccount: cachedAccount);
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthMessage(error));
    }
  }

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required TeamSummary team,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _redirectUrl,
        data: _metadataFromAccount(
          AppAccount(
            fullName: fullName.trim(),
            email: email.trim().toLowerCase(),
            password: '',
            team: team,
            createdAt: DateTime.now(),
          ),
        ),
      );

      if (response.session != null) {
        await _client.auth.signOut();
      }
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthMessage(error));
    }
  }

  @override
  Future<void> sendResetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: _redirectUrl);
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthMessage(error));
    }
  }

  @override
  Future<AppAccount> saveAccount(AppAccount account) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw const FormatException('Sign in again to update your profile.');
    }

    try {
      final response = await _client.auth.updateUser(
        UserAttributes(data: _metadataFromAccount(account)),
      );
      final user = response.user ?? _client.auth.currentUser ?? currentUser;
      return _accountFromUser(user, cachedAccount: account);
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthMessage(error));
    }
  }

  @override
  Future<void> updatePassword({
    required AppAccount account,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: account.normalizedEmail,
        password: currentPassword,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthMessage(error));
    }
  }

  @override
  Future<void> updateRecoveryPassword({required String newPassword}) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthMessage(error));
    }
  }

  void _handleAuthStateChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.passwordRecovery:
        _changes.add(
          const SolarAuthStateChange(event: SolarAuthEvent.passwordRecovery),
        );
        return;
      case AuthChangeEvent.signedOut:
        _changes.add(
          const SolarAuthStateChange(event: SolarAuthEvent.signedOut),
        );
        return;
      case AuthChangeEvent.signedIn:
        final account = state.session?.user == null
            ? null
            : _safeAccountFromUser(state.session!.user);
        _changes.add(
          SolarAuthStateChange(
            event: SolarAuthEvent.signedIn,
            account: account,
          ),
        );
        return;
      case AuthChangeEvent.userUpdated:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.mfaChallengeVerified:
        final account = state.session?.user == null
            ? null
            : _safeAccountFromUser(state.session!.user);
        _changes.add(
          SolarAuthStateChange(
            event: SolarAuthEvent.userUpdated,
            account: account,
          ),
        );
        return;
      default:
        return;
    }
  }

  AppAccount? _safeAccountFromUser(User user) {
    try {
      return _accountFromUser(user);
    } on FormatException {
      return null;
    }
  }

  AppAccount _accountFromUser(User user, {AppAccount? cachedAccount}) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final normalizedEmail = (user.email ?? cachedAccount?.normalizedEmail ?? '')
        .trim()
        .toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const FormatException('Your Supabase account is missing an email.');
    }

    final fullName = _readString(
      metadata[_fullNameKey],
      fallback: cachedAccount?.fullName,
    );
    if (fullName.isEmpty) {
      throw const FormatException(
        'Your Supabase account is missing its profile name.',
      );
    }

    final team = _teamFromMetadata(
      metadata[_teamKey],
      fallback: cachedAccount?.team,
    );
    if (team == null) {
      throw const FormatException(
        'Your Supabase account is missing its team info.',
      );
    }

    return AppAccount(
      fullName: fullName,
      email: normalizedEmail,
      password: cachedAccount?.password ?? '',
      team: team,
      createdAt:
          DateTime.tryParse(user.createdAt) ??
          cachedAccount?.createdAt ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> _metadataFromAccount(AppAccount account) {
    return <String, dynamic>{
      _fullNameKey: account.fullName.trim(),
      _teamKey: _teamMetadata(account.team),
    };
  }

  Map<String, dynamic> _teamMetadata(TeamSummary team) {
    return <String, dynamic>{
      'id': team.id,
      'number': team.number,
      'teamName': team.teamName,
      'organization': team.organization,
      'robotName': team.robotName,
      'grade': team.grade,
      'registered': team.registered,
      'location': <String, dynamic>{
        'venue': team.location.venue,
        'address1': team.location.address1,
        'city': team.location.city,
        'region': team.location.region,
        'postcode': team.location.postcode,
        'country': team.location.country,
      },
    };
  }

  TeamSummary? _teamFromMetadata(Object? rawTeam, {TeamSummary? fallback}) {
    if (rawTeam is! Map) {
      return fallback;
    }

    final teamMap = Map<String, dynamic>.from(rawTeam);
    final locationMap = teamMap['location'] is Map
        ? Map<String, dynamic>.from(teamMap['location'] as Map)
        : const <String, dynamic>{};

    final number = _readString(teamMap['number'], fallback: fallback?.number);
    if (number.isEmpty) {
      return fallback;
    }

    return TeamSummary(
      id: _readInt(teamMap['id'], fallback: fallback?.id ?? 0),
      number: number,
      teamName: _readString(teamMap['teamName'], fallback: fallback?.teamName),
      organization: _readString(
        teamMap['organization'],
        fallback: fallback?.organization,
      ),
      robotName: _readString(
        teamMap['robotName'],
        fallback: fallback?.robotName,
      ),
      location: LocationSummary(
        venue: _readString(
          locationMap['venue'],
          fallback: fallback?.location.venue,
        ),
        address1: _readString(
          locationMap['address1'] ?? locationMap['address_1'],
          fallback: fallback?.location.address1,
        ),
        city: _readString(
          locationMap['city'],
          fallback: fallback?.location.city,
        ),
        region: _readString(
          locationMap['region'],
          fallback: fallback?.location.region,
        ),
        postcode: _readString(
          locationMap['postcode'],
          fallback: fallback?.location.postcode,
        ),
        country: _readString(
          locationMap['country'],
          fallback: fallback?.location.country,
        ),
      ),
      grade: _readString(teamMap['grade'], fallback: fallback?.grade),
      registered: _readBool(
        teamMap['registered'],
        fallback: fallback?.registered ?? true,
      ),
    );
  }

  String _friendlyAuthMessage(AuthException error) {
    final message = error.message.trim();
    if (message.isEmpty) {
      return 'Supabase rejected this request.';
    }
    return message;
  }
}

String _readString(Object? value, {String? fallback}) {
  final raw = (value as String?)?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }
  return fallback?.trim() ?? '';
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? fallback;
}

bool _readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return fallback;
}
