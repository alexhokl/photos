package database

import (
	"gorm.io/gorm"
)

type User struct {
	gorm.Model
	Username string `gorm:"not null;unique"`
}

type TailscaleAddress struct {
	Address string `gorm:"primaryKey;not null;unique"`
	UserID  uint   `gorm:"not null"`
	User    User   `gorm:"foreignKey:UserID"`
}

type PhotoObject struct {
	gorm.Model
	ObjectID    string `gorm:"not null;unique"`
	ContentType string `gorm:"not null"`
	MD5Hash     string `gorm:"not null"`
	UserID      uint   `gorm:"not null"`
	User        User   `gorm:"foreignKey:UserID"`
}

type PhotoDirectory struct {
	gorm.Model
	Path   string `gorm:"not null;unique"`
	UserID uint   `gorm:"not null"`
	User   User   `gorm:"foreignKey:UserID"`
}
