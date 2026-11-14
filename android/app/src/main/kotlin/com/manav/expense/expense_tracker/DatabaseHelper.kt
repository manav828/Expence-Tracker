package com.manav.expense.expense_tracker

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "expenses.db"
        private const val DATABASE_VERSION = 1
        private const val TABLE_EXPENSES = "expenses"
        private const val COLUMN_ID = "id"
        private const val COLUMN_AMOUNT = "amount"
        private const val COLUMN_CATEGORY = "category"
        private const val COLUMN_PAYMENT_METHOD = "payment_method"
        private const val COLUMN_COMMENT = "comment"
        private const val COLUMN_EXPENSE_DATE = "expense_date"
        private const val COLUMN_CREATED_AT = "created_at"
        private const val COLUMN_UPDATED_AT = "updated_at"
        private const val COLUMN_TYPE = "type"

        private const val TABLE_CATEGORIES = "categories"
        private const val TABLE_PAYMENT_METHODS = "payment_methods"
        private const val COLUMN_NAME = "name"

        val DEFAULT_CATEGORIES = listOf(
            "Food & Dining",
            "Shopping",
            "Transport",
            "Bills & Utilities",
            "Entertainment",
            "Health & Wellness",
            "Investment",
            "Salary",
            "General"
        )

        val DEFAULT_PAYMENT_METHODS = listOf(
            "UPI",
            "Card",
            "Cash",
            "Transfer"
        )
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTableQuery = ("CREATE TABLE $TABLE_EXPENSES ("
                + "$COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "$COLUMN_AMOUNT REAL NOT NULL, "
                + "$COLUMN_CATEGORY TEXT NOT NULL, "
                + "$COLUMN_PAYMENT_METHOD TEXT NOT NULL, "
                + "$COLUMN_COMMENT TEXT, "
                + "$COLUMN_EXPENSE_DATE INTEGER NOT NULL, "
                + "$COLUMN_CREATED_AT INTEGER NOT NULL, "
                + "$COLUMN_UPDATED_AT INTEGER NOT NULL, "
                + "$COLUMN_TYPE TEXT NOT NULL DEFAULT 'expense')")
        
        db.execSQL(createTableQuery)

        // Create indexes
        db.execSQL("CREATE INDEX idx_expense_date ON $TABLE_EXPENSES($COLUMN_EXPENSE_DATE)")
        db.execSQL("CREATE INDEX idx_category ON $TABLE_EXPENSES($COLUMN_CATEGORY)")
        db.execSQL("CREATE INDEX idx_payment_method ON $TABLE_EXPENSES($COLUMN_PAYMENT_METHOD)")
        db.execSQL("CREATE INDEX idx_expense_type ON $TABLE_EXPENSES($COLUMN_TYPE)")

        ensureMetaTables(db)
    }

    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        ensureMetaTables(db)
    }

    private fun ensureMetaTables(db: SQLiteDatabase) {
        try {
            db.execSQL("ALTER TABLE $TABLE_EXPENSES ADD COLUMN $COLUMN_TYPE TEXT NOT NULL DEFAULT 'expense'")
        } catch (_: Exception) {}

        db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE_CATEGORIES ($COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT, $COLUMN_NAME TEXT UNIQUE NOT NULL)")
        db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE_PAYMENT_METHODS ($COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT, $COLUMN_NAME TEXT UNIQUE NOT NULL)")

        // Seed default categories if empty
        val catCursor = db.rawQuery("SELECT COUNT(*) FROM $TABLE_CATEGORIES", null)
        var catCount = 0
        if (catCursor.moveToFirst()) {
            catCount = catCursor.getInt(0)
        }
        catCursor.close()

        if (catCount == 0) {
            for (cat in DEFAULT_CATEGORIES) {
                val cv = ContentValues().apply { put(COLUMN_NAME, cat) }
                db.insertWithOnConflict(TABLE_CATEGORIES, null, cv, SQLiteDatabase.CONFLICT_IGNORE)
            }
        }

        // Seed default payment methods if empty
        val pmCursor = db.rawQuery("SELECT COUNT(*) FROM $TABLE_PAYMENT_METHODS", null)
        var pmCount = 0
        if (pmCursor.moveToFirst()) {
            pmCount = pmCursor.getInt(0)
        }
        pmCursor.close()

        if (pmCount == 0) {
            for (pm in DEFAULT_PAYMENT_METHODS) {
                val cv = ContentValues().apply { put(COLUMN_NAME, pm) }
                db.insertWithOnConflict(TABLE_PAYMENT_METHODS, null, cv, SQLiteDatabase.CONFLICT_IGNORE)
            }
        }
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Upgrade logic if needed in the future
    }

    fun insertExpense(
        amount: Double,
        category: String,
        paymentMethod: String,
        comment: String?,
        expenseDate: Long = System.currentTimeMillis(),
        type: String = "expense"
    ): Long {
        val db = this.writableDatabase
        val values = ContentValues()
        val currentTime = System.currentTimeMillis()
        val normalizedType = if (type.equals("income", ignoreCase = true)) "income" else "expense"
        
        values.put(COLUMN_AMOUNT, amount)
        values.put(COLUMN_CATEGORY, category)
        values.put(COLUMN_PAYMENT_METHOD, paymentMethod)
        values.put(COLUMN_COMMENT, comment)
        values.put(COLUMN_EXPENSE_DATE, expenseDate)
        values.put(COLUMN_CREATED_AT, currentTime)
        values.put(COLUMN_UPDATED_AT, currentTime)
        values.put(COLUMN_TYPE, normalizedType)

        val id = db.insert(TABLE_EXPENSES, null, values)
        db.close()
        Log.d("DatabaseHelper", "Inserted expense: ID=$id, type=$normalizedType")
        return id
    }

    fun deleteExpense(id: Long): Int {
        val db = this.writableDatabase
        val count = db.delete(TABLE_EXPENSES, "$COLUMN_ID = ?", arrayOf(id.toString()))
        db.close()
        Log.d("DatabaseHelper", "Deleted expense: ID=$id, count=$count")
        return count
    }

    fun updateExpense(
        id: Long,
        amount: Double,
        category: String,
        paymentMethod: String,
        comment: String?,
        expenseDate: Long,
        type: String = "expense"
    ): Int {
        val db = this.writableDatabase
        val normalizedType = if (type.equals("income", ignoreCase = true)) "income" else "expense"
        val values = ContentValues().apply {
            put(COLUMN_AMOUNT, amount)
            put(COLUMN_CATEGORY, category)
            put(COLUMN_PAYMENT_METHOD, paymentMethod)
            put(COLUMN_COMMENT, comment)
            put(COLUMN_EXPENSE_DATE, expenseDate)
            put(COLUMN_UPDATED_AT, System.currentTimeMillis())
            put(COLUMN_TYPE, normalizedType)
        }
        val count = db.update(TABLE_EXPENSES, values, "$COLUMN_ID = ?", arrayOf(id.toString()))
        db.close()
        Log.d("DatabaseHelper", "Updated expense: ID=$id, count=$count, type=$normalizedType")
        return count
    }

    fun getExpenseType(id: Long): String {
        val db = this.readableDatabase
        var type = "expense"
        try {
            val cursor = db.query(TABLE_EXPENSES, arrayOf(COLUMN_TYPE), "$COLUMN_ID = ?", arrayOf(id.toString()), null, null, null)
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(COLUMN_TYPE)
                if (idx != -1 && !cursor.isNull(idx)) {
                    type = cursor.getString(idx)
                }
            }
            cursor.close()
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error getting expense type for $id: ${e.message}")
        } finally {
            db.close()
        }
        return type
    }

    fun getCategories(): List<String> {
        val list = mutableListOf<String>()
        val db = this.readableDatabase
        val cursor = db.query(TABLE_CATEGORIES, arrayOf(COLUMN_NAME), null, null, null, null, "$COLUMN_ID ASC")
        while (cursor.moveToNext()) {
            list.add(cursor.getString(0))
        }
        cursor.close()
        db.close()
        val result = if (list.isEmpty()) DEFAULT_CATEGORIES.toMutableList() else list
        if (!result.contains("Salary")) {
            result.add("Salary")
        }
        return result
    }

    fun addCategory(name: String): Long {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return -1
        val db = this.writableDatabase
        val values = ContentValues().apply { put(COLUMN_NAME, trimmed) }
        val id = db.insertWithOnConflict(TABLE_CATEGORIES, null, values, SQLiteDatabase.CONFLICT_IGNORE)
        db.close()
        return id
    }

    fun getPaymentMethods(): List<String> {
        val list = mutableListOf<String>()
        val db = this.readableDatabase
        val cursor = db.query(TABLE_PAYMENT_METHODS, arrayOf(COLUMN_NAME), null, null, null, null, "$COLUMN_ID ASC")
        while (cursor.moveToNext()) {
            list.add(cursor.getString(0))
        }
        cursor.close()
        db.close()
        return if (list.isEmpty()) DEFAULT_PAYMENT_METHODS else list
    }

    fun addPaymentMethod(name: String): Long {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return -1
        val db = this.writableDatabase
        val values = ContentValues().apply { put(COLUMN_NAME, trimmed) }
        val id = db.insertWithOnConflict(TABLE_PAYMENT_METHODS, null, values, SQLiteDatabase.CONFLICT_IGNORE)
        db.close()
        return id
    }

    fun updateCategory(oldName: String, newName: String): Int {
        val trimmed = newName.trim()
        if (trimmed.isEmpty() || trimmed == oldName) return 0
        val db = this.writableDatabase
        val values = ContentValues().apply { put(COLUMN_NAME, trimmed) }
        val count = db.update(TABLE_CATEGORIES, values, "$COLUMN_NAME = ?", arrayOf(oldName))
        val expValues = ContentValues().apply { put(COLUMN_CATEGORY, trimmed) }
        db.update(TABLE_EXPENSES, expValues, "$COLUMN_CATEGORY = ?", arrayOf(oldName))
        db.close()
        return count
    }

    fun updatePaymentMethod(oldName: String, newName: String): Int {
        val trimmed = newName.trim()
        if (trimmed.isEmpty() || trimmed == oldName) return 0
        val db = this.writableDatabase
        val values = ContentValues().apply { put(COLUMN_NAME, trimmed) }
        val count = db.update(TABLE_PAYMENT_METHODS, values, "$COLUMN_NAME = ?", arrayOf(oldName))
        val expValues = ContentValues().apply { put(COLUMN_PAYMENT_METHOD, trimmed) }
        db.update(TABLE_EXPENSES, expValues, "$COLUMN_PAYMENT_METHOD = ?", arrayOf(oldName))
        db.close()
        return count
    }

    data class RecentExpenseItem(
        val id: Long,
        val category: String,
        val amount: Double,
        val paymentMethod: String,
        val expenseDate: Long
    )

    fun getTodayTotal(): Double {
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val startOfDay = calendar.timeInMillis
        calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
        val endOfDay = calendar.timeInMillis

        val db = this.readableDatabase
        val cursor = db.rawQuery(
            "SELECT SUM($COLUMN_AMOUNT) FROM $TABLE_EXPENSES WHERE $COLUMN_EXPENSE_DATE >= ? AND $COLUMN_EXPENSE_DATE < ? AND ($COLUMN_TYPE IS NULL OR $COLUMN_TYPE != 'income')",
            arrayOf(startOfDay.toString(), endOfDay.toString())
        )
        var total = 0.0
        if (cursor.moveToFirst()) {
            total = cursor.getDouble(0)
        }
        cursor.close()
        db.close()
        return total
    }

    fun getMonthTotal(): Double {
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.DAY_OF_MONTH, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val startOfMonth = calendar.timeInMillis
        calendar.add(java.util.Calendar.MONTH, 1)
        val endOfMonth = calendar.timeInMillis

        val db = this.readableDatabase
        val cursor = db.rawQuery(
            "SELECT SUM($COLUMN_AMOUNT) FROM $TABLE_EXPENSES WHERE $COLUMN_EXPENSE_DATE >= ? AND $COLUMN_EXPENSE_DATE < ? AND ($COLUMN_TYPE IS NULL OR $COLUMN_TYPE != 'income')",
            arrayOf(startOfMonth.toString(), endOfMonth.toString())
        )
        var total = 0.0
        if (cursor.moveToFirst()) {
            total = cursor.getDouble(0)
        }
        cursor.close()
        db.close()
        return total
    }

    fun getRecentExpenses(limit: Int = 3): List<RecentExpenseItem> {
        val list = mutableListOf<RecentExpenseItem>()
        val db = this.readableDatabase
        val cursor = db.query(
            TABLE_EXPENSES,
            arrayOf(COLUMN_ID, COLUMN_CATEGORY, COLUMN_AMOUNT, COLUMN_PAYMENT_METHOD, COLUMN_EXPENSE_DATE),
            null,
            null,
            null,
            null,
            "$COLUMN_EXPENSE_DATE DESC",
            limit.toString()
        )
        while (cursor.moveToNext()) {
            list.add(
                RecentExpenseItem(
                    id = cursor.getLong(0),
                    category = cursor.getString(1),
                    amount = cursor.getDouble(2),
                    paymentMethod = cursor.getString(3),
                    expenseDate = cursor.getLong(4)
                )
            )
        }
        cursor.close()
        db.close()
        return list
    }
}

