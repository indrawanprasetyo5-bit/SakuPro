package id.sakupro.saku_pro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class SakuHomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateSingleWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_WIDGET = "saku_widget_prefs"
        const val KEY_SAFE_DAILY = "safe_daily"
        const val KEY_NET_WORTH = "net_worth"
        const val KEY_STATUS_LABEL = "status_label"
        const val EXTRA_SAKU_ACTION = "saku_action"
        const val ACTION_QUICK_INPUT = "quick_input"
        const val ACTION_SCAN_RECEIPT = "scan_receipt"

        fun saveAndRefresh(
            context: Context,
            safeDailyText: String,
            netWorthText: String,
            statusLabel: String
        ) {
            val prefs = context.getSharedPreferences(PREFS_WIDGET, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_SAFE_DAILY, safeDailyText)
                .putString(KEY_NET_WORTH, netWorthText)
                .putString(KEY_STATUS_LABEL, statusLabel)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SakuHomeWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            for (id in ids) {
                updateSingleWidget(context, manager, id)
            }
        }

        private fun updateSingleWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_WIDGET, Context.MODE_PRIVATE)
            val safeDaily = prefs.getString(KEY_SAFE_DAILY, "Rp 0 / hari") ?: "Rp 0 / hari"
            val netWorth = prefs.getString(KEY_NET_WORTH, "Saldo Bersih: Rp 0") ?: "Saldo Bersih: Rp 0"
            val statusLabel = prefs.getString(KEY_STATUS_LABEL, "Aman") ?: "Aman"

            val views = RemoteViews(context.packageName, R.layout.saku_home_widget)
            views.setTextViewText(R.id.widget_safe_daily, safeDaily)
            views.setTextViewText(R.id.widget_net_worth, netWorth)
            views.setTextViewText(R.id.widget_status_badge, statusLabel)

            views.setOnClickPendingIntent(
                R.id.widget_root,
                buildLaunchPendingIntent(context, 7001, null)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_quick_add,
                buildLaunchPendingIntent(context, 7002, ACTION_QUICK_INPUT)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_scan,
                buildLaunchPendingIntent(context, 7003, ACTION_SCAN_RECEIPT)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun buildLaunchPendingIntent(
            context: Context,
            requestCode: Int,
            actionExtra: String?
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (actionExtra != null) {
                    putExtra(EXTRA_SAKU_ACTION, actionExtra)
                }
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getActivity(context, requestCode, intent, flags)
        }
    }
}
