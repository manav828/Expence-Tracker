import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/trip_photo.dart';
import '../../providers/trip_photo_provider.dart';
import '../../services/trip_photo_service.dart';
import '../../services/photo_download_helper.dart';
import '../../widgets/shimmer_box.dart';

class TripPhotoViewerScreen extends StatefulWidget {
  final List<TripPhoto> photos;
  final int initialIndex;
  final String groupId;
  final String groupName;

  const TripPhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<TripPhotoViewerScreen> createState() => _TripPhotoViewerScreenState();
}

class _TripPhotoViewerScreenState extends State<TripPhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<TripPhoto> _photos;
  bool _isDownloading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _photos = List<TripPhoto>.from(widget.photos);
    _currentIndex = widget.initialIndex.clamp(0, _photos.isNotEmpty ? _photos.length - 1 : 0);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  TripPhoto? get _currentPhoto =>
      _photos.isNotEmpty && _currentIndex < _photos.length ? _photos[_currentIndex] : null;

  bool get _isCurrentPhotoOwner {
    final photo = _currentPhoto;
    if (photo == null) return false;
    final currentUid = TripPhotoService.instance.currentUserId;
    return photo.uploaderId.isNotEmpty &&
        (photo.uploaderId == currentUid || currentUid == 'anonymous');
  }

  Future<void> _handleDownload() async {
    final photo = _currentPhoto;
    if (photo == null || _isDownloading) return;

    setState(() => _isDownloading = true);
    final ext = photo.photoUrl.contains('.')
        ? photo.photoUrl.split('.').last.split('?').first
        : 'jpg';
    final fileName = '${widget.groupName}_photo_${_currentIndex + 1}.$ext';

    final success = await saveOrSharePhoto(url: photo.photoUrl, fileName: fileName);
    if (mounted) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Photo saved to your phone!' : 'Failed to download photo.',
          ),
          backgroundColor: success ? const Color(0xFF006948) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final photo = _currentPhoto;
    if (photo == null || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Photo?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete this photo from the trip vault for everyone.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      final provider = context.read<TripPhotoProvider>();
      final success = await provider.deletePhoto(photo);

      if (mounted) {
        setState(() => _isDeleting = false);
        if (success) {
          setState(() {
            _photos.removeAt(_currentIndex);
            if (_photos.isEmpty) {
              Navigator.pop(context);
              return;
            }
            if (_currentIndex >= _photos.length) {
              _currentIndex = _photos.length - 1;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo deleted from vault.'),
              backgroundColor: Color(0xFF006948),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete photo.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0D14),
        body: Center(child: Text('No photos', style: TextStyle(color: Colors.white))),
      );
    }

    final photo = _photos[_currentIndex];
    final provider = context.watch<TripPhotoProvider>();
    final isLiked = provider.isPhotoLiked(photo.id);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.65),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} of ${_photos.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // 1. Personal Private Like (Heart) button
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? const Color(0xFFE11D48) : Colors.white,
              size: 24,
            ),
            tooltip: isLiked ? 'Unlike' : 'Like (Personal)',
            onPressed: () => provider.toggleLike(widget.groupId, photo.id),
          ),

          // 2. Download Photo to Camera Roll button
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white, size: 24),
            tooltip: 'Save to Phone',
            onPressed: _handleDownload,
          ),

          // 3. Delete Photo button (STRICTLY OWNER ONLY)
          if (_isCurrentPhotoOwner)
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
              tooltip: 'Delete (Uploader Only)',
              onPressed: _handleDelete,
            ),

          const SizedBox(width: 8),
        ],
      ),
      // Pure, full-bleed photo view with NO bottom card
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _photos.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final item = _photos[index];
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    item.photoUrl,
                    fit: BoxFit.contain,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      final isLoaded = frame != null;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!isLoaded)
                            const Center(
                              child: SizedBox(
                                width: 260,
                                height: 260,
                                child: PhotoShimmerPlaceholder(
                                  borderRadius: 16,
                                  isDark: true,
                                  showIcon: true,
                                ),
                              ),
                            ),
                          AnimatedOpacity(
                            opacity: isLoaded ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            child: child,
                          ),
                        ],
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      final total = loadingProgress.expectedTotalBytes;
                      final loaded = loadingProgress.cumulativeBytesLoaded;
                      return Center(
                        child: CircularProgressIndicator(
                          value: total != null ? loaded / total : null,
                          color: const Color(0xFF006948),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.white38),
                          SizedBox(height: 12),
                          Text('Failed to load image', style: TextStyle(color: Colors.white60)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Subtle left navigation arrow affordance
          if (_currentIndex > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),

          // Subtle right navigation arrow affordance
          if (_currentIndex < _photos.length - 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
