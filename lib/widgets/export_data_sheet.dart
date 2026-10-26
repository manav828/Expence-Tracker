import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../services/data_export_service.dart';

class ExportDataSheet extends StatefulWidget {
  const ExportDataSheet({super.key});

  @override
  State<ExportDataSheet> createState() => _ExportDataSheetState();
}

class _ExportDataSheetState extends State<ExportDataSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    if (provider.expenses.isEmpty) {
      _showEmptyNotice();
      return;
    }

    setState(() => _isExporting = true);
    try {
      await DataExportService.instance.exportCsvFile(provider.expenses);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV Export ready! File downloaded / shared.'),
            backgroundColor: Color(0xFF006948),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: const Color(0xFFBA1A1A)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportJson() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    if (provider.expenses.isEmpty) {
      _showEmptyNotice();
      return;
    }

    setState(() => _isExporting = true);
    try {
      await DataExportService.instance.exportJsonFile(provider.expenses);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('JSON Backup ready! File downloaded / shared.'),
            backgroundColor: Color(0xFF006948),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: const Color(0xFFBA1A1A)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _copyCsv() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    if (provider.expenses.isEmpty) {
      _showEmptyNotice();
      return;
    }
    final csv = DataExportService.instance.generateCsv(provider.expenses);
    await DataExportService.instance.copyToClipboard(csv);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV data copied to clipboard! You can paste it directly into Excel or Google Sheets.'),
          backgroundColor: Color(0xFF006948),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyJson() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    if (provider.expenses.isEmpty) {
      _showEmptyNotice();
      return;
    }
    final json = DataExportService.instance.generateJson(provider.expenses);
    await DataExportService.instance.copyToClipboard(json);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON raw backup copied to clipboard!'),
          backgroundColor: Color(0xFF006948),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEmptyNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No expense records in ledger to export.'),
        backgroundColor: Color(0xFF6D7A72),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final count = provider.expenses.length;
    final total = provider.totalExpenses;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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

          // Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF006948).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: Color(0xFF006948), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Export Ledger Data',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                      ),
                      Text(
                        'Download spreadsheet CSV or raw JSON backup',
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

          // Overview Stats Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('TOTAL ENTRIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D7A72))),
                    const SizedBox(height: 4),
                    Text('$count Records', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF131B2E))),
                  ],
                ),
                Container(width: 1, height: 30, color: const Color(0x1F000000)),
                Column(
                  children: [
                    const Text('ACCUMULATED SUM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D7A72))),
                    const SizedBox(height: 4),
                    Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF006948))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF006948),
            unselectedLabelColor: const Color(0xFF6D7A72),
            indicatorColor: const Color(0xFF006948),
            tabs: const [
              Tab(text: 'Excel / CSV (.csv)'),
              Tab(text: 'Full JSON Backup (.json)'),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // CSV Tab
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comma Separated Values (CSV)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF131B2E)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Standard format compatible with Microsoft Excel, Google Sheets, Apple Numbers, and Notion tables.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF3D4A42)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportCsv,
                        icon: const Icon(Icons.download, color: Colors.white, size: 18),
                        label: const Text(
                          'Download / Share CSV File',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006948),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _copyCsv,
                        icon: const Icon(Icons.copy, size: 16, color: Color(0xFF006948)),
                        label: const Text(
                          'Copy CSV Content to Clipboard',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF006948)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF006948)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),

                // JSON Tab
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Structured JSON Backup',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF131B2E)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Full raw JSON backup including dates, categories, accounts, and transaction notes for complete data portability.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF3D4A42)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportJson,
                        icon: const Icon(Icons.download, color: Colors.white, size: 18),
                        label: const Text(
                          'Download / Share JSON File',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF131B2E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _copyJson,
                        icon: const Icon(Icons.copy, size: 16, color: Color(0xFF131B2E)),
                        label: const Text(
                          'Copy JSON Content to Clipboard',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF131B2E)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF131B2E)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
