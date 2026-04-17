import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:solar_v6/src/app/solar_app.dart';
import 'package:solar_v6/src/app/app_solar_config_loader.dart';
import 'package:solar_v6/src/app/solar_supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final config = await AppSolarConfigLoader.load();
  await SolarSupabaseBootstrap.ensureInitialized(config);
  runApp(const SolarApp());
}
