package database

import (
	"testing"
	"time"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func setupTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}
	if err := AutoMigrate(db); err != nil {
		t.Fatalf("failed to migrate test database: %v", err)
	}
	return db
}

func TestCreateOrRestorePhotoDirectory_NewDirectory(t *testing.T) {
	db := setupTestDB(t)
	path := "photos/2024"

	err := CreateOrRestorePhotoDirectory(db, path)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}

	var dir PhotoDirectory
	if err := db.Where("path = ?", path).First(&dir).Error; err != nil {
		t.Errorf("expected directory to exist, got error %v", err)
	}
	if dir.Path != path {
		t.Errorf("expected path %s, got %s", path, dir.Path)
	}
	if dir.DeletedAt.Valid {
		t.Errorf("expected directory to not be soft-deleted")
	}
}

func TestCreateOrRestorePhotoDirectory_ExistingDirectory(t *testing.T) {
	db := setupTestDB(t)
	path := "photos/2024"

	// Create directory first
	if err := db.Create(&PhotoDirectory{Path: path}).Error; err != nil {
		t.Fatalf("failed to create initial directory: %v", err)
	}

	// Call CreateOrRestorePhotoDirectory again - should be a no-op
	err := CreateOrRestorePhotoDirectory(db, path)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}

	// Verify only one directory exists
	var count int64
	if err := db.Model(&PhotoDirectory{}).Where("path = ?", path).Count(&count).Error; err != nil {
		t.Errorf("failed to count directories: %v", err)
	}
	if count != 1 {
		t.Errorf("expected 1 directory, got %d", count)
	}
}

func TestCreateOrRestorePhotoDirectory_RestoreSoftDeleted(t *testing.T) {
	db := setupTestDB(t)
	path := "photos/2024"

	// Create and then soft-delete the directory
	dir := &PhotoDirectory{Path: path}
	if err := db.Create(dir).Error; err != nil {
		t.Fatalf("failed to create initial directory: %v", err)
	}
	if err := db.Delete(dir).Error; err != nil {
		t.Fatalf("failed to soft-delete directory: %v", err)
	}

	// Verify it's soft-deleted (not visible in normal query)
	var count int64
	if err := db.Model(&PhotoDirectory{}).Where("path = ?", path).Count(&count).Error; err != nil {
		t.Errorf("failed to count directories: %v", err)
	}
	if count != 0 {
		t.Errorf("expected 0 directories (soft-deleted), got %d", count)
	}

	// But exists in unscoped query
	if err := db.Unscoped().Model(&PhotoDirectory{}).Where("path = ?", path).Count(&count).Error; err != nil {
		t.Errorf("failed to count unscoped directories: %v", err)
	}
	if count != 1 {
		t.Errorf("expected 1 unscoped directory, got %d", count)
	}

	// Now restore the directory
	err := CreateOrRestorePhotoDirectory(db, path)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}

	// Verify it's restored (visible in normal query)
	var restoredDir PhotoDirectory
	if err := db.Where("path = ?", path).First(&restoredDir).Error; err != nil {
		t.Errorf("expected restored directory to exist, got error %v", err)
	}
	if restoredDir.DeletedAt.Valid {
		t.Errorf("expected directory to not be soft-deleted after restore")
	}
}

func TestCreateOrRestorePhotoDirectory_RestorePreservesTimestamps(t *testing.T) {
	db := setupTestDB(t)
	path := "photos/2024"

	// Create directory with specific created_at
	dir := &PhotoDirectory{Path: path}
	if err := db.Create(dir).Error; err != nil {
		t.Fatalf("failed to create initial directory: %v", err)
	}
	originalCreatedAt := dir.CreatedAt

	// Soft-delete the directory
	if err := db.Delete(dir).Error; err != nil {
		t.Fatalf("failed to soft-delete directory: %v", err)
	}

	// Wait a bit to ensure time difference
	time.Sleep(10 * time.Millisecond)

	// Restore the directory
	if err := CreateOrRestorePhotoDirectory(db, path); err != nil {
		t.Fatalf("failed to restore directory: %v", err)
	}

	// Verify created_at is preserved
	var restoredDir PhotoDirectory
	if err := db.Where("path = ?", path).First(&restoredDir).Error; err != nil {
		t.Errorf("expected restored directory to exist, got error %v", err)
	}
	if !restoredDir.CreatedAt.Equal(originalCreatedAt) {
		t.Errorf("expected created_at to be preserved, got %v instead of %v", restoredDir.CreatedAt, originalCreatedAt)
	}
}

