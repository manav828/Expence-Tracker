import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/split_models.dart';
import '../../providers/trip_photo_provider.dart';
import '../../services/trip_photo_service.dart';
import '../../services/file_picker_service.dart';
import 'trip_photo_viewer_screen.dart';
import 'upload_photos_sheet.dart';

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
  static const _primaryColor = Color(0xFF006948);
  static const _likedHeartColor = Color(0xFFE11D48);

  // Samsung Gallery zoom levels: 3 (zoomed in), 4 (default), 7 (zoomed out)
  int _crossAxisCount = 4;
  DateTime? _lastScaleTime;

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

  @override
  Widget build(BuildContext context) {
    return Consumer<TripPhotoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.allPhotos.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryColor),
          );
        }

        final photos = provider.filteredPhotos;
        final totalCount = provider.totalCount;
        final likedCount = provider.likedCount;
        final contributorCounts = provider.contributorCounts;
        final contributorNames = provider.contributorNames;
        final currentUid = TripPhotoService.instance.currentUserId;

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

        return Stack(
          children: [
            GestureDetector(
              onScaleUpdate: _handleScaleUpdate,
              child: RefreshIndicator(
                onRefresh: () => provider.loadPhotos(widget.group.id),
                color: _primaryColor,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 1. Sleek Compact Timer & Status Strip (Small UI, No Limits)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isUrgent ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isUrgent ? Icons.warning_amber_rounded : Icons.timer_outlined,
                                color: isUrgent ? const Color(0xFFD97706) : const Color(0xFF006948),
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                countdownText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isUrgent ? const Color(0xFF92400E) : const Color(0xFF0F172A),
                                ),
                              ),
                              const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                              Text(
                                '$totalCount photos',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (provider.formattedStorageUsage.isNotEmpty) ...[
                                Text(
                                  ' (${provider.formattedStorageUsage})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                              const Spacer(),

                              // Samsung Gallery Zoom Selector [3 | 4 | 7]
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildZoomButton(3, '3'),
                                    _buildZoomButton(4, '4'),
                                    _buildZoomButton(7, '7'),
                                  ],
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
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8F7F0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
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
                                    : 'Upload memories before the 48-hour vault expires!',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                textAlign: TextAlign.center,
                              ),
                            ],
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

                              return GestureDetector(
                                onTap: () {
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
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(radius),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        photo.photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFFE2E8F0),
                                          child: const Icon(Icons.broken_image, color: Colors.black26, size: 16),
                                        ),
                                      ),

                                      // Heart icon in bottom-right corner
                                      if (isLiked)
                                        Positioned(
                                          right: _crossAxisCount == 7 ? 2 : 4,
                                          bottom: _crossAxisCount == 7 ? 2 : 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              provider.toggleLike(widget.group.id, photo.id);
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(_crossAxisCount == 7 ? 2 : 3.5),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.45),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.favorite_rounded,
                                                size: _crossAxisCount == 7 ? 10 : 13,
                                                color: _likedHeartColor,
                                              ),
                                            ),
                                          ),
                                        )
                                      else if (_crossAxisCount <= 4)
                                        Positioned(
                                          right: 4,
                                          bottom: 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              provider.toggleLike(widget.group.id, photo.id);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(3.5),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.35),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.favorite_border_rounded,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
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

            // Floating "+ Upload Photos" Button
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
          ],
        );
      },
    );
  }

  Widget _buildZoomButton(int count, String label) {
    final isSelected = _crossAxisCount == count;
    return InkWell(
      onTap: () {
        setState(() => _crossAxisCount = count);
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
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
