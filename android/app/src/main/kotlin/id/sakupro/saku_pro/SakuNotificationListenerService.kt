package id.sakupro.saku_pro

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class SakuNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val notification = sbn.notification ?: return

        // Skip Android group summary notifications to avoid duplicate aggregated events.
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) {
            return
        }

        val packageName = sbn.packageName?.trim() ?: return
        if (packageName.isEmpty() || packageName == applicationContext.packageName) {
            return
        }

        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) {
            return
        }

        val allowed = prefs.getStringSet(KEY_ALLOWED_PACKAGES, DEFAULT_PACKAGES) ?: DEFAULT_PACKAGES
        val matchedPackage = allowed.any { it.equals(packageName, ignoreCase = true) }
        if (!matchedPackage) {
            return
        }

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim().orEmpty()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim().orEmpty()

        val body = if (bigText.length >= text.length) bigText else text
        if (title.isEmpty() && body.isEmpty()) {
            return
        }

        val postTime = if (sbn.postTime > 0L) sbn.postTime else System.currentTimeMillis()
        val dedupeBucket = postTime / 20_000L
        val fingerprint = "${packageName.lowercase()}|${title.lowercase()}|${body.lowercase()}|$dedupeBucket"

        val event = JSONObject().apply {
            put("packageName", packageName)
            put("title", title)
            put("text", body)
            put("subText", subText)
            put("postTime", postTime)
            put("fingerprint", fingerprint)
        }

        if (enqueueEvent(applicationContext, event, fingerprint)) {
            onEventCaptured?.invoke()
        }
    }

    companion object {
        const val PREFS_NAME = "saku_notif_prefs"
        const val KEY_ENABLED = "enabled"
        const val KEY_ALLOWED_PACKAGES = "allowed_packages"
        const val KEY_PENDING_EVENTS = "pending_events"
        const val KEY_RECENT_LOGS = "recent_logs"
        const val KEY_LAST_FINGERPRINT = "last_fingerprint"

        private const val MAX_PENDING_EVENTS = 100
        private const val MAX_RECENT_LOGS = 25

        val DEFAULT_PACKAGES: Set<String> = setOf(
            "id.co.bankbkemobile.digitalbank",
            "id.dana",
            "com.gojek.gopay",
            "com.gojek.app",
            "com.jago.digitalBanking"
        )

        @Volatile
        var onEventCaptured: (() -> Unit)? = null

        fun isPermissionGranted(context: Context): Boolean {
            val enabledListeners = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            ) ?: return false
            val expected = ComponentName(context, SakuNotificationListenerService::class.java)
                .flattenToString()
            return enabledListeners.split(':').any { entry ->
                entry.equals(expected, ignoreCase = true) ||
                    entry.contains(context.packageName, ignoreCase = true)
            }
        }

        @Synchronized
        fun updateConfig(context: Context, enabled: Boolean, packages: List<String>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_ENABLED, enabled)
                .putStringSet(KEY_ALLOWED_PACKAGES, packages.toSet())
                .apply()
        }

        @Synchronized
        private fun enqueueEvent(
            context: Context,
            event: JSONObject,
            fingerprint: String
        ): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.getString(KEY_LAST_FINGERPRINT, null) == fingerprint) {
                return false
            }

            val pending = parseArray(prefs.getString(KEY_PENDING_EVENTS, null))
            for (i in 0 until pending.length()) {
                val existing = pending.optJSONObject(i)
                if (existing?.optString("fingerprint") == fingerprint) {
                    return false
                }
            }
            pending.put(event)
            val trimmedPending = trimTail(pending, MAX_PENDING_EVENTS)

            val logs = parseArray(prefs.getString(KEY_RECENT_LOGS, null))
            logs.put(event)
            val trimmedLogs = trimTail(logs, MAX_RECENT_LOGS)

            prefs.edit()
                .putString(KEY_LAST_FINGERPRINT, fingerprint)
                .putString(KEY_PENDING_EVENTS, trimmedPending.toString())
                .putString(KEY_RECENT_LOGS, trimmedLogs.toString())
                .apply()
            return true
        }

        @Synchronized
        fun drainPendingEvents(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING_EVENTS, "[]") ?: "[]"
            if (raw != "[]") {
                prefs.edit().putString(KEY_PENDING_EVENTS, "[]").apply()
            }
            return raw
        }

        @Synchronized
        fun readRecentLogs(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(KEY_RECENT_LOGS, "[]") ?: "[]"
        }

        @Synchronized
        fun clearRecentLogs(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_RECENT_LOGS, "[]").apply()
        }

        private fun parseArray(raw: String?): JSONArray {
            if (raw.isNullOrBlank()) return JSONArray()
            return try {
                JSONArray(raw)
            } catch (_: Exception) {
                JSONArray()
            }
        }

        private fun trimTail(array: JSONArray, maxItems: Int): JSONArray {
            if (array.length() <= maxItems) return array
            val trimmed = JSONArray()
            val start = array.length() - maxItems
            for (i in start until array.length()) {
                trimmed.put(array.get(i))
            }
            return trimmed
        }
    }
}
