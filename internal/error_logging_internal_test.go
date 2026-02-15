package internal

import (
	"context"
	"errors"
	"testing"

	"google.golang.org/grpc"
)

func TestErrorLoggingInterceptor_SuccessfulRequest(t *testing.T) {
	// Test that successful responses pass through unchanged
	expectedResp := "success response"
	handler := func(ctx context.Context, req any) (any, error) {
		return expectedResp, nil
	}

	info := &grpc.UnaryServerInfo{
		FullMethod: "/test.Service/TestMethod",
	}

	resp, err := ErrorLoggingInterceptor(context.Background(), "request", info, handler)

	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
	if resp != expectedResp {
		t.Errorf("expected response %q, got %q", expectedResp, resp)
	}
}

func TestErrorLoggingInterceptor_ErrorRequest(t *testing.T) {
	// Test that errors are passed through (logging is a side effect)
	expectedErr := errors.New("handler error")
	handler := func(ctx context.Context, req any) (any, error) {
		return nil, expectedErr
	}

	info := &grpc.UnaryServerInfo{
		FullMethod: "/test.Service/TestMethod",
	}

	resp, err := ErrorLoggingInterceptor(context.Background(), "request", info, handler)

	if err != expectedErr {
		t.Errorf("expected error %v, got %v", expectedErr, err)
	}
	if resp != nil {
		t.Errorf("expected nil response, got %v", resp)
	}
}

func TestErrorLoggingInterceptor_NilResponse(t *testing.T) {
	// Test nil response with no error
	handler := func(ctx context.Context, req any) (any, error) {
		return nil, nil
	}

	info := &grpc.UnaryServerInfo{
		FullMethod: "/test.Service/TestMethod",
	}

	resp, err := ErrorLoggingInterceptor(context.Background(), "request", info, handler)

	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
	if resp != nil {
		t.Errorf("expected nil response, got %v", resp)
	}
}

func TestErrorLoggingInterceptor_PreservesContext(t *testing.T) {
	// Test that context is passed through to handler
	type ctxKey struct{}
	expectedValue := "context value"

	var receivedCtx context.Context
	handler := func(ctx context.Context, req any) (any, error) {
		receivedCtx = ctx
		return nil, nil
	}

	info := &grpc.UnaryServerInfo{
		FullMethod: "/test.Service/TestMethod",
	}

	ctx := context.WithValue(context.Background(), ctxKey{}, expectedValue)
	_, _ = ErrorLoggingInterceptor(ctx, "request", info, handler)

	if receivedCtx == nil {
		t.Fatal("handler was not called")
	}
	if receivedCtx.Value(ctxKey{}) != expectedValue {
		t.Errorf("context value not preserved: expected %q, got %v", expectedValue, receivedCtx.Value(ctxKey{}))
	}
}

func TestErrorLoggingInterceptor_PreservesRequest(t *testing.T) {
	// Test that request is passed through to handler unchanged
	expectedReq := "test request"

	var receivedReq any
	handler := func(ctx context.Context, req any) (any, error) {
		receivedReq = req
		return nil, nil
	}

	info := &grpc.UnaryServerInfo{
		FullMethod: "/test.Service/TestMethod",
	}

	_, _ = ErrorLoggingInterceptor(context.Background(), expectedReq, info, handler)

	if receivedReq != expectedReq {
		t.Errorf("request not preserved: expected %q, got %v", expectedReq, receivedReq)
	}
}
