package com.dergah.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * 1x1 ana ekran widget'ı: sıradaki namaz vaktinin adı + kalan süre.
 * Vakit verisini PrayerWidgetProvider ile aynı yerden (SharedPreferences)
 * okur; kendi alarmıyla vakit girince yenilenir.
 */
class NextPrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAll(context)
        }
    }

    override fun onDisabled(context: Context) {
        cancelAlarm(context)
    }

    companion object {
        const val ACTION_REFRESH = "com.dergah.app.WIDGET_NEXT_REFRESH"
        private const val PREFS = "dergah_widget"
        private const val KEY = "schedule"
        private val TZ: TimeZone = TimeZone.getTimeZone("Europe/Istanbul")
        private val KEYS = arrayOf("Sabah", "Gunes", "Ogle", "Ikindi", "Aksam", "Yatsi")
        private val LABELS: Array<String> get() = S.labels()
        // Geri sayım Güneş'i de içerir: İmsak → Güneş → Öğle → ...
        private val PRAYER_IDX = intArrayOf(0, 1, 2, 3, 4, 5)

        fun updateAll(context: Context) {
            S.init(context)
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, NextPrayerWidgetProvider::class.java))
            if (ids.isEmpty()) return
            render(context, mgr, ids)
        }

        private fun toMillis(date: String, hhmm: String): Long? {
            return try {
                val d = date.split("-")
                val h = hhmm.split(":")
                val c = Calendar.getInstance(TZ)
                c.clear()
                c.set(d[0].toInt(), d[1].toInt() - 1, d[2].toInt(), h[0].toInt(), h[1].toInt(), 0)
                c.timeInMillis
            } catch (e: Exception) {
                null
            }
        }

        private fun hhmm(ms: Long): String {
            val c = Calendar.getInstance(TZ)
            c.timeInMillis = ms
            return String.format(java.util.Locale.US, "%02d:%02d", c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
        }

        /** (hedef zamanı, etiket) ya da null */
        private fun nextPrayer(context: Context, now: Long): Pair<Long, String>? {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null) ?: return null
            return try {
                val arr = JSONObject(raw).getJSONArray("days")
                var best = Long.MAX_VALUE
                var label = ""
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val date = o.getString("d")
                    for (idx in PRAYER_IDX) {
                        val t = toMillis(date, o.optString(KEYS[idx], "--:--")) ?: continue
                        if (t > now && t < best) { best = t; label = LABELS[idx] }
                    }
                }
                if (best == Long.MAX_VALUE) null else Pair(best, label)
            } catch (e: Exception) {
                null
            }
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val views = RemoteViews(context.packageName, R.layout.widget_next)
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pi = PendingIntent.getActivity(
                    context, 1, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.wn_root, pi)
            }

            val now = System.currentTimeMillis()
            val next = nextPrayer(context, now)
            if (next == null) {
                views.setTextViewText(R.id.wn_label, S.str(R.string.wn_times))
                views.setViewVisibility(R.id.wn_timer, View.GONE)
                views.setViewVisibility(R.id.wn_fallback, View.VISIBLE)
                views.setTextViewText(R.id.wn_fallback, S.str(R.string.wn_open))
                manager.updateAppWidget(ids, views)
                cancelAlarm(context)
                return
            }

            views.setTextViewText(R.id.wn_label, "${next.second} vakti")
            // 1 saatten azsa "MM:SS" (büyük), fazlaysa "H:MM:SS" (küçük) sığsın diye
            val long = next.first - now >= 60L * 60L * 1000L
            views.setTextViewTextSize(R.id.wn_label, TypedValue.COMPLEX_UNIT_DIP, 9f)
            views.setTextViewTextSize(R.id.wn_timer, TypedValue.COMPLEX_UNIT_DIP, if (long) 12f else 16f)
            if (Build.VERSION.SDK_INT >= 24) {
                views.setViewVisibility(R.id.wn_timer, View.VISIBLE)
                views.setViewVisibility(R.id.wn_fallback, View.GONE)
                views.setChronometerCountDown(R.id.wn_timer, true)
                views.setChronometer(
                    R.id.wn_timer,
                    SystemClock.elapsedRealtime() + (next.first - now),
                    null,
                    true
                )
            } else {
                views.setViewVisibility(R.id.wn_timer, View.GONE)
                views.setViewVisibility(R.id.wn_fallback, View.VISIBLE)
                views.setTextViewText(R.id.wn_fallback, hhmm(next.first))
            }
            manager.updateAppWidget(ids, views)
            // 1 saat sınırında da yeniden çiz (yazı boyutu değişir)
            val oneHourBefore = next.first - 60L * 60L * 1000L
            val at = if (oneHourBefore > now) oneHourBefore + 1000L else next.first + 1000L
            scheduleAlarm(context, at)
        }

        private fun refreshIntent(context: Context): PendingIntent {
            val i = Intent(context, NextPrayerWidgetProvider::class.java).setAction(ACTION_REFRESH)
            return PendingIntent.getBroadcast(
                context, 7313, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun scheduleAlarm(context: Context, at: Long) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = refreshIntent(context)
            try {
                val canExact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
                if (canExact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } catch (e: SecurityException) {
                am.set(AlarmManager.RTC_WAKEUP, at, pi)
            }
        }

        private fun cancelAlarm(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(refreshIntent(context))
        }
    }
}
