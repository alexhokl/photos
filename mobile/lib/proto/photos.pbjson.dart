// This is a generated file - do not edit.
//
// Generated from proto/photos.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use photoDescriptor instead')
const Photo$json = {
  '1': 'Photo',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
    {'1': 'filename', '3': 2, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'content_type', '3': 3, '4': 1, '5': 9, '10': 'contentType'},
    {'1': 'size_bytes', '3': 4, '4': 1, '5': 3, '10': 'sizeBytes'},
    {'1': 'created_at', '3': 5, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'updated_at', '3': 6, '4': 1, '5': 9, '10': 'updatedAt'},
  ],
};

/// Descriptor for `Photo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List photoDescriptor = $convert.base64Decode(
    'CgVQaG90bxIbCglvYmplY3RfaWQYASABKAlSCG9iamVjdElkEhoKCGZpbGVuYW1lGAIgASgJUg'
    'hmaWxlbmFtZRIhCgxjb250ZW50X3R5cGUYAyABKAlSC2NvbnRlbnRUeXBlEh0KCnNpemVfYnl0'
    'ZXMYBCABKANSCXNpemVCeXRlcxIdCgpjcmVhdGVkX2F0GAUgASgJUgljcmVhdGVkQXQSHQoKdX'
    'BkYXRlZF9hdBgGIAEoCVIJdXBkYXRlZEF0');

@$core.Deprecated('Use uploadRequestDescriptor instead')
const UploadRequest$json = {
  '1': 'UploadRequest',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
    {'1': 'content_type', '3': 2, '4': 1, '5': 9, '10': 'contentType'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `UploadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadRequestDescriptor = $convert.base64Decode(
    'Cg1VcGxvYWRSZXF1ZXN0EhsKCW9iamVjdF9pZBgBIAEoCVIIb2JqZWN0SWQSIQoMY29udGVudF'
    '90eXBlGAIgASgJUgtjb250ZW50VHlwZRISCgRkYXRhGAMgASgMUgRkYXRh');

@$core.Deprecated('Use uploadResponseDescriptor instead')
const UploadResponse$json = {
  '1': 'UploadResponse',
  '2': [
    {
      '1': 'photo',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.photos.Photo',
      '10': 'photo'
    },
  ],
};

/// Descriptor for `UploadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadResponseDescriptor = $convert.base64Decode(
    'Cg5VcGxvYWRSZXNwb25zZRIjCgVwaG90bxgBIAEoCzINLnBob3Rvcy5QaG90b1IFcGhvdG8=');

@$core.Deprecated('Use downloadRequestDescriptor instead')
const DownloadRequest$json = {
  '1': 'DownloadRequest',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
  ],
};

/// Descriptor for `DownloadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List downloadRequestDescriptor = $convert.base64Decode(
    'Cg9Eb3dubG9hZFJlcXVlc3QSGwoJb2JqZWN0X2lkGAEgASgJUghvYmplY3RJZA==');

@$core.Deprecated('Use downloadResponseDescriptor instead')
const DownloadResponse$json = {
  '1': 'DownloadResponse',
  '2': [
    {
      '1': 'photo',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.photos.Photo',
      '10': 'photo'
    },
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `DownloadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List downloadResponseDescriptor = $convert.base64Decode(
    'ChBEb3dubG9hZFJlc3BvbnNlEiMKBXBob3RvGAEgASgLMg0ucGhvdG9zLlBob3RvUgVwaG90bx'
    'ISCgRkYXRhGAIgASgMUgRkYXRh');

@$core.Deprecated('Use deletePhotoRequestDescriptor instead')
const DeletePhotoRequest$json = {
  '1': 'DeletePhotoRequest',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
  ],
};

/// Descriptor for `DeletePhotoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePhotoRequestDescriptor =
    $convert.base64Decode(
        'ChJEZWxldGVQaG90b1JlcXVlc3QSGwoJb2JqZWN0X2lkGAEgASgJUghvYmplY3RJZA==');

@$core.Deprecated('Use deletePhotoResponseDescriptor instead')
const DeletePhotoResponse$json = {
  '1': 'DeletePhotoResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `DeletePhotoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePhotoResponseDescriptor =
    $convert.base64Decode(
        'ChNEZWxldGVQaG90b1Jlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use getPhotoRequestDescriptor instead')
const GetPhotoRequest$json = {
  '1': 'GetPhotoRequest',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
  ],
};

/// Descriptor for `GetPhotoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPhotoRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRQaG90b1JlcXVlc3QSGwoJb2JqZWN0X2lkGAEgASgJUghvYmplY3RJZA==');

@$core.Deprecated('Use getPhotoResponseDescriptor instead')
const GetPhotoResponse$json = {
  '1': 'GetPhotoResponse',
  '2': [
    {
      '1': 'photo',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.photos.Photo',
      '10': 'photo'
    },
  ],
};

/// Descriptor for `GetPhotoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPhotoResponseDescriptor = $convert.base64Decode(
    'ChBHZXRQaG90b1Jlc3BvbnNlEiMKBXBob3RvGAEgASgLMg0ucGhvdG9zLlBob3RvUgVwaG90bw'
    '==');

@$core.Deprecated('Use listPhotosRequestDescriptor instead')
const ListPhotosRequest$json = {
  '1': 'ListPhotosRequest',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 2, '4': 1, '5': 9, '10': 'pageToken'},
    {'1': 'prefix', '3': 3, '4': 1, '5': 9, '10': 'prefix'},
  ],
};

