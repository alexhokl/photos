package internal

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/alexhokl/photos/database"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"tailscale.com/client/tailscale/apitype"
	"tailscale.com/tailcfg"
)

// fakeCallerIdentityLookup is a test double for callerIdentityLookup, so the
// WhoIs-based authentication decisions can be tested without a live tsnet
// node.
type fakeCallerIdentityLookup struct {
	calls int
	resp  *apitype.WhoIsResponse
	err   error
}

func (f *fakeCallerIdentityLookup) GetCallerIdentityFromRemoteIPAddress(_ context.Context, _ string) (*apitype.WhoIsResponse, error) {
	f.calls++
	return f.resp, f.err
}

func whoIsResponseForLogin(loginName string) *apitype.WhoIsResponse {
	return &apitype.WhoIsResponse{
		UserProfile: &tailcfg.UserProfile{LoginName: loginName},
	}
}

// fakeServerStream is a minimal grpc.ServerStream test double that only
// needs to carry a context.
type fakeServerStream struct {
	ctx context.Context
}

func (f *fakeServerStream) SetHeader(metadata.MD) error  { return nil }
func (f *fakeServerStream) SendHeader(metadata.MD) error { return nil }
func (f *fakeServerStream) SetTrailer(metadata.MD)       {}
func (f *fakeServerStream) Context() context.Context     { return f.ctx }
func (f *fakeServerStream) SendMsg(any) error            { return nil }
func (f *fakeServerStream) RecvMsg(any) error            { return nil }

func contextWithPeerAddress(addr string) context.Context {
	return peer.NewContext(context.Background(), &peer.Peer{
		Addr: &net.TCPAddr{IP: net.ParseIP(addr), Port: 54321},
	})
}

func TestIntercept_CacheHit_SkipsWhoIsLookup(t *testing.T) {
	db := setupTestDB(t)
	user := &database.User{Username: "cached@example.com"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}
	if err := db.Create(&database.TailscaleAddress{Address: "100.64.0.1", UserID: user.ID}).Error; err != nil {
		t.Fatalf("failed to create cached address: %v", err)
	}

	fake := &fakeCallerIdentityLookup{}
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: fake}

	var gotUserID uint
	handler := func(ctx context.Context, req any) (any, error) {
		gotUserID, _ = ctx.Value(contextKeyUser{}).(uint)
		return "ok", nil
	}

	resp, err := interceptor.Intercept(contextWithPeerAddress("100.64.0.1"), nil, nil, handler)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp != "ok" {
		t.Errorf("expected handler response %q, got %v", "ok", resp)
	}
	if gotUserID != user.ID {
		t.Errorf("expected userID %d in context, got %d", user.ID, gotUserID)
	}
	if fake.calls != 0 {
		t.Errorf("expected WhoIs lookup to be skipped on cache hit, called %d times", fake.calls)
	}
}

func TestIntercept_WhoIsSuccess_CreatesUserAndCachesAddress(t *testing.T) {
	db := setupTestDB(t)
	fake := &fakeCallerIdentityLookup{resp: whoIsResponseForLogin("newuser@example.com")}
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: fake}

	var gotUserID uint
	handler := func(ctx context.Context, req any) (any, error) {
		gotUserID, _ = ctx.Value(contextKeyUser{}).(uint)
		return "ok", nil
	}

	if _, err := interceptor.Intercept(contextWithPeerAddress("100.64.0.2"), nil, nil, handler); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gotUserID == 0 {
		t.Errorf("expected a non-zero userID to be set in context")
	}
	if fake.calls != 1 {
		t.Errorf("expected exactly 1 WhoIs lookup, got %d", fake.calls)
	}

	userID, ok := getAddressInfo(db, "100.64.0.2")
	if !ok {
		t.Fatalf("expected address to be cached after successful WhoIs lookup")
	}
	if userID != gotUserID {
		t.Errorf("expected cached userID %d to match context userID %d", userID, gotUserID)
	}

	// A second call from the same address should now be served from cache.
	if _, err := interceptor.Intercept(contextWithPeerAddress("100.64.0.2"), nil, nil, handler); err != nil {
		t.Fatalf("unexpected error on second call: %v", err)
	}
	if fake.calls != 1 {
		t.Errorf("expected WhoIs lookup not to be repeated once cached, called %d times", fake.calls)
	}
}

func TestIntercept_WhoIsFailure_ReturnsUnauthenticated(t *testing.T) {
	db := setupTestDB(t)
	fake := &fakeCallerIdentityLookup{err: errors.New("peer not found")}
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: fake}

	handlerCalled := false
	handler := func(ctx context.Context, req any) (any, error) {
		handlerCalled = true
		return "ok", nil
	}

	_, err := interceptor.Intercept(contextWithPeerAddress("100.64.0.3"), nil, nil, handler)
	if err == nil {
		t.Fatalf("expected an error, got nil")
	}
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("expected codes.Unauthenticated, got %v", status.Code(err))
	}
	if handlerCalled {
		t.Errorf("expected handler not to be called on authentication failure")
	}
}

