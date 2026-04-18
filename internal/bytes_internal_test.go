package internal

import (
	"context"
	"io"
	"testing"

	"github.com/alexhokl/photos/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

func TestExtractDirectoryFromPath(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		// Basic cases
		{"photos/2024/image.jpg", "photos/2024"},
		{"photos/image.jpg", "photos"},
		{"image.jpg", ""},
		{"", ""},

		// Nested directories
		{"a/b/c/d/file.txt", "a/b/c/d"},
		{"deep/nested/path/to/photo.png", "deep/nested/path/to"},

		// Edge cases
		{"single", ""},
		{"/absolute/path/file.jpg", "/absolute/path"},
		{"trailing/slash/", "trailing/slash"},

		// Special characters in path
		{"photos/2024-01-15/vacation_photo.jpg", "photos/2024-01-15"},
		{"photos/My Photos/image.jpg", "photos/My Photos"},
	}

	for _, test := range tests {
		t.Run(test.input, func(t *testing.T) {
			result := ExtractDirectoryFromPath(test.input)
			if result != test.expected {
				t.Errorf("ExtractDirectoryFromPath(%q) = %q, expected %q", test.input, result, test.expected)
			}
		})
	}
}

func TestValidateUploadRequest(t *testing.T) {
	tests := []struct {
		name         string
		request      *proto.UploadRequest
		expectedCode codes.Code
		expectError  bool
	}{
		{
			name:         "nil request",
			request:      nil,
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "missing object_id",
			request: &proto.UploadRequest{
				ObjectId: "",
				Data:     []byte("test data"),
			},
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "missing data",
			request: &proto.UploadRequest{
				ObjectId: "photos/test.jpg",
				Data:     nil,
			},
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "empty data",
			request: &proto.UploadRequest{
				ObjectId: "photos/test.jpg",
				Data:     []byte{},
			},
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "valid request",
			request: &proto.UploadRequest{
				ObjectId:    "photos/test.jpg",
				Data:        []byte("test data"),
				ContentType: "image/jpeg",
			},
			expectError: false,
		},
		{
			name: "valid request without content type",
			request: &proto.UploadRequest{
				ObjectId: "photos/test.jpg",
				Data:     []byte("test data"),
			},
			expectError: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateUploadRequest(test.request)

			if test.expectError {
				if err == nil {
					t.Errorf("expected error but got nil")
					return
				}
				st, ok := status.FromError(err)
				if !ok {
					t.Errorf("expected gRPC status error, got %v", err)
					return
				}
				if st.Code() != test.expectedCode {
					t.Errorf("expected code %v, got %v", test.expectedCode, st.Code())
				}
			} else {
				if err != nil {
					t.Errorf("expected no error, got %v", err)
				}
			}
		})
	}
}

func TestValidateDownloadRequest(t *testing.T) {
	tests := []struct {
		name         string
		request      *proto.DownloadRequest
		expectedCode codes.Code
		expectError  bool
	}{
		{
			name:         "nil request",
			request:      nil,
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "missing object_id",
			request: &proto.DownloadRequest{
				ObjectId: "",
			},
			expectedCode: codes.InvalidArgument,
			expectError:  true,
		},
		{
			name: "valid request",
			request: &proto.DownloadRequest{
				ObjectId: "photos/test.jpg",
			},
			expectError: false,
		},
		{
			name: "valid request with nested path",
			request: &proto.DownloadRequest{
				ObjectId: "photos/2024/vacation/beach.jpg",
			},
			expectError: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateDownloadRequest(test.request)

			if test.expectError {
				if err == nil {
					t.Errorf("expected error but got nil")
					return
				}
				st, ok := status.FromError(err)
				if !ok {
					t.Errorf("expected gRPC status error, got %v", err)
					return
				}
				if st.Code() != test.expectedCode {
					t.Errorf("expected code %v, got %v", test.expectedCode, st.Code())
				}
			} else {
				if err != nil {
					t.Errorf("expected no error, got %v", err)
				}
			}
		})
	}
}

// mockBulkUploadStream implements grpc.BidiStreamingServer for BulkStreamingUpload tests.
// Requests are fed in via recvMsgs; responses sent by the handler are collected in sentResults.
type mockBulkUploadStream struct {
	grpc.ServerStream
	ctx         context.Context
	recvMsgs    []*proto.StreamingUploadRequest
	recvIdx     int
	sentResults []*proto.BulkUploadFileResult
	sendErr     error // if non-nil, Send returns this error
}

func newMockBulkUploadStream(ctx context.Context, msgs []*proto.StreamingUploadRequest) *mockBulkUploadStream {
	return &mockBulkUploadStream{ctx: ctx, recvMsgs: msgs}
}

func (m *mockBulkUploadStream) Recv() (*proto.StreamingUploadRequest, error) {
	if m.recvIdx >= len(m.recvMsgs) {
		return nil, io.EOF
	}
	msg := m.recvMsgs[m.recvIdx]
	m.recvIdx++
	return msg, nil
}

func (m *mockBulkUploadStream) Send(result *proto.BulkUploadFileResult) error {
	if m.sendErr != nil {
		return m.sendErr
	}
	m.sentResults = append(m.sentResults, result)
	return nil
}

func (m *mockBulkUploadStream) Context() context.Context { return m.ctx }

func (m *mockBulkUploadStream) SetHeader(metadata.MD) error  { return nil }
func (m *mockBulkUploadStream) SendHeader(metadata.MD) error { return nil }
func (m *mockBulkUploadStream) SetTrailer(metadata.MD)       {}
func (m *mockBulkUploadStream) SendMsg(any) error            { return nil }
func (m *mockBulkUploadStream) RecvMsg(any) error            { return nil }

