package com.dergah.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.ContextCompat

/**
 * Uygulamanın KENDİ ses servisi: ezan / hatırlatma sesini bildirim kanalına
 * bırakmadan MediaPlayer ile çalar. Böylece telefonun bildirim kanalı ses
 * ayarları (ör. Xiaomi'de "Seslere izin ver" kapalı gelmesi) sesi engelleyemez.
 *
 * - Ön plan servisi (mediaPlayback): ses bitene kadar süreç canlı kalır.
 * - stream = alarm -> ALARM ses kanalı (telefon sessizdeyken de çalar)
 * - stream = media -> MEDYA ses kanalı
 * - stream = notification -> BİLDİRİM ses kanalı (telefonun sessiz modunu izler)
 * - Bildirimde "Sesi kapat" düğmesi sesi anında durdurur.
 * - Servis başlatılamazsa AlertScheduler eski yönteme (kanal sesi) düşer.
 */
class EzanService : Service() {

    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var notifId = 0
    private var finalNotification: Notification? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        S.init(this)
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent.action == ACTION_STOP) {
            val id = intent.getIntExtra(EXTRA_ID, notifId)
            stopPlayback()
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
            stopForegroundCompat(remove = true)
            stopSelf()
            return START_NOT_STICKY
        }

        notifId = intent.getIntExtra(EXTRA_ID, 20)
        val title = intent.getStringExtra(EXTRA_TITLE) ?: S.str(R.string.alert_prayer_time)
        val text = intent.getStringExtra(EXTRA_TEXT) ?: ""
        val adhan = intent.getBooleanExtra(EXTRA_ADHAN, true)
        val stream = intent.getStringExtra(EXTRA_STREAM) ?: "alarm"
        val volume = intent.getFloatExtra(EXTRA_VOLUME, 1f).coerceIn(0.05f, 1f)
        val whenMs = intent.getLongExtra(EXTRA_WHEN, System.currentTimeMillis())

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(nm)
        val ongoing = buildNotification(title, text, whenMs, withStop = true, ongoing = true)
        finalNotification = buildNotification(title, text, whenMs, withStop = false, ongoing = false)

        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(notifId, ongoing, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(notifId, ongoing)
            }
        } catch (e: Exception) {
            // Ön plana alınamadı: bildirimi yine de göster, sesi çalmayı dene
            nm.notify(notifId, finalNotification)
        }

        vibrateOnce()
        startPlayback(adhan, stream, volume)
        return START_NOT_STICKY
    }

    // ----------------------------------------------------------- bildirim
    private fun ensureChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < 26) return
        val ch = NotificationChannel(CHANNEL, S.str(R.string.ch_playing), NotificationManager.IMPORTANCE_HIGH)
        ch.description = S.str(R.string.ch_playing_d)
        ch.setSound(null, null)       // ses MediaPlayer'dan gelir, kanaldan değil
        ch.enableVibration(false)     // titreşimi servis tek sefer verir
        nm.createNotificationChannel(ch)
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(
        title: String, text: String, whenMs: Long, withStop: Boolean, ongoing: Boolean
    ): Notification {
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
        else Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
        b.setSmallIcon(R.drawable.ic_stat_dergah)
            .setContentTitle(title)
            .setContentText(text)
            .setWhen(whenMs)
            .setShowWhen(true)
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            b.setContentIntent(
                PendingIntent.getActivity(
                    this, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        if (withStop) {
            val stop = Intent(this, EzanService::class.java)
                .setAction(ACTION_STOP).putExtra(EXTRA_ID, notifId)
            val spi = PendingIntent.getService(
                this, notifId, stop, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            b.addAction(R.drawable.ic_stat_dergah, S.str(R.string.stop_sound), spi)
        }
        return b.build()
    }

    // --------------------------------------------------------------- ses
    private fun startPlayback(adhan: Boolean, stream: String, volume: Float) {
        stopPlayback()
        val attrs = AudioAttributes.Builder()
            .setUsage(
                when (stream) {
                    "media" -> AudioAttributes.USAGE_MEDIA
                    "notification" -> AudioAttributes.USAGE_NOTIFICATION
                    else -> AudioAttributes.USAGE_ALARM
                }
            )
            .setContentType(
                if (adhan) AudioAttributes.CONTENT_TYPE_MUSIC else AudioAttributes.CONTENT_TYPE_SONIFICATION
            )
            .build()
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(attrs)
            mp.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            val resId = resources.getIdentifier("ezan", "raw", packageName)
            if (adhan && resId != 0) {
                val afd = resources.openRawResourceFd(resId)
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            } else {
                val uri = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_NOTIFICATION)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                mp.setDataSource(applicationContext, uri)
            }
            mp.setOnCompletionListener { finishPlayback() }
            mp.setOnErrorListener { _, _, _ -> finishPlayback(); true }
            mp.setOnPreparedListener {
                requestFocus(attrs)
                it.setVolume(volume, volume)
                it.start()
            }
            player = mp
            mp.prepareAsync()
            // Güvenlik: en geç 6 dakika sonra her durumda bitir
            handler.postDelayed({ finishPlayback() }, 6L * 60L * 1000L)
        } catch (e: Exception) {
            finishPlayback()
        }
    }

    private fun requestFocus(attrs: AudioAttributes) {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                val fr = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attrs).build()
                focusRequest = fr
                am.requestAudioFocus(fr)
            }
        } catch (e: Exception) {
        }
    }

    private fun abandonFocus() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { am.abandonAudioFocusRequest(it) }
        } catch (e: Exception) {
        }
        focusRequest = null
    }

    private fun stopPlayback() {
        handler.removeCallbacksAndMessages(null)
        player?.let {
            try { if (it.isPlaying) it.stop() } catch (e: Exception) {}
            try { it.release() } catch (e: Exception) {}
        }
        player = null
        abandonFocus()
    }

    /** Ses kendiliğinden bitti: bildirim kalsın ama "Sesi kapat" düğmesi kalksın. */
    private fun finishPlayback() {
        if (player == null && finalNotification == null) {
            stopSelf()
            return
        }
        stopPlayback()
        stopForegroundCompat(remove = false)
        finalNotification?.let {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(notifId, it)
        }
        stopSelf()
    }

    private fun stopForegroundCompat(remove: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= 24) {
                stopForeground(if (remove) Service.STOP_FOREGROUND_REMOVE else Service.STOP_FOREGROUND_DETACH)
            } else {
                @Suppress("DEPRECATION") stopForeground(remove)
            }
        } catch (e: Exception) {
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrateOnce() {
        try {
            val v: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= 26) {
                v?.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                v?.vibrate(400)
            }
        } catch (e: Exception) {
        }
    }

    override fun onDestroy() {
        stopPlayback()
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "com.dergah.app.EZAN_SERVICE_STOP"
        private const val CHANNEL = "ezan_calma_v1"
        private const val EXTRA_ID = "id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_ADHAN = "adhan"
        private const val EXTRA_STREAM = "stream"
        private const val EXTRA_VOLUME = "volume"
        private const val EXTRA_WHEN = "when"

        /** Servisi başlatır. Başlatılamazsa (arka plan kısıtı vb.) false döner. */
        fun start(
            context: Context, id: Int, title: String, text: String,
            adhan: Boolean, stream: String, volume: Float, whenMs: Long
        ): Boolean {
            return try {
                val i = Intent(context, EzanService::class.java)
                    .putExtra(EXTRA_ID, id)
                    .putExtra(EXTRA_TITLE, title)
                    .putExtra(EXTRA_TEXT, text)
                    .putExtra(EXTRA_ADHAN, adhan)
                    .putExtra(EXTRA_STREAM, stream)
                    .putExtra(EXTRA_VOLUME, volume)
                    .putExtra(EXTRA_WHEN, whenMs)
                ContextCompat.startForegroundService(context, i)
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}
