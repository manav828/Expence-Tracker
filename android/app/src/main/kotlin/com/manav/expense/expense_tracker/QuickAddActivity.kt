package com.manav.expense.expense_tracker

import android.app.Activity
import android.app.AlertDialog
import android.app.DatePickerDialog
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class QuickAddActivity : Activity() {

    private lateinit var dbHelper: DatabaseHelper
    private val selectedCalendar = Calendar.getInstance()

    private val expenseCategories = mutableListOf<String>()
    private val incomeCategories = mutableListOf<String>()
    private val paymentMethods = mutableListOf<String>()

    private val currentCategories: MutableList<String>
        get() = if (selectedType == "income") incomeCategories else expenseCategories

    private var selectedCategory = "Food & Dining"
    private var selectedPaymentMethod = "UPI"
    private var selectedType = "expense"

    private val paymentViews = mutableListOf<TextView>()

    private lateinit var layoutCategorySelector: LinearLayout
    private lateinit var textSelectedCategory: TextView
    private lateinit var paymentContainer: LinearLayout
    private lateinit var btnTypeExpense: TextView
    private lateinit var btnTypeIncome: TextView
    private lateinit var textCurrencySymbol: TextView
    private lateinit var textTitle: TextView
    private lateinit var btnSave: Button

    // Auto-detection & Edit tracking fields
    private var expenseId: Long = -1L
    private var isEditMode = false
    private var isAutoDetected = false
    private var incomingAmount: Double = 0.0
    private var incomingCategory: String? = null
    private var incomingPaymentMethod: String? = null
    private var incomingComment: String? = null

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent != null) {
            setIntent(intent)
            recreate()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Wake screen and show over lock screen if phone is locked
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        // Window & Dialog Setup
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        setFinishOnTouchOutside(true)
        setContentView(R.layout.activity_quick_add)

        setupWindowDimensions()

        dbHelper = DatabaseHelper(this)

        // Parse incoming intent extras
        expenseId = intent.getLongExtra("EXTRA_EXPENSE_ID", -1L)
        isEditMode = intent.getBooleanExtra("EXTRA_IS_EDIT_MODE", false) && expenseId != -1L
        isAutoDetected = intent.getBooleanExtra("EXTRA_IS_AUTO_DETECTED", false)
        incomingAmount = intent.getDoubleExtra("EXTRA_AMOUNT", 0.0)
        incomingCategory = intent.getStringExtra("EXTRA_CATEGORY")
        incomingPaymentMethod = intent.getStringExtra("EXTRA_PAYMENT_METHOD")
        incomingComment = intent.getStringExtra("EXTRA_COMMENT")
        val incomingType = intent.getStringExtra("EXTRA_TYPE") ?: if (isEditMode) dbHelper.getExpenseType(expenseId) else "expense"
        selectedType = if (incomingType.equals("income", ignoreCase = true)) "income" else "expense"

        // Dismiss the alert notification since user opened the dialog
        dismissNotificationIfPresent()

        // Load categories and payment methods from DB
        expenseCategories.clear()
        expenseCategories.addAll(dbHelper.getCategories())

        incomeCategories.clear()
        incomeCategories.addAll(dbHelper.getIncomeCategories())

        if (!incomingCategory.isNullOrBlank()) {
            val trimmedCat = incomingCategory!!.trim()
            if (selectedType == "income") {
                if (!incomeCategories.any { it.equals(trimmedCat, ignoreCase = true) }) {
                    incomeCategories.add(trimmedCat)
                    dbHelper.addIncomeCategory(trimmedCat)
                }
                selectedCategory = incomeCategories.firstOrNull { it.equals(trimmedCat, ignoreCase = true) } ?: trimmedCat
            } else {
                if (!expenseCategories.any { it.equals(trimmedCat, ignoreCase = true) }) {
                    expenseCategories.add(trimmedCat)
                    dbHelper.addCategory(trimmedCat)
                }
                selectedCategory = expenseCategories.firstOrNull { it.equals(trimmedCat, ignoreCase = true) } ?: trimmedCat
            }
        } else {
            val activeCategories = currentCategories
            if (activeCategories.isNotEmpty()) {
                selectedCategory = activeCategories[0]
            }
        }

        paymentMethods.clear()
        paymentMethods.addAll(dbHelper.getPaymentMethods())
        if (paymentMethods.isNotEmpty()) {
            selectedPaymentMethod = incomingPaymentMethod?.takeIf { method ->
                paymentMethods.any { it.equals(method, ignoreCase = true) }
            }?.let { method ->
                paymentMethods.first { it.equals(method, ignoreCase = true) }
            } ?: paymentMethods[0]
        }

        textTitle = findViewById(R.id.textTitle)
        val editAmount = findViewById<EditText>(R.id.editAmount)
        val editComment = findViewById<EditText>(R.id.editComment)
        btnSave = findViewById(R.id.btnSave)
        val btnCancel = findViewById<Button>(R.id.btnCancel)
        val btnClose = findViewById<ImageButton>(R.id.btnClose)
        layoutCategorySelector = findViewById(R.id.layoutCategorySelector)
        textSelectedCategory = findViewById(R.id.textSelectedCategory)
        paymentContainer = findViewById(R.id.paymentMethodContainer)
        btnTypeExpense = findViewById(R.id.btnTypeExpense)
        btnTypeIncome = findViewById(R.id.btnTypeIncome)
        textCurrencySymbol = findViewById(R.id.textCurrencySymbol)

        // Type Toggle Listeners
        btnTypeExpense.setOnClickListener {
            if (selectedType != "expense") {
                selectedType = "expense"
                val match = expenseCategories.firstOrNull { it.equals(selectedCategory, ignoreCase = true) }
                selectedCategory = match ?: expenseCategories.firstOrNull() ?: "Food & Dining"
                updateCategoryDisplay()
                updateTypeUI()
            }
        }

        btnTypeIncome.setOnClickListener {
            if (selectedType != "income") {
                selectedType = "income"
                val match = incomeCategories.firstOrNull { it.equals(selectedCategory, ignoreCase = true) }
                selectedCategory = match ?: incomeCategories.firstOrNull() ?: "Salary"
                updateCategoryDisplay()
                updateTypeUI()
            }
        }

        // Configure UI according to mode and type
        updateTypeUI()

        if (isEditMode) {
            btnCancel.text = "DISCARD"
        } else {
            btnCancel.text = "CANCEL"
        }

        // Prefill amount and comments
        if (incomingAmount > 0) {
            val formattedAmount = if (incomingAmount % 1.0 == 0.0) {
                incomingAmount.toInt().toString()
            } else {
                String.format(Locale.US, "%.2f", incomingAmount)
            }
            editAmount.setText(formattedAmount)
        }
        if (!incomingComment.isNullOrEmpty()) {
            editComment.setText(incomingComment)
        }

        // Setup Category Dropdown Selector
        updateCategoryDisplay()
        layoutCategorySelector.setOnClickListener {
            showCategoryPickerDialog()
        }

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

        val rootContainer = findViewById<View>(R.id.rootContainer)
        val scrollView = findViewById<ScrollView>(R.id.quickAddScrollView)

        // Dismiss when tapping outside the dialog card
        rootContainer?.setOnClickListener {
            dismissNotificationIfPresent()
            finish()
        }
        scrollView?.setOnClickListener {
            // Absorb click inside the dialog card so it does not dismiss
        }

        // Close handlers
        btnClose.setOnClickListener {
            dismissNotificationIfPresent()
            finish()
        }

        // Auto-scroll when editComment is focused so it is never hidden behind the keyboard
        editComment.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                scrollView?.postDelayed({
                    scrollView.fullScroll(View.FOCUS_DOWN)
                }, 200)
            }
        }

        // Auto-scroll when editAmount is focused
        editAmount.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                scrollView?.postDelayed({
                    scrollView.smoothScrollTo(0, editAmount.top)
                }, 150)
            }
        }

        // Hide keyboard when user taps 'Done' on the soft keyboard
        editComment.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.hideSoftInputFromWindow(editComment.windowToken, 0)
                editComment.clearFocus()
                true
            } else {
                false
            }
        }

        // Cancel / Discard Handler
        btnCancel.setOnClickListener {
            dismissNotificationIfPresent()
            if (isEditMode) {
                // Discard deletes the auto-logged record
                val deleted = dbHelper.deleteExpense(expenseId)
                if (deleted > 0) {
                    ExpenseWidgetProvider.sendUpdateBroadcast(this)
                    Toast.makeText(this, "Transaction discarded & removed", Toast.LENGTH_SHORT).show()
                }
            } else {
                Toast.makeText(this, "Transaction discarded", Toast.LENGTH_SHORT).show()
            }
            finish()
        }

        // Focus keyboard if amount is empty
        if (incomingAmount <= 0) {
            editAmount.postDelayed({
                editAmount.requestFocus()
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.showSoftInput(editAmount, InputMethodManager.SHOW_IMPLICIT)
            }, 150)
        }

        // Save / Update Button Handler
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

            dismissNotificationIfPresent()

            if (isEditMode) {
                // Update the existing auto-logged entry with selectedType
                val rows = dbHelper.updateExpense(expenseId, amount, selectedCategory, selectedPaymentMethod, comment, expenseDate, selectedType)
                if (rows > 0) {
                    ExpenseWidgetProvider.sendUpdateBroadcast(this)
                    val actionWord = if (selectedType == "income") "income" else "spend"
                    Toast.makeText(this, "Updated $actionWord in $selectedCategory!", Toast.LENGTH_SHORT).show()
                    finish()
                } else {
                    Toast.makeText(this, "Error updating transaction", Toast.LENGTH_SHORT).show()
                }
            } else {
                // Insert brand new expense with selectedType
                val id = dbHelper.insertExpense(amount, selectedCategory, selectedPaymentMethod, comment, expenseDate, selectedType)
                if (id != -1L) {
                    ExpenseWidgetProvider.sendUpdateBroadcast(this)
                    val prefix = if (selectedType == "income") "+₹" else "₹"
                    Toast.makeText(this, "$prefix${String.format(Locale.US, "%.2f", amount)} Recorded in $selectedCategory!", Toast.LENGTH_SHORT).show()
                    finish()
                } else {
                    Toast.makeText(this, "Error saving transaction", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun updateTypeUI() {
        val isIncome = selectedType == "income"
        if (isIncome) {
            btnTypeIncome.setBackgroundResource(R.drawable.type_income_selected)
            btnTypeIncome.setTextColor(Color.WHITE)
            btnTypeExpense.setBackgroundColor(Color.TRANSPARENT)
            btnTypeExpense.setTextColor(Color.parseColor("#6D7A72"))

            textCurrencySymbol.text = "+₹ "
            textCurrencySymbol.setTextColor(Color.parseColor("#006948"))

            if (isEditMode) {
                textTitle.text = "Edit Logged Income"
                btnSave.text = "UPDATE INCOME"
            } else {
                textTitle.text = "Quick Add Income"
                btnSave.text = "SAVE INCOME"
            }
        } else {
            btnTypeExpense.setBackgroundResource(R.drawable.type_expense_selected)
            btnTypeExpense.setTextColor(Color.WHITE)
            btnTypeIncome.setBackgroundColor(Color.TRANSPARENT)
            btnTypeIncome.setTextColor(Color.parseColor("#6D7A72"))

            textCurrencySymbol.text = "₹ "
            textCurrencySymbol.setTextColor(Color.parseColor("#BA1A1A"))

            if (isEditMode) {
                textTitle.text = "Edit Logged Spend"
                btnSave.text = "UPDATE SPEND"
            } else {
                textTitle.text = "Quick Add Spend"
                btnSave.text = "SAVE SPEND"
            }
        }
    }

    private fun dismissNotificationIfPresent() {
        val notifId = intent.getIntExtra("EXTRA_NOTIFICATION_ID", -1)
        if (notifId != -1) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(notifId)
        }
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
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)

        // Make window match parent so window insets and keyboard adjustResize work properly
        window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        window.setGravity(Gravity.CENTER)

        // Constrain the dialog card to max 420dp width
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val maxPx = (420 * displayMetrics.density).toInt()
        val calculatedWidth = (screenWidth * 0.90).toInt()
        val targetWidth = calculatedWidth.coerceAtMost(maxPx)

        val scrollView = findViewById<ScrollView>(R.id.quickAddScrollView)
        scrollView?.layoutParams = (scrollView?.layoutParams as? FrameLayout.LayoutParams)?.apply {
            width = targetWidth
            gravity = Gravity.CENTER
        } ?: FrameLayout.LayoutParams(targetWidth, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER)
    }

    private fun updateCategoryDisplay() {
        textSelectedCategory.text = selectedCategory
    }

    private fun showCategoryPickerDialog() {
        val density = resources.displayMetrics.density
        val isIncome = selectedType == "income"
        val allItems = currentCategories.toList()
        val filteredItems = allItems.toMutableList()

        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val hPad = (16 * density).toInt()
            setPadding(hPad, (10 * density).toInt(), hPad, (4 * density).toInt())
        }

        val searchInput = EditText(this).apply {
            hint = "Search category..."
            textSize = 14f
            setTextColor(Color.parseColor("#131B2E"))
            setHintTextColor(Color.parseColor("#9AA49E"))
            setBackgroundResource(R.drawable.input_field_bg)
            val padH = (12 * density).toInt()
            val padV = (10 * density).toInt()
            setPadding(padH, padV, padH, padV)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = (8 * density).toInt()
            }
        }

        val listView = ListView(this).apply {
            dividerHeight = 1
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (280 * density).toInt()
            )
        }

        val adapter = object : ArrayAdapter<String>(
            this,
            android.R.layout.simple_list_item_1,
            filteredItems
        ) {
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val tv = super.getView(position, convertView, parent) as TextView
                val item = filteredItems[position]
                val isSelected = item.equals(selectedCategory, ignoreCase = true)
                tv.text = if (isSelected) "$item   ✓" else item
                tv.textSize = 14f
                tv.typeface = if (isSelected) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                tv.setTextColor(
                    if (isSelected) Color.parseColor("#006948") else Color.parseColor("#131B2E")
                )
                val vPad = (12 * density).toInt()
                tv.setPadding((8 * density).toInt(), vPad, (8 * density).toInt(), vPad)
                return tv
            }
        }
        listView.adapter = adapter

        searchInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                val query = s?.toString()?.trim()?.lowercase(Locale.getDefault()) ?: ""
                filteredItems.clear()
                if (query.isEmpty()) {
                    filteredItems.addAll(allItems)
                } else {
                    filteredItems.addAll(
                        allItems.filter { it.lowercase(Locale.getDefault()).contains(query) }
                    )
                }
                adapter.notifyDataSetChanged()
            }
        })

        rootLayout.addView(searchInput)
        rootLayout.addView(listView)

        val dialog = AlertDialog.Builder(this)
            .setTitle(if (isIncome) "Select Income Category" else "Select Expense Category")
            .setView(rootLayout)
            .setPositiveButton("+ Add New") { d, _ ->
                d.dismiss()
                showAddDialog(isCategory = true, container = null)
            }
            .setNegativeButton("Cancel") { d, _ ->
                d.dismiss()
            }
            .create()

        listView.setOnItemClickListener { _, _, position, _ ->
            selectedCategory = filteredItems[position]
            updateCategoryDisplay()
            dialog.dismiss()
        }

        dialog.show()
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
            val isSelected = chip.text.toString().equals(selectedPaymentMethod, ignoreCase = true)
            if (isSelected) {
                chip.setBackgroundResource(R.drawable.chip_selected)
                chip.setTextColor(Color.WHITE)
            } else {
                chip.setBackgroundResource(R.drawable.chip_unselected)
                chip.setTextColor(Color.parseColor("#3D4A42"))
            }
        }
    }

    private fun showAddDialog(isCategory: Boolean, container: LinearLayout? = null) {
        val isIncome = selectedType == "income"
        val title = if (isCategory) {
            if (isIncome) "Add Income Category" else "Add Expense Category"
        } else {
            "Add Payment Method"
        }
        val hint = if (isCategory) {
            if (isIncome) "e.g. Dividend, Bonus, Rental" else "e.g. Subscriptions, Fuel"
        } else {
            "e.g. NetBanking, Wallet"
        }

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
                        if (isIncome) {
                            dbHelper.addIncomeCategory(name)
                            if (incomeCategories.none { it.equals(name, ignoreCase = true) }) {
                                incomeCategories.add(name)
                            }
                        } else {
                            dbHelper.addCategory(name)
                            if (expenseCategories.none { it.equals(name, ignoreCase = true) }) {
                                expenseCategories.add(name)
                            }
                        }
                        selectedCategory = name
                        updateCategoryDisplay()
                    } else {
                        dbHelper.addPaymentMethod(name)
                        if (paymentMethods.none { it.equals(name, ignoreCase = true) }) {
                            paymentMethods.add(name)
                        }
                        selectedPaymentMethod = name
                        if (container != null) {
                            setupPaymentChips(container)
                        }
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