func TestCreateOrRestorePhotoDirectory_MultipleRestoreCycles(t *testing.T) {
	db := setupTestDB(t)
	path := "photos/2024"

	// First cycle: create
	if err := CreateOrRestorePhotoDirectory(db, path); err != nil {
		t.Fatalf("cycle 1 create failed: %v", err)
	}

	// First cycle: delete
	if err := db.Where("path = ?", path).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("cycle 1 delete failed: %v", err)
	}

	// Second cycle: restore
	if err := CreateOrRestorePhotoDirectory(db, path); err != nil {
		t.Fatalf("cycle 2 restore failed: %v", err)
	}

	// Second cycle: delete
	if err := db.Where("path = ?", path).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("cycle 2 delete failed: %v", err)
	}

	// Third cycle: restore
	if err := CreateOrRestorePhotoDirectory(db, path); err != nil {
		t.Fatalf("cycle 3 restore failed: %v", err)
	}

	// Verify directory is active
	var dir PhotoDirectory
	if err := db.Where("path = ?", path).First(&dir).Error; err != nil {
		t.Errorf("expected directory to exist after third restore, got error %v", err)
	}
	if dir.DeletedAt.Valid {
		t.Errorf("expected directory to not be soft-deleted after third restore")
	}

	// Verify only one record exists in total
	var count int64
	if err := db.Unscoped().Model(&PhotoDirectory{}).Where("path = ?", path).Count(&count).Error; err != nil {
		t.Errorf("failed to count unscoped directories: %v", err)
	}
	if count != 1 {
		t.Errorf("expected exactly 1 directory record (including soft-deleted), got %d", count)
	}
}

func TestCreateOrRestorePhotoObject_NewObject(t *testing.T) {
	db := setupTestDB(t)

	// Create a user first (required for foreign key)
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	photoObject := &PhotoObject{
		ObjectID:    "photos/2024/image.jpg",
		ContentType: "image/jpeg",
		MD5Hash:     "abc123",
		UserID:      user.ID,
	}

	err := CreateOrRestorePhotoObject(db, photoObject)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}

	var obj PhotoObject
	if err := db.Where("object_id = ?", photoObject.ObjectID).First(&obj).Error; err != nil {
		t.Errorf("expected photo object to exist, got error %v", err)
	}
	if obj.ContentType != "image/jpeg" {
		t.Errorf("expected content type 'image/jpeg', got '%s'", obj.ContentType)
	}
}

func TestCreateOrRestorePhotoObject_RestoreSoftDeleted(t *testing.T) {
	db := setupTestDB(t)

	// Create a user first
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	objectID := "photos/2024/image.jpg"

	// Create and then soft-delete the photo object
	obj := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "abc123",
		UserID:      user.ID,
	}
	if err := db.Create(obj).Error; err != nil {
		t.Fatalf("failed to create initial photo object: %v", err)
	}
	if err := db.Delete(obj).Error; err != nil {
		t.Fatalf("failed to soft-delete photo object: %v", err)
	}

	// Verify it's soft-deleted
	var count int64
	if err := db.Model(&PhotoObject{}).Where("object_id = ?", objectID).Count(&count).Error; err != nil {
		t.Errorf("failed to count photo objects: %v", err)
	}
	if count != 0 {
		t.Errorf("expected 0 photo objects (soft-deleted), got %d", count)
	}

	// Restore with new metadata
	newObj := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/png",
		MD5Hash:     "def456",
		UserID:      user.ID,
	}
	if err := CreateOrRestorePhotoObject(db, newObj); err != nil {
		t.Fatalf("failed to restore photo object: %v", err)
	}

	// Verify it's restored with new metadata
	var restoredObj PhotoObject
	if err := db.Where("object_id = ?", objectID).First(&restoredObj).Error; err != nil {
		t.Errorf("expected restored photo object to exist, got error %v", err)
	}
	if restoredObj.DeletedAt.Valid {
		t.Errorf("expected photo object to not be soft-deleted after restore")
	}
	if restoredObj.ContentType != "image/png" {
		t.Errorf("expected content type 'image/png', got '%s'", restoredObj.ContentType)
	}
	if restoredObj.MD5Hash != "def456" {
		t.Errorf("expected MD5 hash 'def456', got '%s'", restoredObj.MD5Hash)
	}
}

