package id.sakupro.saku_pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class SakuReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = context.getSharedPreferences(
            SakuLocalNotificationHelper.PREFS_REMINDER,
            Context.MODE_PRIVATE
        )
        if (!prefs.getBoolean(SakuLocalNotificationHelper.KEY_ENABLED, false)) {
            return
        }

        val cal = Calendar.getInstance()
        val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val currentDay = cal.get(Calendar.DAY_OF_MONTH)

        val billsJson = prefs.getString(SakuLocalNotificationHelper.KEY_BILLS_JSON, "[]") ?: "[]"
        val lastBillDate = prefs.getString(SakuLocalNotificationHelper.KEY_LAST_BILL_DATE, "")
        if (lastBillDate != todayKey) {
            val dueNames = mutableListOf<String>()
            try {
                val arr = JSONArray(billsJson)
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i) ?: continue
                    val paid = obj.optBoolean("paid", false)
                    val dueDay = obj.optInt("dueDay", -1)
                    val name = obj.optString("name", "")
                    if (!paid && name.isNotEmpty() && dueDay in currentDay..(currentDay + 2)) {
                        val suffix = if (dueDay == currentDay) "hari ini" else "tgl $dueDay"
                        dueNames.add("$name ($suffix)")
                    }
                }
            } catch (_: Exception) {
                // Ignore malformed cached payload.
            }

            if (dueNames.isNotEmpty()) {
                val sent = SakuLocalNotificationHelper.showNotification(
                    context = context,
                    notificationId = 5101,
                    channelId = SakuLocalNotificationHelper.CHANNEL_REMINDERS,
                    title = "Pengingat Tagihan SakuProWann",
                    body = "Segera jatuh tempo: ${dueNames.joinToString(", ")}."
                )
                if (sent) {
                    prefs.edit().putString(SakuLocalNotificationHelper.KEY_LAST_BILL_DATE, todayKey).apply()
                }
            }
        }

        val isSunday = cal.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY
        val weeklyText = prefs.getString(SakuLocalNotificationHelper.KEY_WEEKLY_SUMMARY, "").orEmpty()
        val lastWeeklyDate = prefs.getString(SakuLocalNotificationHelper.KEY_LAST_WEEKLY_DATE, "")
        if (isSunday && weeklyText.isNotEmpty() && lastWeeklyDate != todayKey) {
            val sent = SakuLocalNotificationHelper.showNotification(
                context = context,
                notificationId = 5102,
                channelId = SakuLocalNotificationHelper.CHANNEL_REMINDERS,
                title = "Ringkasan Mingguan SakuProWann",
                body = weeklyText
            )
            if (sent) {
                prefs.edit().putString(SakuLocalNotificationHelper.KEY_LAST_WEEKLY_DATE, todayKey).apply()
            }
        }
    }
}