/// Descriptor for `ListPhotosRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPhotosRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0UGhvdG9zUmVxdWVzdBIbCglwYWdlX3NpemUYASABKAVSCHBhZ2VTaXplEh0KCnBhZ2'
    'VfdG9rZW4YAiABKAlSCXBhZ2VUb2tlbhIWCgZwcmVmaXgYAyABKAlSBnByZWZpeA==');

@$core.Deprecated('Use listPhotosResponseDescriptor instead')
const ListPhotosResponse$json = {
  '1': 'ListPhotosResponse',
  '2': [
    {
      '1': 'photos',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.photos.Photo',
      '10': 'photos'
    },
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
  ],
};

/// Descriptor for `ListPhotosResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPhotosResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0UGhvdG9zUmVzcG9uc2USJQoGcGhvdG9zGAEgAygLMg0ucGhvdG9zLlBob3RvUgZwaG'
    '90b3MSJgoPbmV4dF9wYWdlX3Rva2VuGAIgASgJUg1uZXh0UGFnZVRva2Vu');

@$core.Deprecated('Use copyPhotoRequestDescriptor instead')
const CopyPhotoRequest$json = {
  '1': 'CopyPhotoRequest',
  '2': [
    {'1': 'source_object_id', '3': 1, '4': 1, '5': 9, '10': 'sourceObjectId'},
    {
      '1': 'destination_object_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'destinationObjectId'
    },
  ],
};

/// Descriptor for `CopyPhotoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List copyPhotoRequestDescriptor = $convert.base64Decode(
    'ChBDb3B5UGhvdG9SZXF1ZXN0EigKEHNvdXJjZV9vYmplY3RfaWQYASABKAlSDnNvdXJjZU9iam'
    'VjdElkEjIKFWRlc3RpbmF0aW9uX29iamVjdF9pZBgCIAEoCVITZGVzdGluYXRpb25PYmplY3RJ'
    'ZA==');

@$core.Deprecated('Use copyPhotoResponseDescriptor instead')
const CopyPhotoResponse$json = {
  '1': 'CopyPhotoResponse',
  '2': [
    {
      '1': 'photo',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.photos.Photo',
      '10': 'photo'
    },
  ],
};

/// Descriptor for `CopyPhotoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List copyPhotoResponseDescriptor = $convert.base64Decode(
    'ChFDb3B5UGhvdG9SZXNwb25zZRIjCgVwaG90bxgBIAEoCzINLnBob3Rvcy5QaG90b1IFcGhvdG'
    '8=');

@$core.Deprecated('Use updatePhotoMetadataRequestDescriptor instead')
const UpdatePhotoMetadataRequest$json = {
  '1': 'UpdatePhotoMetadataRequest',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
    {
      '1': 'custom_metadata',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.photos.UpdatePhotoMetadataRequest.CustomMetadataEntry',
      '10': 'customMetadata'
    },
    {'1': 'content_type', '3': 3, '4': 1, '5': 9, '10': 'contentType'},
  ],
  '3': [UpdatePhotoMetadataRequest_CustomMetadataEntry$json],
};