func TestCreateOrRestorePhotoObject_UpdateExistingActive(t *testing.T) {
	db := setupTestDB(t)

	// Create a user first
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	objectID := "photos/2024/image.jpg"

	// Create photo object
	obj := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "abc123",
		UserID:      user.ID,
	}
	if err := db.Create(obj).Error; err != nil {
		t.Fatalf("failed to create initial photo object: %v", err)
	}

	// Call CreateOrRestorePhotoObject with updated metadata
	updatedObj := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/png",
		MD5Hash:     "def456",
		UserID:      user.ID,
	}
	if err := CreateOrRestorePhotoObject(db, updatedObj); err != nil {
		t.Fatalf("failed to update photo object: %v", err)
	}

	// Verify it's updated
	var resultObj PhotoObject
	if err := db.Where("object_id = ?", objectID).First(&resultObj).Error; err != nil {
		t.Errorf("expected photo object to exist, got error %v", err)
	}
	if resultObj.ContentType != "image/png" {
		t.Errorf("expected content type 'image/png', got '%s'", resultObj.ContentType)
	}
	if resultObj.MD5Hash != "def456" {
		t.Errorf("expected MD5 hash 'def456', got '%s'", resultObj.MD5Hash)
	}
}

// Tests simulating SyncDatabase scenarios for directory un-delete

func TestSyncScenario_RestoreDeletedPhotoAndDirectory(t *testing.T) {
	db := setupTestDB(t)

	// Create a user
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	objectID := "photos/2024/image.jpg"
	dirPath := "photos/2024"

	// Simulate initial state: photo and directory exist
	photo := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "abc123",
		UserID:      user.ID,
	}
	if err := db.Create(photo).Error; err != nil {
		t.Fatalf("failed to create photo: %v", err)
	}
	dir := &PhotoDirectory{Path: dirPath}
	if err := db.Create(dir).Error; err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}

	// Simulate: both photo and directory are soft-deleted
	if err := db.Delete(photo).Error; err != nil {
		t.Fatalf("failed to soft-delete photo: %v", err)
	}
	if err := db.Delete(dir).Error; err != nil {
		t.Fatalf("failed to soft-delete directory: %v", err)
	}

	// Verify both are soft-deleted
	var photoCount, dirCount int64
	db.Model(&PhotoObject{}).Where("object_id = ?", objectID).Count(&photoCount)
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if photoCount != 0 || dirCount != 0 {
		t.Fatalf("expected both to be soft-deleted, got photo=%d, dir=%d", photoCount, dirCount)
	}

	// Simulate SyncDatabase: restore photo and directory
	newPhoto := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "abc123",
		UserID:      user.ID,
	}
	if err := CreateOrRestorePhotoObject(db, newPhoto); err != nil {
		t.Fatalf("failed to restore photo: %v", err)
	}
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to restore directory: %v", err)
	}

	// Verify both are restored
	db.Model(&PhotoObject{}).Where("object_id = ?", objectID).Count(&photoCount)
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if photoCount != 1 {
		t.Errorf("expected 1 photo after restore, got %d", photoCount)
	}
	if dirCount != 1 {
		t.Errorf("expected 1 directory after restore, got %d", dirCount)
	}
}

