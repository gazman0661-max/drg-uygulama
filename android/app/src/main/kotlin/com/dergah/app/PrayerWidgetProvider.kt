package com.dergah.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.SystemClock
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * Ana ekran widget'ı: sıradaki namaz vaktine kalan süre (Android'in kendi
 * geri sayım sayacı, uygulama kapalıyken de akar), günün 6 vakti ve kerahat
 * durumu. Vakit verisini Flutter uygulaması açıldığında kaydeder; widget
 * vakit/kerahat sınırlarında kendini bir alarmla yeniler.
 */
class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, newOptions: android.os.Bundle
    ) {
        // Widget yeniden boyutlandırılınca (küçük/büyük düzen) yeniden çiz
        render(context, manager, intArrayOf(id))
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

    private class Day(val millis: LongArray) // KEYS sırasıyla 6 vakit

    companion object {
        const val ACTION_REFRESH = "com.dergah.app.WIDGET_REFRESH"
        private const val PREFS = "dergah_widget"
        private const val KEY = "schedule"
        private const val ONE_HOUR_MS = 60L * 60L * 1000L
        private val TZ: TimeZone = TimeZone.getTimeZone("Europe/Istanbul")

        private val KEYS = arrayOf("Sabah", "Gunes", "Ogle", "Ikindi", "Aksam", "Yatsi")
        private val LABELS = arrayOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
        // Geri sayım hedefi olabilecek (namaz) vakitlerin KEYS içindeki indeksleri
        private val PRAYER_IDX = intArrayOf(0, 2, 3, 4, 5)

        private val TIME_IDS = intArrayOf(
            R.id.widget_t0, R.id.widget_t1, R.id.widget_t2,
            R.id.widget_t3, R.id.widget_t4, R.id.widget_t5
        )
        private val LABEL_IDS = intArrayOf(
            R.id.widget_l0, R.id.widget_l1, R.id.widget_l2,
            R.id.widget_l3, R.id.widget_l4, R.id.widget_l5
        )

        fun saveSchedule(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, json).apply()
        }

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
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
                null // "--:--" gibi bozuk değerler
            }
        }

        private fun kerahatMs(context: Context): Long = try {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            if (raw == null) 45L * 60_000L else JSONObject(raw).optInt("kerahatMin", 45) * 60_000L
        } catch (e: Exception) {
            45L * 60_000L
        }

        private fun hhmm(ms: Long): String {
            val c = Calendar.getInstance(TZ)
            c.timeInMillis = ms
            return "%02d:%02d".format(c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
        }

        private fun load(context: Context): Pair<String, List<Day>>? {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null) ?: return null
            return try {
                val obj = JSONObject(raw)
                val arr = obj.getJSONArray("days")
                val days = ArrayList<Day>()
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val date = o.getString("d")
                    val ms = LongArray(KEYS.size)
                    var ok = true
                    for (k in KEYS.indices) {
                        val t = toMillis(date, o.optString(KEYS[k], "--:--"))
                        if (t == null) { ok = false; break }
                        ms[k] = t
                    }
                    if (ok) days.add(Day(ms))
                }
                days.sortBy { it.millis[0] }
                Pair(obj.optString("place", ""), days)
            } catch (e: Exception) {
                null
            }
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val views = RemoteViews(context.packageName, R.layout.widget_prayer)

            // Widget'a dokununca uygulamayı aç
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }

            val now = System.currentTimeMillis()
            val data = load(context)

            // Sıradaki namaz vakti: şu andan sonraki ilk (İmsak/Öğle/İkindi/Akşam/Yatsı)
            var targetDay: Day? = null
            var targetIdx = -1
            if (data != null) {
                outer@ for (d in data.second) {
                    for (idx in PRAYER_IDX) {
                        if (d.millis[idx] > now) {
                            targetDay = d
                            targetIdx = idx
                            break@outer
                        }
                    }
                }
            }

            if (data == null || targetDay == null) {
                // Veri yok ya da bitti: uygulamayı açmaya yönlendir
                views.setTextViewText(R.id.widget_title, "Vakitler güncel değil")
                views.setTextViewText(R.id.widget_place, "")
                views.setViewVisibility(R.id.widget_timer, View.GONE)
                views.setViewVisibility(R.id.widget_timer_fallback, View.VISIBLE)
                views.setTextViewText(R.id.widget_timer_fallback, "Uygulamayı açın")
                for (k in KEYS.indices) {
                    views.setTextViewText(LABEL_IDS[k], LABELS[k])
                    views.setTextViewText(TIME_IDS[k], "--:--")
                    views.setTextColor(TIME_IDS[k], Color.WHITE)
                }
                push(manager, ids, views, false, 21, 8)
                cancelAlarm(context)
                return
            }

            val target = targetDay.millis[targetIdx]
            views.setTextViewText(R.id.widget_title, "${LABELS[targetIdx]} vakti")
            views.setTextViewText(R.id.widget_place, data.first)

            // Geri sayım (API 24+); daha eski cihazlarda vaktin saati gösterilir
            if (Build.VERSION.SDK_INT >= 24) {
                views.setViewVisibility(R.id.widget_timer, View.VISIBLE)
                views.setViewVisibility(R.id.widget_timer_fallback, View.GONE)
                views.setChronometerCountDown(R.id.widget_timer, true)
                views.setChronometer(
                    R.id.widget_timer,
                    SystemClock.elapsedRealtime() + (target - now),
                    null,
                    true
                )
            } else {
                views.setViewVisibility(R.id.widget_timer, View.GONE)
                views.setViewVisibility(R.id.widget_timer_fallback, View.VISIBLE)
                views.setTextViewText(R.id.widget_timer_fallback, hhmm(target))
            }

            // 6 vakit; sıradaki altın renkte
            val gold = Color.parseColor("#C7A24B")
            for (k in KEYS.indices) {
                views.setTextViewText(LABEL_IDS[k], LABELS[k])
                views.setTextViewText(TIME_IDS[k], hhmm(targetDay.millis[k]))
                views.setTextColor(TIME_IDS[k], if (k == targetIdx) gold else Color.WHITE)
            }

            // Kerahat: Güneş doğuşu +45 dk, istiva (öğleden 45 dk önce), batış (akşamdan 45 dk önce)
            val gunes = targetDay.millis[1]
            val ogle = targetDay.millis[2]
            val aksam = targetDay.millis[4]
            val kerahat = kerahatMs(context)
            val starts = longArrayOf(gunes, ogle - kerahat, aksam - kerahat)
            val ends = longArrayOf(gunes + kerahat, ogle, aksam)
            val names = arrayOf("Güneşin Doğuşu", "İstiva (Tam Öğle)", "Güneşin Batışı")
            var active = -1
            for (i in 0..2) {
                if (now >= starts[i] && now < ends[i]) active = i
            }
            views.setViewVisibility(R.id.widget_kerahat, View.VISIBLE)
            if (active >= 0) {
                views.setTextViewText(
                    R.id.widget_kerahat,
                    "⚠ Kerahat vakti: ${names[active]} (${hhmm(starts[active])}–${hhmm(ends[active])})"
                )
                views.setTextColor(R.id.widget_kerahat, Color.parseColor("#F2B8A8"))
            } else {
                val txt = (0..2).joinToString(" • ") { "${hhmm(starts[it])}–${hhmm(ends[it])}" }
                views.setTextViewText(R.id.widget_kerahat, "Kerahat: $txt")
                views.setTextColor(R.id.widget_kerahat, Color.parseColor("#B9C8C2"))
            }

            // Geri sayım metni: 1 saatten azsa "MM:SS" (5), fazlaysa "H:MM:SS" (8)
            val timerChars = if (target - now >= ONE_HOUR_MS) 8 else 5
            val titleLen = "${LABELS[targetIdx]} vakti".length
            push(manager, ids, views, true, titleLen, timerChars)

            // Bir sonraki değişim anında (vakit ya da kerahat sınırı) yeniden çiz
            var next = target
            for (t in starts + ends + longArrayOf(target - ONE_HOUR_MS)) {
                if (t > now && t < next) next = t
            }
            scheduleAlarm(context, next + 1000L)
        }

        /**
         * Widget boyutuna göre düzen: küçükken (ör. 1x1–2x1) yalnızca vakit adı
         * ve geri sayım gösterilir; vakit satırı, yer ve kerahat gizlenir.
         * Yazı boyutları genişliğe göre KODDAN hesaplanır (autoSize bazı
         * launcher'larda "Araç yüklenemiyor" hatası verdiği için kullanılmaz).
         */
        private fun push(
            manager: AppWidgetManager, ids: IntArray, views: RemoteViews,
            showKerahat: Boolean, titleLen: Int, timerChars: Int
        ) {
            for (id in ids) {
                val o = manager.getAppWidgetOptions(id)
                val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
                val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
                val compact = w < 200 || h < 95
                val vis = if (compact) View.GONE else View.VISIBLE
                views.setViewVisibility(R.id.widget_times_row, vis)
                views.setViewVisibility(R.id.widget_place, vis)
                views.setViewVisibility(
                    R.id.widget_kerahat,
                    if (compact || !showKerahat) View.GONE else View.VISIBLE
                )

                // Kullanılabilir genişlik (dp) = widget genişliği - kenar boşlukları
                val avail = (w - 24).coerceAtLeast(40).toFloat()
                val title = (avail / (titleLen.coerceAtLeast(1) * 0.60f)).coerceIn(9f, 14f)
                val timer = (avail / (timerChars.coerceAtLeast(1) * 0.62f)).coerceIn(10f, 34f)
                val fallback = (avail / (15 * 0.60f)).coerceIn(10f, 28f) // "Uygulamayı açın"
                views.setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, title)
                views.setTextViewTextSize(R.id.widget_timer, TypedValue.COMPLEX_UNIT_SP, timer)
                views.setTextViewTextSize(
                    R.id.widget_timer_fallback, TypedValue.COMPLEX_UNIT_SP, fallback
                )
                manager.updateAppWidget(id, views)
            }
        }

        private fun refreshIntent(context: Context): PendingIntent {
            val i = Intent(context, PrayerWidgetProvider::class.java).setAction(ACTION_REFRESH)
            return PendingIntent.getBroadcast(
                context, 7311, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun scheduleAlarm(context: Context, at: Long) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = refreshIntent(context)
            try {
                val canExact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
                if (Build.VERSION.SDK_INT >= 23) {
                    if (canExact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                    else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, at, pi)
                }
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
