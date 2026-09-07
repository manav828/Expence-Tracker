import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/sms_parser.dart';
import '../services/transaction_detection_service.dart';

class SmsTesterSheet extends StatefulWidget {
  const SmsTesterSheet({super.key});

  @override
  State<SmsTesterSheet> createState() => _SmsTesterSheetState();
}

class _SmsTesterSheetState extends State<SmsTesterSheet> {
  final _smsController = TextEditingController();
  ParsedSmsResult? _parsedResult;

  final Map<String, String> _sampleSms = {
    'HDFC Card ₹20': '''Txn Rs.20.00
On HDFC Bank Card 6706
At paytm-7289005034@ptys 
by UPI 125529188357
On 30-06''',
    'HDFC UPI ₹80': '''Sent Rs.80.00
From HDFC Bank A/C *8401
To dilipbhai ghughrwala
On 11/07/26
Ref 126100685141''',
    'SBI Debit ₹1000': '''Dear UPI user A/C X1412 debited by 1000.00 on date 30Mar26 trf to MUTUAL FUNDS ICC Refno 645596222024''',
    'HDFC Credit ₹600': '''Credit Alert!
Rs.600.00 credited to HDFC Bank A/c XX8401 on 05-09-26 from VPA mistryshreya99@oksbi (UPI 624864884939)''',
    'HDFC Salary ₹30,185': '''Update! INR 30,185.00 deposited in HDFC Bank A/c XX8401 on 07-SEP-26 for A2AINT01 - ONPRINTSHOP SOFTWARE PRIVATE LIMITED - Salary - SALARY AUG 2026.Avl bal INR 30,810.89. Cheque deposits in A/C are subject to clearing''',
    'SBI Credit ₹12000': '''Dear SBI User, your A/c X1412-credited by Rs.12000 on 08Mar26 transfer from SATASIYA MANAV SURESHBHAI Ref No 119687655301 -SBI''',
  };

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  void _parseCurrentText() {
    final res = SmsParser.parse(_smsController.text);
    setState(() {
      _parsedResult = res;
    });
  }

  void _openDetectedTransactionPopup() {
    if (_parsedResult == null) return;
    final result = _parsedResult!;
    Navigator.of(context).pop();

    TransactionDetectionService.showDetectedTransactionPopup(
      context,
      amount: result.amount,
      category: result.category,
      paymentMethod: result.paymentMethod,
      comment: 'SMS from ${result.bank}: ${result.payee}',
    );
  }

  void _saveParsedExpense() {
    if (_parsedResult == null) return;

    final now = DateTime.now();
    final expense = Expense(
      amount: _parsedResult!.amount,
      category: _parsedResult!.category,
      paymentMethod: _parsedResult!.paymentMethod,
      comment: 'Auto-detected from ${_parsedResult!.bank} SMS: ${_parsedResult!.payee}',
      expenseDate: now.millisecondsSinceEpoch,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    Provider.of<ExpenseProvider>(context, listen: false).addExpense(expense);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-Added ₹${_parsedResult!.amount.toStringAsFixed(2)} (${_parsedResult!.category}) via Bank SMS'),
        backgroundColor: const Color(0xFF006948),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006948).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sms_outlined, color: Color(0xFF006948)),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank SMS Auto-Parser',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Simulate real-time HDFC & SBI text interception',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a sample transaction pattern or paste custom SMS:',
              style: TextStyle(color: Color(0xFF3D4A42), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sampleSms.entries.map((e) {
                return ActionChip(
                  label: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: const Color(0xFFF2F3FF),
                  side: const BorderSide(color: Color(0x1A006948), width: 1),
                  labelStyle: const TextStyle(color: Color(0xFF131B2E)),
                  onPressed: () {
                    _smsController.text = e.value;
                    _parseCurrentText();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _smsController,
              maxLines: 3,
              onChanged: (_) => _parseCurrentText(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF131B2E)),
              decoration: InputDecoration(
                hintText: 'Paste incoming bank transaction SMS here...',
                hintStyle: const TextStyle(color: Color(0xFF6D7A72)),
                filled: true,
                fillColor: const Color(0xFFF2F3FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_parsedResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _parsedResult!.isExpense ? const Color(0xFF006948) : const Color(0xFF4B41E1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _parsedResult!.isExpense ? 'VERIFIED OUTFLOW' : 'VERIFIED INFLOW',
                          style: TextStyle(
                            color: _parsedResult!.isExpense ? const Color(0xFF006948) : const Color(0xFF4B41E1),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '₹${_parsedResult!.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _parsedResult!.isExpense ? const Color(0xFF006948) : const Color(0xFF4B41E1),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0x1A000000), height: 20),
                    Row(
                      children: [
                        _buildInfoBadge('Bank', _parsedResult!.bank),
                        const SizedBox(width: 8),
                        _buildInfoBadge('Method', _parsedResult!.paymentMethod),
                        const SizedBox(width: 8),
                        _buildInfoBadge('Category', _parsedResult!.category),
                      ],
                    ),
                    if (_parsedResult!.payee.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Payee/Ref: ${_parsedResult!.payee}',
                        style: const TextStyle(color: Color(0xFF3D4A42), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _openDetectedTransactionPopup,
                  icon: const Icon(Icons.flash_on, color: Colors.white, size: 18),
                  label: const Text(
                    'Open Auto-Fill Popup & Select Category',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006948),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0x40006948),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: _saveParsedExpense,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF006948),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Quick Auto-Save with Default Category',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else if (_smsController.text.isNotEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Could not detect amount or bank pattern from text.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14000000), width: 1),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
      ),
    );
  }
}
