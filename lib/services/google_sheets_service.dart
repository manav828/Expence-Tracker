import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';

class GoogleSheetsService {
  static final GoogleSheetsService instance = GoogleSheetsService._init();
  GoogleSheetsService._init();

  static const String defaultWebhookUrl =
      'https://script.google.com/macros/s/AKfycbwWTl79yP8fyCtgNitvnjAaRDK-wyf3vwfNiHaGkz1ghdXSl8GeauZjqwXy3foPgLI1/exec';

  static const String _prefKeyUrl = 'google_sheets_webhook_url';
  static const String _prefKeyAutoSync = 'google_sheets_auto_sync';
  static const String _prefKeyLastSync = 'google_sheets_last_sync_time';

  Future<String> getWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUrl) ?? defaultWebhookUrl;
  }

  Future<void> setWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUrl, url.trim());
  }

  Future<void> resetToDefaultUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUrl, defaultWebhookUrl);
  }

  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyAutoSync) ?? true;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoSync, enabled);
  }

  Future<int?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyLastSync);
  }

  Future<void> setLastSyncTime(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLastSync, timestamp);
  }

  /// Map an Expense to JSON payload for Google Apps Script
  Map<String, dynamic> _expenseToPayload(Expense expense) {
    final dt = expense.dateTime;
    return {
      'date': DateFormat('yyyy-MM-dd').format(dt),
      'time': DateFormat('hh:mm a').format(dt),
      'category': expense.category,
      'amount': expense.amount,
      'paymentMethod': expense.paymentMethod,
      'comment': expense.comment ?? '',
      'timestamp': expense.expenseDate,
      'id': expense.id ?? 0,
    };
  }

  /// Sends a single expense to the Google Sheet
  Future<bool> sendExpense(Expense expense) async {
    try {
      final url = await getWebhookUrl();
      if (url.trim().isEmpty) return false;

      final payload = _expenseToPayload(expense);

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // Google Apps Script usually returns 200 or 302 redirect
      if (response.statusCode >= 200 && response.statusCode < 400) {
        // Check for Google permission error page in response body
        if (response.body.contains('You need access') || response.body.contains('accounts.google.com')) {
          debugPrint('GoogleSheetsService: 403 Permission error (access not set to Anyone)');
          return false;
        }
        await setLastSyncTime(DateTime.now().millisecondsSinceEpoch);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('GoogleSheetsService error sending expense: $e');
      return false;
    }
  }

  /// Automatically syncs if auto-sync is enabled in settings
  Future<void> syncExpenseIfEnabled(Expense expense) async {
    final autoSync = await isAutoSyncEnabled();
    if (autoSync) {
      sendExpense(expense);
    }
  }

  /// Batch syncs all expenses to the Google Sheet
  Future<Map<String, dynamic>> syncAllExpenses(List<Expense> expenses) async {
    if (expenses.isEmpty) {
      return {'success': true, 'count': 0, 'message': 'No expenses to sync.'};
    }

    try {
      final url = await getWebhookUrl();
      if (url.trim().isEmpty) {
        return {'success': false, 'count': 0, 'message': 'Google Sheets Webhook URL is not configured.'};
      }

      final batch = expenses.map(_expenseToPayload).toList();
      final payload = {'batch': batch};

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 400) {
        if (response.body.contains('You need access') || response.body.contains('accounts.google.com')) {
          return {
            'success': false,
            'count': 0,
            'message': 'Permission Denied: In Apps Script Deploy settings, change "Who has access" to "Anyone".',
          };
        }

        await setLastSyncTime(DateTime.now().millisecondsSinceEpoch);
        return {
          'success': true,
          'count': expenses.length,
          'message': 'Successfully synced ${expenses.length} expenses to Google Sheets!',
        };
      } else {
        return {
          'success': false,
          'count': 0,
          'message': 'Server responded with status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'count': 0,
        'message': 'Network error while syncing: $e',
      };
    }
  }

  /// Tests the connection to the Google Apps Script Webhook
  Future<Map<String, dynamic>> testConnection([String? customUrl]) async {
    try {
      final targetUrl = customUrl?.trim().isNotEmpty == true ? customUrl!.trim() : await getWebhookUrl();
      if (targetUrl.isEmpty) {
        return {'success': false, 'message': 'Webhook URL cannot be empty.'};
      }

      final testPayload = {
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'time': DateFormat('hh:mm a').format(DateTime.now()),
        'category': 'Test Connection',
        'amount': 0.0,
        'paymentMethod': 'System Ping',
        'comment': 'Connection verification test from ExpenCircle',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http.post(
        Uri.parse(targetUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(testPayload),
      );

      if (response.statusCode >= 200 && response.statusCode < 400) {
        if (response.body.contains('You need access') || response.body.contains('accounts.google.com')) {
          return {
            'success': false,
            'message': 'Permission Denied: In Google Apps Script -> Deploy -> Manage deployments -> Change "Who has access" to "Anyone".',
          };
        }
        return {'success': true, 'message': 'Connected! Test ping recorded in your Google Sheet.'};
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': '403 Forbidden: In Google Apps Script Deploy settings, set "Who has access" to "Anyone".',
        };
      } else {
        return {
          'success': false,
          'message': 'Server returned HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// The standard script users can copy and paste into Google Apps Script
  static const String recommendedAppsScript = '''
function doPost(e) {
  try {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
    var data = JSON.parse(e.postData.contents);
    
    // Support single item or batch sync
    var items = data.batch ? data.batch : [data];
    
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      sheet.appendRow([
        item.date || new Date().toLocaleDateString(),
        item.time || new Date().toLocaleTimeString(),
        item.category,
        item.amount,
        item.paymentMethod,
        item.comment || "",
        new Date().toLocaleString()
      ]);
    }
    
    return ContentService.createTextOutput(JSON.stringify({ status: "success", count: items.length }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({ status: "error", message: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
''';
}
