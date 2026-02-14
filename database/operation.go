package database

import (
	"gorm.io/gorm"
)

func AutoMigrate(db *gorm.DB) error {
	if err := db.AutoMigrate(
		&User{},
		&TailscaleAddress{},
		&PhotoObject{},
		&PhotoDirectory{},
	); err != nil {
		return err
	}

	return nil
}

// CreateOrRestorePhotoObject creates a new PhotoObject or restores a soft-deleted one.
// If a soft-deleted record with the same ObjectID exists, it will be restored and updated
// with the new values. Otherwise, a new record will be created.
func CreateOrRestorePhotoObject(db *gorm.DB, photoObject *PhotoObject) error {
	var existing PhotoObject
	result := db.Unscoped().Where("object_id = ?", photoObject.ObjectID).First(&existing)

	if result.Error == nil {
		// Record exists (possibly soft-deleted), update and restore it
		existing.DeletedAt = gorm.DeletedAt{}
		existing.ContentType = photoObject.ContentType
		existing.MD5Hash = photoObject.MD5Hash
		existing.UserID = photoObject.UserID
		existing.TimeTaken = photoObject.TimeTaken
		return db.Unscoped().Save(&existing).Error
	}

	if result.Error == gorm.ErrRecordNotFound {
		// No existing record, create new
		return db.Create(photoObject).Error
	}

	return result.Error
}

// CreateOrRestorePhotoDirectory creates a new PhotoDirectory or restores a soft-deleted one.
// If a soft-deleted record with the same Path exists, it will be restored.
// If an active record exists, no action is taken.
// If the path is empty, no action is taken.
// Otherwise, a new record will be created.
func CreateOrRestorePhotoDirectory(db *gorm.DB, path string) error {
	if path == "" {
		return nil
	}

	var existing PhotoDirectory
	result := db.Unscoped().Where("path = ?", path).First(&existing)

	if result.Error == nil {
		if existing.DeletedAt.Valid {
			// Record exists but is soft-deleted, restore it
			existing.DeletedAt = gorm.DeletedAt{}
			return db.Unscoped().Save(&existing).Error
		}
		// Already exists and not deleted, nothing to do
		return nil
	}

	if result.Error == gorm.ErrRecordNotFound {
		// No existing record, create new
		return db.Create(&PhotoDirectory{Path: path}).Error
	}

	return result.Error
}
