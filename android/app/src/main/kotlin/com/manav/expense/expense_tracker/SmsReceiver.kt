package com.manav.expense.expense_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "expencircle_tx_detection"
        const val CHANNEL_NAME = "Transaction Detection"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val messageBody = sms.displayMessageBody ?: continue
                val sender = sms.displayOriginatingAddress ?: ""
                Log.d("SmsReceiver", "SMS received from $sender: $messageBody")
                
                parseAndProcessTransaction(context, messageBody, sender)
            }
        }
    }

    private fun parseAndProcessTransaction(context: Context, messageBody: String, sender: String) {
        val lowerMsg = messageBody.lowercase()

        // 0. Exclude OTP / 2FA messages (Issue #12)
        val otpKeywords = listOf("otp", "verification code", "security code", "auth code", "secret code", "do not share", "never share", "valid for", "is your code")
        if (otpKeywords.any { lowerMsg.contains(it) }) {
            Log.d("SmsReceiver", "Ignored OTP SMS: $messageBody")
            return
        }

        // 0.1 Exclude Promotional / Marketing messages (Issue #13)
        val promoKeywords = listOf("flat rs", "flat inr", "cashback", "off on", "discount", "coupon", "pre-approved", "loan", "win cash", "hurry", "apply now", "promocode")
        if (promoKeywords.any { lowerMsg.contains(it) }) {
            Log.d("SmsReceiver", "Ignored Promo SMS: $messageBody")
            return
        }

        var amount: Double? = null

        // 1. Extract amount using priority regex avoiding balance collision (Issue #11)
        val verbAmountPattern = Pattern.compile(
            "(?:debited|credited|spent|paid|withdrawn|deposited|sent|received|txn\\s*rs|charged)\\s*(?:by|with|for|in|of|to)?\\s*(?:Rs\\.?|INR)?\\s*([0-9,]+(?:\\.[0-9]{1,2})?)",
            Pattern.CASE_INSENSITIVE
        )
        val vMatcher = verbAmountPattern.matcher(messageBody)
        if (vMatcher.find()) {
            amount = vMatcher.group(1)?.replace(",", "")?.toDoubleOrNull()
        }

        if (amount == null) {
            val amountPattern = Pattern.compile(
                "(?:Rs\\.?|INR)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)",
                Pattern.CASE_INSENSITIVE
            )
            val matcher = amountPattern.matcher(messageBody)
            while (matcher.find()) {
                val start = matcher.start()
                val prefix = messageBody.substring(if (start > 20) start - 20 else 0, start).lowercase()
                if (!prefix.contains("bal") && !prefix.contains("avl") && !prefix.contains("available") && !prefix.contains("limit")) {
                    amount = matcher.group(1)?.replace(",", "")?.toDoubleOrNull()
                    if (amount != null && amount > 0) break
                }
            }
        }

        if (amount == null || amount <= 0) return

        // 2. Determine transaction type (Credit/Income vs Debit/Expense)
        val hasDebitVerbs = lowerMsg.contains("debited") || lowerMsg.contains("sent rs") || 
                            lowerMsg.contains("sent inr") || lowerMsg.contains("txn rs") || 
                            lowerMsg.contains("spent") || lowerMsg.contains("paid") || 
                            lowerMsg.contains("withdrawn") || lowerMsg.contains("charged") ||
                            lowerMsg.contains("purchase of")

        val hasCreditVerbs = lowerMsg.contains("credited") || lowerMsg.contains("deposited") || 
                             lowerMsg.contains("received") || lowerMsg.contains("cashback") || 
                             lowerMsg.contains("refund") || lowerMsg.contains("salary") || 
                             lowerMsg.contains("reversal") || lowerMsg.contains("added to")

        val isCredit: Boolean
        val isDebit: Boolean

        if (hasDebitVerbs && hasCreditVerbs) {
            // Disambiguate when both appear (e.g. "debited from a/c ... credited towards card bill")
            if (lowerMsg.contains("debited from") || lowerMsg.contains("debited for") || lowerMsg.contains("debited by")) {
                isDebit = true
                isCredit = false
            } else if (lowerMsg.contains("credited to") || lowerMsg.contains("credited with") || lowerMsg.contains("credited by")) {
                isCredit = true
                isDebit = false
            } else {
                isDebit = true
                isCredit = false
            }
        } else if (hasCreditVerbs) {
            isCredit = true
            isDebit = false
        } else if (hasDebitVerbs) {
            isDebit = true
            isCredit = false
        } else {
            val isBankTxn = lowerMsg.contains("a/c") || lowerMsg.contains("bank") || 
                            lowerMsg.contains("inr") || lowerMsg.contains("avl bal")
            if (!isBankTxn) return

            // Fallback for bank transactions lacking direct keywords
            if (lowerMsg.contains("cr") || lowerMsg.contains("deposit")) {
                isCredit = true
                isDebit = false
            } else {
                isDebit = true
                isCredit = false
            }
        }

        val txType = if (isCredit) "income" else "expense"

        // 3. Smart payment method detection
        var paymentMethod = "UPI"
        if (lowerMsg.contains("credit card") || lowerMsg.contains("card") || lowerMsg.contains("cc ")) {
            paymentMethod = "Card"
        } else if (lowerMsg.contains("debit card") || lowerMsg.contains("dc ")) {
            paymentMethod = "Card"
        } else if (lowerMsg.contains("netbanking") || lowerMsg.contains("a/c") || lowerMsg.contains("deposited") || lowerMsg.contains("transfer") || lowerMsg.contains("trf")) {
            paymentMethod = "Transfer"
        } else if (lowerMsg.contains("cash")) {
            paymentMethod = "Cash"
        }

        // 4. Smart merchant / comment extraction
        var comment = if (isCredit) "Income / Deposit" else "Bank SMS from $sender"
        if (lowerMsg.contains("salary")) {
            val salaryPattern = Pattern.compile("(?:for|from)\\s+([A-Za-z0-9@\\.\\-_\\s&]+?)(?:\\s*-\\s*Salary|\\s*\\.|\\s+on|\\s+ref|\\s+avl|$)", Pattern.CASE_INSENSITIVE)
            val sMatcher = salaryPattern.matcher(messageBody)
            if (sMatcher.find()) {
                var comp = sMatcher.group(1)?.replace(Regex("^[A-Z0-9]+ - "), "")?.trim() ?: ""
                if (comp.isNotEmpty()) {
                    if (comp.length > 35) comp = comp.substring(0, 35).trim()
                    comment = "$comp - Salary"
                } else {
                    comment = "Salary Deposit"
                }
            } else {
                comment = "Salary Deposit"
            }
        } else if (lowerMsg.contains("refund")) {
            comment = "Refund Received"
        } else if (lowerMsg.contains("cashback")) {
            comment = "Cashback Received"
        } else {
            val merchantPattern = Pattern.compile("(?:at|to|for|from|info)\\s+([A-Za-z0-9@\\.\\-_\\s&]{3,35})(?:\\s+on|\\s+ref|\\s+by|\\s+avl|\\.|$)", Pattern.CASE_INSENSITIVE)
            val mMatcher = merchantPattern.matcher(messageBody)
            if (mMatcher.find()) {
                val mName = mMatcher.group(1)?.trim()
                if (!mName.isNullOrEmpty()) {
                    comment = mName
                }
            }
        }

        // 5. Smart initial category guess
        var suggestedCategory = if (isCredit) "Salary" else "General"
        if (lowerMsg.contains("salary") || lowerMsg.contains("payroll") || lowerMsg.contains("stipend")) {
            suggestedCategory = "Salary"
        } else if (isCredit && (lowerMsg.contains("refund") || lowerMsg.contains("cashback") || lowerMsg.contains("reversal"))) {
            suggestedCategory = "General"
        } else if (lowerMsg.contains("swiggy") || lowerMsg.contains("zomato") || lowerMsg.contains("restaurant") || lowerMsg.contains("food") || lowerMsg.contains("cafe")) {
            suggestedCategory = "Food & Dining"
        } else if (lowerMsg.contains("amazon") || lowerMsg.contains("flipkart") || lowerMsg.contains("myntra") || lowerMsg.contains("shopping") || lowerMsg.contains("mart")) {
            suggestedCategory = "Shopping"
        } else if (lowerMsg.contains("uber") || lowerMsg.contains("ola") || lowerMsg.contains("fuel") || lowerMsg.contains("petrol")) {
            suggestedCategory = "Transport"
        } else if (lowerMsg.contains("hospital") || lowerMsg.contains("pharmacy") || lowerMsg.contains("med")) {
            suggestedCategory = "Health & Wellness"
        } else if (lowerMsg.contains("mutual fund") || lowerMsg.contains("zerodha") || lowerMsg.contains("groww") || lowerMsg.contains("invest") || lowerMsg.contains("dividend")) {
            suggestedCategory = "Investment"
        } else if (lowerMsg.contains("bill") || lowerMsg.contains("recharge") || lowerMsg.contains("electricity")) {
            suggestedCategory = "Bills & Utilities"
        }

        // 6. IMMEDIATELY auto-log into Database with proper transaction type
        val dbHelper = DatabaseHelper(context)
        val expenseId = dbHelper.insertExpense(amount, suggestedCategory, paymentMethod, comment, System.currentTimeMillis(), txType)
        if (expenseId != -1L) {
            ExpenseWidgetProvider.sendUpdateBroadcast(context)
            Log.d("SmsReceiver", "Auto-logged transaction with ID: $expenseId, type: $txType")
        }

        val notificationId = (System.currentTimeMillis() % 100000).toInt()

        // 7. Intent to EDIT the auto-logged expense
        val editIntent = Intent(context, QuickAddActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("EXTRA_EXPENSE_ID", expenseId)
            putExtra("EXTRA_AMOUNT", amount)
            putExtra("EXTRA_PAYMENT_METHOD", paymentMethod)
            putExtra("EXTRA_COMMENT", comment)
            putExtra("EXTRA_CATEGORY", suggestedCategory)
            putExtra("EXTRA_IS_AUTO_DETECTED", true)
            putExtra("EXTRA_IS_EDIT_MODE", true)
            putExtra("EXTRA_NOTIFICATION_ID", notificationId)
            putExtra("EXTRA_TYPE", txType)
        }

        val editPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            editIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 8. Intent to DISCARD (Delete) the auto-logged expense
        val discardIntent = Intent(context, NotificationDismissReceiver::class.java).apply {
            putExtra("EXTRA_EXPENSE_ID", expenseId)
            putExtra("EXTRA_NOTIFICATION_ID", notificationId)
        }
        val discardPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 1,
            discardIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 9. Create Notification Channel
        createNotificationChannel(context)

        // 10. Show Notification with Edit & Discard actions
        val formattedAmount = if (amount % 1.0 == 0.0) amount.toInt().toString() else String.format(Locale.US, "%.2f", amount)
        val notifTitle = if (isCredit) "₹$formattedAmount Credited via $paymentMethod" else "₹$formattedAmount Spent via $paymentMethod"
        val bigText = if (isCredit) {
            "Credited ₹$formattedAmount in $suggestedCategory for $comment ($paymentMethod).\nTap to edit details, or tap Discard to delete."
        } else {
            "Logged ₹$formattedAmount in $suggestedCategory for $comment ($paymentMethod).\nTap to edit details, or tap Discard to delete."
        }

        val notifBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(notifTitle)
            .setContentText("$comment · $suggestedCategory ($paymentMethod)")
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(editPendingIntent)
            .setAutoCancel(true)
            .addAction(android.R.drawable.ic_menu_edit, "Edit", editPendingIntent)
            .addAction(android.R.drawable.ic_menu_delete, "Discard", discardPendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        notificationManager?.notify(notificationId, notifBuilder.build())

        // Notify running Flutter app if in foreground
        MainActivity.notifyTransactionDetected(amount, suggestedCategory, paymentMethod, comment, txType)
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when a new bank or UPI transaction SMS is detected and logged"
                enableVibration(true)
                enableLights(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.createNotificationChannel(channel)
        }
    }
}
