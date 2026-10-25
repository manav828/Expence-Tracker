package com.manav.expense.expense_tracker

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast

class NotificationDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notifId = intent.getIntExtra("EXTRA_NOTIFICATION_ID", -1)
        if (notifId != -1) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(notifId)
        }

        val expenseId = intent.getLongExtra("EXTRA_EXPENSE_ID", -1L)
        if (expenseId != -1L) {
            val dbHelper = DatabaseHelper(context)
            val deletedCount = dbHelper.deleteExpense(expenseId)
            if (deletedCount > 0) {
                ExpenseWidgetProvider.sendUpdateBroadcast(context)
                Log.d("NotificationDismiss", "Auto-logged expense $expenseId deleted upon Discard.")
                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(context.applicationContext, "Transaction discarded & removed", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
}
