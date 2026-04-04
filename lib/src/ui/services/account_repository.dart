import '../models/app_account.dart';

abstract class AccountRepository {
  Future<AppSettings> loadSettings();

  Future<void> saveSettings(AppSettings settings);

  Future<AppAccount?> findByEmail(String email);

  Future<void> saveAccount(AppAccount account);

  Future<void> close();
}
