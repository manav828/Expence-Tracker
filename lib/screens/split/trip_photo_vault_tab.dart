import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/split_models.dart';
import '../../models/trip_photo.dart';
import '../../providers/trip_photo_provider.dart';
import '../../services/trip_photo_service.dart';
import '../../services/file_picker_service.dart';
import '../../services/app_permission_service.dart';
import '../../services/photo_download_helper.dart';
import '../../widgets/shimmer_box.dart';
import 'trip_photo_viewer_screen.dart';
import 'upload_photos_sheet.dart';
import '../../core/theme/app_colors.dart';


class TripPhotoVaultTab extends StatefulWidget {
  final SplitGroup group;
  final String currentMemberName;

  const TripPhotoVaultTab({
    super.key,
    required this.group,
    required this.currentMemberName,
  });

  @override
  State<TripPhotoVaultTab> createState() => _TripPhotoVaultTabState();
}

class _TripPhotoVaultTabState extends State<TripPhotoVaultTab> {
  static const _primaryColor = AppColors.primary;
  static const _likedHeartColor = Color(0xFFE11D48);

  // Samsung Gallery zoom levels: 3 (zoomed in), 4 (default), 7 (zoomed out)
  int _crossAxisCount = 4;
  DateTime? _lastScaleTime;

  // Multi-selection state
  final Set<String> _selectedPhotoIds = {};
  bool get _isSelectionMode => _selectedPhotoIds.isNotEmpty;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripPhotoProvider>().loadPhotos(widget.group.id);
    });
  }

  void _zoomIn() {
    if (_crossAxisCount == 7) {
      setState(() => _crossAxisCount = 4);
      HapticFeedback.selectionClick();
    } else if (_crossAxisCount == 4) {
      setState(() => _crossAxisCount = 3);
      HapticFeedback.selectionClick();
    }
  }

  void _zoomOut() {
    if (_crossAxisCount == 3) {
      setState(() => _crossAxisCount = 4);
      HapticFeedback.selectionClick();
    } else if (_crossAxisCount == 4) {
      setState(() => _crossAxisCount = 7);
      HapticFeedback.selectionClick();
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      final now = DateTime.now();
      if (_lastScaleTime != null &&
          now.difference(_lastScaleTime!).inMilliseconds < 320) {
        return;
      }
      if (details.scale > 1.25) {
        // Pinch outwards -> Zoom in (fewer columns: 7 -> 4 -> 3)
        _zoomIn();
        _lastScaleTime = now;
      } else if (details.scale < 0.78) {
        // Pinch inwards -> Zoom out (more columns: 3 -> 4 -> 7)
        _zoomOut();
        _lastScaleTime = now;
      }
    }
  }

  Future<void> _handlePickAndUpload() async {
    final hasPermission = await AppPermissionService.requestPhotosPermission(
      context,
      reason: 'select photos to upload to the trip vault',
    );
    if (!hasPermission || !mounted) return;

    final pickedFiles = await pickMultipleImageFiles();
    if (!mounted || pickedFiles.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UploadPhotosSheet(
        groupId: widget.group.id,
        groupName: widget.group.name,
        currentMemberName: widget.currentMemberName,
        initialFiles: pickedFiles,
        onUpload: (files, originalQuality) async {
          final provider = context.read<TripPhotoProvider>();
          final success = await provider.uploadPhotos(
            groupId: widget.group.id,
            uploaderName: widget.currentMemberName,
            files: files,
            originalQuality: originalQuality,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Uploaded ${files.length} photos to vault!'
                      : (provider.errorMessage ?? 'Upload failed.'),
                ),
                backgroundColor: success ? _primaryColor : Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _handleDownloadAllLiked() async {
    final provider = context.read<TripPhotoProvider>();
    final count = await provider.downloadAllLikedPhotos(widget.group.name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Saved $count liked photos to your phone!'
                : 'No liked photos to download.',
          ),
          backgroundColor: count > 0 ? _primaryColor : Colors.amber.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleSelectPhoto(String photoId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
      } else {
        _selectedPhotoIds.add(photoId);
      }
    });
  }

  void _clearSelection() {
    if (_selectedPhotoIds.isNotEmpty) {
      setState(() => _selectedPhotoIds.clear());
    }
  }

  void _selectAll(List<TripPhoto> photos) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPhotoIds.length == photos.length) {
        _selectedPhotoIds.clear();
      } else {
        _selectedPhotoIds.addAll(photos.map((p) => p.id));
      }
    });
  }

  Future<void> _handleDownloadSelected(List<TripPhoto> photos) async {
    final selectedPhotos = photos.where((p) => _selectedPhotoIds.contains(p.id)).toList();
    if (selectedPhotos.isEmpty || _isProcessingAction) return;

    setState(() => _isProcessingAction = true);
    int successCount = 0;
    try {
      for (int i = 0; i < selectedPhotos.length; i++) {
        final p = selectedPhotos[i];
        final ext = p.photoUrl.contains('.')
            ? p.photoUrl.split('.').last.split('?').first
            : 'jpg';
        final fileName = '${widget.group.name}_photo_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        final ok = await saveOrSharePhoto(url: p.photoUrl, fileName: fileName);
        if (ok) successCount++;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _selectedPhotoIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 0
                  ? 'Saved $successCount photo${successCount > 1 ? "s" : ""} to your device!'
                  : 'Failed to download selected photos.',
            ),
            backgroundColor: successCount > 0 ? _primaryColor : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteSelected(List<TripPhoto> photos) async {
    final selectedPhotos = photos.where((p) => _selectedPhotoIds.contains(p.id)).toList();
    if (selectedPhotos.isEmpty || _isProcessingAction) return;

    final count = selectedPhotos.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $count photo${count > 1 ? "s" : ""}?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to permanently delete the selected $count photo${count > 1 ? "s" : ""} you uploaded? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessingAction = true);
    final provider = context.read<TripPhotoProvider>();
    int deletedCount = 0;
    try {
      for (final p in selectedPhotos) {
        final ok = await provider.deletePhoto(p);
        if (ok) deletedCount++;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _selectedPhotoIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deletedCount > 0
                  ? 'Deleted $deletedCount photo${deletedCount > 1 ? "s" : ""}.'
                  : 'Failed to delete selected photos.',
            ),
            backgroundColor: deletedCount > 0 ? const Color(0xFF1E293B) : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripPhotoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.allPhotos.isEmpty) {
          return VaultGallerySkeleton(crossAxisCount: _crossAxisCount);
        }

        final photos = provider.filteredPhotos;
        final totalCount = provider.totalCount;
        final likedCount = provider.likedCount;
        final contributorCounts = provider.contributorCounts;
        final contributorNames = provider.contributorNames;
        final currentUid = TripPhotoService.instance.currentUserId;
        final selectedPhotos = photos.where((p) => _selectedPhotoIds.contains(p.id)).toList();
        final myName = widget.currentMemberName.trim().toLowerCase();
        // Strict ownership rule: If ANY selected photo was uploaded by another user, delete icon hides!
        final bool canDeleteSelected = selectedPhotos.isNotEmpty && selectedPhotos.every((photo) {
          final isMeUid = currentUid.isNotEmpty && currentUid != 'anonymous' && photo.uploaderId == currentUid;
          final isMeName = myName.isNotEmpty && photo.uploaderName.trim().toLowerCase() == myName;
          return isMeUid || isMeName;
        });

        // Earliest expiration calculation
        final earliestExp = provider.earliestExpiration;
        final bool isUrgent = earliestExp != null && earliestExp.inHours < 6;
        final String countdownText = earliestExp != null
            ? (earliestExp.inHours > 0
                ? '${earliestExp.inHours}h ${earliestExp.inMinutes % 60}m left'
                : '${earliestExp.inMinutes}m left')
            : '48h countdown';

        // Grid spacing & border radius tuned for column count
        final double spacing = _crossAxisCount == 7 ? 2.0 : (_crossAxisCount == 4 ? 4.0 : 6.0);
        final double radius = _crossAxisCount == 7 ? 3.0 : (_crossAxisCount == 4 ? 6.0 : 10.0);
        final double horizontalPadding = _crossAxisCount == 7 ? 8.0 : 14.0;

        return PopScope(
          canPop: !_isSelectionMode,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_isSelectionMode) {
              _clearSelection();
            }
          },
          child: ShimmerLoading(
            child: Stack(
              children: [
              GestureDetector(
                onScaleUpdate: _handleScaleUpdate,
                child: RefreshIndicator(
                  onRefresh: () => provider.loadPhotos(widget.group.id),
                  color: _primaryColor,
                  child: CustomScrollView(
                    cacheExtent: 300,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                    // 1. Sleek Compact Timer & Modern Max Storage Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isUrgent ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Row 1: Timer Pill, Photo Count & Gallery Density Switcher
                              Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                          // Timer Badge Pill
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                            decoration: BoxDecoration(
                                              color: isUrgent ? const Color(0xFFD97706) : _primaryColor,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                                                const SizedBox(width: 4),
                                                Text(
                                                  countdownText,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '$totalCount photos',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Samsung Gallery Density Switcher (Icons)
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildZoomIconButton(3, Icons.view_module_rounded, 'Large (3 in row)'),
                                        _buildZoomIconButton(4, Icons.grid_view_rounded, 'Standard (4 in row)'),
                                        _buildZoomIconButton(7, Icons.apps_rounded, 'Compact (7 in row)'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Row 2: Storage Size & Micro Progress Bar
                              Row(
                                children: [
                                  const Icon(Icons.cloud_outlined, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Storage: ${provider.formattedUsedStorage} / ${provider.formattedStorageCapacity}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(provider.storageUsageRatio * 100).toStringAsFixed(1)}% used',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: provider.storageUsageRatio,
                                  minHeight: 3.5,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isUrgent ? const Color(0xFFD97706) : _primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. Filter Bar
                    SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Row(
                          children: [
                            // [All (count)]
                            _buildFilterChip(
                              label: 'All ($totalCount)',
                              isSelected: provider.selectedFilter == 'all',
                              onTap: () => provider.setFilter('all'),
                            ),
                            const SizedBox(width: 6),

                            // [❤️ Liked (count)]
                            _buildFilterChip(
                              label: '❤️ Liked ($likedCount)',
                              isSelected: provider.selectedFilter == 'liked',
                              activeColor: _likedHeartColor,
                              onTap: () => provider.setFilter('liked'),
                            ),
                            const SizedBox(width: 6),

                            // Member contributor chips
                            ...contributorCounts.entries.map((entry) {
                              final uid = entry.key;
                              final count = entry.value;
                              final isMe = uid == currentUid;
                              final rawName = contributorNames[uid] ?? 'Member';
                              final displayName = isMe ? 'You' : rawName;

                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _buildFilterChip(
                                  label: '👤 $displayName ($count)',
                                  isSelected: provider.selectedFilter == uid,
                                  onTap: () => provider.setFilter(uid),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    // 3. Action Header when viewing [❤️ Liked]
                    if (provider.selectedFilter == 'liked' && likedCount > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                          child: Row(
                            children: [
                              Text(
                                '$likedCount Personal Favorites',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                                label: Text(
                                  'Download ($likedCount)',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: _handleDownloadAllLiked,
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 4)),

                    // 4. Samsung Gallery Style Dynamic Grid (3, 4, or 7 columns)
                    if (photos.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (totalCount == 0 &&
                                    provider.selectedFilter == 'all' &&
                                    provider.errorMessage == null)
                                  Image.asset(
                                    'assets/illustrations/empty-photo-vault.webp',
                                    width: 120,
                                    height: 120,
                                    excludeFromSemantics: true,
                                  )
                                else
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Color(0xFFE8F7F0),
                                    child: Icon(
                                      Icons.photo_library_outlined,
                                      color: _primaryColor,
                                      size: 28,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Text(
                                  provider.selectedFilter == 'liked'
                                      ? 'No liked photos yet'
                                      : 'No trip photos in this vault',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.selectedFilter == 'liked'
                                      ? 'Tap the heart icon on any photo to save your favorites.'
                                      : 'Photos are available for 48 hours after upload.',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 80),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _crossAxisCount,
                            mainAxisSpacing: spacing,
                            crossAxisSpacing: spacing,
                            childAspectRatio: 1.0,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final photo = photos[index];
                              final isLiked = provider.isPhotoLiked(photo.id);
                              final isSelected = _selectedPhotoIds.contains(photo.id);

                              return GestureDetector(
                                onLongPress: () {
                                  HapticFeedback.mediumImpact();
                                  _toggleSelectPhoto(photo.id);
                                },
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleSelectPhoto(photo.id);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TripPhotoViewerScreen(
                                          photos: photos,
                                          initialIndex: index,
                                          groupId: widget.group.id,
                                          groupName: widget.group.name,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(radius),
                                    border: isSelected
                                        ? Border.all(color: _primaryColor, width: 2.5)
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(radius - (isSelected ? 1.0 : 0.0)),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          photo.photoUrl,
                                          fit: BoxFit.cover,
                                          cacheWidth: _crossAxisCount == 7
                                              ? 220
                                              : (_crossAxisCount == 4 ? 380 : 560),
                                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                            if (wasSynchronouslyLoaded) return child;
                                            final isLoaded = frame != null;
                                            return Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                if (!isLoaded)
                                                  PhotoShimmerPlaceholder(
                                                    borderRadius: radius,
                                                    showIcon: _crossAxisCount != 7,
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
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFFE2E8F0),
                                            child: const Center(
                                              child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 16),
                                            ),
                                          ),
                                        ),

                                        // Subtle tint overlay when selected
                                        if (isSelected)
                                          Container(color: Colors.black.withValues(alpha: 0.18)),

                                        // Checkmark indicator in top-left when in selection mode
                                        if (_isSelectionMode)
                                          Positioned(
                                            left: _crossAxisCount == 7 ? 2 : 4,
                                            top: _crossAxisCount == 7 ? 2 : 4,
                                            child: Container(
                                              width: _crossAxisCount == 7 ? 16 : 22,
                                              height: _crossAxisCount == 7 ? 16 : 22,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected ? _primaryColor : Colors.black.withValues(alpha: 0.4),
                                                border: Border.all(
                                                  color: isSelected ? Colors.white : Colors.white70,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? Icon(
                                                      Icons.check_rounded,
                                                      size: _crossAxisCount == 7 ? 10 : 14,
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                          ),

                                        // Heart icon in bottom-right corner (hidden while in selection mode)
                                        if (!_isSelectionMode)
                                          Positioned(
                                            right: _crossAxisCount == 7 ? 2 : 4,
                                            bottom: _crossAxisCount == 7 ? 2 : 4,
                                            child: GestureDetector(
                                              onTap: () {
                                                provider.toggleLike(widget.group.id, photo.id);
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(_crossAxisCount == 7 ? 2.5 : 3.5),
                                                decoration: BoxDecoration(
                                                  color: isLiked
                                                      ? Colors.black.withValues(alpha: 0.5)
                                                      : Colors.black.withValues(alpha: 0.35),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                  size: _crossAxisCount == 7 ? 11 : 13,
                                                  color: isLiked ? _likedHeartColor : Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: photos.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Floating "+ Upload Photos" Button (shown only when NOT selecting)
            if (!_isSelectionMode)
              Positioned(
                right: 18,
                bottom: 18,
                child: FloatingActionButton.extended(
                  backgroundColor: _primaryColor,
                  elevation: 3,
                  icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Upload Photos',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onPressed: _handlePickAndUpload,
                ),
              ),

            // Floating Multi-Selection Action Bar (shown when photos are selected)
            if (_isSelectionMode)
              Positioned(
                left: 14,
                right: 14,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Close / Cancel selection
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Cancel',
                        onPressed: _clearSelection,
                      ),
                      const SizedBox(width: 10),

                      // Selected Count
                      Text(
                        '${_selectedPhotoIds.length} selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const Spacer(),

                      // Select All / Deselect All
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _selectAll(photos),
                        child: Text(
                          _selectedPhotoIds.length == photos.length ? 'Deselect' : 'All',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Download Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 19),
                          tooltip: 'Download selected',
                          onPressed: _isProcessingAction ? null : () => _handleDownloadSelected(photos),
                        ),
                      ),

                      // Delete Button (ONLY visible when every selected photo belongs to the current user!)
                      if (canDeleteSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFB7185), size: 19),
                            tooltip: 'Delete selected',
                            onPressed: _isProcessingAction ? null : () => _handleDeleteSelected(photos),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildZoomIconButton(int count, IconData icon, String tooltip) {
    final isSelected = _crossAxisCount == count;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() => _crossAxisCount = count);
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color activeColor = _primaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
