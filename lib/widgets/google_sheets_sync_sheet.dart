import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../services/google_sheets_service.dart';

class GoogleSheetsSyncSheet extends StatefulWidget {
  const GoogleSheetsSyncSheet({super.key});

  @override
  State<GoogleSheetsSyncSheet> createState() => _GoogleSheetsSyncSheetState();
}

class _GoogleSheetsSyncSheetState extends State<GoogleSheetsSyncSheet> {
  final _urlController = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isSyncing = false;
  bool _autoSync = true;
  String? _testStatusMessage;
  bool? _testSuccess;
  bool _isGuideExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final url = await GoogleSheetsService.instance.getWebhookUrl();
    final autoSync = await GoogleSheetsService.instance.isAutoSyncEnabled();
    if (mounted) {
      setState(() {
        _urlController.text = url;
        _autoSync = autoSync;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    await GoogleSheetsService.instance.setWebhookUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sheets Webhook URL saved!'),
          backgroundColor: Color(0xFF006948),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    await GoogleSheetsService.instance.resetToDefaultUrl();
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset to default Webhook URL'),
          backgroundColor: Color(0xFF131B2E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testStatusMessage = 'Please enter a valid Google Apps Script Webhook URL.';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testStatusMessage = null;
      _testSuccess = null;
    });

    final res = await GoogleSheetsService.instance.testConnection(url);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = res['success'] == true;
        _testStatusMessage = res['message'] as String;
      });
    }
  }

  Future<void> _syncAllExpenses() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    if (provider.expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No expenses recorded in ledger to sync.'),
          backgroundColor: Color(0xFF6D7A72),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    final res = await provider.syncAllToGoogleSheets();

    if (mounted) {
      setState(() => _isSyncing = false);
      final isSuccess = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String),
          backgroundColor: isSuccess ? const Color(0xFF006948) : const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _copyScriptToClipboard() {
    Clipboard.setData(const ClipboardData(text: GoogleSheetsService.recommendedAppsScript));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Apps Script code copied to clipboard!'),
        backgroundColor: Color(0xFF006948),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF006948))),
      );
    }

    final provider = Provider.of<ExpenseProvider>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_chart, color: Color(0xFF0F9D58), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Google Sheets Sync',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                      ),
                      Text(
                        'Real-time cloud backup to your spreadsheet',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF3D4A42)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: [
                // Webhook URL Section Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x0F000000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'WEBHOOK URL (APPS SCRIPT)',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6D7A72), letterSpacing: 0.8),
                          ),
                          TextButton(
                            onPressed: _resetToDefault,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Reset', style: TextStyle(fontSize: 11, color: Color(0xFF006948), fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF131B2E)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'https://script.google.com/macros/s/.../exec',
                          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9AA49E)),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x1F000000)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x1F000000)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF006948), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveUrl,
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Save URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006948),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isTesting ? null : _testConnection,
                              icon: _isTesting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF006948)),
                                    )
                                  : const Icon(Icons.cable, size: 16, color: Color(0xFF006948)),
                              label: Text(
                                _isTesting ? 'Testing...' : 'Test Ping',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF006948)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF006948)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Test result feedback banner
                      if (_testStatusMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _testSuccess == true
                                ? const Color(0xFF85F8C4).withValues(alpha: 0.25)
                                : const Color(0xFFFFDAD6).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _testSuccess == true ? const Color(0xFF006948) : const Color(0xFFBA1A1A),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _testSuccess == true ? Icons.check_circle : Icons.error_outline,
                                size: 18,
                                color: _testSuccess == true ? const Color(0xFF006948) : const Color(0xFFBA1A1A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _testStatusMessage!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _testSuccess == true ? const Color(0xFF00402C) : const Color(0xFF93000A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Auto-Sync Toggle Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x0F000000)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006948).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sync, color: Color(0xFF006948), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Auto-Sync on New Spend',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF131B2E)),
                              ),
                              Text(
                                'Instantly send new expenses to Google Sheet',
                                style: TextStyle(fontSize: 10, color: Color(0xFF6D7A72)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _autoSync,
                        activeColor: const Color(0xFF006948),
                        onChanged: (val) async {
                          setState(() => _autoSync = val);
                          await GoogleSheetsService.instance.setAutoSyncEnabled(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Batch Sync All Past Expenses Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncAllExpenses,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
                    label: Text(
                      _isSyncing
                          ? 'Syncing ${provider.expenses.length} Records...'
                          : 'Sync All ${provider.expenses.length} Past Expenses Now',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF131B2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Step-by-Step Setup Guide (Interactive Accordion)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1F4B41E1)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.help_outline, color: Color(0xFF4B41E1), size: 20),
                        title: const Text(
                          'How to connect your own Google Sheet (Setup Guide)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF131B2E)),
                        ),
                        trailing: Icon(
                          _isGuideExpanded ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF4B41E1),
                        ),
                        onTap: () {
                          setState(() => _isGuideExpanded = !_isGuideExpanded);
                        },
                      ),
                      if (_isGuideExpanded) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGuideStep(
                                step: '1',
                                title: 'Create Google Sheet',
                                description: 'Go to sheets.new and add column headers in Row 1: Date, Time, Category, Amount, Payment Method, Note, Timestamp.',
                              ),
                              const SizedBox(height: 10),
                              _buildGuideStep(
                                step: '2',
                                title: 'Open Apps Script',
                                description: 'Click "Extensions" in top menu, then choose "Apps Script".',
                              ),
                              const SizedBox(height: 10),
                              _buildGuideStep(
                                step: '3',
                                title: 'Paste Script Code',
                                description: 'Replace the default code with our sync script (tap below to copy):',
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton.icon(
                                onPressed: _copyScriptToClipboard,
                                icon: const Icon(Icons.copy, size: 14, color: Colors.white),
                                label: const Text('Copy Apps Script Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4B41E1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildGuideStep(
                                step: '4',
                                title: 'Deploy Web App (Important!)',
                                description: 'Click "Deploy" > "New deployment" > Select type "Web app".\n• Execute as: Me\n• Who has access: Anyone (Important: select Anyone so the app can post data).\nClick Deploy and copy the Web App URL.',
                              ),
                              const SizedBox(height: 10),
                              _buildGuideStep(
                                step: '5',
                                title: 'Paste & Test',
                                description: 'Paste the copied URL in the field above and tap "Test Ping". You are ready!',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({required String step, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF4B41E1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF131B2E)),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: Color(0xFF3D4A42), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
