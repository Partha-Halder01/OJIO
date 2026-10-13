package com.ojio.app.ojio_mobile

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var pushChannel: MethodChannel? = null
    private var dartReady = false
    private var pendingTap: Map<String, String>? = null
    private val notificationExtra = "ojio_notification_data"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingTap = readNotification(intent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ojio_activity", "OJIO activity", NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Messages, ad updates and confirmed payments"
            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pushChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ojio/push_notifications")
        pushChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialNotification" -> {
                    dartReady = true
                    result.success(pendingTap)
                    pendingTap = null
                }
                "clear" -> {
                    pendingTap = null
                    getSystemService(NotificationManager::class.java).cancelAll()
                    result.success(null)
                }
                "show" -> {
                    try {
                        result.success(showNotification(call.arguments as? Map<*, *> ?: emptyMap<String, Any>()))
                    } catch (_: SecurityException) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val data = readNotification(intent) ?: return
        if (dartReady) pushChannel?.invokeMethod("onNotificationTap", data)
        else pendingTap = data
    }

    private fun readNotification(intent: Intent?): Map<String, String>? {
        val raw = intent?.getStringExtra(notificationExtra) ?: return null
        intent.removeExtra(notificationExtra)
        return try {
            val json = JSONObject(raw)
            json.keys().asSequence().associateWith { json.optString(it) }
        } catch (_: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun notificationBuilder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, "ojio_activity")
        else Notification.Builder(this)

    @Suppress("DEPRECATION")
    private fun showNotification(arguments: Map<*, *>): Boolean {
        val manager = getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel("ojio_activity")?.importance == NotificationManager.IMPORTANCE_NONE) return false
        val title = arguments["title"]?.toString()?.take(200) ?: "OJIO"
        val body = arguments["body"]?.toString()?.take(2000) ?: "You have a new update."
        val data = (arguments["data"] as? Map<*, *>)?.entries
            ?.filter { it.key is String && it.value is String }
            ?.associate { it.key.toString() to it.value.toString() } ?: emptyMap()
        val id = (arguments["eventId"]?.toString() ?: System.nanoTime().toString()).hashCode()
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(notificationExtra, JSONObject(data).toString())
        }
        val tap = PendingIntent.getActivity(this, id, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val publicNotification = notificationBuilder()
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("OJIO")
            .setContentText("You have a new update.")
            .build()
        val notification = notificationBuilder()
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicNotification)
            .setPriority(Notification.PRIORITY_HIGH)
            .setDefaults(Notification.DEFAULT_ALL)
            .build()
        manager.notify("ojio_foreground", id, notification)
        return true
    }
}
