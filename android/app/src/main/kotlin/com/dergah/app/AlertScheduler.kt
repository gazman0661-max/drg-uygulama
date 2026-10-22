package com.dergah.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * ZİNCİRLEME ALARM: ezan, vakit hatırlatması ve bildirim çubuğu paneli.
 *
 * Flutter, vakit verisini ve ayarları kaydeder (AlertScheduler.saveSchedule
 * değil, PrayerWidgetProvider.saveSchedule ile aynı JSON). Burada yalnızca
 * SIRADAKİ alarm kurulur; alarm çalınca [AlertReceiver] [process] çağırır,
 * o da bildirimi gösterir ve bir sonrakini kurar. Böylece Android'in alarm
 * sayısı sınırına takılmayız ve uygulamayı düzenli açmak gerekmez
 * (veri bitene kadar, ~2-3 ay).
 */
object AlertScheduler {
    const val ACTION_ALERT = "com.dergah.app.ALERT"
    const val ACTION_STOP = "com.dergah.app.STOP_ADHAN"

    private const val PREFS_DATA = "dergah_widget"
    private const val KEY_DATA = "schedule"
    private const val PREFS_STATE = "dergah_alerts"
    private const val KEY_LAST = "last_handled"

    private const val CH_EZAN = "ezan_vakti_v2"
    private const val CH_ADHAN_DEFAULT = "namaz_vakti_varsayilan_v2"
    private const val CH_REMINDER = "namaz_hatirlatma_v2"
    private const val CH_PANEL = "vakit_paneli"
    private const val CH_SILENT = "namaz_vakti_sessiz_v2"
    private val VIBRATE_ONCE = longArrayOf(0L, 400L) // 1 kez kısa titreşim

    private const val PANEL_ID = 1
    private const val TOLERANCE_MS = 10L * 60L * 1000L // gecikmiş alarmı en fazla 10 dk sonra göster
    private const val KERAHAT_MS = 45L * 60L * 1000L

    private val TZ: TimeZone = TimeZone.getTimeZone("Europe/Istanbul")
    private val KEYS = arrayOf("Sabah", "Gunes", "Ogle", "Ikindi", "Aksam", "Yatsi")
    private val LABELS = arrayOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
    private val PRAYER_IDX = intArrayOf(0, 2, 3, 4, 5) // Güneş namaz vakti değil
    private val PRAYER_KEYS = setOf("Sabah", "Ogle", "Ikindi", "Aksam", "Yatsi")

    private class Alert(val t: Long, val adhan: Boolean, val label: String, val minutes: Int)
    private class Ev(val t: Long, val key: String, val day: Int)
    private class Config(
        val days: List<LongArray>,
        val alerts: List<Alert>,
        val panel: Boolean,
        val panelKerahat: Boolean,
        val notify: Boolean,
        val sound: Boolean
    )

    // ---------------------------------------------------------------- veri
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
        return "%02d:%02d".format(c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    private fun load(context: Context): Config? {
        val raw = context.getSharedPreferences(PREFS_DATA, Context.MODE_PRIVATE)
            .getString(KEY_DATA, null) ?: return null
        return try {
            val obj = JSONObject(raw)
            val arr = obj.getJSONArray("days")
            val days = ArrayList<LongArray>()
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
                if (ok) days.add(ms)
            }
            days.sortBy { it[0] }

            val rem = obj.optJSONObject("reminders")
            val alerts = ArrayList<Alert>()
            for (d in days) {
                for (k in KEYS.indices) {
                    if (PRAYER_IDX.contains(k)) {
                        alerts.add(Alert(d[k], true, LABELS[k], 0))
                    }
                    val m = rem?.optInt(KEYS[k], 0) ?: 0
                    if (m > 0) {
                        alerts.add(Alert(d[k] - m * 60_000L, false, LABELS[k], m))
                    }
                }
            }
            Config(
                days, alerts,
                obj.optBoolean("panel", false), obj.optBoolean("panelKerahat", true),
                obj.optBoolean("notify", true), obj.optBoolean("sound", true)
            )
        } catch (e: Exception) {
            null
        }
    }

    // ------------------------------------------------------------ ana akış
    /**
     * [fromApp] true ise (uygulama açıldı / ayar değişti / telefon yeniden
     * başladı / saat değişti) geçmiş olaylar için ses ÇALMAZ; sadece paneli
     * tazeler ve sıradaki alarmı kurar. Gerçek alarmda false gelir.
     */
    fun process(context: Context, fromApp: Boolean) {
        val now = System.currentTimeMillis()
        val horizon = now + 1000L
        val sp = context.getSharedPreferences(PREFS_STATE, Context.MODE_PRIVATE)
        val stored = sp.getLong(KEY_LAST, 0L)
        val last = if (stored == 0L) horizon else stored

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val cfg = load(context)
        if (cfg == null) {
            nm.cancel(PANEL_ID)
            cancelAlarm(context)
            sp.edit().putLong(KEY_LAST, horizon).apply()
            return
        }
        createChannels(context)

        if (!fromApp && cfg.notify) {
            for (a in cfg.alerts) {
                if (a.t > last && a.t <= horizon && now - a.t <= TOLERANCE_MS) {
                    postAlert(context, nm, a, cfg.sound)
                }
            }
        }
        sp.edit().putLong(KEY_LAST, horizon).apply()

        val ev = if (cfg.panel) events(cfg) else emptyList()
        if (cfg.panel) showPanel(context, nm, cfg, ev, now) else nm.cancel(PANEL_ID)

        // Sıradaki alarm: en yakın ezan/hatırlatma ya da panel dilim sınırı
        var next = Long.MAX_VALUE
        for (a in cfg.alerts) if (a.t > horizon && a.t < next) next = a.t
        for (e in ev) if (e.t > horizon && e.t < next) next = e.t
        if (next == Long.MAX_VALUE) cancelAlarm(context) else scheduleAlarm(context, next)
    }

