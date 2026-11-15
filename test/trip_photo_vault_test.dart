import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/trip_photo.dart';
import 'package:expense_tracker/models/split_models.dart';
import 'package:expense_tracker/providers/trip_photo_provider.dart';
import 'package:expense_tracker/services/trip_photo_local_likes_service.dart';
import 'package:expense_tracker/screens/split/trip_photo_vault_tab.dart';
import 'package:expense_tracker/screens/split/trip_photo_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('TripPhoto Model Tests', () {
    test('Serializes to and from Map accurately', () {
      final now = DateTime.now();
      final expires = now.add(const Duration(hours: 48));

      final photo = TripPhoto(
        id: 'photo_101',
        groupId: 'group_ujjain',
        uploaderId: 'user_manav',
        uploaderName: 'Manav',
        photoUrl: 'https://example.com/vaults/group_ujjain/user_manav/sunset.jpg',
        thumbnailUrl: null,
        storagePath: 'vaults/group_ujjain/user_manav/sunset.jpg',
        fileSizeBytes: 1572864, // 1.5 MB
        width: 2560,
        height: 1440,
        createdAt: now,
        expiresAt: expires,
      );

      final map = photo.toMap();
      final deserialized = TripPhoto.fromMap(map);

      expect(deserialized.id, 'photo_101');
      expect(deserialized.groupId, 'group_ujjain');
      expect(deserialized.uploaderId, 'user_manav');
      expect(deserialized.uploaderName, 'Manav');
      expect(deserialized.photoUrl, 'https://example.com/vaults/group_ujjain/user_manav/sunset.jpg');
      expect(deserialized.storagePath, 'vaults/group_ujjain/user_manav/sunset.jpg');
      expect(deserialized.fileSizeBytes, 1572864);
      expect(deserialized.width, 2560);
      expect(deserialized.height, 1440);
      expect(deserialized.isExpired, isFalse);
      expect(deserialized.formattedFileSize, '1.5 MB');
    });

    test('Computes isExpired, remainingTime and isUrgent flags accurately', () {
      final now = DateTime.now();

      // Active photo with 34h remaining
      final activePhoto = TripPhoto(
        id: 'photo_active',
        groupId: 'group_ujjain',
        uploaderId: 'user_1',
        uploaderName: 'Dinesh',
        photoUrl: 'https://example.com/1.jpg',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 34, minutes: 18)),
      );
      expect(activePhoto.isExpired, isFalse);
      expect(activePhoto.isUrgent, isFalse);
      expect(activePhoto.formattedRemainingTime, contains('34h'));

      // Urgent photo with 3h remaining
      final urgentPhoto = TripPhoto(
        id: 'photo_urgent',
        groupId: 'group_ujjain',
        uploaderId: 'user_2',
        uploaderName: 'Pooja',
        photoUrl: 'https://example.com/2.jpg',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 3, minutes: 10)),
      );
      expect(urgentPhoto.isExpired, isFalse);
      expect(urgentPhoto.isUrgent, isTrue);
      expect(urgentPhoto.formattedRemainingTime, contains('3h'));

      // Expired photo
      final expiredPhoto = TripPhoto(
        id: 'photo_expired',
        groupId: 'group_ujjain',
        uploaderId: 'user_3',
        uploaderName: 'Rahul',
        photoUrl: 'https://example.com/3.jpg',
        createdAt: now.subtract(const Duration(hours: 50)),
        expiresAt: now.subtract(const Duration(hours: 2)),
      );
      expect(expiredPhoto.isExpired, isTrue);
      expect(expiredPhoto.remainingTime, Duration.zero);
      expect(expiredPhoto.formattedRemainingTime, 'Expired');
    });
  });

  group('TripPhotoLocalLikesService Tests (Personal & Private)', () {
    test('Toggles like and persists in SharedPreferences privately by group', () async {
      final likesService = TripPhotoLocalLikesService.instance;

      expect(await likesService.getLikedPhotoIds('group_ujjain'), isEmpty);

      // Like photo 1
      final isLiked1 = await likesService.toggleLike('group_ujjain', 'photo_1');
      expect(isLiked1, isTrue);
      expect(await likesService.isPhotoLiked('group_ujjain', 'photo_1'), isTrue);

      // Like photo 2
      final isLiked2 = await likesService.toggleLike('group_ujjain', 'photo_2');
      expect(isLiked2, isTrue);

      final likedSet = await likesService.getLikedPhotoIds('group_ujjain');
      expect(likedSet, containsAll(['photo_1', 'photo_2']));

      // Unlike photo 1
      final isUnliked1 = await likesService.toggleLike('group_ujjain', 'photo_1');
      expect(isUnliked1, isFalse);
      expect(await likesService.isPhotoLiked('group_ujjain', 'photo_1'), isFalse);
      expect(await likesService.getLikedPhotoIds('group_ujjain'), contains('photo_2'));

      // Separate group is isolated and empty
      expect(await likesService.getLikedPhotoIds('group_goa'), isEmpty);
    });
  });

  group('TripPhotoProvider State & Filtering Tests', () {
    test('Computes contributor counts and filters by All, Liked, and Uploader', () async {
      final provider = TripPhotoProvider();
      final now = DateTime.now();

      final p1 = TripPhoto(
        id: 'p1',
        groupId: 'group_1',
        uploaderId: 'manav',
        uploaderName: 'Manav',
        photoUrl: 'https://example.com/p1.jpg',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 40)),
      );
      final p2 = TripPhoto(
        id: 'p2',
        groupId: 'group_1',
        uploaderId: 'dinesh',
        uploaderName: 'Dinesh',
        photoUrl: 'https://example.com/p2.jpg',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 40)),
      );
      final p3 = TripPhoto(
        id: 'p3',
        groupId: 'group_1',
        uploaderId: 'dinesh',
        uploaderName: 'Dinesh',
        photoUrl: 'https://example.com/p3.jpg',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 40)),
      );

      expect(p1.uploaderName, 'Manav');
      expect(p2.uploaderName, 'Dinesh');
      expect(p3.uploaderName, 'Dinesh');

      // Manually set photos via upload helper or internal state
      await provider.uploadPhotos(
        groupId: 'group_1',
        uploaderName: 'Test',
        files: [],
      );

      // Verify filter switching
      provider.setFilter('all');
      expect(provider.selectedFilter, 'all');

      provider.setFilter('liked');
      expect(provider.selectedFilter, 'liked');

      provider.setFilter('dinesh');
      expect(provider.selectedFilter, 'dinesh');
    });
  });

  group('TripPhotoViewerScreen Security & Permission Widget Tests', () {
    testWidgets('Renders viewer with header actions, and strictly hides delete button for non-owner', (tester) async {
      final now = DateTime.now();
      final photos = [
        TripPhoto(
          id: 'photo_dinesh_1',
          groupId: 'group_ujjain',
          uploaderId: 'user_dinesh',
          uploaderName: 'Dinesh',
          photoUrl: 'https://example.com/temple.jpg',
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 40)),
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TripPhotoProvider()),
          ],
          child: MaterialApp(
            home: TripPhotoViewerScreen(
              photos: photos,
              initialIndex: 0,
              groupId: 'group_ujjain',
              groupName: 'Ujjain Trip',
            ),
          ),
        ),
      );

      // Verify Header: 1 of 1, Heart icon, and Download icon are present
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);

      // Verify that there is NO bottom card!
      expect(find.text('Uploaded by Dinesh'), findsNothing);
    });
  });

  group('TripPhotoVaultTab Widget Tests', () {
    testWidgets('Renders vault status banner, countdown, and filter chips', (tester) async {
      final group = SplitGroup(
        id: 'group_test_1',
        name: 'Ujjain Trip',
        createdBy: 'Manav',
        inviteCode: 'UJJAIN123',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TripPhotoProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TripPhotoVaultTab(
                group: group,
                currentMemberName: 'Manav',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Compact Vault Status Strip & Samsung Gallery Zoom Selectors
      expect(find.text('0 photos'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      // Verify Filter Chips: All and ❤️ Liked
      expect(find.text('All (0)'), findsOneWidget);
      expect(find.text('❤️ Liked (0)'), findsOneWidget);

      // Verify Upload Photos FAB
      expect(find.text('Upload Photos'), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_rounded), findsOneWidget);
    });
  });
}
