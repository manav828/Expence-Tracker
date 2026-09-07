package com.manav.expense.expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.util.Locale

class ExpenseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, ExpenseWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (id in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_expense)
        val dbHelper = DatabaseHelper(context)

        try {
            val todayTotal = dbHelper.getTodayTotal()
            val monthTotal = dbHelper.getMonthTotal()
            val recentList = dbHelper.getRecentExpenses(2)

            val todayStr = String.format(Locale.getDefault(), "₹%.2f", todayTotal)
            val monthStr = String.format(Locale.getDefault(), "₹%.2f", monthTotal)

            views.setTextViewText(R.id.tv_widget_today, todayStr)
            views.setTextViewText(R.id.tv_widget_month, monthStr)

            if (recentList.isNotEmpty()) {
                views.setViewVisibility(R.id.tv_widget_empty, View.GONE)

                // Item 1
                val item1 = recentList[0]
                views.setViewVisibility(R.id.row_recent_1, View.VISIBLE)
                views.setTextViewText(R.id.tv_cat_1, item1.category)
                views.setTextViewText(
                    R.id.tv_amount_1,
                    String.format(Locale.getDefault(), "-₹%.2f", item1.amount)
                )

                // Item 2
                if (recentList.size > 1) {
                    val item2 = recentList[1]
                    views.setViewVisibility(R.id.row_recent_2, View.VISIBLE)
                    views.setTextViewText(R.id.tv_cat_2, item2.category)
                    views.setTextViewText(
                        R.id.tv_amount_2,
                        String.format(Locale.getDefault(), "-₹%.2f", item2.amount)
                    )
                } else {
                    views.setViewVisibility(R.id.row_recent_2, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.row_recent_1, View.GONE)
                views.setViewVisibility(R.id.row_recent_2, View.GONE)
                views.setViewVisibility(R.id.tv_widget_empty, View.VISIBLE)
            }
        } catch (e: Exception) {
            views.setTextViewText(R.id.tv_widget_today, "₹0.00")
            views.setTextViewText(R.id.tv_widget_month, "₹0.00")
            views.setViewVisibility(R.id.tv_widget_empty, View.VISIBLE)
        }

        // Set pending intent for Quick Add "+" button
        val quickAddIntent = Intent(context, QuickAddActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingQuickAdd = PendingIntent.getActivity(
            context,
            0,
            quickAddIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_widget_quick_add, pendingQuickAdd)

        // Set pending intent for Widget Body -> Open Main App
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingMain = PendingIntent.getActivity(
            context,
            1,
            mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingMain)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        fun sendUpdateBroadcast(context: Context) {
            try {
                val intent = Intent(context, ExpenseWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val componentName = ComponentName(context, ExpenseWidgetProvider::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                }
                context.sendBroadcast(intent)
            } catch (e: Exception) {
                // Ignore if widget is not placed
            }
        }
    }
}
