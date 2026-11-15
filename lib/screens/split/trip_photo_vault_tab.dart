import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripPhotoProvider>().loadPhotos(widget.group.id);
    });
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

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => provider.loadPhotos(widget.group.id),
              color: _primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Vault Status Banner (Urgency & Storage Bar)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUrgent ? const Color(0xFFFEF3C7) : const Color(0xFFE8F7F0),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF85F8C4),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isUrgent ? Icons.warning_amber_rounded : Icons.bolt_rounded,
                                  color: isUrgent ? const Color(0xFFD97706) : _primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '48-Hour Trip Vault',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isUrgent ? const Color(0xFF92400E) : _primaryColor,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isUrgent ? const Color(0xFFD97706) : _primaryColor,
                                    borderRadius: BorderRadius.circular(12),
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
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Storage: $totalCount / 100 Photos (${provider.formattedStorageUsage})',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (totalCount / 100).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.black.withValues(alpha: 0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isUrgent ? const Color(0xFFD97706) : _primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Photos auto-expire after 48 hrs. Save your favorites!',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Horizontal Filter Bar (All | Liked | Contributors)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // [All (count)]
                          _buildFilterChip(
                            label: 'All ($totalCount)',
                            isSelected: provider.selectedFilter == 'all',
                            onTap: () => provider.setFilter('all'),
                          ),
                          const SizedBox(width: 8),

                          // [❤️ Liked (count)] — Strictly personal to you!
                          _buildFilterChip(
                            label: '❤️ Liked ($likedCount)',
                            isSelected: provider.selectedFilter == 'liked',
                            activeColor: _likedHeartColor,
                            onTap: () => provider.setFilter('liked'),
                          ),
                          const SizedBox(width: 8),

                          // Member contributor chips e.g. [👤 You (18)], [👤 Dinesh (24)]
                          ...contributorCounts.entries.map((entry) {
                            final uid = entry.key;
                            final count = entry.value;
                            final isMe = uid == currentUid;
                            final rawName = contributorNames[uid] ?? 'Member';
                            final displayName = isMe ? 'You' : rawName;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
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

                  // 3. 1-Click Action Header when viewing [❤️ Liked] tab
                  if (provider.selectedFilter == 'liked' && likedCount > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Text(
                              '$likedCount Personal Favorites',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                              label: Text(
                                'Download ($likedCount)',
                                style: const TextStyle(
                                  fontSize: 12,
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

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 4. Native Edge-to-Edge Clean Photo Grid (3 Columns)
                  if (photos.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F7F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                color: _primaryColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              provider.selectedFilter == 'liked'
                                  ? 'No liked photos yet'
                                  : 'No trip photos in this vault',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              provider.selectedFilter == 'liked'
                                  ? 'Tap the heart icon on any photo to save your favorites.'
                                  : 'Upload memories before the 48-hour vault expires!',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
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
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      photo.photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFE2E8F0),
                                        child: const Icon(Icons.broken_image, color: Colors.black26),
                                      ),
                                    ),

                                    // Subtle frosted heart toggle in bottom-right corner
                                    Positioned(
                                      right: 5,
                                      bottom: 5,
                                      child: GestureDetector(
                                        onTap: () {
                                          provider.toggleLike(widget.group.id, photo.id);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.45),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            size: 15,
                                            color: isLiked ? _likedHeartColor : Colors.white,
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

            // Floating "+ Upload Photos" Button
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton.extended(
                backgroundColor: _primaryColor,
                elevation: 3,
                icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Upload Photos',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                onPressed: _handlePickAndUpload,
              ),
            ),
          ],
        );
      },
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
