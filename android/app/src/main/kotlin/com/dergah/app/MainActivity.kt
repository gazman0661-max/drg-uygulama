package com.dergah.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Flutter -> ana ekran widget'ı köprüsü (vakit verisini widget'a yazar)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dergah/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveSchedule" -> {
                        val json = call.arguments as? String
                        if (json == null) {
                            result.error("ARG", "Vakit verisi yok", null)
                        } else {
                            PrayerWidgetProvider.saveSchedule(applicationContext, json)
                            PrayerWidgetProvider.updateAll(applicationContext)
                            // Ezan/hatırlatma/panel zincirini yeni veriyle yeniden kur
                            AlertScheduler.process(applicationContext, fromApp = true)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
