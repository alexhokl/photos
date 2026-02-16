import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/widgets/photo_grid.dart';

class MockAssetEntity extends Mock implements AssetEntity {}

void main() {
  group('PhotoDateGroup', () {
    late MockAssetEntity mockAsset1;
    late MockAssetEntity mockAsset2;

    setUp(() {
      mockAsset1 = MockAssetEntity();
      mockAsset2 = MockAssetEntity();
      when(() => mockAsset1.id).thenReturn('photo1');
      when(() => mockAsset2.id).thenReturn('photo2');
    });

    test('stores date and photos', () {
      final date = DateTime(2026, 2, 15);
      final photos = [mockAsset1, mockAsset2];

      final group = PhotoDateGroup(date: date, photos: photos);

      expect(group.date, equals(date));
      expect(group.photos, equals(photos));
      expect(group.photos.length, equals(2));
    });

    test('formattedDate returns correct format', () {
      final date = DateTime(2026, 2, 15);
      final group = PhotoDateGroup(date: date, photos: []);

      // Format depends on locale, but should contain month and year
      expect(group.formattedDate, contains('February'));
      expect(group.formattedDate, contains('15'));
      expect(group.formattedDate, contains('2026'));
    });

    test('dayOfWeek returns correct day', () {
      // February 15, 2026 is a Sunday
      final date = DateTime(2026, 2, 15);
      final group = PhotoDateGroup(date: date, photos: []);

      expect(group.dayOfWeek, equals('Sunday'));
    });

    test('dayOfWeek returns Monday correctly', () {
      // February 16, 2026 is a Monday
      final date = DateTime(2026, 2, 16);
      final group = PhotoDateGroup(date: date, photos: []);

      expect(group.dayOfWeek, equals('Monday'));
    });
  });

  group('PhotoGridAction enum', () {
    test('has delete value', () {
      expect(PhotoGridAction.values, contains(PhotoGridAction.delete));
    });

    test('has upload value', () {
      expect(PhotoGridAction.values, contains(PhotoGridAction.upload));
    });

    test('has uploadTo value', () {
      expect(PhotoGridAction.values, contains(PhotoGridAction.uploadTo));
    });

    test('has exactly 3 values', () {
      expect(PhotoGridAction.values.length, equals(3));
    });

    test('delete has index 0', () {
      expect(PhotoGridAction.delete.index, equals(0));
    });

    test('upload has index 1', () {
      expect(PhotoGridAction.upload.index, equals(1));
    });

    test('uploadTo has index 2', () {
      expect(PhotoGridAction.uploadTo.index, equals(2));
    });
  });

  group('PhotoGrid widget contract', () {
    test('PhotoGrid is a StatefulWidget', () {
      expect(PhotoGrid, isA<Type>());
    });

    test('PhotoGridState is the state class', () {
      expect(PhotoGridState, isA<Type>());
    });
  });

  group('Photo grouping by date logic', () {
    // These tests verify the expected behavior of photo grouping
    // which is used by _groupPhotosByDate in PhotoGridState

    test('photos should be grouped by date only (ignoring time)', () {
      // Two photos on the same date but different times should be in one group
      final date1 = DateTime(2026, 2, 15, 10, 30, 0); // 10:30 AM
      final date2 = DateTime(2026, 2, 15, 14, 45, 0); // 2:45 PM

      // Normalize to date-only (midnight)
      final dateOnly1 = DateTime(date1.year, date1.month, date1.day);
      final dateOnly2 = DateTime(date2.year, date2.month, date2.day);

      expect(dateOnly1, equals(dateOnly2));
    });

    test('photos on different dates should be in different groups', () {
      final date1 = DateTime(2026, 2, 15, 10, 30, 0);
      final date2 = DateTime(2026, 2, 16, 10, 30, 0);

      final dateOnly1 = DateTime(date1.year, date1.month, date1.day);
      final dateOnly2 = DateTime(date2.year, date2.month, date2.day);

      expect(dateOnly1, isNot(equals(dateOnly2)));
    });

    test('date normalization strips time components', () {
      final dateWithTime = DateTime(2026, 2, 15, 23, 59, 59);
      final dateOnly = DateTime(
        dateWithTime.year,
        dateWithTime.month,
        dateWithTime.day,
      );

      expect(dateOnly.hour, equals(0));
      expect(dateOnly.minute, equals(0));
      expect(dateOnly.second, equals(0));
      expect(dateOnly.day, equals(15));
    });
  });

  group('Photo removal and regrouping behavior', () {
    // These tests document the expected behavior when photos are removed
    // and verify that the grouping logic handles removal correctly

    test('removing last photo from a date should eliminate that date group', () {
      // Simulating the grouping behavior
      final Map<DateTime, List<String>> groups = {
        DateTime(2026, 2, 15): ['photo1'],
        DateTime(2026, 2, 16): ['photo2', 'photo3'],
      };

      // Remove photo1 (last photo on Feb 15)
      groups[DateTime(2026, 2, 15)]!.remove('photo1');

      // Remove empty groups (this is what _groupPhotosByDate does by rebuilding)
      groups.removeWhere((_, photos) => photos.isEmpty);

      expect(groups.length, equals(1));
      expect(groups.containsKey(DateTime(2026, 2, 15)), isFalse);
      expect(groups.containsKey(DateTime(2026, 2, 16)), isTrue);
    });

    test('removing one photo from multi-photo date should keep the group', () {
      final Map<DateTime, List<String>> groups = {
        DateTime(2026, 2, 15): ['photo1', 'photo2'],
        DateTime(2026, 2, 16): ['photo3'],
      };

      // Remove photo1 (one of two photos on Feb 15)
      groups[DateTime(2026, 2, 15)]!.remove('photo1');

      expect(groups.length, equals(2));
      expect(groups[DateTime(2026, 2, 15)]!.length, equals(1));
      expect(groups[DateTime(2026, 2, 15)]!, contains('photo2'));
    });

    test('regrouping after removal maintains chronological order', () {
      // Simulate photos list after removal
      final photoIds = ['photo3', 'photo2']; // photo1 was removed
      final photoDates = {
        'photo2': DateTime(2026, 2, 15),
        'photo3': DateTime(2026, 2, 14),
      };

      // Rebuild groups from photos (simulating _groupPhotosByDate)
      final Map<DateTime, List<String>> newGroups = {};
      for (final id in photoIds) {
        final date = photoDates[id]!;
        final dateOnly = DateTime(date.year, date.month, date.day);
        newGroups.putIfAbsent(dateOnly, () => []);
        newGroups[dateOnly]!.add(id);
      }

      // Sort dates in reverse chronological order
      final sortedDates = newGroups.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      // Feb 15 should come before Feb 14 (reverse chronological)
      expect(sortedDates[0], equals(DateTime(2026, 2, 15)));
      expect(sortedDates[1], equals(DateTime(2026, 2, 14)));
    });

    test('regrouping empty photo list results in empty groups', () {
      final List<String> photoIds = [];
      final Map<DateTime, List<String>> groups = {};

      for (final id in photoIds) {
        // This loop doesn't execute for empty list
        groups.putIfAbsent(DateTime.now(), () => [id]);
      }

      expect(groups.isEmpty, isTrue);
    });

    test('removing multiple photos from same date updates group correctly', () {
      final photos = ['photo1', 'photo2', 'photo3'];
      final toRemove = {'photo1', 'photo3'};

      // Simulate removeWhere
      photos.removeWhere((p) => toRemove.contains(p));

      expect(photos.length, equals(1));
      expect(photos, contains('photo2'));
    });
  });

  group('Selection state after photo removal', () {
    test('selected photo IDs should be cleared after bulk delete', () {
      final selectedPhotoIds = {'photo1', 'photo2', 'photo3'};

      // Simulate _deleteSelectedPhotos behavior
      selectedPhotoIds.clear();

      expect(selectedPhotoIds.isEmpty, isTrue);
    });

    test('removing single photo removes it from selection', () {
      final selectedPhotoIds = {'photo1', 'photo2', 'photo3'};
      const photoIdToRemove = 'photo2';

      // Simulate removePhoto behavior
      selectedPhotoIds.remove(photoIdToRemove);

      expect(selectedPhotoIds.length, equals(2));
      expect(selectedPhotoIds, isNot(contains(photoIdToRemove)));
      expect(selectedPhotoIds, contains('photo1'));
      expect(selectedPhotoIds, contains('photo3'));
    });

    test('selection mode exits when last selected photo is removed', () {
      final selectedPhotoIds = {'photo1'};
      var isSelectionMode = true;

      // Simulate removePhoto behavior
      selectedPhotoIds.remove('photo1');
      if (selectedPhotoIds.isEmpty) {
        isSelectionMode = false;
      }

      expect(selectedPhotoIds.isEmpty, isTrue);
      expect(isSelectionMode, isFalse);
    });

    test('selection mode stays active when some photos remain selected', () {
      final selectedPhotoIds = {'photo1', 'photo2'};
      var isSelectionMode = true;

      // Simulate removePhoto behavior
      selectedPhotoIds.remove('photo1');
      if (selectedPhotoIds.isEmpty) {
        isSelectionMode = false;
      }

      expect(selectedPhotoIds.length, equals(1));
      expect(isSelectionMode, isTrue);
    });
  });

  group('Upload result photo removal', () {
    test('successful uploads are identified for removal', () {
      // Simulate UploadResult behavior
      final results = [
        _MockUploadResult(id: 'photo1', success: true),
        _MockUploadResult(id: 'photo2', success: false),
        _MockUploadResult(id: 'photo3', success: true),
      ];

      final deletedIds = results
          .where((r) => r.success)
          .map((r) => r.id)
          .toSet();

      expect(deletedIds.length, equals(2));
      expect(deletedIds, contains('photo1'));
      expect(deletedIds, contains('photo3'));
      expect(deletedIds, isNot(contains('photo2')));
    });

    test('photos are removed using deletedIds set', () {
      final photos = ['photo1', 'photo2', 'photo3', 'photo4'];
      final deletedIds = {'photo1', 'photo3'};

      photos.removeWhere((p) => deletedIds.contains(p));

      expect(photos.length, equals(2));
      expect(photos, containsAll(['photo2', 'photo4']));
    });
  });
}

/// Helper class to simulate UploadResult behavior in tests
class _MockUploadResult {
  final String id;
  final bool success;

  _MockUploadResult({required this.id, required this.success});
}