@$core.Deprecated('Use updatePhotoMetadataRequestDescriptor instead')
const UpdatePhotoMetadataRequest_CustomMetadataEntry$json = {
  '1': 'CustomMetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `UpdatePhotoMetadataRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePhotoMetadataRequestDescriptor = $convert.base64Decode(
    'ChpVcGRhdGVQaG90b01ldGFkYXRhUmVxdWVzdBIbCglvYmplY3RfaWQYASABKAlSCG9iamVjdE'
    'lkEl8KD2N1c3RvbV9tZXRhZGF0YRgCIAMoCzI2LnBob3Rvcy5VcGRhdGVQaG90b01ldGFkYXRh'
    'UmVxdWVzdC5DdXN0b21NZXRhZGF0YUVudHJ5Ug5jdXN0b21NZXRhZGF0YRIhCgxjb250ZW50X3'
    'R5cGUYAyABKAlSC2NvbnRlbnRUeXBlGkEKE0N1c3RvbU1ldGFkYXRhRW50cnkSEAoDa2V5GAEg'
    'ASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use updatePhotoMetadataResponseDescriptor instead')
const UpdatePhotoMetadataResponse$json = {
  '1': 'UpdatePhotoMetadataResponse',
  '2': [
    {
      '1': 'photo',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.photos.Photo',
      '10': 'photo'
    },
  ],
};

/// Descriptor for `UpdatePhotoMetadataResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePhotoMetadataResponseDescriptor =
    $convert.base64Decode(
        'ChtVcGRhdGVQaG90b01ldGFkYXRhUmVzcG9uc2USIwoFcGhvdG8YASABKAsyDS5waG90b3MuUG'
        'hvdG9SBXBob3Rv');

@$core.Deprecated('Use generateSignedUrlRequestDescriptor instead')
const GenerateSignedUrlRequest$json = {
  '1': 'GenerateSignedUrlRequest',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
    {
      '1': 'expiration_seconds',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'expirationSeconds'
    },
    {'1': 'method', '3': 3, '4': 1, '5': 9, '10': 'method'},
  ],
};

/// Descriptor for `GenerateSignedUrlRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateSignedUrlRequestDescriptor = $convert.base64Decode(
    'ChhHZW5lcmF0ZVNpZ25lZFVybFJlcXVlc3QSGwoJb2JqZWN0X2lkGAEgASgJUghvYmplY3RJZB'
    'ItChJleHBpcmF0aW9uX3NlY29uZHMYAiABKANSEWV4cGlyYXRpb25TZWNvbmRzEhYKBm1ldGhv'
    'ZBgDIAEoCVIGbWV0aG9k');

@$core.Deprecated('Use generateSignedUrlResponseDescriptor instead')
const GenerateSignedUrlResponse$json = {
  '1': 'GenerateSignedUrlResponse',
  '2': [
    {'1': 'signed_url', '3': 1, '4': 1, '5': 9, '10': 'signedUrl'},
    {'1': 'expires_at', '3': 2, '4': 1, '5': 9, '10': 'expiresAt'},
  ],
};

/// Descriptor for `GenerateSignedUrlResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateSignedUrlResponseDescriptor =
    $convert.base64Decode(
        'ChlHZW5lcmF0ZVNpZ25lZFVybFJlc3BvbnNlEh0KCnNpZ25lZF91cmwYASABKAlSCXNpZ25lZF'
        'VybBIdCgpleHBpcmVzX2F0GAIgASgJUglleHBpcmVzQXQ=');

@$core.Deprecated('Use photoExistsRequestDescriptor instead')
const PhotoExistsRequest$json = {
  '1': 'PhotoExistsRequest',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
  ],
};

/// Descriptor for `PhotoExistsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List photoExistsRequestDescriptor =
    $convert.base64Decode(
        'ChJQaG90b0V4aXN0c1JlcXVlc3QSGwoJb2JqZWN0X2lkGAEgASgJUghvYmplY3RJZA==');

@$core.Deprecated('Use photoExistsResponseDescriptor instead')
const PhotoExistsResponse$json = {
  '1': 'PhotoExistsResponse',
  '2': [
    {'1': 'exists', '3': 1, '4': 1, '5': 8, '10': 'exists'},
  ],
};

