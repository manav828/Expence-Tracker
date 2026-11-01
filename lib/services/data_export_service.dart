import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import 'export_helper.dart' as exporter;

class DataExportService {
  static final DataExportService instance = DataExportService._init();
  DataExportService._init();

  /// Converts the list of expenses into a formatted CSV string
  String generateCsv(List<Expense> expenses) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('ID,Type,Date,Time,Category,Amount (INR),Payment Method,Note / Payee,Created Timestamp');

    for (final e in expenses) {
      final dt = e.dateTime;
      final dateStr = DateFormat('yyyy-MM-dd').format(dt);
      final timeStr = DateFormat('hh:mm a').format(dt);

      final typeStr = e.isExpense ? 'Expense' : 'Income';
      final formattedAmount = '${e.isExpense ? '-' : '+'}${e.amount.toStringAsFixed(2)}';
      final escapedCategory = _escapeCsv(e.category);
      final escapedMethod = _escapeCsv(e.paymentMethod);
      final escapedComment = _escapeCsv(e.comment ?? '');

      buffer.writeln('${e.id ?? ""},$typeStr,$dateStr,$timeStr,$escapedCategory,$formattedAmount,$escapedMethod,$escapedComment,${e.createdAt}');
    }

    return buffer.toString();
  }

  /// Converts the list of expenses into a formatted JSON string
  String generateJson(List<Expense> expenses) {
    final list = expenses.map((e) {
      final dt = e.dateTime;
      return {
        'id': e.id,
        'type': e.isExpense ? 'expense' : 'income',
        'isExpense': e.isExpense,
        'amount': e.amount,
        'category': e.category,
        'paymentMethod': e.paymentMethod,
        'comment': e.comment,
        'date': DateFormat('yyyy-MM-dd').format(dt),
        'time': DateFormat('hh:mm a').format(dt),
        'expenseDateTimestamp': e.expenseDate,
        'createdAtTimestamp': e.createdAt,
        'updatedAtTimestamp': e.updatedAt,
      };
    }).toList();

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(list);
  }

  /// Copies text to clipboard
  Future<void> copyToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
  }

  /// Exports CSV file (triggers download on Web, shares/saves on Android)
  Future<void> exportCsvFile(List<Expense> expenses) async {
    final csvContent = generateCsv(expenses);
    final dateTag = DateFormat('yyyyMMdd').format(DateTime.now());
    final filename = 'expencircle_spend_export_$dateTag.csv';

    await exporter.saveOrShareFile(
      filename: filename,
      content: csvContent,
      mimeType: 'text/csv',
    );
  }

  /// Exports JSON file (triggers download on Web, shares/saves on Android)
  Future<void> exportJsonFile(List<Expense> expenses) async {
    final jsonContent = generateJson(expenses);
    final dateTag = DateFormat('yyyyMMdd').format(DateTime.now());
    final filename = 'expencircle_spend_backup_$dateTag.json';

    await exporter.saveOrShareFile(
      filename: filename,
      content: jsonContent,
      mimeType: 'application/json',
    );
  }

  String _escapeCsv(String raw) {
    var val = raw;
    final trimmed = val.trimLeft();
    // Prevent CSV Formula Injection (OWASP CWE-1236)
    if (trimmed.startsWith('=') ||
        trimmed.startsWith('+') ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('@') ||
        trimmed.startsWith('\t') ||
        trimmed.startsWith('\r')) {
      val = "'$val";
    }

    if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains("'")) {
      final replaced = val.replaceAll('"', '""');
      return '"$replaced"';
    }
    return val;
  }
}