func TestSyncScenario_RestorePhotoInDeletedDirectory_MultiplePaths(t *testing.T) {
	db := setupTestDB(t)

	// Create a user
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	// Create multiple photos in different directories
	photos := []struct {
		objectID string
		dirPath  string
	}{
		{"photos/2024/jan/image1.jpg", "photos/2024/jan"},
		{"photos/2024/feb/image2.jpg", "photos/2024/feb"},
		{"photos/2024/mar/image3.jpg", "photos/2024/mar"},
	}

	// Create all photos and directories
	for _, p := range photos {
		photo := &PhotoObject{
			ObjectID:    p.objectID,
			ContentType: "image/jpeg",
			MD5Hash:     "hash",
			UserID:      user.ID,
		}
		if err := db.Create(photo).Error; err != nil {
			t.Fatalf("failed to create photo %s: %v", p.objectID, err)
		}
		if err := CreateOrRestorePhotoDirectory(db, p.dirPath); err != nil {
			t.Fatalf("failed to create directory %s: %v", p.dirPath, err)
		}
	}

	// Soft-delete all photos and directories
	for _, p := range photos {
		if err := db.Where("object_id = ?", p.objectID).Delete(&PhotoObject{}).Error; err != nil {
			t.Fatalf("failed to delete photo %s: %v", p.objectID, err)
		}
		if err := db.Where("path = ?", p.dirPath).Delete(&PhotoDirectory{}).Error; err != nil {
			t.Fatalf("failed to delete directory %s: %v", p.dirPath, err)
		}
	}

	// Restore only the first photo and its directory (simulating partial sync)
	firstPhoto := &PhotoObject{
		ObjectID:    photos[0].objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "hash",
		UserID:      user.ID,
	}
	if err := CreateOrRestorePhotoObject(db, firstPhoto); err != nil {
		t.Fatalf("failed to restore first photo: %v", err)
	}
	if err := CreateOrRestorePhotoDirectory(db, photos[0].dirPath); err != nil {
		t.Fatalf("failed to restore first directory: %v", err)
	}

	// Verify only the first photo and directory are restored
	var count int64
	db.Model(&PhotoObject{}).Count(&count)
	if count != 1 {
		t.Errorf("expected 1 active photo, got %d", count)
	}

	db.Model(&PhotoDirectory{}).Count(&count)
	if count != 1 {
		t.Errorf("expected 1 active directory, got %d", count)
	}

	// Verify the correct directory is restored
	var restoredDir PhotoDirectory
	if err := db.First(&restoredDir).Error; err != nil {
		t.Errorf("expected restored directory, got error %v", err)
	}
	if restoredDir.Path != photos[0].dirPath {
		t.Errorf("expected path %s, got %s", photos[0].dirPath, restoredDir.Path)
	}
}

func TestSyncScenario_DirectoryWithMixedPhotos(t *testing.T) {
	db := setupTestDB(t)

	// Create a user
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	dirPath := "photos/2024"

	// Create directory and two photos in it
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}

	photo1 := &PhotoObject{
		ObjectID:    "photos/2024/image1.jpg",
		ContentType: "image/jpeg",
		MD5Hash:     "hash1",
		UserID:      user.ID,
	}
	photo2 := &PhotoObject{
		ObjectID:    "photos/2024/image2.jpg",
		ContentType: "image/jpeg",
		MD5Hash:     "hash2",
		UserID:      user.ID,
	}
	if err := db.Create(photo1).Error; err != nil {
		t.Fatalf("failed to create photo1: %v", err)
	}
	if err := db.Create(photo2).Error; err != nil {
		t.Fatalf("failed to create photo2: %v", err)
	}

	// Soft-delete only photo1 (photo2 remains active)
	if err := db.Delete(photo1).Error; err != nil {
		t.Fatalf("failed to delete photo1: %v", err)
	}

	// Directory should still be active because photo2 is still there
	var dirCount int64
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if dirCount != 1 {
		t.Errorf("expected directory to still exist, got count %d", dirCount)
	}

	// Restore photo1
	newPhoto1 := &PhotoObject{
		ObjectID:    "photos/2024/image1.jpg",
		ContentType: "image/jpeg",
		MD5Hash:     "hash1_updated",
		UserID:      user.ID,
	}
	if err := CreateOrRestorePhotoObject(db, newPhoto1); err != nil {
		t.Fatalf("failed to restore photo1: %v", err)
	}
	// Also call CreateOrRestorePhotoDirectory (as SyncDatabase would)
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to ensure directory exists: %v", err)
	}

	// Verify both photos are active
	var photoCount int64
	db.Model(&PhotoObject{}).Where("object_id LIKE ?", dirPath+"/%").Count(&photoCount)
	if photoCount != 2 {
		t.Errorf("expected 2 active photos, got %d", photoCount)
	}

	// Verify only one directory record exists (not duplicated)
	db.Unscoped().Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if dirCount != 1 {
		t.Errorf("expected exactly 1 directory record, got %d", dirCount)
	}
}

