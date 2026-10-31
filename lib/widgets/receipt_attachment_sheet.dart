import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cloudflare_r2_service.dart';
import '../services/file_picker_service.dart';

class ReceiptAttachmentSheet extends StatefulWidget {
  final String? initialUrl;

  const ReceiptAttachmentSheet({
    super.key,
    this.initialUrl,
  });

  @override
  State<ReceiptAttachmentSheet> createState() => _ReceiptAttachmentSheetState();
}

class _ReceiptAttachmentSheetState extends State<ReceiptAttachmentSheet> {
  final _urlCtrl = TextEditingController();
  bool _isUploading = false;
  String? _previewUrl;

  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.initialUrl;
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlCtrl.text = widget.initialUrl!;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadReceipt() async {
    setState(() => _isUploading = true);
    try {
      final picked = await pickImageFile();
      if (picked == null) {
        if (mounted) {
          setState(() => _isUploading = false);
          if (!kIsWeb) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File upload is available on Web. On mobile, you can paste an image link or sample receipt.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        return;
      }

      final url = await CloudflareR2Service.instance.uploadImage(
        bytes: picked.bytes,
        folder: 'receipts',
        extension: picked.extension,
      );

      if (mounted) {
        if (url != null) {
          setState(() {
            _previewUrl = url;
            _urlCtrl.text = url;
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt uploaded successfully!'),
              backgroundColor: _primaryColor,
            ),
          );
        } else {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload receipt. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              children: [
                const Icon(Icons.receipt_long, color: _primaryColor, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Attach Bill & Receipt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Attach a bill photo or restaurant/store invoice.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            // Option 1: Upload directly
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 36, color: _primaryColor),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload Photo / Receipt',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF131B2E)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Stored safely in cloud storage',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isUploading ? null : _pickAndUploadReceipt,
                      icon: _isUploading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.file_upload_outlined, color: Colors.white, size: 18),
                      label: Text(
                        _isUploading ? 'Uploading receipt...' : 'Choose Receipt Image',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Center(
              child: Text('— OR PASTE LINK —', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
            ),
            const SizedBox(height: 16),

            // Option 2: Paste link
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: 'Image / Receipt URL',
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.link, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _urlCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _urlCtrl.clear();
                          setState(() => _previewUrl = null);
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _previewUrl = v.trim().isEmpty ? null : v.trim()),
            ),

            const SizedBox(height: 12),
            // Quick Sample Receipt button (for quick demonstration or offline testing)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  const sample = 'https://images.unsplash.com/photo-1554415707-9e4c0192a561?auto=format&fit=crop&w=800&q=80';
                  _urlCtrl.text = sample;
                  setState(() => _previewUrl = sample);
                },
                icon: const Icon(Icons.receipt, size: 14, color: Color(0xFF64748B)),
                label: const Text('Insert Sample Receipt', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            ),

            // Preview Section
            if (_previewUrl != null && _previewUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Receipt Preview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFF1F5F9),
                  child: Image.network(
                    _previewUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Invalid image link', style: TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, _previewUrl),
                  child: const Text('Attach This Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full screen interactive zoomable image viewer for receipts
class FullScreenReceiptViewer extends StatelessWidget {
  final String imageUrl;
  final String title;

  const FullScreenReceiptViewer({
    super.key,
    required this.imageUrl,
    this.title = 'Bill / Receipt',
  });

  static void show(BuildContext context, {required String imageUrl, String title = 'Bill / Receipt'}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => FullScreenReceiptViewer(imageUrl: imageUrl, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        fit: StackFit.loose,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 100,
                      height: 100,
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white70, size: 48),
                        SizedBox(height: 12),
                        Text('Could not load receipt photo', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.6)),
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                  tooltip: 'Copy image link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: imageUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Receipt link copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.6)),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
