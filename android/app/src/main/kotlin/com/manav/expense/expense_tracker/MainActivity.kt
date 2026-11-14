package com.manav.expense.expense_tracker

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.manav.expense/widget"
    private val PERMISSION_CHANNEL = "com.manav.expense/permissions"
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
        requestRequiredPermissionsIfNeeded()
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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        transactionChannel = null
    }
}
