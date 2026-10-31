import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/pixabay_service.dart';
import '../../services/cloudflare_r2_service.dart';
import '../../services/file_picker_service.dart';

class GroupBannerPickerSheet extends StatefulWidget {
  final String? initialUrl;
  final String? suggestedKeyword;

  const GroupBannerPickerSheet({
    super.key,
    this.initialUrl,
    this.suggestedKeyword,
  });

  @override
  State<GroupBannerPickerSheet> createState() => _GroupBannerPickerSheetState();
}

class _GroupBannerPickerSheetState extends State<GroupBannerPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  List<String> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  bool _isUploading = false;
  String? _uploadedUrl;

  String? _previewUrl;

  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _previewUrl = widget.initialUrl;
    if (widget.suggestedKeyword != null && widget.suggestedKeyword!.trim().isNotEmpty) {
      _searchCtrl.text = widget.suggestedKeyword!.trim();
    }
    // Auto-search initial suggested keyword if available
    if (_searchCtrl.text.trim().isNotEmpty) {
      _performSearch(_searchCtrl.text.trim());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final results = await PixabayService.searchImages(clean);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _pickAndUpload({bool useCamera = false}) async {
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
        folder: 'groups',
        extension: picked.extension,
      );

      if (mounted) {
        if (url != null) {
          setState(() {
            _uploadedUrl = url;
            _previewUrl = url;
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Banner uploaded successfully!'),
              backgroundColor: _primaryColor,
            ),
          );
        } else {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.panorama_outlined, color: _primaryColor, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Choose Group Banner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: _primaryColor,
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.auto_awesome, size: 16), text: 'Curated'),
              Tab(icon: Icon(Icons.search, size: 16), text: 'Search'),
              Tab(icon: Icon(Icons.cloud_upload_outlined, size: 16), text: 'Upload'),
            ],
          ),

          // Content Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCuratedTab(),
                _buildPixabayTab(),
                _buildUploadTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Curated Presets ──────────────────────────────────────────────────────
  Widget _buildCuratedTab() {
    final presets = PixabayService.curatedPresets;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: presets.length,
      itemBuilder: (context, idx) {
        final p = presets[idx];
        final url = p['url']!;
        final label = p['label']!;
        final isSelected = _previewUrl == url;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _previewUrl = url);
            Navigator.pop(context, url);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: _primaryColor, width: 3)
                      : Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 2. Pixabay Search ───────────────────────────────────────────────────────
  Widget _buildPixabayTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search destinations, mountains, beach...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
                onPressed: _isSearching ? null : () => _performSearch(_searchCtrl.text),
                child: _isSearching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),

        // Quick Tag Suggestions
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: ['Goa', 'Manali', 'Rajasthan', 'Dinner', 'Bali', 'Road Trip', 'Friends', 'Camp'].map((tag) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(tag, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () {
                    _searchCtrl.text = tag;
                    _performSearch(tag);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(height: 16),

        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: _primaryColor))
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasSearched ? Icons.search_off : Icons.image_search,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hasSearched ? 'No photos found for "${_searchCtrl.text}"' : 'Search Pixabay for photos',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.45,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, idx) {
                        final url = _searchResults[idx];
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() => _previewUrl = url);
                            Navigator.pop(context, url);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ─── 3. Cloudflare R2 Upload ────────────────────────────────────────────────
  Widget _buildUploadTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_upload_outlined, size: 48, color: _primaryColor),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload Custom Banner',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Stored securely in cloud storage',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          if (_uploadedUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Image.network(_uploadedUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, _uploadedUrl),
                child: const Text('Use This Uploaded Banner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isUploading ? null : () => _pickAndUpload(useCamera: true),
                  icon: const Icon(Icons.camera_alt_outlined, color: _primaryColor, size: 20),
                  label: const Text(
                    'Take Photo',
                    style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isUploading ? null : () => _pickAndUpload(useCamera: false),
                  icon: _isUploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file, color: Colors.white, size: 20),
                  label: Text(
                    _isUploading ? 'Uploading...' : 'Upload File',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
