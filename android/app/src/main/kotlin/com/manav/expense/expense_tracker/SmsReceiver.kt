package com.manav.expense.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val messageBody = sms.displayMessageBody
                val sender = sms.displayOriginatingAddress ?: ""
                Log.d("SmsReceiver", "SMS received from $sender: $messageBody")
                
                parseAndTriggerPopup(context, messageBody, sender)
            }
        }
    }

    private fun parseAndTriggerPopup(context: Context, messageBody: String, sender: String) {
        var amount: Double? = null
        val lowerMsg = messageBody.lowercase()

        // 1. Extract amount using regex
        // Patterns to match: "INR 30,185.00", "Txn Rs.20.00", "Rs.600.00", "Sent Rs.80.00", "Rs.12000", "debited by 1000.00", "deposited in HDFC"
        val amountPattern = Pattern.compile(
            "(?:Rs\\.?|INR)\\s*([0-9,]+\\.?[0-9]*)|(?:debited|credited|deposited)\\s*(?:by|in|to)?\\s*(?:Rs\\.?|INR)?\\s*([0-9,]+\\.?[0-9]*)|spent Rs\\.?\\s*([0-9,]+\\.?[0-9]*)",
            Pattern.CASE_INSENSITIVE
        )
        val matcher = amountPattern.matcher(messageBody)
        if (matcher.find()) {
            val amountStr = matcher.group(1) ?: matcher.group(2) ?: matcher.group(3)
            amount = amountStr?.replace(",", "")?.toDoubleOrNull()
        }

        if (amount == null || amount <= 0) return

        // 2. Determine transaction type
        val isDebit = lowerMsg.contains("debited") || lowerMsg.contains("sent rs") || 
                      lowerMsg.contains("txn rs") || lowerMsg.contains("spent") || 
                      lowerMsg.contains("paid") || lowerMsg.contains("withdrawn")
        val isCredit = lowerMsg.contains("deposited") || lowerMsg.contains("credited") || 
                       lowerMsg.contains("received") || lowerMsg.contains("salary") || 
                       lowerMsg.contains("deposit") || lowerMsg.contains("added")
        val isBankTxn = lowerMsg.contains("a/c") || lowerMsg.contains("bank") || 
                        lowerMsg.contains("inr") || lowerMsg.contains("avl bal")

        // Must be a recognized transaction or bank financial alert
        if (!isDebit && !isCredit && !isBankTxn) return

        // 3. Smart payment method detection (UPI, Card, Transfer, Cash)
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
        } else if (lowerMsg.contains("swiggy") || lowerMsg.contains("zomato") || lowerMsg.contains("restaurant") || lowerMsg.contains("food") || lowerMsg.contains("cafe")) {
            suggestedCategory = "Food & Dining"
        } else if (lowerMsg.contains("amazon") || lowerMsg.contains("flipkart") || lowerMsg.contains("myntra") || lowerMsg.contains("shopping") || lowerMsg.contains("mart")) {
            suggestedCategory = "Shopping"
        } else if (lowerMsg.contains("uber") || lowerMsg.contains("ola") || lowerMsg.contains("fuel") || lowerMsg.contains("petrol")) {
            suggestedCategory = "Transport"
        } else if (lowerMsg.contains("hospital") || lowerMsg.contains("pharmacy") || lowerMsg.contains("med")) {
            suggestedCategory = "Health & Wellness"
        } else if (lowerMsg.contains("mutual fund") || lowerMsg.contains("zerodha") || lowerMsg.contains("groww") || lowerMsg.contains("invest")) {
            suggestedCategory = "Investment"
        } else if (lowerMsg.contains("bill") || lowerMsg.contains("recharge") || lowerMsg.contains("electricity")) {
            suggestedCategory = "Bills & Utilities"
        }

        // Open the QuickAddActivity popup with pre-filled details!
        // If the user closes or dismisses it, QuickAddActivity's fallbackAutoSaveIfNeeded() will automatically log it with defaults!
        try {
            val popupIntent = Intent(context, QuickAddActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                putExtra("EXTRA_AMOUNT", amount)
                putExtra("EXTRA_PAYMENT_METHOD", paymentMethod)
                putExtra("EXTRA_COMMENT", comment)
                putExtra("EXTRA_CATEGORY", suggestedCategory)
                putExtra("EXTRA_IS_AUTO_DETECTED", true)
            }
            context.startActivity(popupIntent)
            Log.d("SmsReceiver", "Opened QuickAddActivity popup for transaction of ₹$amount")
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Failed to launch QuickAdd popup, saving default directly: ${e.message}")
            val dbHelper = DatabaseHelper(context)
            dbHelper.insertExpense(amount, suggestedCategory, paymentMethod, comment)
            ExpenseWidgetProvider.sendUpdateBroadcast(context)
        }
    }
}
