// This is a generated file - do not edit.
//
// Generated from proto/photos.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'photos.pb.dart' as $0;

export 'photos.pb.dart';

/// ByteService provides photo upload, retrieval, and deletion operations
@$pb.GrpcServiceName('photos.ByteService')
class ByteServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ByteServiceClient(super.channel, {super.options, super.interceptors});

  /// Upload uploads a new photo
  $grpc.ResponseFuture<$0.UploadResponse> upload(
    $0.UploadRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$upload, request, options: options);
  }

  /// Download retrieves a photo by ID
  $grpc.ResponseFuture<$0.DownloadResponse> download(
    $0.DownloadRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$download, request, options: options);
  }

  /// StreamingUpload uploads a photo using client-side streaming for large files
  $grpc.ResponseFuture<$0.UploadResponse> streamingUpload(
    $async.Stream<$0.StreamingUploadRequest> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$streamingUpload, request, options: options)
        .single;
  }

  /// StreamingDownload downloads a photo using server-side streaming for large files
  $grpc.ResponseStream<$0.StreamingDownloadResponse> streamingDownload(
    $0.StreamingDownloadRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$streamingDownload, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$upload =
      $grpc.ClientMethod<$0.UploadRequest, $0.UploadResponse>(
          '/photos.ByteService/Upload',
          ($0.UploadRequest value) => value.writeToBuffer(),
          $0.UploadResponse.fromBuffer);
  static final _$download =
      $grpc.ClientMethod<$0.DownloadRequest, $0.DownloadResponse>(
          '/photos.ByteService/Download',
          ($0.DownloadRequest value) => value.writeToBuffer(),
          $0.DownloadResponse.fromBuffer);
  static final _$streamingUpload =
      $grpc.ClientMethod<$0.StreamingUploadRequest, $0.UploadResponse>(
          '/photos.ByteService/StreamingUpload',
          ($0.StreamingUploadRequest value) => value.writeToBuffer(),
          $0.UploadResponse.fromBuffer);
  static final _$streamingDownload = $grpc.ClientMethod<
          $0.StreamingDownloadRequest, $0.StreamingDownloadResponse>(
      '/photos.ByteService/StreamingDownload',
      ($0.StreamingDownloadRequest value) => value.writeToBuffer(),
      $0.StreamingDownloadResponse.fromBuffer);
}

@$pb.GrpcServiceName('photos.ByteService')
abstract class ByteServiceBase extends $grpc.Service {
  $core.String get $name => 'photos.ByteService';

  ByteServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.UploadRequest, $0.UploadResponse>(
        'Upload',
        upload_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UploadRequest.fromBuffer(value),
        ($0.UploadResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DownloadRequest, $0.DownloadResponse>(
        'Download',
        download_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DownloadRequest.fromBuffer(value),
        ($0.DownloadResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.StreamingUploadRequest, $0.UploadResponse>(
            'StreamingUpload',
            streamingUpload,
            true,
            false,
            ($core.List<$core.int> value) =>
                $0.StreamingUploadRequest.fromBuffer(value),
            ($0.UploadResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.StreamingDownloadRequest,
            $0.StreamingDownloadResponse>(
        'StreamingDownload',
        streamingDownload_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.StreamingDownloadRequest.fromBuffer(value),
        ($0.StreamingDownloadResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.UploadResponse> upload_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.UploadRequest> $request) async {
    return upload($call, await $request);
  }

  $async.Future<$0.UploadResponse> upload(
      $grpc.ServiceCall call, $0.UploadRequest request);

  $async.Future<$0.DownloadResponse> download_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DownloadRequest> $request) async {
    return download($call, await $request);
  }

  $async.Future<$0.DownloadResponse> download(
      $grpc.ServiceCall call, $0.DownloadRequest request);

  $async.Future<$0.UploadResponse> streamingUpload(
      $grpc.ServiceCall call, $async.Stream<$0.StreamingUploadRequest> request);

  $async.Stream<$0.StreamingDownloadResponse> streamingDownload_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.StreamingDownloadRequest> $request) async* {
    yield* streamingDownload($call, await $request);
  }

  $async.Stream<$0.StreamingDownloadResponse> streamingDownload(
      $grpc.ServiceCall call, $0.StreamingDownloadRequest request);
}

@$pb.GrpcServiceName('photos.LibraryService')
class LibraryServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  LibraryServiceClient(super.channel, {super.options, super.interceptors});

  /// DeletePhoto removes a photo by ID
  $grpc.ResponseFuture<$0.DeletePhotoResponse> deletePhoto(
    $0.DeletePhotoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deletePhoto, request, options: options);
  }

  /// GetPhoto retrieves photo metadata by ID
  $grpc.ResponseFuture<$0.GetPhotoResponse> getPhoto(
    $0.GetPhotoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPhoto, request, options: options);
  }

  /// ListPhotos returns a paginated list of photos with optional prefix filtering
  $grpc.ResponseFuture<$0.ListPhotosResponse> listPhotos(
    $0.ListPhotosRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPhotos, request, options: options);
  }

  /// CopyPhoto copies a photo to a new location
  $grpc.ResponseFuture<$0.CopyPhotoResponse> copyPhoto(
    $0.CopyPhotoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$copyPhoto, request, options: options);
  }

