import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/solar_config.dart';

class SolarSupabaseBootstrap {
  static Future<void> ensureInitialized(SolarConfig config) async {
    if (!config.hasSupabaseConfig) {
      return;
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
  }
}