/// Descriptor for `PhotoExistsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List photoExistsResponseDescriptor =
    $convert.base64Decode(
        'ChNQaG90b0V4aXN0c1Jlc3BvbnNlEhYKBmV4aXN0cxgBIAEoCFIGZXhpc3Rz');

@$core.Deprecated('Use listDirectoriesRequestDescriptor instead')
const ListDirectoriesRequest$json = {
  '1': 'ListDirectoriesRequest',
  '2': [
    {'1': 'prefix', '3': 1, '4': 1, '5': 9, '10': 'prefix'},
  ],
};

/// Descriptor for `ListDirectoriesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDirectoriesRequestDescriptor =
    $convert.base64Decode(
        'ChZMaXN0RGlyZWN0b3JpZXNSZXF1ZXN0EhYKBnByZWZpeBgBIAEoCVIGcHJlZml4');

@$core.Deprecated('Use listDirectoriesResponseDescriptor instead')
const ListDirectoriesResponse$json = {
  '1': 'ListDirectoriesResponse',
  '2': [
    {'1': 'prefixes', '3': 1, '4': 3, '5': 9, '10': 'prefixes'},
  ],
};

/// Descriptor for `ListDirectoriesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDirectoriesResponseDescriptor =
    $convert.base64Decode(
        'ChdMaXN0RGlyZWN0b3JpZXNSZXNwb25zZRIaCghwcmVmaXhlcxgBIAMoCVIIcHJlZml4ZXM=');

@$core.Deprecated('Use streamingUploadRequestDescriptor instead')
const StreamingUploadRequest$json = {
  '1': 'StreamingUploadRequest',
  '2': [
    {
      '1': 'metadata',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.photos.PhotoMetadata',
      '9': 0,
      '10': 'metadata'
    },
    {'1': 'chunk', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'chunk'},
  ],
  '8': [
    {'1': 'data'},
  ],
};

/// Descriptor for `StreamingUploadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamingUploadRequestDescriptor = $convert.base64Decode(
    'ChZTdHJlYW1pbmdVcGxvYWRSZXF1ZXN0EjMKCG1ldGFkYXRhGAEgASgLMhUucGhvdG9zLlBob3'
    'RvTWV0YWRhdGFIAFIIbWV0YWRhdGESFgoFY2h1bmsYAiABKAxIAFIFY2h1bmtCBgoEZGF0YQ==');

@$core.Deprecated('Use photoMetadataDescriptor instead')
const PhotoMetadata$json = {
  '1': 'PhotoMetadata',
  '2': [
    {'1': 'filename', '3': 1, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'content_type', '3': 2, '4': 1, '5': 9, '10': 'contentType'},
  ],
};

/// Descriptor for `PhotoMetadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List photoMetadataDescriptor = $convert.base64Decode(
    'Cg1QaG90b01ldGFkYXRhEhoKCGZpbGVuYW1lGAEgASgJUghmaWxlbmFtZRIhCgxjb250ZW50X3'
    'R5cGUYAiABKAlSC2NvbnRlbnRUeXBl');

@$core.Deprecated('Use streamingDownloadRequestDescriptor instead')
const StreamingDownloadRequest$json = {
  '1': 'StreamingDownloadRequest',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
  ],
};

/// Descriptor for `StreamingDownloadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamingDownloadRequestDescriptor =
    $convert.base64Decode(
        'ChhTdHJlYW1pbmdEb3dubG9hZFJlcXVlc3QSGwoJb2JqZWN0X2lkGAEgASgJUghvYmplY3RJZA'
        '==');

@$core.Deprecated('Use streamingDownloadResponseDescriptor instead')
const StreamingDownloadResponse$json = {
  '1': 'StreamingDownloadResponse',
  '2': [
    {
      '1': 'metadata',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.photos.Photo',
      '9': 0,
      '10': 'metadata'
    },
    {'1': 'chunk', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'chunk'},
  ],
  '8': [
    {'1': 'data'},
  ],
};

/// Descriptor for `StreamingDownloadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamingDownloadResponseDescriptor =
    $convert.base64Decode(
        'ChlTdHJlYW1pbmdEb3dubG9hZFJlc3BvbnNlEisKCG1ldGFkYXRhGAEgASgLMg0ucGhvdG9zLl'
        'Bob3RvSABSCG1ldGFkYXRhEhYKBWNodW5rGAIgASgMSABSBWNodW5rQgYKBGRhdGE=');