// bulkUploadCtxWithUserID returns a context carrying the userID value expected by BulkStreamingUpload.
func bulkUploadCtxWithUserID(userID uint) context.Context {
	return context.WithValue(context.Background(), contextKeyUser{}, userID)
}

func bulkMetadataMsg(filename, contentType string) *proto.StreamingUploadRequest {
	return &proto.StreamingUploadRequest{
		Data: &proto.StreamingUploadRequest_Metadata{
			Metadata: &proto.PhotoMetadata{
				Filename:    filename,
				ContentType: contentType,
			},
		},
	}
}

func bulkChunkMsg(data []byte) *proto.StreamingUploadRequest {
	return &proto.StreamingUploadRequest{
		Data: &proto.StreamingUploadRequest_Chunk{Chunk: data},
	}
}

func bulkEofMsg() *proto.StreamingUploadRequest {
	return &proto.StreamingUploadRequest{
		Data: &proto.StreamingUploadRequest_EndOfFile{EndOfFile: true},
	}
}

// TestBulkStreamingUpload_Unauthenticated verifies that a missing userID in context
// causes the handler to return an Unauthenticated gRPC error immediately.
func TestBulkStreamingUpload_Unauthenticated(t *testing.T) {
	server := &BytesServer{}
	stream := newMockBulkUploadStream(context.Background(), nil)

	err := server.BulkStreamingUpload(stream)

	if err == nil {
		t.Fatal("expected error, got nil")
	}
	st, ok := status.FromError(err)
	if !ok {
		t.Fatalf("expected gRPC status error, got %v", err)
	}
	if st.Code() != codes.Unauthenticated {
		t.Errorf("expected Unauthenticated, got %v", st.Code())
	}
}

// TestBulkStreamingUpload_EmptyFilename verifies that a metadata message with an
// empty filename causes the handler to return an InvalidArgument error.
func TestBulkStreamingUpload_EmptyFilename(t *testing.T) {
	server := &BytesServer{}
	msgs := []*proto.StreamingUploadRequest{
		bulkMetadataMsg("", "image/jpeg"),
	}
	stream := newMockBulkUploadStream(bulkUploadCtxWithUserID(1), msgs)

	err := server.BulkStreamingUpload(stream)

	if err == nil {
		t.Fatal("expected error, got nil")
	}
	st, ok := status.FromError(err)
	if !ok {
		t.Fatalf("expected gRPC status error, got %v", err)
	}
	if st.Code() != codes.InvalidArgument {
		t.Errorf("expected InvalidArgument, got %v", st.Code())
	}
}

// TestBulkStreamingUpload_DuplicateMetadataWithoutEndOfFile verifies that sending a
// second metadata message before end_of_file for the current file returns InvalidArgument.
func TestBulkStreamingUpload_DuplicateMetadataWithoutEndOfFile(t *testing.T) {
	server := &BytesServer{}
	msgs := []*proto.StreamingUploadRequest{
		bulkMetadataMsg("photo1.jpg", "image/jpeg"),
		bulkChunkMsg([]byte("some data")),
		// Missing end_of_file — immediately send metadata for next file.
		bulkMetadataMsg("photo2.jpg", "image/jpeg"),
	}
	stream := newMockBulkUploadStream(bulkUploadCtxWithUserID(1), msgs)

	err := server.BulkStreamingUpload(stream)

	if err == nil {
		t.Fatal("expected error, got nil")
	}
	st, ok := status.FromError(err)
	if !ok {
		t.Fatalf("expected gRPC status error, got %v", err)
	}
	if st.Code() != codes.InvalidArgument {
		t.Errorf("expected InvalidArgument, got %v", st.Code())
	}
}

// TestBulkStreamingUpload_ChunkBeforeMetadataIsIgnored verifies that chunk messages
// received before any metadata are silently ignored and the handler completes without error.
func TestBulkStreamingUpload_ChunkBeforeMetadataIsIgnored(t *testing.T) {
	server := &BytesServer{}
	msgs := []*proto.StreamingUploadRequest{
		// Chunk with no preceding metadata — should be ignored.
		bulkChunkMsg([]byte("orphan data")),
	}
	stream := newMockBulkUploadStream(bulkUploadCtxWithUserID(1), msgs)

	err := server.BulkStreamingUpload(stream)

	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
	if len(stream.sentResults) != 0 {
		t.Errorf("expected no results, got %d", len(stream.sentResults))
	}
}

// TestBulkStreamingUpload_EndOfFileBeforeMetadataIsIgnored verifies that an end_of_file
// message received with no preceding metadata is silently ignored.
func TestBulkStreamingUpload_EndOfFileBeforeMetadataIsIgnored(t *testing.T) {
	server := &BytesServer{}
	msgs := []*proto.StreamingUploadRequest{
		// end_of_file with no preceding metadata — should be ignored.
		bulkEofMsg(),
	}
	stream := newMockBulkUploadStream(bulkUploadCtxWithUserID(1), msgs)

	err := server.BulkStreamingUpload(stream)

	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
	if len(stream.sentResults) != 0 {
		t.Errorf("expected no results, got %d", len(stream.sentResults))
	}
}

// TestBulkStreamingUpload_EmptyStreamSucceeds verifies that an empty stream
// (no messages at all) completes without error and produces no results.
func TestBulkStreamingUpload_EmptyStreamSucceeds(t *testing.T) {
	server := &BytesServer{}
	stream := newMockBulkUploadStream(bulkUploadCtxWithUserID(1), nil)

	err := server.BulkStreamingUpload(stream)

	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
	if len(stream.sentResults) != 0 {
		t.Errorf("expected no results, got %d", len(stream.sentResults))
	}
}