  /// UpdatePhotoMetadata updates metadata for a photo
  $grpc.ResponseFuture<$0.UpdatePhotoMetadataResponse> updatePhotoMetadata(
    $0.UpdatePhotoMetadataRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updatePhotoMetadata, request, options: options);
  }

  /// GenerateSignedUrl creates a time-limited signed URL for photo access
  $grpc.ResponseFuture<$0.GenerateSignedUrlResponse> generateSignedUrl(
    $0.GenerateSignedUrlRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generateSignedUrl, request, options: options);
  }

  /// PhotoExists checks if a photo exists by ID
  $grpc.ResponseFuture<$0.PhotoExistsResponse> photoExists(
    $0.PhotoExistsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$photoExists, request, options: options);
  }

  /// ListDirectories lists virtual directories (common prefixes) in a bucket
  $grpc.ResponseFuture<$0.ListDirectoriesResponse> listDirectories(
    $0.ListDirectoriesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listDirectories, request, options: options);
  }

  /// SyncDatabase syncs the photo database with the storage backend
  $grpc.ResponseFuture<$1.Empty> syncDatabase(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$syncDatabase, request, options: options);
  }

  // method descriptors

  static final _$deletePhoto =
      $grpc.ClientMethod<$0.DeletePhotoRequest, $0.DeletePhotoResponse>(
          '/photos.LibraryService/DeletePhoto',
          ($0.DeletePhotoRequest value) => value.writeToBuffer(),
          $0.DeletePhotoResponse.fromBuffer);
  static final _$getPhoto =
      $grpc.ClientMethod<$0.GetPhotoRequest, $0.GetPhotoResponse>(
          '/photos.LibraryService/GetPhoto',
          ($0.GetPhotoRequest value) => value.writeToBuffer(),
          $0.GetPhotoResponse.fromBuffer);
  static final _$listPhotos =
      $grpc.ClientMethod<$0.ListPhotosRequest, $0.ListPhotosResponse>(
          '/photos.LibraryService/ListPhotos',
          ($0.ListPhotosRequest value) => value.writeToBuffer(),
          $0.ListPhotosResponse.fromBuffer);
  static final _$copyPhoto =
      $grpc.ClientMethod<$0.CopyPhotoRequest, $0.CopyPhotoResponse>(
          '/photos.LibraryService/CopyPhoto',
          ($0.CopyPhotoRequest value) => value.writeToBuffer(),
          $0.CopyPhotoResponse.fromBuffer);
  static final _$updatePhotoMetadata = $grpc.ClientMethod<
          $0.UpdatePhotoMetadataRequest, $0.UpdatePhotoMetadataResponse>(
      '/photos.LibraryService/UpdatePhotoMetadata',
      ($0.UpdatePhotoMetadataRequest value) => value.writeToBuffer(),
      $0.UpdatePhotoMetadataResponse.fromBuffer);
  static final _$generateSignedUrl = $grpc.ClientMethod<
          $0.GenerateSignedUrlRequest, $0.GenerateSignedUrlResponse>(
      '/photos.LibraryService/GenerateSignedUrl',
      ($0.GenerateSignedUrlRequest value) => value.writeToBuffer(),
      $0.GenerateSignedUrlResponse.fromBuffer);
  static final _$photoExists =
      $grpc.ClientMethod<$0.PhotoExistsRequest, $0.PhotoExistsResponse>(
          '/photos.LibraryService/PhotoExists',
          ($0.PhotoExistsRequest value) => value.writeToBuffer(),
          $0.PhotoExistsResponse.fromBuffer);
  static final _$listDirectories =
      $grpc.ClientMethod<$0.ListDirectoriesRequest, $0.ListDirectoriesResponse>(
          '/photos.LibraryService/ListDirectories',
          ($0.ListDirectoriesRequest value) => value.writeToBuffer(),
          $0.ListDirectoriesResponse.fromBuffer);
  static final _$syncDatabase = $grpc.ClientMethod<$1.Empty, $1.Empty>(
      '/photos.LibraryService/SyncDatabase',
      ($1.Empty value) => value.writeToBuffer(),
      $1.Empty.fromBuffer);
}