func TestIntercept_NoPeerInContext_ReturnsInternal(t *testing.T) {
	db := setupTestDB(t)
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: &fakeCallerIdentityLookup{}}

	handler := func(ctx context.Context, req any) (any, error) {
		return "ok", nil
	}

	_, err := interceptor.Intercept(context.Background(), nil, nil, handler)
	if err == nil {
		t.Fatalf("expected an error, got nil")
	}
	if status.Code(err) != codes.Internal {
		t.Errorf("expected codes.Internal, got %v", status.Code(err))
	}
}

func TestInterceptStream_WhoIsSuccess_WrapsContextWithUserID(t *testing.T) {
	db := setupTestDB(t)
	fake := &fakeCallerIdentityLookup{resp: whoIsResponseForLogin("streamuser@example.com")}
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: fake}

	stream := &fakeServerStream{ctx: contextWithPeerAddress("100.64.0.4")}

	var gotUserID uint
	handler := func(srv any, ss grpc.ServerStream) error {
		gotUserID, _ = ss.Context().Value(contextKeyUser{}).(uint)
		return nil
	}

	if err := interceptor.InterceptStream(nil, stream, nil, handler); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gotUserID == 0 {
		t.Errorf("expected a non-zero userID to be set in stream context")
	}
}

func TestInterceptStream_WhoIsFailure_ReturnsUnauthenticated(t *testing.T) {
	db := setupTestDB(t)
	fake := &fakeCallerIdentityLookup{err: errors.New("peer not found")}
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: fake}

	stream := &fakeServerStream{ctx: contextWithPeerAddress("100.64.0.5")}
	handlerCalled := false
	handler := func(srv any, ss grpc.ServerStream) error {
		handlerCalled = true
		return nil
	}

	err := interceptor.InterceptStream(nil, stream, nil, handler)
	if err == nil {
		t.Fatalf("expected an error, got nil")
	}
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("expected codes.Unauthenticated, got %v", status.Code(err))
	}
	if handlerCalled {
		t.Errorf("expected handler not to be called on authentication failure")
	}
}

func TestHTTPMiddleware_CacheHit(t *testing.T) {
	db := setupTestDB(t)
	user := &database.User{Username: "httpcached@example.com"}
	if err := db.Create(user).Error; err != nil {
		t.Fatalf("failed to create user: %v", err)
	}
	if err := db.Create(&database.TailscaleAddress{Address: "100.64.0.10", UserID: user.ID}).Error; err != nil {
		t.Fatalf("failed to create cached address: %v", err)
	}

	fake := &fakeCallerIdentityLookup{}
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: fake}

	var gotUserID uint
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotUserID, _ = r.Context().Value(contextKeyUser{}).(uint)
		w.WriteHeader(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/foo.jpg", nil)
	req.RemoteAddr = "100.64.0.10:12345"
	w := httptest.NewRecorder()

	interceptor.HTTPMiddleware(next).ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
	if gotUserID != user.ID {
		t.Errorf("expected userID %d in context, got %d", user.ID, gotUserID)
	}
	if fake.calls != 0 {
		t.Errorf("expected WhoIs lookup to be skipped on cache hit, called %d times", fake.calls)
	}
}

func TestHTTPMiddleware_WhoIsFailure_ReturnsUnauthorized(t *testing.T) {
	db := setupTestDB(t)
	fake := &fakeCallerIdentityLookup{err: errors.New("peer not found")}
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: fake}

	nextCalled := false
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nextCalled = true
		w.WriteHeader(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/foo.jpg", nil)
	req.RemoteAddr = "100.64.0.11:12345"
	w := httptest.NewRecorder()

	interceptor.HTTPMiddleware(next).ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status 401, got %d", w.Code)
	}
	if nextCalled {
		t.Errorf("expected next handler not to be called on authentication failure")
	}
}

func TestHTTPMiddleware_MalformedRemoteAddr_ReturnsInternalServerError(t *testing.T) {
	db := setupTestDB(t)
	interceptor := &TailscaleAuthenticationInterceptor{db: db, privateServer: &fakeCallerIdentityLookup{}}

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("next handler should not be called")
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/foo.jpg", nil)
	req.RemoteAddr = "not-a-valid-address"
	w := httptest.NewRecorder()

	interceptor.HTTPMiddleware(next).ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected status 500, got %d", w.Code)
	}
}

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
