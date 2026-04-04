import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../models/app_account.dart';
import 'account_repository.dart';

class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository._(this._database);

  static const _databaseName = 'solar_app.db';
  static const _settingsKey = 'app_settings';

  static final _accountsStore = stringMapStoreFactory.store('accounts');
  static final _settingsStore = stringMapStoreFactory.store('settings');

  final Database _database;

  static Future<LocalAccountRepository> openDefault() async {
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = '${directory.path}/$_databaseName';
    final database = await databaseFactoryIo.openDatabase(databasePath);
    return LocalAccountRepository._(database);
  }

  @override
  Future<AppAccount?> findByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final snapshot = await _accountsStore
        .record(normalizedEmail)
        .get(_database);
    if (snapshot == null) {
      return null;
    }
    return AppAccount.fromJson(Map<String, dynamic>.from(snapshot));
  }

  @override
  Future<AppSettings> loadSettings() async {
    final snapshot = await _settingsStore.record(_settingsKey).get(_database);
    if (snapshot == null) {
      return AppSettings.empty;
    }
    return AppSettings.fromJson(Map<String, dynamic>.from(snapshot));
  }

  @override
  Future<void> saveAccount(AppAccount account) {
    return _accountsStore
        .record(account.normalizedEmail)
        .put(_database, account.toJson());
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    return _settingsStore
        .record(_settingsKey)
        .put(_database, settings.toJson());
  }

  @override
  Future<void> close() {
    return _database.close();
  }
}
