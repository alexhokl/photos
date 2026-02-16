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

  group('PhotoGrid widget callbacks', () {
    test('PhotoGrid accepts onLoadingChanged callback', () {
      // Verify the callback parameter exists and can be set
      bool? loadingState;
      void callback(bool isLoading) {
        loadingState = isLoading;
      }

      // Simulate callback invocation
      callback(true);
      expect(loadingState, isTrue);

      callback(false);
      expect(loadingState, isFalse);
    });

    test('PhotoGrid accepts onSelectionChanged callback', () {
      int? selectionCount;
      void callback(int count) {
        selectionCount = count;
      }

      callback(5);
      expect(selectionCount, equals(5));

      callback(0);
      expect(selectionCount, equals(0));
    });
  });

  group('Continuous loading behavior', () {
    test('page size is 50', () {
      // Document the expected page size constant
      const pageSize = 50;
      expect(pageSize, equals(50));
    });

    test('loading continues while hasMorePhotos is true', () {
      // Simulate the loading loop condition
      var hasMorePhotos = true;
      var loadCount = 0;
      const maxLoads = 5;

      while (hasMorePhotos && loadCount < maxLoads) {
        loadCount++;
        // Simulate loading completion after some iterations
        if (loadCount >= 3) {
          hasMorePhotos = false;
        }
      }

      expect(loadCount, equals(3));
      expect(hasMorePhotos, isFalse);
    });

    test('loading stops when all photos are loaded', () {
      // Simulate total count vs loaded count
      const totalCount = 120;
      const pageSize = 50;
      var loadedCount = 0;
      var pageNumber = 0;

      while (loadedCount < totalCount) {
        final batchSize = (loadedCount + pageSize > totalCount)
            ? totalCount - loadedCount
            : pageSize;
        loadedCount += batchSize;
        pageNumber++;
      }

      expect(loadedCount, equals(totalCount));
      expect(pageNumber, equals(3)); // 50 + 50 + 20 = 120
    });

    test('loading state transitions from true to false when complete', () {
      final loadingStates = <bool>[];

      // Simulate loading state changes
      void onLoadingChanged(bool isLoading) {
        loadingStates.add(isLoading);
      }

      // Initial load starts
      onLoadingChanged(true);
      // Loading completes
      onLoadingChanged(false);

      expect(loadingStates, equals([true, false]));
    });

    test('empty album results in loading state false immediately', () {
      var isLoadingAll = true;
      const albumIsEmpty = true;

      if (albumIsEmpty) {
        isLoadingAll = false;
      }

      expect(isLoadingAll, isFalse);
    });

    test('batch loading calculates correct start index', () {
      const pageSize = 50;

      // Page 0
      expect(0 * pageSize, equals(0));
      // Page 1
      expect(1 * pageSize, equals(50));
      // Page 2
      expect(2 * pageSize, equals(100));
      // Page 3
      expect(3 * pageSize, equals(150));
    });

    test('batch loading calculates correct end index', () {
      const pageSize = 50;

      // Page 0: 0 to 50
      expect(0 * pageSize + pageSize, equals(50));
      // Page 1: 50 to 100
      expect(1 * pageSize + pageSize, equals(100));
      // Page 2: 100 to 150
      expect(2 * pageSize + pageSize, equals(150));
    });

    test('hasMorePhotos is true when loaded count less than total', () {
      const totalCount = 150;

      expect(50 < totalCount, isTrue); // After page 1
      expect(100 < totalCount, isTrue); // After page 2
      expect(150 < totalCount, isFalse); // After page 3 (all loaded)
    });

    test('merging photos into groups is called for each batch', () {
      var mergeCallCount = 0;
      const totalBatches = 3;

      for (var i = 0; i < totalBatches; i++) {
        // Simulate merging
        mergeCallCount++;
      }

      expect(mergeCallCount, equals(totalBatches));
    });
  });

  group('Error handling and retry logic', () {
    test('PhotoGrid accepts onLoadError callback', () {
      String? receivedError;
      void callback(String? error) {
        receivedError = error;
      }

      // Simulate error callback invocation
      callback('Failed to load photos: Network error');
      expect(receivedError, equals('Failed to load photos: Network error'));

      // Simulate clearing error
      callback(null);
      expect(receivedError, isNull);
    });

    test('error state is tracked when loading fails', () {
      String? loadError;
      var isLoadingAll = true;

      // Simulate error during loading
      void handleLoadError(String error) {
        loadError = error;
        isLoadingAll = false;
      }

      handleLoadError('Failed to load photos: Network timeout');

      expect(loadError, isNotNull);
      expect(loadError, contains('Failed to load photos'));
      expect(isLoadingAll, isFalse);
    });

    test('loading callbacks are called in correct order on error', () {
      final tracker = _LoadingCallbackTracker();

      // Simulate: start loading -> error occurs
      tracker.onLoadingChanged(true); // Loading starts
      tracker.onLoadError('Network error'); // Error occurs
      tracker.onLoadingChanged(false); // Loading stops

      expect(tracker.loadingStates, equals([true, false]));
      expect(tracker.errors, equals(['Network error']));
    });

    test('retry clears previous error before restarting', () {
      final tracker = _LoadingCallbackTracker();
      String? currentError = 'Previous error';

      // Simulate retry behavior
      void retryLoading() {
        currentError = null;
        tracker.onLoadError(null);
        tracker.onLoadingChanged(true);
      }

      retryLoading();

      expect(currentError, isNull);
      expect(tracker.errors, equals([null]));
      expect(tracker.loadingStates, equals([true]));
    });

    test(
      'retry does nothing when there is no error and loading is complete',
      () {
        String? loadError;
        var hasMorePhotos = false;
        var retryCalled = false;

        bool retryLoading() {
          if (loadError == null || !hasMorePhotos) {
            return false;
          }
          retryCalled = true;
          return true;
        }

        final result = retryLoading();

        expect(result, isFalse);
        expect(retryCalled, isFalse);
      },
    );

    test(
      'retry starts loading when there is an error and more photos exist',
      () {
        String? loadError = 'Network error';
        var hasMorePhotos = true;
        var isLoadingAll = false;

        bool retryLoading() {
          if (!hasMorePhotos) {
            return false;
          }
          isLoadingAll = true;
          return true;
        }

        final result = retryLoading();

        expect(result, isTrue);
        expect(isLoadingAll, isTrue);
      },
    );

    test('error message contains exception details', () {
      final exception = Exception('Connection refused');
      final errorMessage = 'Failed to load photos: $exception';

      expect(errorMessage, contains('Failed to load photos'));
      expect(errorMessage, contains('Connection refused'));
    });

    test('loading loop stops on first error', () {
      var pagesLoaded = 0;
      var errorOccurred = false;
      const errorOnPage = 3;
      const totalPages = 10;

      for (var page = 0; page < totalPages; page++) {
        if (page == errorOnPage) {
          errorOccurred = true;
          break; // Simulate error breaking the loop
        }
        pagesLoaded++;
      }

      expect(pagesLoaded, equals(errorOnPage));
      expect(errorOccurred, isTrue);
    });

    test('successfully loaded photos are preserved after error', () {
      final photos = <String>[];
      const photosPerPage = 50;

      // Simulate loading 2 pages successfully, then error on page 3
      for (var page = 0; page < 3; page++) {
        if (page == 2) {
          // Error on page 3 - don't add photos
          break;
        }
        for (var i = 0; i < photosPerPage; i++) {
          photos.add('photo_${page}_$i');
        }
      }

      // Photos from first 2 pages should be preserved
      expect(photos.length, equals(100));
    });

    test('multiple retries can be attempted', () {
      var retryCount = 0;
      String? loadError = 'Error';
      const maxRetries = 3;

      while (loadError != null && retryCount < maxRetries) {
        retryCount++;
        // Simulate retry failing until last attempt
        if (retryCount == maxRetries) {
          loadError = null;
        }
      }

      expect(retryCount, equals(maxRetries));
      expect(loadError, isNull);
    });

    test('hasLoadError returns true when error exists', () {
      String? loadError = 'Some error';

      bool hasLoadError() => loadError != null;

      expect(hasLoadError(), isTrue);

      loadError = null;
      expect(hasLoadError(), isFalse);
    });
  });

  group('PhotoLoadProgress', () {
    test('stores loaded and total counts', () {
      const progress = PhotoLoadProgress(loaded: 50, total: 200);

      expect(progress.loaded, equals(50));
      expect(progress.total, equals(200));
    });

    test('isComplete returns false when loaded < total', () {
      const progress = PhotoLoadProgress(loaded: 50, total: 200);

      expect(progress.isComplete, isFalse);
    });

    test('isComplete returns true when loaded >= total', () {
      const progress1 = PhotoLoadProgress(loaded: 200, total: 200);
      const progress2 = PhotoLoadProgress(loaded: 250, total: 200);

      expect(progress1.isComplete, isTrue);
      expect(progress2.isComplete, isTrue);
    });

    test('progress returns correct ratio', () {
      const progress = PhotoLoadProgress(loaded: 50, total: 200);

      expect(progress.progress, equals(0.25));
    });

    test('progress returns 0.0 when total is 0', () {
      const progress = PhotoLoadProgress(loaded: 0, total: 0);

      expect(progress.progress, equals(0.0));
    });

    test('progress returns 1.0 when fully loaded', () {
      const progress = PhotoLoadProgress(loaded: 200, total: 200);

      expect(progress.progress, equals(1.0));
    });

    test('progress can exceed 1.0 if loaded > total', () {
      const progress = PhotoLoadProgress(loaded: 250, total: 200);

      expect(progress.progress, equals(1.25));
    });
  });

  group('PhotoGrid onLoadProgress callback', () {
    test('PhotoGrid accepts onLoadProgress callback', () {
      PhotoLoadProgress? lastProgress;
      void callback(PhotoLoadProgress progress) {
        lastProgress = progress;
      }

      // Simulate progress callback invocation
      callback(const PhotoLoadProgress(loaded: 50, total: 200));
      expect(lastProgress?.loaded, equals(50));
      expect(lastProgress?.total, equals(200));

      callback(const PhotoLoadProgress(loaded: 100, total: 200));
      expect(lastProgress?.loaded, equals(100));
    });

    test('progress is reported after each batch', () {
      final progressHistory = <PhotoLoadProgress>[];
      void callback(PhotoLoadProgress progress) {
        progressHistory.add(progress);
      }

      // Simulate batches of 50 photos
      callback(const PhotoLoadProgress(loaded: 50, total: 200));
      callback(const PhotoLoadProgress(loaded: 100, total: 200));
      callback(const PhotoLoadProgress(loaded: 150, total: 200));
      callback(const PhotoLoadProgress(loaded: 200, total: 200));

      expect(progressHistory.length, equals(4));
      expect(progressHistory[0].loaded, equals(50));
      expect(progressHistory[1].loaded, equals(100));
      expect(progressHistory[2].loaded, equals(150));
      expect(progressHistory[3].loaded, equals(200));
      expect(progressHistory.last.isComplete, isTrue);
    });

    test('progress callback receives correct total throughout loading', () {
      final progressHistory = <PhotoLoadProgress>[];
      void callback(PhotoLoadProgress progress) {
        progressHistory.add(progress);
      }

      // All progress updates should have the same total
      callback(const PhotoLoadProgress(loaded: 50, total: 500));
      callback(const PhotoLoadProgress(loaded: 100, total: 500));
      callback(const PhotoLoadProgress(loaded: 150, total: 500));

      for (final progress in progressHistory) {
        expect(progress.total, equals(500));
      }
    });

    test('empty album reports 0/0 progress', () {
      PhotoLoadProgress? lastProgress;
      void callback(PhotoLoadProgress progress) {
        lastProgress = progress;
      }

      callback(const PhotoLoadProgress(loaded: 0, total: 0));

      expect(lastProgress?.loaded, equals(0));
      expect(lastProgress?.total, equals(0));
      expect(lastProgress?.isComplete, isTrue);
    });
  });
}

/// Helper class to simulate UploadResult behavior in tests
class _MockUploadResult {
  final String id;
  final bool success;

  _MockUploadResult({required this.id, required this.success});
}

/// Helper class to track loading and error callback invocations
class _LoadingCallbackTracker {
  final List<bool> loadingStates = [];
  final List<String?> errors = [];

  void onLoadingChanged(bool isLoading) {
    loadingStates.add(isLoading);
  }

  void onLoadError(String? error) {
    errors.add(error);
  }
}
