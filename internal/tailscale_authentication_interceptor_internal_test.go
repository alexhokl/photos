package internal

import (
	"testing"

	"github.com/alexhokl/photos/database"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func setupTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}
	if err := database.AutoMigrate(db); err != nil {
		t.Fatalf("failed to migrate test database: %v", err)
	}
	return db
}

func TestGetAddressInfo_NotFound(t *testing.T) {
	db := setupTestDB(t)

	userID, ok := getAddressInfo(db, "192.168.1.1")
	if ok {
		t.Errorf("expected ok=false for non-existent address, got true")
	}
	if userID != 0 {
		t.Errorf("expected userID=0 for non-existent address, got %d", userID)
	}
}

func TestGetAddressInfo_Found(t *testing.T) {
	db := setupTestDB(t)

	// Create a user first
	user := &database.User{Username: "testuser"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}

	// Create an address entry
	addr := &database.TailscaleAddress{
		Address: "100.64.0.1",
		UserID:  user.ID,
	}
	if err := db.Create(addr).Error; err != nil {
		t.Fatalf("failed to create address: %v", err)
	}

	userID, ok := getAddressInfo(db, "100.64.0.1")
	if !ok {
		t.Errorf("expected ok=true for existing address, got false")
	}
	if userID != user.ID {
		t.Errorf("expected userID=%d, got %d", user.ID, userID)
	}
}

func TestGetAddressInfo_MultipleAddresses(t *testing.T) {
	db := setupTestDB(t)

	// Create two users
	user1 := &database.User{Username: "user1"}
	user2 := &database.User{Username: "user2"}
	if err := db.Create(user1).Error; err != nil {
		t.Fatalf("failed to create user1: %v", err)
	}
	if err := db.Create(user2).Error; err != nil {
		t.Fatalf("failed to create user2: %v", err)
	}

	// Create addresses for each user
	addr1 := &database.TailscaleAddress{Address: "100.64.0.1", UserID: user1.ID}
	addr2 := &database.TailscaleAddress{Address: "100.64.0.2", UserID: user2.ID}
	if err := db.Create(addr1).Error; err != nil {
		t.Fatalf("failed to create addr1: %v", err)
	}
	if err := db.Create(addr2).Error; err != nil {
		t.Fatalf("failed to create addr2: %v", err)
	}

	// Test first address
	userID, ok := getAddressInfo(db, "100.64.0.1")
	if !ok {
		t.Errorf("expected ok=true for addr1, got false")
	}
	if userID != user1.ID {
		t.Errorf("expected userID=%d for addr1, got %d", user1.ID, userID)
	}

	// Test second address
	userID, ok = getAddressInfo(db, "100.64.0.2")
	if !ok {
		t.Errorf("expected ok=true for addr2, got false")
	}
	if userID != user2.ID {
		t.Errorf("expected userID=%d for addr2, got %d", user2.ID, userID)
	}

	// Test non-existent address
	_, ok = getAddressInfo(db, "100.64.0.99")
	if ok {
		t.Errorf("expected ok=false for non-existent address, got true")
	}
}

func TestGetOrCreateUser_CreateNew(t *testing.T) {
	db := setupTestDB(t)

	user, err := getOrCreateUser(db, "newuser@example.com")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user == nil {
		t.Fatalf("expected user to be non-nil")
	}
	if user.Username != "newuser@example.com" {
		t.Errorf("expected username 'newuser@example.com', got %q", user.Username)
	}
	if user.ID == 0 {
		t.Errorf("expected user ID to be set, got 0")
	}

	// Verify user was created in the database
	var count int64
	db.Model(&database.User{}).Where("username = ?", "newuser@example.com").Count(&count)
	if count != 1 {
		t.Errorf("expected 1 user in database, got %d", count)
	}
}

func TestGetOrCreateUser_GetExisting(t *testing.T) {
	db := setupTestDB(t)

	// Create user first
	existingUser := &database.User{Username: "existing@example.com"}
	if err := db.Create(existingUser).Error; err != nil {
		t.Fatalf("failed to create existing user: %v", err)
	}
	originalID := existingUser.ID

	// Call getOrCreateUser - should return existing user
	user, err := getOrCreateUser(db, "existing@example.com")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user == nil {
		t.Fatalf("expected user to be non-nil")
	}
	if user.ID != originalID {
		t.Errorf("expected user ID %d, got %d", originalID, user.ID)
	}
	if user.Username != "existing@example.com" {
		t.Errorf("expected username 'existing@example.com', got %q", user.Username)
	}

	// Verify no duplicate was created
	var count int64
	db.Model(&database.User{}).Where("username = ?", "existing@example.com").Count(&count)
	if count != 1 {
		t.Errorf("expected exactly 1 user in database, got %d", count)
	}
}

func TestGetOrCreateUser_MultipleCalls(t *testing.T) {
	db := setupTestDB(t)

	// Call multiple times for the same username
	user1, err := getOrCreateUser(db, "multiuser@example.com")
	if err != nil {
		t.Fatalf("first call unexpected error: %v", err)
	}

	user2, err := getOrCreateUser(db, "multiuser@example.com")
	if err != nil {
		t.Fatalf("second call unexpected error: %v", err)
	}

	user3, err := getOrCreateUser(db, "multiuser@example.com")
	if err != nil {
		t.Fatalf("third call unexpected error: %v", err)
	}

	// All should return the same user ID
	if user1.ID != user2.ID || user2.ID != user3.ID {
		t.Errorf("expected same user ID from all calls, got %d, %d, %d", user1.ID, user2.ID, user3.ID)
	}

	// Verify only one user was created
	var count int64
	db.Model(&database.User{}).Where("username = ?", "multiuser@example.com").Count(&count)
	if count != 1 {
		t.Errorf("expected exactly 1 user in database, got %d", count)
	}
}

func TestGetOrCreateUser_DifferentUsers(t *testing.T) {
	db := setupTestDB(t)

	user1, err := getOrCreateUser(db, "user1@example.com")
	if err != nil {
		t.Fatalf("user1 unexpected error: %v", err)
	}

	user2, err := getOrCreateUser(db, "user2@example.com")
	if err != nil {
		t.Fatalf("user2 unexpected error: %v", err)
	}

	if user1.ID == user2.ID {
		t.Errorf("expected different user IDs, both got %d", user1.ID)
	}
	if user1.Username != "user1@example.com" {
		t.Errorf("user1 username mismatch: expected 'user1@example.com', got %q", user1.Username)
	}
	if user2.Username != "user2@example.com" {
		t.Errorf("user2 username mismatch: expected 'user2@example.com', got %q", user2.Username)
	}

	// Verify two users were created
	var count int64
	db.Model(&database.User{}).Count(&count)
	if count != 2 {
		t.Errorf("expected 2 users in database, got %d", count)
	}
}
