package com.manav.expense.expense_tracker

import android.app.Activity
import android.app.AlertDialog
import android.app.DatePickerDialog
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class QuickAddActivity : Activity() {

    private lateinit var dbHelper: DatabaseHelper
    private val selectedCalendar = Calendar.getInstance()

    private val categories = mutableListOf<String>()
    private val paymentMethods = mutableListOf<String>()

    private var selectedCategory = "Food & Dining"
    private var selectedPaymentMethod = "UPI"

    private val categoryViews = mutableListOf<TextView>()
    private val paymentViews = mutableListOf<TextView>()

    private lateinit var categoryContainer: LinearLayout
    private lateinit var paymentContainer: LinearLayout

    // Auto-detection tracking fields
    private var isAutoDetected = false
    private var incomingAmount: Double = 0.0
    private var incomingCategory: String? = null
    private var incomingPaymentMethod: String? = null
    private var incomingComment: String? = null
    private var isSavedByUser = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Window & Dialog Setup
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        setFinishOnTouchOutside(true)
        setContentView(R.layout.activity_quick_add)

        setupWindowDimensions()

        dbHelper = DatabaseHelper(this)

        // Parse incoming intent extras for auto-detected transactions
        isAutoDetected = intent.getBooleanExtra("EXTRA_IS_AUTO_DETECTED", false)
        incomingAmount = intent.getDoubleExtra("EXTRA_AMOUNT", 0.0)
        incomingCategory = intent.getStringExtra("EXTRA_CATEGORY")
        incomingPaymentMethod = intent.getStringExtra("EXTRA_PAYMENT_METHOD")
        incomingComment = intent.getStringExtra("EXTRA_COMMENT")

        // Load categories and payment methods from DB
        categories.clear()
        categories.addAll(dbHelper.getCategories())
        if (categories.isNotEmpty()) {
            selectedCategory = incomingCategory?.takeIf { categories.contains(it) } ?: categories[0]
        }

        paymentMethods.clear()
        paymentMethods.addAll(dbHelper.getPaymentMethods())
        if (paymentMethods.isNotEmpty()) {
            selectedPaymentMethod = incomingPaymentMethod?.takeIf { paymentMethods.contains(it) } ?: paymentMethods[0]
        }

        val editAmount = findViewById<EditText>(R.id.editAmount)
        val editComment = findViewById<EditText>(R.id.editComment)
        val btnSave = findViewById<Button>(R.id.btnSave)
        val btnCancel = findViewById<Button>(R.id.btnCancel)
        val btnClose = findViewById<ImageButton>(R.id.btnClose)
        val layoutAutoDetectNotice = findViewById<LinearLayout>(R.id.layoutAutoDetectNotice)
        categoryContainer = findViewById(R.id.categoryChipsContainer)
        paymentContainer = findViewById(R.id.paymentMethodContainer)

        // Show auto-detect notice & prefill data if triggered automatically
        if (isAutoDetected && incomingAmount > 0) {
            layoutAutoDetectNotice?.visibility = View.VISIBLE
            val formattedAmount = if (incomingAmount % 1.0 == 0.0) {
                incomingAmount.toInt().toString()
            } else {
                String.format(Locale.US, "%.2f", incomingAmount)
            }
            editAmount.setText(formattedAmount)
            if (!incomingComment.isNullOrEmpty()) {
                editComment.setText(incomingComment)
            }
        }

        // Setup Category Chips
        setupCategoryChips(categoryContainer)

        // Setup Payment Method Chips
        setupPaymentChips(paymentContainer)

        // Setup Date Selector
        val layoutDateSelector = findViewById<LinearLayout>(R.id.layoutDateSelector)
        val textSelectedDate = findViewById<TextView>(R.id.textSelectedDate)
        updateDateDisplay(textSelectedDate)

        layoutDateSelector.setOnClickListener {
            DatePickerDialog(
                this,
                { _, year, month, dayOfMonth ->
                    selectedCalendar.set(Calendar.YEAR, year)
                    selectedCalendar.set(Calendar.MONTH, month)
                    selectedCalendar.set(Calendar.DAY_OF_MONTH, dayOfMonth)
                    updateDateDisplay(textSelectedDate)
                },
                selectedCalendar.get(Calendar.YEAR),
                selectedCalendar.get(Calendar.MONTH),
                selectedCalendar.get(Calendar.DAY_OF_MONTH)
            ).show()
        }

        // Close handlers - closing triggers fallback auto-save if auto-detected
        btnClose.setOnClickListener { finish() }
        btnCancel.setOnClickListener { finish() }

        // Keyboard Auto-Show for Amount if not auto-filled
        if (!isAutoDetected) {
            editAmount.postDelayed({
                editAmount.requestFocus()
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.showSoftInput(editAmount, InputMethodManager.SHOW_IMPLICIT)
            }, 150)
        }

        // Save Button Handler
        btnSave.setOnClickListener {
            val amountText = editAmount.text.toString().trim()
            if (amountText.isEmpty()) {
                Toast.makeText(this, "Please enter an amount", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val amount = amountText.toDoubleOrNull()
            if (amount == null || amount <= 0) {
                Toast.makeText(this, "Please enter a valid amount", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val comment = editComment.text.toString().trim().ifEmpty { null }
            val expenseDate = selectedCalendar.timeInMillis

            isSavedByUser = true // Prevent fallback auto-save

            val id = dbHelper.insertExpense(amount, selectedCategory, selectedPaymentMethod, comment, expenseDate)
            if (id != -1L) {
                ExpenseWidgetProvider.sendUpdateBroadcast(this)
                Toast.makeText(this, "₹${String.format(Locale.US, "%.2f", amount)} Recorded in $selectedCategory!", Toast.LENGTH_SHORT).show()
                finish()
            } else {
                Toast.makeText(this, "Error saving expense", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun fallbackAutoSaveIfNeeded() {
        if (isAutoDetected && !isSavedByUser && incomingAmount > 0) {
            isSavedByUser = true // Prevent duplicate saves

            val fallbackCategory = incomingCategory ?: if (categories.isNotEmpty()) categories[0] else "Uncategorized"
            val fallbackMethod = incomingPaymentMethod ?: if (paymentMethods.isNotEmpty()) paymentMethods[0] else "UPI"
            val fallbackComment = incomingComment ?: "Auto-logged from SMS"

            val id = dbHelper.insertExpense(incomingAmount, fallbackCategory, fallbackMethod, fallbackComment, System.currentTimeMillis())
            if (id != -1L) {
                ExpenseWidgetProvider.sendUpdateBroadcast(this)
                Toast.makeText(
                    applicationContext,
                    "Auto-logged: ₹${String.format(Locale.US, "%.2f", incomingAmount)} in $fallbackCategory",
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }

    override fun finish() {
        fallbackAutoSaveIfNeeded()
        super.finish()
    }

    override fun onDestroy() {
        fallbackAutoSaveIfNeeded()
        super.onDestroy()
    }

    private fun updateDateDisplay(textDate: TextView) {
        val now = Calendar.getInstance()
        if (selectedCalendar.get(Calendar.YEAR) == now.get(Calendar.YEAR) &&
            selectedCalendar.get(Calendar.DAY_OF_YEAR) == now.get(Calendar.DAY_OF_YEAR)) {
            textDate.text = "Today, " + SimpleDateFormat("d MMM yyyy", Locale.getDefault()).format(selectedCalendar.time)
        } else {
            textDate.text = SimpleDateFormat("EEE, d MMM yyyy", Locale.getDefault()).format(selectedCalendar.time)
        }
    }

    private fun setupWindowDimensions() {
        val window = window ?: return
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(0.55f)

        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val maxPx = (420 * displayMetrics.density).toInt()
        val calculatedWidth = (screenWidth * 0.90).toInt()
        val targetWidth = calculatedWidth.coerceAtMost(maxPx)

        window.setLayout(targetWidth, ViewGroup.LayoutParams.WRAP_CONTENT)
        window.setGravity(Gravity.CENTER)
    }

    private fun setupCategoryChips(container: LinearLayout) {
        container.removeAllViews()
        categoryViews.clear()

        val density = resources.displayMetrics.density

        for (cat in categories) {
            val chip = TextView(this).apply {
                text = cat
                textSize = 12f
                typeface = Typeface.DEFAULT_BOLD
                setPadding((14 * density).toInt(), (8 * density).toInt(), (14 * density).toInt(), (8 * density).toInt())
                gravity = Gravity.CENTER

                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(0, 0, (8 * density).toInt(), 0)
                }
                layoutParams = params

                setOnClickListener {
                    selectedCategory = cat
                    updateCategorySelection()
                }
            }
            categoryViews.add(chip)
            container.addView(chip)
        }

        // Dedicated + Add Chip
        val addChip = TextView(this).apply {
            text = "+ Add"
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
            setPadding((14 * density).toInt(), (8 * density).toInt(), (14 * density).toInt(), (8 * density).toInt())
            gravity = Gravity.CENTER
            setBackgroundResource(R.drawable.chip_unselected)
            setTextColor(Color.parseColor("#006948"))

            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            layoutParams = params

            setOnClickListener {
                showAddDialog(isCategory = true, container = container)
            }
        }
        container.addView(addChip)

        updateCategorySelection()
    }

    private fun updateCategorySelection() {
        for (chip in categoryViews) {
            val isSelected = chip.text.toString() == selectedCategory
            if (isSelected) {
                chip.setBackgroundResource(R.drawable.chip_selected)
                chip.setTextColor(Color.WHITE)
            } else {
                chip.setBackgroundResource(R.drawable.chip_unselected)
                chip.setTextColor(Color.parseColor("#3D4A42"))
            }
        }
    }

    private fun setupPaymentChips(container: LinearLayout) {
        container.removeAllViews()
        paymentViews.clear()

        val density = resources.displayMetrics.density

        for (method in paymentMethods) {
            val chip = TextView(this).apply {
                text = method
                textSize = 12f
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                setPadding((14 * density).toInt(), (8 * density).toInt(), (14 * density).toInt(), (8 * density).toInt())

                val params = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(0, 0, (8 * density).toInt(), 0)
                }
                layoutParams = params

                setOnClickListener {
                    selectedPaymentMethod = method
                    updatePaymentSelection()
                }
            }
            paymentViews.add(chip)
            container.addView(chip)
        }

        // Dedicated + Add Chip for Payment Method
        val addChip = TextView(this).apply {
            text = "+ Add"
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
            setPadding((14 * density).toInt(), (8 * density).toInt(), (14 * density).toInt(), (8 * density).toInt())
            gravity = Gravity.CENTER
            setBackgroundResource(R.drawable.chip_unselected)
            setTextColor(Color.parseColor("#006948"))

            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            layoutParams = params

            setOnClickListener {
                showAddDialog(isCategory = false, container = container)
            }
        }
        container.addView(addChip)

        updatePaymentSelection()
    }

    private fun updatePaymentSelection() {
        for (chip in paymentViews) {
            val isSelected = chip.text.toString() == selectedPaymentMethod
            if (isSelected) {
                chip.setBackgroundResource(R.drawable.chip_selected)
                chip.setTextColor(Color.WHITE)
            } else {
                chip.setBackgroundResource(R.drawable.chip_unselected)
                chip.setTextColor(Color.parseColor("#3D4A42"))
            }
        }
    }

    private fun showAddDialog(isCategory: Boolean, container: LinearLayout) {
        val title = if (isCategory) "Add New Category" else "Add Payment Method"
        val hint = if (isCategory) "e.g. Subscriptions, Fuel" else "e.g. NetBanking, Wallet"

        val input = EditText(this).apply {
            setHint(hint)
            textSize = 15f
            setTextColor(Color.parseColor("#131B2E"))
            setHintTextColor(Color.parseColor("#9AA49E"))
            setBackgroundResource(R.drawable.input_field_bg)
            val density = resources.displayMetrics.density
            val pad = (14 * density).toInt()
            setPadding(pad, pad, pad, pad)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val density = resources.displayMetrics.density
            val margin = (20 * density).toInt()
            setPadding(margin, (12 * density).toInt(), margin, 0)
            addView(input)
        }

        val dialog = AlertDialog.Builder(this)
            .setTitle(title)
            .setView(layout)
            .setPositiveButton("Add") { d, _ ->
                val name = input.text.toString().trim()
                if (name.isNotEmpty()) {
                    if (isCategory) {
                        dbHelper.addCategory(name)
                        if (!categories.contains(name)) categories.add(name)
                        selectedCategory = name
                        setupCategoryChips(container)
                    } else {
                        dbHelper.addPaymentMethod(name)
                        if (!paymentMethods.contains(name)) paymentMethods.add(name)
                        selectedPaymentMethod = name
                        setupPaymentChips(container)
                    }
                }
                d.dismiss()
            }
            .setNegativeButton("Cancel") { d, _ ->
                d.dismiss()
            }
            .create()

        dialog.show()

        input.postDelayed({
            input.requestFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
        }, 150)
    }
}
