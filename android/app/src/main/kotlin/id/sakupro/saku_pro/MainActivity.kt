package id.sakupro.saku_pro

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private var notificationChannel: MethodChannel? = null
    private var automationChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingSharedImagePath: String? = null
    private var pendingLaunchAction: String? = null
    private var pendingNotifPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent, notifyFlutter = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent, notifyFlutter = true)
    }

    private fun handleIncomingIntent(intent: Intent?, notifyFlutter: Boolean) {
        if (intent == null) return

        val actionExtra = intent.getStringExtra(SakuHomeWidgetProvider.EXTRA_SAKU_ACTION)
        if (!actionExtra.isNullOrBlank()) {
            pendingLaunchAction = actionExtra
            intent.removeExtra(SakuHomeWidgetProvider.EXTRA_SAKU_ACTION)
            if (notifyFlutter) {
                mainHandler.post {
                    automationChannel?.invokeMethod("onLaunchAction", actionExtra)
                }
            }
        }

        if (intent.action == Intent.ACTION_SEND && intent.type?.startsWith("image/") == true) {
            val streamUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            if (streamUri != null) {
                val copiedPath = copySharedImageToCache(streamUri)
                if (copiedPath != null) {
                    pendingSharedImagePath = copiedPath
                    if (notifyFlutter) {
                        mainHandler.post {
                            automationChannel?.invokeMethod("onSharedImageReceived", copiedPath)
                        }
                    }
                }
            }
        }
    }

    private fun copySharedImageToCache(uri: Uri): String? {
        return try {
            val outDir = File(cacheDir, "shared_receipts").apply { mkdirs() }
            // Prune cached shared screenshots older than 24 hours.
            val cutoff = System.currentTimeMillis() - 86_400_000L
            outDir.listFiles()?.forEach { file ->
                if (file.isFile && file.lastModified() < cutoff) {
                    file.delete()
                }
            }
            val mime = contentResolver.getType(uri)?.lowercase().orEmpty()
            val ext = when {
                mime.contains("png") -> "png"
                mime.contains("webp") -> "webp"
                else -> "jpg"
            }
            val outFile = File(outDir, "receipt_${System.currentTimeMillis()}.$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            outFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val notifChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL
        )
        notificationChannel = notifChannel

        notifChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(
                        SakuNotificationListenerService.isPermissionGranted(applicationContext)
                    )
                }

                "openNotificationAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_SETTINGS_FAILED", e.message, null)
                    }
                }

                "openAppDetailsSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_APP_DETAILS_FAILED", e.message, null)
                    }
                }

                "updateConfig" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    SakuNotificationListenerService.updateConfig(
                        applicationContext,
                        enabled,
                        packages
                    )
                    result.success(true)
                }

                "drainPendingEvents" -> {
                    result.success(
                        SakuNotificationListenerService.drainPendingEvents(applicationContext)
                    )
                }

                "readRecentLogs" -> {
                    result.success(
                        SakuNotificationListenerService.readRecentLogs(applicationContext)
                    )
                }

                "clearRecentLogs" -> {
                    SakuNotificationListenerService.clearRecentLogs(applicationContext)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        val autoChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUTOMATION_CHANNEL
        )
        automationChannel = autoChannel

        autoChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingSharedImage" -> {
                    val path = pendingSharedImagePath
                    pendingSharedImagePath = null
                    result.success(path)
                }

                "consumePendingLaunchAction" -> {
                    val action = pendingLaunchAction
                    pendingLaunchAction = null
                    result.success(action)
                }

                "hasPostNotificationPermission" -> {
                    result.success(
                        SakuLocalNotificationHelper.hasNotificationPermission(applicationContext)
                    )
                }

                "requestPostNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        SakuLocalNotificationHelper.hasNotificationPermission(applicationContext)
                    ) {
                        result.success(true)
                    } else {
                        pendingNotifPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            REQ_POST_NOTIFICATIONS
                        )
                    }
                }

                "showLocalNotification" -> {
                    val id = call.argument<Int>("id") ?: 5001
                    val channel = call.argument<String>("channel")
                        ?: SakuLocalNotificationHelper.CHANNEL_BUDGET
                    val title = call.argument<String>("title").orEmpty()
                    val body = call.argument<String>("body").orEmpty()
                    val ok = SakuLocalNotificationHelper.showNotification(
                        context = applicationContext,
                        notificationId = id,
                        channelId = channel,
                        title = title,
                        body = body
                    )
                    result.success(ok)
                }

                "syncWidgetData" -> {
                    val safeDaily = call.argument<String>("safeDailyText") ?: "Rp 0 / hari"
                    val netWorth = call.argument<String>("netWorthText") ?: "Saldo Bersih: Rp 0"
                    val statusLabel = call.argument<String>("statusLabel") ?: "Aman"
                    SakuHomeWidgetProvider.saveAndRefresh(
                        context = applicationContext,
                        safeDailyText = safeDaily,
                        netWorthText = netWorth,
                        statusLabel = statusLabel
                    )
                    result.success(true)
                }

                "syncReminderSchedule" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val billsJson = call.argument<String>("billsJson") ?: "[]"
                    val weeklySummary = call.argument<String>("weeklySummary") ?: ""
                    SakuLocalNotificationHelper.syncReminderSchedule(
                        context = applicationContext,
                        enabled = enabled,
                        billsJson = billsJson,
                        weeklySummary = weeklySummary
                    )
                    result.success(true)
                }

                "saveFileToDownloads" -> {
                    val fileName = call.argument<String>("fileName").orEmpty()
                    val mimeType = call.argument<String>("mimeType")
                        ?: "application/octet-stream"
                    val bytes = call.argument<ByteArray>("bytes")
                    val prunePrefix = call.argument<String>("prunePrefix")
                    val maxRetained = call.argument<Int>("maxRetained") ?: 5
                    if (fileName.isEmpty() || bytes == null) {
                        result.success(null)
                    } else {
                        val savedPath = SakuDownloadStorageHelper.saveToDownloads(
                            context = applicationContext,
                            fileName = fileName,
                            mimeType = mimeType,
                            bytes = bytes,
                            prunePrefix = prunePrefix,
                            maxRetained = maxRetained
                        )
                        result.success(savedPath)
                    }
                }

                else -> result.notImplemented()
            }
        }

        SakuNotificationListenerService.onEventCaptured = {
            mainHandler.post {
                notificationChannel?.invokeMethod("onPendingEventsAvailable", null)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            val granted = SakuLocalNotificationHelper.hasNotificationPermission(applicationContext)
            pendingNotifPermissionResult?.success(granted)
            pendingNotifPermissionResult = null
        }
    }

    override fun onDestroy() {
        SakuNotificationListenerService.onEventCaptured = null
        notificationChannel?.setMethodCallHandler(null)
        notificationChannel = null
        automationChannel?.setMethodCallHandler(null)
        automationChannel = null
        super.onDestroy()
    }

    companion object {
        private const val NOTIFICATION_CHANNEL = "id.sakupro.saku_pro/notification_listener"
        private const val AUTOMATION_CHANNEL = "id.sakupro.saku_pro/automation"
        private const val REQ_POST_NOTIFICATIONS = 9031
    }
}
