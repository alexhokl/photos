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

import 'package:protobuf/protobuf.dart' as $pb;

/// Phase identifies which stage of the sync produced this progress message.
class SyncDatabaseProgress_Phase extends $pb.ProtobufEnum {
  static const SyncDatabaseProgress_Phase PHASE_UNSPECIFIED =
      SyncDatabaseProgress_Phase._(
          0, _omitEnumNames ? '' : 'PHASE_UNSPECIFIED');
  static const SyncDatabaseProgress_Phase PHASE_ADD =
      SyncDatabaseProgress_Phase._(1, _omitEnumNames ? '' : 'PHASE_ADD');
  static const SyncDatabaseProgress_Phase PHASE_REMOVE =
      SyncDatabaseProgress_Phase._(2, _omitEnumNames ? '' : 'PHASE_REMOVE');
  static const SyncDatabaseProgress_Phase PHASE_METADATA =
      SyncDatabaseProgress_Phase._(3, _omitEnumNames ? '' : 'PHASE_METADATA');

  static const $core.List<SyncDatabaseProgress_Phase> values =
      <SyncDatabaseProgress_Phase>[
    PHASE_UNSPECIFIED,
    PHASE_ADD,
    PHASE_REMOVE,
    PHASE_METADATA,
  ];

  static final $core.List<SyncDatabaseProgress_Phase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static SyncDatabaseProgress_Phase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SyncDatabaseProgress_Phase._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
