// This is a generated file - do not edit.
//
// Generated from proto/photos.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Photo represents a stored photo with metadata
class Photo extends $pb.GeneratedMessage {
  factory Photo({
    $core.String? objectId,
    $core.String? filename,
    $core.String? contentType,
    $fixnum.Int64? sizeBytes,
    $core.String? createdAt,
    $core.String? updatedAt,
  }) {
    final result = create();
    if (objectId != null) result.objectId = objectId;
    if (filename != null) result.filename = filename;
    if (contentType != null) result.contentType = contentType;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  Photo._();

  factory Photo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Photo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Photo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..aOS(2, _omitFieldNames ? '' : 'filename')
    ..aOS(3, _omitFieldNames ? '' : 'contentType')
    ..aInt64(4, _omitFieldNames ? '' : 'sizeBytes')
    ..aOS(5, _omitFieldNames ? '' : 'createdAt')
    ..aOS(6, _omitFieldNames ? '' : 'updatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Photo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Photo copyWith(void Function(Photo) updates) =>
      super.copyWith((message) => updates(message as Photo)) as Photo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Photo create() => Photo._();
  @$core.override
  Photo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Photo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Photo>(create);
  static Photo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get filename => $_getSZ(1);
  @$pb.TagNumber(2)
  set filename($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFilename() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilename() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get contentType => $_getSZ(2);
  @$pb.TagNumber(3)
  set contentType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContentType() => $_has(2);
  @$pb.TagNumber(3)
  void clearContentType() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sizeBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSizeBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearSizeBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get createdAt => $_getSZ(4);
  @$pb.TagNumber(5)
  set createdAt($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedAt() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get updatedAt => $_getSZ(5);
  @$pb.TagNumber(6)
  set updatedAt($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUpdatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearUpdatedAt() => $_clearField(6);
}

/// UploadRequest contains the photo data to upload
class UploadRequest extends $pb.GeneratedMessage {
  factory UploadRequest({
    $core.String? filename,
    $core.String? contentType,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (filename != null) result.filename = filename;
    if (contentType != null) result.contentType = contentType;
    if (data != null) result.data = data;
    return result;
  }

  UploadRequest._();

  factory UploadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UploadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'filename')
    ..aOS(2, _omitFieldNames ? '' : 'contentType')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadRequest copyWith(void Function(UploadRequest) updates) =>
      super.copyWith((message) => updates(message as UploadRequest))
          as UploadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UploadRequest create() => UploadRequest._();
  @$core.override
  UploadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UploadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadRequest>(create);
  static UploadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get filename => $_getSZ(0);
  @$pb.TagNumber(1)
  set filename($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFilename() => $_has(0);
  @$pb.TagNumber(1)
  void clearFilename() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get contentType => $_getSZ(1);
  @$pb.TagNumber(2)
  set contentType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContentType() => $_has(1);
  @$pb.TagNumber(2)
  void clearContentType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);
}

/// UploadResponse returns the uploaded photo metadata
class UploadResponse extends $pb.GeneratedMessage {
  factory UploadResponse({
    Photo? photo,
  }) {
    final result = create();
    if (photo != null) result.photo = photo;
    return result;
  }

  UploadResponse._();

  factory UploadResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UploadResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOM<Photo>(1, _omitFieldNames ? '' : 'photo', subBuilder: Photo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadResponse copyWith(void Function(UploadResponse) updates) =>
      super.copyWith((message) => updates(message as UploadResponse))
          as UploadResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UploadResponse create() => UploadResponse._();
  @$core.override
  UploadResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UploadResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadResponse>(create);
  static UploadResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Photo get photo => $_getN(0);
  @$pb.TagNumber(1)
  set photo(Photo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhoto() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhoto() => $_clearField(1);
  @$pb.TagNumber(1)
  Photo ensurePhoto() => $_ensure(0);
}

/// DownloadRequest specifies which photo to retrieve
class DownloadRequest extends $pb.GeneratedMessage {
  factory DownloadRequest({
    $core.String? objectId,
  }) {
    final result = create();
    if (objectId != null) result.objectId = objectId;
    return result;
  }

  DownloadRequest._();

  factory DownloadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DownloadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadRequest copyWith(void Function(DownloadRequest) updates) =>
      super.copyWith((message) => updates(message as DownloadRequest))
          as DownloadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DownloadRequest create() => DownloadRequest._();
  @$core.override
  DownloadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DownloadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadRequest>(create);
  static DownloadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);
}

/// DownloadResponse returns the photo with its data
class DownloadResponse extends $pb.GeneratedMessage {
  factory DownloadResponse({
    Photo? photo,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (photo != null) result.photo = photo;
    if (data != null) result.data = data;
    return result;
  }

  DownloadResponse._();

  factory DownloadResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DownloadResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DownloadResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOM<Photo>(1, _omitFieldNames ? '' : 'photo', subBuilder: Photo.create)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownloadResponse copyWith(void Function(DownloadResponse) updates) =>
      super.copyWith((message) => updates(message as DownloadResponse))
          as DownloadResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DownloadResponse create() => DownloadResponse._();
  @$core.override
  DownloadResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DownloadResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DownloadResponse>(create);
  static DownloadResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Photo get photo => $_getN(0);
  @$pb.TagNumber(1)
  set photo(Photo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhoto() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhoto() => $_clearField(1);
  @$pb.TagNumber(1)
  Photo ensurePhoto() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

/// DeletePhotoRequest specifies which photo to delete
class DeletePhotoRequest extends $pb.GeneratedMessage {
  factory DeletePhotoRequest({
    $core.String? objectId,
  }) {
    final result = create();
    if (objectId != null) result.objectId = objectId;
    return result;
  }

  DeletePhotoRequest._();

  factory DeletePhotoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePhotoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePhotoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePhotoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePhotoRequest copyWith(void Function(DeletePhotoRequest) updates) =>
      super.copyWith((message) => updates(message as DeletePhotoRequest))
          as DeletePhotoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePhotoRequest create() => DeletePhotoRequest._();
  @$core.override
  DeletePhotoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePhotoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePhotoRequest>(create);
  static DeletePhotoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);
}

/// DeletePhotoResponse confirms deletion
class DeletePhotoResponse extends $pb.GeneratedMessage {
  factory DeletePhotoResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  DeletePhotoResponse._();

  factory DeletePhotoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePhotoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePhotoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePhotoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePhotoResponse copyWith(void Function(DeletePhotoResponse) updates) =>
      super.copyWith((message) => updates(message as DeletePhotoResponse))
          as DeletePhotoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePhotoResponse create() => DeletePhotoResponse._();
  @$core.override
  DeletePhotoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePhotoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePhotoResponse>(create);
  static DeletePhotoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

/// GetPhotoRequest specifies which photo metadata to retrieve
class GetPhotoRequest extends $pb.GeneratedMessage {
  factory GetPhotoRequest({
    $core.String? objectId,
  }) {
    final result = create();
    if (objectId != null) result.objectId = objectId;
    return result;
  }

  GetPhotoRequest._();

  factory GetPhotoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPhotoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPhotoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPhotoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPhotoRequest copyWith(void Function(GetPhotoRequest) updates) =>
      super.copyWith((message) => updates(message as GetPhotoRequest))
          as GetPhotoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPhotoRequest create() => GetPhotoRequest._();
  @$core.override
  GetPhotoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPhotoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPhotoRequest>(create);
  static GetPhotoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);
}

/// GetPhotoResponse returns the photo metadata
class GetPhotoResponse extends $pb.GeneratedMessage {
  factory GetPhotoResponse({
    Photo? photo,
  }) {
    final result = create();
    if (photo != null) result.photo = photo;
    return result;
  }

  GetPhotoResponse._();

  factory GetPhotoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPhotoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPhotoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOM<Photo>(1, _omitFieldNames ? '' : 'photo', subBuilder: Photo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPhotoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPhotoResponse copyWith(void Function(GetPhotoResponse) updates) =>
      super.copyWith((message) => updates(message as GetPhotoResponse))
          as GetPhotoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPhotoResponse create() => GetPhotoResponse._();
  @$core.override
  GetPhotoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPhotoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPhotoResponse>(create);
  static GetPhotoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Photo get photo => $_getN(0);
  @$pb.TagNumber(1)
  set photo(Photo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhoto() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhoto() => $_clearField(1);
  @$pb.TagNumber(1)
  Photo ensurePhoto() => $_ensure(0);
}

/// ListPhotosRequest specifies pagination and filtering options
class ListPhotosRequest extends $pb.GeneratedMessage {
  factory ListPhotosRequest({
    $core.int? pageSize,
    $core.String? pageToken,
    $core.String? prefix,
  }) {
    final result = create();
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    if (prefix != null) result.prefix = prefix;
    return result;
  }

  ListPhotosRequest._();

  factory ListPhotosRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPhotosRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPhotosRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'pageSize')
    ..aOS(2, _omitFieldNames ? '' : 'pageToken')
    ..aOS(3, _omitFieldNames ? '' : 'prefix')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPhotosRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPhotosRequest copyWith(void Function(ListPhotosRequest) updates) =>
      super.copyWith((message) => updates(message as ListPhotosRequest))
          as ListPhotosRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPhotosRequest create() => ListPhotosRequest._();
  @$core.override
  ListPhotosRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPhotosRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPhotosRequest>(create);
  static ListPhotosRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get pageSize => $_getIZ(0);
  @$pb.TagNumber(1)
  set pageSize($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPageSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearPageSize() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set pageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get prefix => $_getSZ(2);
  @$pb.TagNumber(3)
  set prefix($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrefix() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrefix() => $_clearField(3);
}

/// ListPhotosResponse returns a paginated list of photos
class ListPhotosResponse extends $pb.GeneratedMessage {
  factory ListPhotosResponse({
    $core.Iterable<Photo>? photos,
    $core.String? nextPageToken,
  }) {
    final result = create();
    if (photos != null) result.photos.addAll(photos);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  ListPhotosResponse._();

  factory ListPhotosResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPhotosResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPhotosResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..pPM<Photo>(1, _omitFieldNames ? '' : 'photos', subBuilder: Photo.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPhotosResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPhotosResponse copyWith(void Function(ListPhotosResponse) updates) =>
      super.copyWith((message) => updates(message as ListPhotosResponse))
          as ListPhotosResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPhotosResponse create() => ListPhotosResponse._();
  @$core.override
  ListPhotosResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPhotosResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPhotosResponse>(create);
  static ListPhotosResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Photo> get photos => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

/// CopyPhotoRequest specifies source and destination for copy operation
class CopyPhotoRequest extends $pb.GeneratedMessage {
  factory CopyPhotoRequest({
    $core.String? sourceObjectId,
    $core.String? destinationObjectId,
  }) {
    final result = create();
    if (sourceObjectId != null) result.sourceObjectId = sourceObjectId;
    if (destinationObjectId != null)
      result.destinationObjectId = destinationObjectId;
    return result;
  }

  CopyPhotoRequest._();

  factory CopyPhotoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CopyPhotoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CopyPhotoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sourceObjectId')
    ..aOS(2, _omitFieldNames ? '' : 'destinationObjectId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopyPhotoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopyPhotoRequest copyWith(void Function(CopyPhotoRequest) updates) =>
      super.copyWith((message) => updates(message as CopyPhotoRequest))
          as CopyPhotoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CopyPhotoRequest create() => CopyPhotoRequest._();
  @$core.override
  CopyPhotoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CopyPhotoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CopyPhotoRequest>(create);
  static CopyPhotoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sourceObjectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourceObjectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceObjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get destinationObjectId => $_getSZ(1);
  @$pb.TagNumber(2)
  set destinationObjectId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDestinationObjectId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDestinationObjectId() => $_clearField(2);
}

/// CopyPhotoResponse returns the copied photo metadata
class CopyPhotoResponse extends $pb.GeneratedMessage {
  factory CopyPhotoResponse({
    Photo? photo,
  }) {
    final result = create();
    if (photo != null) result.photo = photo;
    return result;
  }

  CopyPhotoResponse._();

  factory CopyPhotoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CopyPhotoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CopyPhotoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOM<Photo>(1, _omitFieldNames ? '' : 'photo', subBuilder: Photo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopyPhotoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CopyPhotoResponse copyWith(void Function(CopyPhotoResponse) updates) =>
      super.copyWith((message) => updates(message as CopyPhotoResponse))
          as CopyPhotoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CopyPhotoResponse create() => CopyPhotoResponse._();
  @$core.override
  CopyPhotoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CopyPhotoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CopyPhotoResponse>(create);
  static CopyPhotoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Photo get photo => $_getN(0);
  @$pb.TagNumber(1)
  set photo(Photo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhoto() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhoto() => $_clearField(1);
  @$pb.TagNumber(1)
  Photo ensurePhoto() => $_ensure(0);
}

/// UpdatePhotoMetadataRequest specifies metadata updates for a photo
class UpdatePhotoMetadataRequest extends $pb.GeneratedMessage {
  factory UpdatePhotoMetadataRequest({
    $core.String? objectId,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? customMetadata,
    $core.String? contentType,
  }) {
    final result = create();
    if (objectId != null) result.objectId = objectId;
    if (customMetadata != null)
      result.customMetadata.addEntries(customMetadata);
    if (contentType != null) result.contentType = contentType;
    return result;
  }

  UpdatePhotoMetadataRequest._();

  factory UpdatePhotoMetadataRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePhotoMetadataRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePhotoMetadataRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..m<$core.String, $core.String>(2, _omitFieldNames ? '' : 'customMetadata',
        entryClassName: 'UpdatePhotoMetadataRequest.CustomMetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('photos'))
    ..aOS(3, _omitFieldNames ? '' : 'contentType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePhotoMetadataRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePhotoMetadataRequest copyWith(
          void Function(UpdatePhotoMetadataRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdatePhotoMetadataRequest))
          as UpdatePhotoMetadataRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePhotoMetadataRequest create() => UpdatePhotoMetadataRequest._();
  @$core.override
  UpdatePhotoMetadataRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePhotoMetadataRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePhotoMetadataRequest>(create);
  static UpdatePhotoMetadataRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $core.String> get customMetadata => $_getMap(1);

  @$pb.TagNumber(3)
  $core.String get contentType => $_getSZ(2);
  @$pb.TagNumber(3)
  set contentType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContentType() => $_has(2);
  @$pb.TagNumber(3)
  void clearContentType() => $_clearField(3);
}

/// UpdatePhotoMetadataResponse returns the updated photo metadata
class UpdatePhotoMetadataResponse extends $pb.GeneratedMessage {
  factory UpdatePhotoMetadataResponse({
    Photo? photo,
  }) {
    final result = create();
    if (photo != null) result.photo = photo;
    return result;
  }

  UpdatePhotoMetadataResponse._();

  factory UpdatePhotoMetadataResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePhotoMetadataResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePhotoMetadataResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOM<Photo>(1, _omitFieldNames ? '' : 'photo', subBuilder: Photo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePhotoMetadataResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePhotoMetadataResponse copyWith(
          void Function(UpdatePhotoMetadataResponse) updates) =>
      super.copyWith(
              (message) => updates(message as UpdatePhotoMetadataResponse))
          as UpdatePhotoMetadataResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePhotoMetadataResponse create() =>
      UpdatePhotoMetadataResponse._();
  @$core.override
  UpdatePhotoMetadataResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePhotoMetadataResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePhotoMetadataResponse>(create);
  static UpdatePhotoMetadataResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Photo get photo => $_getN(0);
  @$pb.TagNumber(1)
  set photo(Photo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhoto() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhoto() => $_clearField(1);
  @$pb.TagNumber(1)
  Photo ensurePhoto() => $_ensure(0);
}

/// GenerateSignedUrlRequest specifies parameters for signed URL generation
class GenerateSignedUrlRequest extends $pb.GeneratedMessage {
  factory GenerateSignedUrlRequest({
    $core.String? objectId,
    $fixnum.Int64? expirationSeconds,
    $core.String? method,
  }) {
    final result = create();
    if (objectId != null) result.objectId = objectId;
    if (expirationSeconds != null) result.expirationSeconds = expirationSeconds;
    if (method != null) result.method = method;
    return result;
  }

  GenerateSignedUrlRequest._();

  factory GenerateSignedUrlRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateSignedUrlRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateSignedUrlRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..aInt64(2, _omitFieldNames ? '' : 'expirationSeconds')
    ..aOS(3, _omitFieldNames ? '' : 'method')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateSignedUrlRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateSignedUrlRequest copyWith(
          void Function(GenerateSignedUrlRequest) updates) =>
      super.copyWith((message) => updates(message as GenerateSignedUrlRequest))
          as GenerateSignedUrlRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateSignedUrlRequest create() => GenerateSignedUrlRequest._();
  @$core.override
  GenerateSignedUrlRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateSignedUrlRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateSignedUrlRequest>(create);
  static GenerateSignedUrlRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expirationSeconds => $_getI64(1);
  @$pb.TagNumber(2)
  set expirationSeconds($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpirationSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpirationSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get method => $_getSZ(2);
  @$pb.TagNumber(3)
  set method($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMethod() => $_has(2);
  @$pb.TagNumber(3)
  void clearMethod() => $_clearField(3);
}

/// GenerateSignedUrlResponse returns the signed URL and expiration time
class GenerateSignedUrlResponse extends $pb.GeneratedMessage {
  factory GenerateSignedUrlResponse({
    $core.String? signedUrl,
    $core.String? expiresAt,
  }) {
    final result = create();
    if (signedUrl != null) result.signedUrl = signedUrl;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  GenerateSignedUrlResponse._();

  factory GenerateSignedUrlResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateSignedUrlResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateSignedUrlResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'signedUrl')
    ..aOS(2, _omitFieldNames ? '' : 'expiresAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateSignedUrlResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateSignedUrlResponse copyWith(
          void Function(GenerateSignedUrlResponse) updates) =>
      super.copyWith((message) => updates(message as GenerateSignedUrlResponse))
          as GenerateSignedUrlResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateSignedUrlResponse create() => GenerateSignedUrlResponse._();
  @$core.override
  GenerateSignedUrlResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateSignedUrlResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateSignedUrlResponse>(create);
  static GenerateSignedUrlResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get signedUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set signedUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignedUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignedUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get expiresAt => $_getSZ(1);
  @$pb.TagNumber(2)
  set expiresAt($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiresAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresAt() => $_clearField(2);
}

/// PhotoExistsRequest specifies which photo to check for existence
class PhotoExistsRequest extends $pb.GeneratedMessage {
  factory PhotoExistsRequest({
    $core.String? objectId,
  }) {
    final result = create();
    if (objectId != null) result.objectId = objectId;
    return result;
  }

  PhotoExistsRequest._();

  factory PhotoExistsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PhotoExistsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PhotoExistsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhotoExistsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhotoExistsRequest copyWith(void Function(PhotoExistsRequest) updates) =>
      super.copyWith((message) => updates(message as PhotoExistsRequest))
          as PhotoExistsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PhotoExistsRequest create() => PhotoExistsRequest._();
  @$core.override
  PhotoExistsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PhotoExistsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PhotoExistsRequest>(create);
  static PhotoExistsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);
}

/// PhotoExistsResponse returns whether the photo exists
class PhotoExistsResponse extends $pb.GeneratedMessage {
  factory PhotoExistsResponse({
    $core.bool? exists,
  }) {
    final result = create();
    if (exists != null) result.exists = exists;
    return result;
  }

  PhotoExistsResponse._();

  factory PhotoExistsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PhotoExistsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PhotoExistsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'exists')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhotoExistsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhotoExistsResponse copyWith(void Function(PhotoExistsResponse) updates) =>
      super.copyWith((message) => updates(message as PhotoExistsResponse))
          as PhotoExistsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PhotoExistsResponse create() => PhotoExistsResponse._();
  @$core.override
  PhotoExistsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PhotoExistsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PhotoExistsResponse>(create);
  static PhotoExistsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get exists => $_getBF(0);
  @$pb.TagNumber(1)
  set exists($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExists() => $_has(0);
  @$pb.TagNumber(1)
  void clearExists() => $_clearField(1);
}

/// ListDirectoriesRequest specifies the prefix and pagination for listing directories
class ListDirectoriesRequest extends $pb.GeneratedMessage {
  factory ListDirectoriesRequest({
    $core.String? prefix,
  }) {
    final result = create();
    if (prefix != null) result.prefix = prefix;
    return result;
  }

  ListDirectoriesRequest._();

  factory ListDirectoriesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListDirectoriesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDirectoriesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'prefix')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDirectoriesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDirectoriesRequest copyWith(
          void Function(ListDirectoriesRequest) updates) =>
      super.copyWith((message) => updates(message as ListDirectoriesRequest))
          as ListDirectoriesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDirectoriesRequest create() => ListDirectoriesRequest._();
  @$core.override
  ListDirectoriesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListDirectoriesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDirectoriesRequest>(create);
  static ListDirectoriesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get prefix => $_getSZ(0);
  @$pb.TagNumber(1)
  set prefix($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPrefix() => $_has(0);
  @$pb.TagNumber(1)
  void clearPrefix() => $_clearField(1);
}

/// ListDirectoriesResponse returns directory prefixes
class ListDirectoriesResponse extends $pb.GeneratedMessage {
  factory ListDirectoriesResponse({
    $core.Iterable<$core.String>? prefixes,
  }) {
    final result = create();
    if (prefixes != null) result.prefixes.addAll(prefixes);
    return result;
  }

  ListDirectoriesResponse._();

  factory ListDirectoriesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListDirectoriesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDirectoriesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'prefixes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDirectoriesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDirectoriesResponse copyWith(
          void Function(ListDirectoriesResponse) updates) =>
      super.copyWith((message) => updates(message as ListDirectoriesResponse))
          as ListDirectoriesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDirectoriesResponse create() => ListDirectoriesResponse._();
  @$core.override
  ListDirectoriesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListDirectoriesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDirectoriesResponse>(create);
  static ListDirectoriesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get prefixes => $_getList(0);
}

enum StreamingUploadRequest_Data { metadata, chunk, notSet }

/// StreamingUploadRequest is sent as a stream of chunks for large uploads
class StreamingUploadRequest extends $pb.GeneratedMessage {
  factory StreamingUploadRequest({
    PhotoMetadata? metadata,
    $core.List<$core.int>? chunk,
  }) {
    final result = create();
    if (metadata != null) result.metadata = metadata;
    if (chunk != null) result.chunk = chunk;
    return result;
  }

  StreamingUploadRequest._();

  factory StreamingUploadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamingUploadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, StreamingUploadRequest_Data>
      _StreamingUploadRequest_DataByTag = {
    1: StreamingUploadRequest_Data.metadata,
    2: StreamingUploadRequest_Data.chunk,
    0: StreamingUploadRequest_Data.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamingUploadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<PhotoMetadata>(1, _omitFieldNames ? '' : 'metadata',
        subBuilder: PhotoMetadata.create)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'chunk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamingUploadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamingUploadRequest copyWith(
          void Function(StreamingUploadRequest) updates) =>
      super.copyWith((message) => updates(message as StreamingUploadRequest))
          as StreamingUploadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamingUploadRequest create() => StreamingUploadRequest._();
  @$core.override
  StreamingUploadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamingUploadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamingUploadRequest>(create);
  static StreamingUploadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  StreamingUploadRequest_Data whichData() =>
      _StreamingUploadRequest_DataByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearData() => $_clearField($_whichOneof(0));

  /// metadata is sent in the first message only
  @$pb.TagNumber(1)
  PhotoMetadata get metadata => $_getN(0);
  @$pb.TagNumber(1)
  set metadata(PhotoMetadata value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMetadata() => $_has(0);
  @$pb.TagNumber(1)
  void clearMetadata() => $_clearField(1);
  @$pb.TagNumber(1)
  PhotoMetadata ensureMetadata() => $_ensure(0);

  /// chunk contains a portion of the photo data
  @$pb.TagNumber(2)
  $core.List<$core.int> get chunk => $_getN(1);
  @$pb.TagNumber(2)
  set chunk($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChunk() => $_has(1);
  @$pb.TagNumber(2)
  void clearChunk() => $_clearField(2);
}

/// PhotoMetadata contains info about the photo being uploaded
class PhotoMetadata extends $pb.GeneratedMessage {
  factory PhotoMetadata({
    $core.String? filename,
    $core.String? contentType,
  }) {
    final result = create();
    if (filename != null) result.filename = filename;
    if (contentType != null) result.contentType = contentType;
    return result;
  }

  PhotoMetadata._();

  factory PhotoMetadata.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PhotoMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PhotoMetadata',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'filename')
    ..aOS(2, _omitFieldNames ? '' : 'contentType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhotoMetadata clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhotoMetadata copyWith(void Function(PhotoMetadata) updates) =>
      super.copyWith((message) => updates(message as PhotoMetadata))
          as PhotoMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PhotoMetadata create() => PhotoMetadata._();
  @$core.override
  PhotoMetadata createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PhotoMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PhotoMetadata>(create);
  static PhotoMetadata? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get filename => $_getSZ(0);
  @$pb.TagNumber(1)
  set filename($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFilename() => $_has(0);
  @$pb.TagNumber(1)
  void clearFilename() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get contentType => $_getSZ(1);
  @$pb.TagNumber(2)
  set contentType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContentType() => $_has(1);
  @$pb.TagNumber(2)
  void clearContentType() => $_clearField(2);
}

/// StreamingDownloadRequest specifies which photo to download
class StreamingDownloadRequest extends $pb.GeneratedMessage {
  factory StreamingDownloadRequest({
    $core.String? objectId,
  }) {
    final result = create();
    if (objectId != null) result.objectId = objectId;
    return result;
  }

  StreamingDownloadRequest._();

  factory StreamingDownloadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamingDownloadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamingDownloadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamingDownloadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamingDownloadRequest copyWith(
          void Function(StreamingDownloadRequest) updates) =>
      super.copyWith((message) => updates(message as StreamingDownloadRequest))
          as StreamingDownloadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamingDownloadRequest create() => StreamingDownloadRequest._();
  @$core.override
  StreamingDownloadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamingDownloadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamingDownloadRequest>(create);
  static StreamingDownloadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);
}

enum StreamingDownloadResponse_Data { metadata, chunk, notSet }

/// StreamingDownloadResponse is streamed back in chunks
class StreamingDownloadResponse extends $pb.GeneratedMessage {
  factory StreamingDownloadResponse({
    Photo? metadata,
    $core.List<$core.int>? chunk,
  }) {
    final result = create();
    if (metadata != null) result.metadata = metadata;
    if (chunk != null) result.chunk = chunk;
    return result;
  }

  StreamingDownloadResponse._();

  factory StreamingDownloadResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamingDownloadResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, StreamingDownloadResponse_Data>
      _StreamingDownloadResponse_DataByTag = {
    1: StreamingDownloadResponse_Data.metadata,
    2: StreamingDownloadResponse_Data.chunk,
    0: StreamingDownloadResponse_Data.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamingDownloadResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'photos'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<Photo>(1, _omitFieldNames ? '' : 'metadata', subBuilder: Photo.create)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'chunk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamingDownloadResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamingDownloadResponse copyWith(
          void Function(StreamingDownloadResponse) updates) =>
      super.copyWith((message) => updates(message as StreamingDownloadResponse))
          as StreamingDownloadResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamingDownloadResponse create() => StreamingDownloadResponse._();
  @$core.override
  StreamingDownloadResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamingDownloadResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamingDownloadResponse>(create);
  static StreamingDownloadResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  StreamingDownloadResponse_Data whichData() =>
      _StreamingDownloadResponse_DataByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearData() => $_clearField($_whichOneof(0));

  /// metadata is sent in the first message only
  @$pb.TagNumber(1)
  Photo get metadata => $_getN(0);
  @$pb.TagNumber(1)
  set metadata(Photo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMetadata() => $_has(0);
  @$pb.TagNumber(1)
  void clearMetadata() => $_clearField(1);
  @$pb.TagNumber(1)
  Photo ensureMetadata() => $_ensure(0);

  /// chunk contains a portion of the photo data
  @$pb.TagNumber(2)
  $core.List<$core.int> get chunk => $_getN(1);
  @$pb.TagNumber(2)
  set chunk($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChunk() => $_has(1);
  @$pb.TagNumber(2)
  void clearChunk() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
