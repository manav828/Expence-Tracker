package com.manav.expense.expense_tracker

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.manav.expense/widget"
    private val PERMISSION_CHANNEL = "com.manav.expense/permissions"
    private val PUSH_CHANNEL = "com.manav.expense/push_notifications"
    private val PUSH_CHANNEL_ID = "expencircle_push_reminders"
    private val SMS_PERMISSION_REQUEST_CODE = 2001

    companion object {
        private const val TX_CHANNEL = "com.manav.expense/transaction_detection"
        var transactionChannel: MethodChannel? = null

        fun notifyTransactionDetected(amount: Double, category: String, paymentMethod: String, comment: String, type: String = "expense") {
            val data = mapOf(
                "amount" to amount,
                "category" to category,
                "paymentMethod" to paymentMethod,
                "comment" to comment,
                "type" to type,
                "isExpense" to (type == "expense")
            )
            transactionChannel?.invokeMethod("onTransactionDetected", data)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Note: Do NOT request sensitive permissions (SMS/Notifications) on cold start.
        // Google Play Store policy requires in-app prominent disclosure before requesting SMS.
        // Permissions are requested on-demand through Flutter when the user enables SMS tracking.
    }

    private fun requestRequiredPermissionsIfNeeded() {
        val permissionsToRequest = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.RECEIVE_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.READ_SMS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsToRequest.toTypedArray(), SMS_PERMISSION_REQUEST_CODE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                ExpenseWidgetProvider.sendUpdateBroadcast(this)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> {
                    val hasReceive = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(hasReceive && hasRead)
                }
                "requestSmsPermission" -> {
                    requestRequiredPermissionsIfNeeded()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val txChan = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TX_CHANNEL)
        transactionChannel = txChan
        txChan.setMethodCallHandler { call, result ->
            result.notImplemented()
        }

        ensurePushNotificationChannel()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PUSH_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "showForegroundNotification") {
                val title = call.argument<String>("title") ?: "Payment Reminder"
                val body = call.argument<String>("body") ?: "You have a new payment reminder."
                showPushNotification(title, body)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun ensurePushNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                PUSH_CHANNEL_ID,
                "Settlement Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Payment and settlement reminders from split group members"
                enableVibration(true)
                enableLights(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.createNotificationChannel(channel)
        }
    }

    private fun showPushNotification(title: String, body: String) {
        ensurePushNotificationChannel()
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val notificationId = (System.currentTimeMillis() % 100000).toInt()
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = NotificationCompat.Builder(this, PUSH_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(notificationId, builder.build())
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        transactionChannel = null
    }
}
