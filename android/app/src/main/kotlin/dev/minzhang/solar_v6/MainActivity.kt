package dev.minzhang.solar_v6

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "solar/ios_companion",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncCompanion" -> {
                    val payload = call.arguments as? Map<*, *>
                    if (payload == null) {
                        result.error(
                            "invalid_payload",
                            "The companion payload was missing required fields.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    SolarCompanionWidgetStore.save(applicationContext, payload)
                    SolarCompanionWidgetRenderer.updateAll(applicationContext)
                    result.success(null)
                }

                "clearCompanion" -> {
                    SolarCompanionWidgetStore.clear(applicationContext)
                    SolarCompanionWidgetRenderer.updateAll(applicationContext)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
