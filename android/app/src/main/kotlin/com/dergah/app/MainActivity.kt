package com.dergah.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private fun openSettings(intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    } catch (e: Exception) {
        false
    }

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
                            NextPrayerWidgetProvider.updateAll(applicationContext)
                            // Ezan/hatırlatma/panel zincirini yeni veriyle yeniden kur
                            AlertScheduler.process(applicationContext, fromApp = true)
                            result.success(true)
                        }
                    }
                    "testAdhan" -> {
                        val stream = call.argument<String>("stream") ?: "alarm"
                        val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
                        result.success(
                            EzanService.start(
                                applicationContext, 9999, "Ezan Denemesi",
                                "Ses ayarınız çalışıyor.", true, stream, volume, System.currentTimeMillis()
                            )
                        )
                    }
                    "openAppSettings" -> result.success(openSettings(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        )
                    ))
                    "openExactAlarmSettings" -> {
                        val ok = Build.VERSION.SDK_INT >= 31 && openSettings(
                            Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(ok)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
