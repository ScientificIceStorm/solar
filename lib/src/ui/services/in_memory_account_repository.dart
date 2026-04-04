import '../models/app_account.dart';
import 'account_repository.dart';

class InMemoryAccountRepository implements AccountRepository {
  AppSettings _settings = AppSettings.empty;
  final Map<String, AppAccount> _accounts = <String, AppAccount>{};

  @override
  Future<void> close() async {}

  @override
  Future<AppAccount?> findByEmail(String email) async {
    return _accounts[email.trim().toLowerCase()];
  }

  @override
  Future<AppSettings> loadSettings() async {
    return _settings;
  }

  @override
  Future<void> saveAccount(AppAccount account) async {
    _accounts[account.normalizedEmail] = account;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}