func TestSyncScenario_DirectorySoftDeletedButPhotoActive(t *testing.T) {
	db := setupTestDB(t)

	// Create a user
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	dirPath := "photos/2024"
	objectID := "photos/2024/image.jpg"

	// Create directory and photo
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}
	photo := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "hash",
		UserID:      user.ID,
	}
	if err := db.Create(photo).Error; err != nil {
		t.Fatalf("failed to create photo: %v", err)
	}

	// Anomalous state: directory is soft-deleted but photo is still active
	// This could happen due to a bug or incomplete operation
	if err := db.Where("path = ?", dirPath).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("failed to delete directory: %v", err)
	}

	// Verify photo is still active
	var photoCount int64
	db.Model(&PhotoObject{}).Where("object_id = ?", objectID).Count(&photoCount)
	if photoCount != 1 {
		t.Errorf("expected photo to still be active, got count %d", photoCount)
	}

	// Verify directory is soft-deleted
	var dirCount int64
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if dirCount != 0 {
		t.Errorf("expected directory to be soft-deleted, got count %d", dirCount)
	}

	// Simulate SyncDatabase running and calling CreateOrRestorePhotoDirectory
	// (the sync would see the photo exists in GCS, and try to ensure directory exists)
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to restore directory: %v", err)
	}

	// Verify directory is now restored
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if dirCount != 1 {
		t.Errorf("expected directory to be restored, got count %d", dirCount)
	}
}

func TestSyncScenario_NestedDirectoryRestore(t *testing.T) {
	db := setupTestDB(t)

	// Create a user
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	// Note: The current implementation only creates/restores the immediate parent directory,
	// not the full path hierarchy. This test verifies that behavior.
	objectID := "photos/2024/jan/vacation/image.jpg"
	immediateDir := "photos/2024/jan/vacation"

	// Create and soft-delete a photo and its immediate directory
	photo := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "hash",
		UserID:      user.ID,
	}
	if err := db.Create(photo).Error; err != nil {
		t.Fatalf("failed to create photo: %v", err)
	}
	if err := CreateOrRestorePhotoDirectory(db, immediateDir); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}

	// Soft-delete both
	if err := db.Delete(photo).Error; err != nil {
		t.Fatalf("failed to delete photo: %v", err)
	}
	if err := db.Where("path = ?", immediateDir).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("failed to delete directory: %v", err)
	}

	// Simulate SyncDatabase restoring the photo and directory
	newPhoto := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "hash",
		UserID:      user.ID,
	}
	if err := CreateOrRestorePhotoObject(db, newPhoto); err != nil {
		t.Fatalf("failed to restore photo: %v", err)
	}
	if err := CreateOrRestorePhotoDirectory(db, immediateDir); err != nil {
		t.Fatalf("failed to restore directory: %v", err)
	}

	// Verify photo and directory are restored
	var photoCount, dirCount int64
	db.Model(&PhotoObject{}).Where("object_id = ?", objectID).Count(&photoCount)
	db.Model(&PhotoDirectory{}).Where("path = ?", immediateDir).Count(&dirCount)

	if photoCount != 1 {
		t.Errorf("expected 1 photo, got %d", photoCount)
	}
	if dirCount != 1 {
		t.Errorf("expected 1 directory, got %d", dirCount)
	}
}

