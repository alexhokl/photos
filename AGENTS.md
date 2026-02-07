# AGENTS.md

This file provides guidance for AI coding agents working in this repository.

## Project Overview

A photo management application with a Go backend (gRPC server + CLI client) and a
Flutter/Dart mobile frontend. The server uses GORM with SQLite for persistence and
Google Cloud Storage for photo storage, with Tailscale for private networking.

### Directory Structure

- `cmd/` -- Cobra CLI commands (both server and client commands)
- `internal/` -- gRPC server implementations, interceptors, helpers
- `database/` -- GORM models and database operations
- `proto/` -- Protobuf definitions and generated Go/Dart code
- `mobile/` -- Flutter application (macOS, Android, iOS, Linux, Windows)
- `google/`, `protoc-gen-openapiv2/` -- Proto dependencies
- `openapiv2/` -- Generated OpenAPI/Swagger specs

## Build, Test, and Lint Commands

Task runner: [Task](https://taskfile.dev/) (`Taskfile.yml`). All commands below can
also be run directly without `task`.

### Go

```bash
task build                    # or: go build -o /dev/null ./...
go test ./...                 # run all tests
task coverage                 # or: go test --cover ./...
go test -run TestRequireSecureConnection ./cmd/       # single test
go test -run TestRequireSecureConnection/localhost ./cmd/  # single subtest
go test -v -run TestRequireSecureConnection ./cmd/    # verbose
task lint                     # golangci-lint run && dart fix --dry-run
task sec                      # gosec ./...
task bench                    # go test -bench=. -benchmem ./...
task install                  # go install
task proto                    # generate protobuf Go + Dart code
```

### Flutter / Dart

```bash
task flutter-coverage         # or: cd mobile && flutter test --no-pub --coverage
cd mobile && flutter test test/photo_viewer_test.dart  # single test file
dart fix --dry-run            # lint (dry run)
task lint-flutter-fix         # or: dart fix --apply
task mac                      # flutter build macos
task apk                      # flutter build apk
task run-flutter              # flutter run -d macos
```

## Code Style Guidelines

### Go

#### Imports

Use `goimports`-style grouping with two groups separated by a blank line:
1. Standard library (`context`, `fmt`, `log/slog`, `os`, etc.)
2. All external packages including project-internal ones, sorted alphabetically

```go
import (
    "context"
    "fmt"
    "log/slog"

    "cloud.google.com/go/storage"
    "github.com/alexhokl/photos/database"
    "github.com/alexhokl/photos/proto"
    "google.golang.org/grpc"
)
```

#### Naming Conventions

- **Files:** `snake_case.go` (e.g., `error_logging.go`, `get_signed_url.go`)
- **Test files:** `*_internal_test.go` for white-box tests in the same package
- **Packages:** lowercase single words (`cmd`, `internal`, `database`)
- **Exported types/functions:** `PascalCase` (`LibraryServer`, `AutoMigrate`)
- **Unexported types/functions:** `camelCase` (`rootOptions`, `runServe`)
- **Constants (exported):** `PascalCase` (`AppName`, `DefaultPort`)
- **Constants (unexported):** `camelCase` (`defaultChunkSize`)

#### Cobra CLI Command Pattern

Each command lives in its own file in `cmd/` following this structure:

1. Options struct: `<command>Options` (unexported, e.g., `serveOptions`)
2. Options variable: `<command>Opts` (package-level, e.g., `serveOpts`)
3. Command variable: `<command>Cmd` (e.g., `serveCmd`)
4. `init()` function: registers flags, adds command to parent
5. Run function: `run<Command>` (e.g., `runServe`) with signature `func(cmd *cobra.Command, args []string) error`

#### Error Handling

**CLI commands** -- wrap with `fmt.Errorf` using `%w` (or `%v` for non-wrapping):
```go
return fmt.Errorf("failed to read file: %w", err)
```

**gRPC server handlers** -- return gRPC status errors with appropriate codes:
```go
return nil, status.Errorf(codes.NotFound, "photo not found: %s", objectID)
return nil, status.Errorf(codes.Internal, "failed to query: %v", err)
return nil, status.Errorf(codes.Unauthenticated, "authentication required")
```

**Deferred resource cleanup** -- suppress close errors with blank identifier:
```go
defer func() { _ = conn.Close() }()
```

**Non-critical calls** -- suppress with blank identifier:
```go
_ = rootCmd.MarkFlagRequired("service")
```

#### Logging

Use `log/slog` structured logging (not `log` or third-party loggers):
```go
slog.Error("gRPC error", slog.String("method", info.FullMethod), slog.String("error", err.Error()))
slog.Warn("failed to create directory", slog.String("path", dir), slog.String("error", err.Error()))
slog.Info("server started", slog.Int("port", port))
```

#### Testing

- Use standard `testing` package (no testify or other assertion libraries)
- Table-driven tests with `t.Run()` subtests
- Manual assertions with `t.Errorf()`

```go
func TestExample(t *testing.T) {
    tests := []struct {
        input    string
        expected bool
    }{
        {"value1", true},
        {"value2", false},
    }
    for _, test := range tests {
        t.Run(test.input, func(t *testing.T) {
            result := someFunc(test.input)
            if result != test.expected {
                t.Errorf("expected %v but got %v", test.expected, result)
            }
        })
    }
}
```

#### Types and Structs

- Database models use GORM conventions with struct tags: `gorm:"not null;unique"`
- gRPC servers embed `Unimplemented*Server` for forward compatibility
- Pointer receivers for all methods on server structs

### Flutter / Dart

- Linting: `package:flutter_lints/flutter.yaml` (see `mobile/analysis_options.yaml`)
- Tests use `flutter_test` with `mocktail` for mocking
- Test structure: `group()` / `testWidgets()` / `expect()` matchers
- Generated gRPC client code lives in `mobile/lib/proto/`
