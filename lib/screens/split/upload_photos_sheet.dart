import 'package:flutter/material.dart';
import '../../services/file_picker_service.dart';
import '../../services/app_permission_service.dart';

class UploadPhotosSheet extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentMemberName;
  final List<PickedFileData> initialFiles;
  final Function(List<PickedFileData> files, bool originalQuality) onUpload;

  const UploadPhotosSheet({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentMemberName,
    required this.initialFiles,
    required this.onUpload,
  });

  @override
  State<UploadPhotosSheet> createState() => _UploadPhotosSheetState();
}

class _UploadPhotosSheetState extends State<UploadPhotosSheet> {
  late List<PickedFileData> _files;
  bool _originalQuality = false;
  bool _isPickingMore = false;

  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _files = List<PickedFileData>.from(widget.initialFiles);
  }

  Future<void> _pickMorePhotos() async {
    if (_isPickingMore) return;
    final hasPermission = await AppPermissionService.requestPhotosPermission(
      context,
      reason: 'choose more photos to add',
    );
    if (!hasPermission || !mounted) return;

    setState(() => _isPickingMore = true);
    try {
      final more = await pickMultipleImageFiles();
      if (mounted && more.isNotEmpty) {
        setState(() {
          _files.addAll(more);
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingMore = false);
    }
  }

  int get _totalSizeBytes => _files.fold(0, (sum, f) => sum + f.bytes.length);

  String get _formattedTotalSize {
    final bytes = _totalSizeBytes;
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload to ${widget.groupName} Vault',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Auto-expires in 48 hours for the group',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal preview strip
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _files.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                // "+ Add More" button
                if (index == _files.length) {
                  return InkWell(
                    onTap: _pickMorePhotos,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 80,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: _isPickingMore
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, color: _primaryColor, size: 24),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add More',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                }

                final file = _files[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 80,
                        height: 96,
                        child: Image.memory(
                          file.bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.image, color: Colors.black26),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _files.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Quality Selector Header
          const Text(
            'UPLOAD QUALITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          // Smart HD (Recommended)
          InkWell(
            onTap: () => setState(() => _originalQuality = false),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: !_originalQuality ? const Color(0xFFE8F7F0) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: !_originalQuality ? _primaryColor : const Color(0xFFE2E8F0),
                  width: !_originalQuality ? 1.8 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !_originalQuality ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: !_originalQuality ? _primaryColor : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✨ Smart HD (Recommended)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Full 2K resolution · ~1.5 MB/photo · Fast upload',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Original Quality Option
          InkWell(
            onTap: () => setState(() => _originalQuality = true),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _originalQuality ? const Color(0xFFE8F7F0) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _originalQuality ? _primaryColor : const Color(0xFFE2E8F0),
                  width: _originalQuality ? 1.8 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _originalQuality ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: _originalQuality ? _primaryColor : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📷 Original File Size',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Uncompressed camera RAW · 15-25 MB/photo · Uses more data',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Total stats and Upload button
          Row(
            children: [
              Text(
                '${_files.length} ${_files.length == 1 ? 'photo' : 'photos'} · $_formattedTotalSize total',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _files.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onUpload(_files, _originalQuality);
                    },
              child: Text(
                'Upload ${_files.length} ${_files.length == 1 ? 'Photo' : 'Photos'} (${_originalQuality ? 'Original' : 'Smart HD'})',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
