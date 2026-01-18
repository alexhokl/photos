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