func TestSyncScenario_EmptyDirectoryPath(t *testing.T) {
	db := setupTestDB(t)

	// When a photo is at root level (no directory), ExtractDirectoryFromPath returns ""
	// CreateOrRestorePhotoDirectory should handle empty path gracefully

	// This tests that calling CreateOrRestorePhotoDirectory with empty string doesn't cause errors
	err := CreateOrRestorePhotoDirectory(db, "")
	if err != nil {
		t.Errorf("expected no error for empty path, got %v", err)
	}

	// Verify no directory was created
	var count int64
	db.Model(&PhotoDirectory{}).Count(&count)
	if count != 0 {
		t.Errorf("expected no directories for empty path, got %d", count)
	}
}

func TestSyncScenario_DirectoryRestoredBeforePhotoFails(t *testing.T) {
	db := setupTestDB(t)

	// Create a user
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	dirPath := "photos/2024"
	objectID := "photos/2024/image.jpg"

	// Create and soft-delete directory (simulating a previous deletion)
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}
	if err := db.Where("path = ?", dirPath).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("failed to delete directory: %v", err)
	}

	// Now simulate a sync where directory restoration happens first,
	// but photo creation fails (we won't actually fail it, just check the order is safe)
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to restore directory: %v", err)
	}

	// Verify directory is restored even without a photo
	var dirCount int64
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if dirCount != 1 {
		t.Errorf("expected 1 directory, got %d", dirCount)
	}

	// Now create the photo
	photo := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "hash",
		UserID:      user.ID,
	}
	if err := CreateOrRestorePhotoObject(db, photo); err != nil {
		t.Fatalf("failed to create photo: %v", err)
	}

	// Verify both exist
	var photoCount int64
	db.Model(&PhotoObject{}).Where("object_id = ?", objectID).Count(&photoCount)
	if photoCount != 1 {
		t.Errorf("expected 1 photo, got %d", photoCount)
	}
}

func TestSyncScenario_PhotoRestoredDirectoryNotRestored(t *testing.T) {
	db := setupTestDB(t)

	// This test simulates what would happen if CreateOrRestorePhotoDirectory
	// is NOT called after restoring a photo (a potential bug scenario)

	// Create a user
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	dirPath := "photos/2024"
	objectID := "photos/2024/image.jpg"

	// Create photo and directory, then soft-delete both
	photo := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "hash",
		UserID:      user.ID,
	}
	if err := db.Create(photo).Error; err != nil {
		t.Fatalf("failed to create photo: %v", err)
	}
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}
	if err := db.Delete(photo).Error; err != nil {
		t.Fatalf("failed to delete photo: %v", err)
	}
	if err := db.Where("path = ?", dirPath).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("failed to delete directory: %v", err)
	}

	// Restore ONLY the photo (simulating a bug where directory restoration is skipped)
	newPhoto := &PhotoObject{
		ObjectID:    objectID,
		ContentType: "image/jpeg",
		MD5Hash:     "hash",
		UserID:      user.ID,
	}
	if err := CreateOrRestorePhotoObject(db, newPhoto); err != nil {
		t.Fatalf("failed to restore photo: %v", err)
	}

	// Verify photo is restored
	var photoCount int64
	db.Model(&PhotoObject{}).Where("object_id = ?", objectID).Count(&photoCount)
	if photoCount != 1 {
		t.Errorf("expected 1 photo, got %d", photoCount)
	}

	// Directory should still be soft-deleted (showing the inconsistency)
	var dirCount int64
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if dirCount != 0 {
		t.Errorf("expected 0 directories (still soft-deleted), got %d", dirCount)
	}

	// This test documents the inconsistent state that can occur if directory
	// restoration is not called after photo restoration. The fix is to always
	// call CreateOrRestorePhotoDirectory after CreateOrRestorePhotoObject in SyncDatabase.
}