@$pb.GrpcServiceName('photos.LibraryService')
abstract class LibraryServiceBase extends $grpc.Service {
  $core.String get $name => 'photos.LibraryService';

  LibraryServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.DeletePhotoRequest, $0.DeletePhotoResponse>(
            'DeletePhoto',
            deletePhoto_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeletePhotoRequest.fromBuffer(value),
            ($0.DeletePhotoResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPhotoRequest, $0.GetPhotoResponse>(
        'GetPhoto',
        getPhoto_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetPhotoRequest.fromBuffer(value),
        ($0.GetPhotoResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListPhotosRequest, $0.ListPhotosResponse>(
        'ListPhotos',
        listPhotos_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListPhotosRequest.fromBuffer(value),
        ($0.ListPhotosResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CopyPhotoRequest, $0.CopyPhotoResponse>(
        'CopyPhoto',
        copyPhoto_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CopyPhotoRequest.fromBuffer(value),
        ($0.CopyPhotoResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdatePhotoMetadataRequest,
            $0.UpdatePhotoMetadataResponse>(
        'UpdatePhotoMetadata',
        updatePhotoMetadata_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdatePhotoMetadataRequest.fromBuffer(value),
        ($0.UpdatePhotoMetadataResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GenerateSignedUrlRequest,
            $0.GenerateSignedUrlResponse>(
        'GenerateSignedUrl',
        generateSignedUrl_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GenerateSignedUrlRequest.fromBuffer(value),
        ($0.GenerateSignedUrlResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.PhotoExistsRequest, $0.PhotoExistsResponse>(
            'PhotoExists',
            photoExists_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.PhotoExistsRequest.fromBuffer(value),
            ($0.PhotoExistsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListDirectoriesRequest,
            $0.ListDirectoriesResponse>(
        'ListDirectories',
        listDirectories_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListDirectoriesRequest.fromBuffer(value),
        ($0.ListDirectoriesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $1.Empty>(
        'SyncDatabase',
        syncDatabase_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$0.DeletePhotoResponse> deletePhoto_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeletePhotoRequest> $request) async {
    return deletePhoto($call, await $request);
  }

  $async.Future<$0.DeletePhotoResponse> deletePhoto(
      $grpc.ServiceCall call, $0.DeletePhotoRequest request);

  $async.Future<$0.GetPhotoResponse> getPhoto_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetPhotoRequest> $request) async {
    return getPhoto($call, await $request);
  }

  $async.Future<$0.GetPhotoResponse> getPhoto(
      $grpc.ServiceCall call, $0.GetPhotoRequest request);

  $async.Future<$0.ListPhotosResponse> listPhotos_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListPhotosRequest> $request) async {
    return listPhotos($call, await $request);
  }

  $async.Future<$0.ListPhotosResponse> listPhotos(
      $grpc.ServiceCall call, $0.ListPhotosRequest request);

  $async.Future<$0.CopyPhotoResponse> copyPhoto_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CopyPhotoRequest> $request) async {
    return copyPhoto($call, await $request);
  }

  $async.Future<$0.CopyPhotoResponse> copyPhoto(
      $grpc.ServiceCall call, $0.CopyPhotoRequest request);

  $async.Future<$0.UpdatePhotoMetadataResponse> updatePhotoMetadata_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdatePhotoMetadataRequest> $request) async {
    return updatePhotoMetadata($call, await $request);
  }

  $async.Future<$0.UpdatePhotoMetadataResponse> updatePhotoMetadata(
      $grpc.ServiceCall call, $0.UpdatePhotoMetadataRequest request);

  $async.Future<$0.GenerateSignedUrlResponse> generateSignedUrl_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GenerateSignedUrlRequest> $request) async {
    return generateSignedUrl($call, await $request);
  }

  $async.Future<$0.GenerateSignedUrlResponse> generateSignedUrl(
      $grpc.ServiceCall call, $0.GenerateSignedUrlRequest request);

  $async.Future<$0.PhotoExistsResponse> photoExists_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PhotoExistsRequest> $request) async {
    return photoExists($call, await $request);
  }

  $async.Future<$0.PhotoExistsResponse> photoExists(
      $grpc.ServiceCall call, $0.PhotoExistsRequest request);

  $async.Future<$0.ListDirectoriesResponse> listDirectories_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListDirectoriesRequest> $request) async {
    return listDirectories($call, await $request);
  }

  $async.Future<$0.ListDirectoriesResponse> listDirectories(
      $grpc.ServiceCall call, $0.ListDirectoriesRequest request);

  $async.Future<$1.Empty> syncDatabase_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return syncDatabase($call, await $request);
  }

  $async.Future<$1.Empty> syncDatabase(
      $grpc.ServiceCall call, $1.Empty request);
}
