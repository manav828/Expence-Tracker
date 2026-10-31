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
  bool _isUploading = false;
  String? _previewUrl;

  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.initialUrl;
  }

  Future<void> _pickAndUploadReceipt({bool useCamera = false}) async {
    setState(() => _isUploading = true);
    try {
      final picked = await pickImageFile(useCamera: useCamera);
      if (picked == null) {
        if (mounted) {
          setState(() => _isUploading = false);
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
              'Upload an image or take a photo of your receipt.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            if (_isUploading) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3, color: _primaryColor),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Uploading receipt...',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF131B2E)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Action Buttons Row: Take Photo + Upload from Device
              Row(
                children: [
                  // Option 1: Take Photo
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _pickAndUploadReceipt(useCamera: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: _primaryColor, size: 26),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Take Photo',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF131B2E)),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Use camera',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Option 2: Upload from Device
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _pickAndUploadReceipt(useCamera: false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.file_upload_outlined, color: Color(0xFF0F172A), size: 26),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Upload File',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF131B2E)),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Gallery / files',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Preview Section
            if (_previewUrl != null && _previewUrl!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Receipt Preview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  TextButton(
                    onPressed: () => setState(() => _previewUrl = null),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Change', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: const Color(0xFFF1F5F9),
                  child: Image.network(
                    _previewUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Failed to load image preview', style: TextStyle(color: Colors.red, fontSize: 13)),
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