func TestSyncScenario_MultiplePhotosInSameDirectoryRestore(t *testing.T) {
	db := setupTestDB(t)

	// Create a user
	user := &User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	dirPath := "photos/2024"
	objectIDs := []string{
		"photos/2024/image1.jpg",
		"photos/2024/image2.jpg",
		"photos/2024/image3.jpg",
	}

	// Create all photos and directory
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}
	for _, id := range objectIDs {
		photo := &PhotoObject{
			ObjectID:    id,
			ContentType: "image/jpeg",
			MD5Hash:     "hash",
			UserID:      user.ID,
		}
		if err := db.Create(photo).Error; err != nil {
			t.Fatalf("failed to create photo %s: %v", id, err)
		}
	}

	// Soft-delete all photos and directory
	for _, id := range objectIDs {
		if err := db.Where("object_id = ?", id).Delete(&PhotoObject{}).Error; err != nil {
			t.Fatalf("failed to delete photo %s: %v", id, err)
		}
	}
	if err := db.Where("path = ?", dirPath).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("failed to delete directory: %v", err)
	}

	// Simulate SyncDatabase restoring photos one by one, each calling CreateOrRestorePhotoDirectory
	for _, id := range objectIDs {
		photo := &PhotoObject{
			ObjectID:    id,
			ContentType: "image/jpeg",
			MD5Hash:     "hash",
			UserID:      user.ID,
		}
		if err := CreateOrRestorePhotoObject(db, photo); err != nil {
			t.Fatalf("failed to restore photo %s: %v", id, err)
		}
		if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
			t.Fatalf("failed to restore directory for %s: %v", id, err)
		}
	}

	// Verify all photos are restored
	var photoCount int64
	db.Model(&PhotoObject{}).Where("object_id LIKE ?", dirPath+"/%").Count(&photoCount)
	if photoCount != 3 {
		t.Errorf("expected 3 photos, got %d", photoCount)
	}

	// Verify only one directory record exists (not duplicated by multiple restore calls)
	var dirCount int64
	db.Unscoped().Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if dirCount != 1 {
		t.Errorf("expected exactly 1 directory record, got %d", dirCount)
	}

	// Verify directory is active
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&dirCount)
	if dirCount != 1 {
		t.Errorf("expected 1 active directory, got %d", dirCount)
	}
}

func TestSyncScenario_DirectoryDeletedAtUpdatedAfterRestore(t *testing.T) {
	db := setupTestDB(t)

	dirPath := "photos/2024"

	// Create directory
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}

	// Soft-delete directory
	if err := db.Where("path = ?", dirPath).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("failed to delete directory: %v", err)
	}

	// Get the soft-deleted record
	var deletedDir PhotoDirectory
	if err := db.Unscoped().Where("path = ?", dirPath).First(&deletedDir).Error; err != nil {
		t.Fatalf("failed to get deleted directory: %v", err)
	}
	if !deletedDir.DeletedAt.Valid {
		t.Fatalf("expected directory to have valid DeletedAt")
	}

	// Restore directory
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to restore directory: %v", err)
	}

	// Verify DeletedAt is now null/invalid
	var restoredDir PhotoDirectory
	if err := db.Unscoped().Where("path = ?", dirPath).First(&restoredDir).Error; err != nil {
		t.Fatalf("failed to get restored directory: %v", err)
	}
	if restoredDir.DeletedAt.Valid {
		t.Errorf("expected DeletedAt to be null after restore, got %v", restoredDir.DeletedAt.Time)
	}
}

func TestSyncScenario_ConcurrentDirectoryRestore(t *testing.T) {
	db := setupTestDB(t)

	dirPath := "photos/2024"

	// Create and soft-delete directory
	if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}
	if err := db.Where("path = ?", dirPath).Delete(&PhotoDirectory{}).Error; err != nil {
		t.Fatalf("failed to delete directory: %v", err)
	}

	// Simulate multiple concurrent restore calls (not truly concurrent, but rapid sequential)
	for i := 0; i < 5; i++ {
		if err := CreateOrRestorePhotoDirectory(db, dirPath); err != nil {
			t.Errorf("restore call %d failed: %v", i, err)
		}
	}

	// Verify only one directory exists
	var count int64
	db.Unscoped().Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&count)
	if count != 1 {
		t.Errorf("expected 1 directory record after multiple restores, got %d", count)
	}

	// Verify directory is active
	db.Model(&PhotoDirectory{}).Where("path = ?", dirPath).Count(&count)
	if count != 1 {
		t.Errorf("expected 1 active directory, got %d", count)
	}
}
