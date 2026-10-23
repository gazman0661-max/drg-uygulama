package com.dergah.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Zincirleme alarmın alıcısı. Gerçek alarmda (ACTION_ALERT) bildirimi gösterir
 * ve sıradaki alarmı kurar. Telefon yeniden başlayınca / saat ya da saat dilimi
 * değişince / uygulama güncellenince sadece zinciri yeniden kurar (ses çalmaz).
 */
class AlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // "Sesi kapat" düğmesi: yalnızca o bildirimi kaldırır (ses de durur).
        // Zincirdeki sıradaki alarma dokunulmaz.
        if (intent.action == AlertScheduler.ACTION_STOP) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as android.app.NotificationManager
            nm.cancel(intent.getIntExtra("id", -1))
            return
        }
        val pending = goAsync()
        try {
            AlertScheduler.process(
                context.applicationContext,
                fromApp = intent.action != AlertScheduler.ACTION_ALERT
            )
        } finally {
            pending.finish()
        }
    }
}