    // --------------------------------------------------------- bildirimler
    private fun launchIntent(context: Context): PendingIntent? {
        val li = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(
            context, 0, li, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun ezanResId(context: Context): Int =
        context.resources.getIdentifier("ezan", "raw", context.packageName)

    private fun builder(context: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel)
        else Notification.Builder(context)

    @Suppress("DEPRECATION")
    private fun postAlert(context: Context, nm: NotificationManager, a: Alert, sound: Boolean) {
        val resId = ezanResId(context)
        val channel = when {
            !sound -> CH_SILENT
            a.adhan && resId != 0 -> CH_EZAN
            a.adhan -> CH_ADHAN_DEFAULT
            else -> CH_REMINDER
        }
        val b = builder(context, channel)
            .setSmallIcon(R.drawable.ic_stat_dergah)
            .setContentTitle(if (a.adhan) "Namaz Vakti" else "Vakit Yaklaşıyor")
            .setContentText(
                if (a.adhan) "${a.label} vakti girdi."
                else "${a.label} vaktine ${a.minutes} dakika kaldı."
            )
            .setAutoCancel(true)
            .setWhen(a.t)
            .setShowWhen(true)
        launchIntent(context)?.let { b.setContentIntent(it) }

        // Aynı dakikadaki ezan ve hatırlatma birbirini ezmesin
        val id = (10 + ((a.t / 60_000L) % 10_000_000L) * 2 + (if (a.adhan) 0 else 1)).toInt()

        // Ezan bildirimine "Sesi kapat" düğmesi: bildirimi kaldırır, ezan sesi
        // durur. Zincirdeki sıradaki alarma dokunmaz; sonraki vakitte yine çalar.
        if (a.adhan) {
            val stop = Intent(context, AlertReceiver::class.java)
                .setAction(ACTION_STOP)
                .putExtra("id", id)
            val spi = PendingIntent.getBroadcast(
                context, id, stop, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            b.addAction(R.drawable.ic_stat_dergah, "Sesi kapat", spi)
        }

        if (Build.VERSION.SDK_INT < 26) {
            b.setPriority(if (sound) Notification.PRIORITY_HIGH else Notification.PRIORITY_DEFAULT)
            b.setVibrate(VIBRATE_ONCE)
            if (sound) {
                if (a.adhan && resId != 0) {
                    b.setSound(Uri.parse("android.resource://${context.packageName}/$resId"))
                } else {
                    b.setDefaults(Notification.DEFAULT_SOUND)
                }
            }
        }
        nm.notify(id, b.build())
    }

    private fun events(cfg: Config): List<Ev> {
        val ev = ArrayList<Ev>()
        for ((di, d) in cfg.days.withIndex()) {
            val sabah = d[0]; val gunes = d[1]; val ogle = d[2]
            val ikindi = d[3]; val aksam = d[4]; val yatsi = d[5]
            ev.add(Ev(sabah, "Sabah", di))
            ev.add(Ev(gunes, "Gunes", di))
            if (cfg.panelKerahat) {
                ev.add(Ev(gunes + KERAHAT_MS, "KEnd", di))
                ev.add(Ev(ogle - KERAHAT_MS, "KIstiva", di))
            }
            ev.add(Ev(ogle, "Ogle", di))
            ev.add(Ev(ikindi, "Ikindi", di))
            if (cfg.panelKerahat) ev.add(Ev(aksam - KERAHAT_MS, "KBatis", di))
            ev.add(Ev(aksam, "Aksam", di))
            ev.add(Ev(yatsi, "Yatsi", di))
        }
        return ev
    }

    @Suppress("DEPRECATION")
    private fun showPanel(
        context: Context, nm: NotificationManager, cfg: Config, ev: List<Ev>, now: Long
    ) {
        // Şu an hangi dilimdeyiz?
        var i = -1
        for (x in 0 until ev.size - 1) {
            if (ev[x].t <= now && now < ev[x + 1].t) { i = x; break }
        }
        // Gece yarısından İmsak'a kadar: dün akşamın verisi yok ama panel yine görünsün
        val beforeFirst = ev.isNotEmpty() && now < ev[0].t
        if (i < 0 && !beforeFirst) { nm.cancel(PANEL_ID); return }

        // Geri sayım hedefi: dilimden sonraki ilk namaz vakti
        var j = -1
        for (x in i + 1 until ev.size) {
            if (PRAYER_KEYS.contains(ev[x].key)) { j = x; break }
        }
        if (j < 0) { nm.cancel(PANEL_ID); return }

        val target = ev[j]
        val d = cfg.days[target.day]
        val targetLabel = LABELS[KEYS.indexOf(target.key)]

        val all = KEYS.indices.map { "${LABELS[it]} ${hhmm(d[it])}" }
        val lines = arrayListOf(
            all.subList(0, 3).joinToString("   "),
            all.subList(3, 6).joinToString("   ")
        )
        var summary = all.joinToString(" · ")

        if (cfg.panelKerahat) {
            val starts = longArrayOf(d[1], d[2] - KERAHAT_MS, d[4] - KERAHAT_MS)
            val ends = longArrayOf(d[1] + KERAHAT_MS, d[2], d[4])
            val names = arrayOf("Güneşin Doğuşu", "İstiva (Tam Öğle)", "Güneşin Batışı")
            val curKey = if (i >= 0) ev[i].key else ""
            val idx = when (curKey) { "Gunes" -> 0; "KIstiva" -> 1; "KBatis" -> 2; else -> -1 }
            if (idx >= 0) {
                lines.add("⚠ Şu an kerahat vakti: ${names[idx]} (${hhmm(starts[idx])}–${hhmm(ends[idx])})")
                summary = "⚠ Kerahat vakti: ${names[idx]}"
            } else {
                lines.add("Kerahat: " + (0..2).joinToString(" • ") { "${hhmm(starts[it])}–${hhmm(ends[it])}" })
            }
        }

        val b = builder(context, CH_PANEL)
            .setSmallIcon(R.drawable.ic_stat_dergah)
            .setContentTitle("$targetLabel vaktine kalan süre")
            .setContentText(summary)
            .setStyle(Notification.BigTextStyle().bigText(lines.joinToString("\n")))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(target.t) // geri sayım hedefi
            .setUsesChronometer(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT >= 24) b.setChronometerCountDown(true)
        if (Build.VERSION.SDK_INT < 26) b.setPriority(Notification.PRIORITY_LOW)
        launchIntent(context)?.let { b.setContentIntent(it) }
        nm.notify(PANEL_ID, b.build())
    }

    // ------------------------------------------------------------- kanallar
    private fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // Kanal ayarları sonradan değişmez: titreşimsiz eski kanalları sil, yenilerini (_v2) kur
        for (old in arrayOf("ezan_vakti", "namaz_vakti_varsayilan", "namaz_hatirlatma", "namaz_vakti_sessiz")) {
            nm.deleteNotificationChannel(old)
        }

        val resId = ezanResId(context)
        if (resId != 0) {
            val ch = NotificationChannel(CH_EZAN, "Ezan (namaz vakti)", NotificationManager.IMPORTANCE_HIGH)
            ch.description = "Namaz vakti girdiğinde ezan sesiyle haber verir"
            ch.setSound(Uri.parse("android.resource://${context.packageName}/$resId"), attrs)
            ch.enableVibration(true)
            ch.vibrationPattern = VIBRATE_ONCE
            nm.createNotificationChannel(ch)
        }
        val def = NotificationChannel(
            CH_ADHAN_DEFAULT, "Namaz vakti (varsayılan ses)", NotificationManager.IMPORTANCE_HIGH
        )
        def.description = "Namaz vakti girdiğinde bildirim gösterir"
        def.enableVibration(true)
        def.vibrationPattern = VIBRATE_ONCE
        nm.createNotificationChannel(def)

        val rem = NotificationChannel(
            CH_REMINDER, "Vakit Hatırlatmaları", NotificationManager.IMPORTANCE_HIGH
        )
        rem.description = "Seçilen namaz vaktinden belirli bir süre önce hatırlatma gösterir"
        rem.enableVibration(true)
        rem.vibrationPattern = VIBRATE_ONCE
        nm.createNotificationChannel(rem)

        val silent = NotificationChannel(
            CH_SILENT, "Sessiz bildirimler", NotificationManager.IMPORTANCE_DEFAULT
        )
        silent.description = "Namaz vakti ve hatırlatmalar sessiz gelir"
        silent.setSound(null, null)
        silent.enableVibration(true)
        silent.vibrationPattern = VIBRATE_ONCE
        nm.createNotificationChannel(silent)

        val panel = NotificationChannel(CH_PANEL, "Vakit paneli", NotificationManager.IMPORTANCE_LOW)
        panel.description = "Bildirim çubuğunda sıradaki vakte kalan süreyi ve günün vakitlerini gösterir"
        panel.setSound(null, null)
        panel.enableVibration(false)
        panel.setShowBadge(false)
        nm.createNotificationChannel(panel)
    }

    // ---------------------------------------------------------------- alarm
    private fun alarmIntent(context: Context): PendingIntent {
        val i = Intent(context, AlertReceiver::class.java).setAction(ACTION_ALERT)
        return PendingIntent.getBroadcast(
            context, 7312, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleAlarm(context: Context, at: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = alarmIntent(context)
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
        am.cancel(alarmIntent(context))
    }
}
