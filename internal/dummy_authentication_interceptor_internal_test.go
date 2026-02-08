package internal

import (
	"context"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

func TestDummyAuthenticationInterceptor(t *testing.T) {
	ctx := context.Background()
	req := "test request"
	info := &grpc.UnaryServerInfo{
		FullMethod: "/test.Service/TestMethod",
	}

	handlerCalled := false
	var capturedUserID uint

	handler := func(ctx context.Context, req any) (any, error) {
		handlerCalled = true
		// Extract user ID from context
		userID, ok := ctx.Value(contextKeyUser{}).(uint)
		if ok {
			capturedUserID = userID
		}
		return "response", nil
	}

	resp, err := DummyAuthenticationInterceptor(ctx, req, info, handler)

	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if !handlerCalled {
		t.Errorf("expected handler to be called")
	}
	if resp != "response" {
		t.Errorf("expected response 'response', got %v", resp)
	}
	if capturedUserID != 1 {
		t.Errorf("expected userID=1 in context, got %d", capturedUserID)
	}
}

func TestDummyAuthenticationInterceptor_HandlerError(t *testing.T) {
	ctx := context.Background()
	req := "test request"
	info := &grpc.UnaryServerInfo{
		FullMethod: "/test.Service/TestMethod",
	}

	expectedErr := context.DeadlineExceeded
	handler := func(ctx context.Context, req any) (any, error) {
		return nil, expectedErr
	}

	resp, err := DummyAuthenticationInterceptor(ctx, req, info, handler)

	if err != expectedErr {
		t.Errorf("expected error %v, got %v", expectedErr, err)
	}
	if resp != nil {
		t.Errorf("expected nil response, got %v", resp)
	}
}

// mockServerStream is a mock implementation of grpc.ServerStream for testing
type mockServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (m *mockServerStream) Context() context.Context {
	return m.ctx
}

func (m *mockServerStream) SetHeader(metadata.MD) error {
	return nil
}

func (m *mockServerStream) SendHeader(metadata.MD) error {
	return nil
}

func (m *mockServerStream) SetTrailer(metadata.MD) {
}

func (m *mockServerStream) SendMsg(any) error {
	return nil
}

func (m *mockServerStream) RecvMsg(any) error {
	return nil
}

func TestDummyStreamAuthenticationInterceptor(t *testing.T) {
	ctx := context.Background()
	mockStream := &mockServerStream{ctx: ctx}
	info := &grpc.StreamServerInfo{
		FullMethod: "/test.Service/TestStreamMethod",
	}

	handlerCalled := false
	var capturedUserID uint

	handler := func(srv any, stream grpc.ServerStream) error {
		handlerCalled = true
		// Extract user ID from stream context
		userID, ok := stream.Context().Value(contextKeyUser{}).(uint)
		if ok {
			capturedUserID = userID
		}
		return nil
	}

	err := DummyStreamAuthenticationInterceptor(nil, mockStream, info, handler)

	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if !handlerCalled {
		t.Errorf("expected handler to be called")
	}
	if capturedUserID != 1 {
		t.Errorf("expected userID=1 in context, got %d", capturedUserID)
	}
}

func TestDummyStreamAuthenticationInterceptor_HandlerError(t *testing.T) {
	ctx := context.Background()
	mockStream := &mockServerStream{ctx: ctx}
	info := &grpc.StreamServerInfo{
		FullMethod: "/test.Service/TestStreamMethod",
	}

	expectedErr := context.Canceled
	handler := func(srv any, stream grpc.ServerStream) error {
		return expectedErr
	}

	err := DummyStreamAuthenticationInterceptor(nil, mockStream, info, handler)

	if err != expectedErr {
		t.Errorf("expected error %v, got %v", expectedErr, err)
	}
}

func TestWrappedServerStream_Context(t *testing.T) {
	originalCtx := context.Background()
	newCtx := context.WithValue(originalCtx, contextKeyUser{}, uint(42))

	mockStream := &mockServerStream{ctx: originalCtx}
	wrapped := &wrappedServerStream{
		ServerStream: mockStream,
		ctx:          newCtx,
	}

	// Verify wrapped stream returns the new context
	resultCtx := wrapped.Context()
	userID, ok := resultCtx.Value(contextKeyUser{}).(uint)
	if !ok {
		t.Errorf("expected user ID in context")
	}
	if userID != 42 {
		t.Errorf("expected userID=42, got %d", userID)
	}

	// Verify original stream still has original context
	originalUserID, ok := mockStream.Context().Value(contextKeyUser{}).(uint)
	if ok && originalUserID == 42 {
		t.Errorf("original stream context should not have user ID")
	}
}

func TestWrappedServerStream_PreservesUnderlyingStream(t *testing.T) {
	ctx := context.Background()
	mockStream := &mockServerStream{ctx: ctx}
	newCtx := context.WithValue(ctx, contextKeyUser{}, uint(1))

	wrapped := &wrappedServerStream{
		ServerStream: mockStream,
		ctx:          newCtx,
	}

	// Test that methods are delegated to underlying stream
	if err := wrapped.SetHeader(nil); err != nil {
		t.Errorf("SetHeader returned error: %v", err)
	}
	if err := wrapped.SendHeader(nil); err != nil {
		t.Errorf("SendHeader returned error: %v", err)
	}
	wrapped.SetTrailer(nil) // no error return
	if err := wrapped.SendMsg(nil); err != nil {
		t.Errorf("SendMsg returned error: %v", err)
	}
	if err := wrapped.RecvMsg(nil); err != nil {
		t.Errorf("RecvMsg returned error: %v", err)
	}
}
