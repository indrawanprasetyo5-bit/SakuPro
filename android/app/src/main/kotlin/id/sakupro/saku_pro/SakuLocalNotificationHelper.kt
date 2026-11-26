package id.sakupro.saku_pro

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import java.util.Calendar

object SakuLocalNotificationHelper {
    const val CHANNEL_BUDGET = "sakupro_budget_alerts"
    const val CHANNEL_REMINDERS = "sakupro_reminders"

    const val PREFS_REMINDER = "saku_reminder_prefs"
    const val KEY_ENABLED = "enabled"
    const val KEY_BILLS_JSON = "bills_json"
    const val KEY_WEEKLY_SUMMARY = "weekly_summary"
    const val KEY_LAST_BILL_DATE = "last_bill_date"
    const val KEY_LAST_WEEKLY_DATE = "last_weekly_date"

    private const val DAILY_ALARM_REQUEST_CODE = 4401

    fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val budgetChannel = NotificationChannel(
            CHANNEL_BUDGET,
            "Peringatan Budget & QRIS",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Peringatan saat pengeluaran mendekati atau melewati batas budget."
        }

        val reminderChannel = NotificationChannel(
            CHANNEL_REMINDERS,
            "Pengingat Tagihan & Ringkasan",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Pengingat tagihan jatuh tempo dan ringkasan keuangan mingguan."
        }

        manager.createNotificationChannel(budgetChannel)
        manager.createNotificationChannel(reminderChannel)
    }

    fun showNotification(
        context: Context,
        notificationId: Int,
        channelId: String,
        title: String,
        body: String
    ): Boolean {
        if (!hasNotificationPermission(context)) {
            return false
        }
        ensureChannels(context)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = PendingIntent.getActivity(context, notificationId, launchIntent, flags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher_monochrome)
            .setColor(0xFF0F766E.toInt())
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification)
        return true
    }

    fun syncReminderSchedule(
        context: Context,
        enabled: Boolean,
        billsJson: String,
        weeklySummary: String
    ) {
        val prefs = context.getSharedPreferences(PREFS_REMINDER, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putString(KEY_BILLS_JSON, billsJson)
            .putString(KEY_WEEKLY_SUMMARY, weeklySummary)
            .apply()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, SakuReminderReceiver::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            DAILY_ALARM_REQUEST_CODE,
            intent,
            flags
        )

        if (!enabled) {
            alarmManager.cancel(pendingIntent)
            return
        }

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_MONTH, 1)
            }
        }

        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            cal.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }
}
