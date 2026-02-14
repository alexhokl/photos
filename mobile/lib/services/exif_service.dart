import 'dart:typed_data';

import 'package:exif/exif.dart';

/// Extracted EXIF metadata from a photo file.
class ExifMetadata {
  final String? cameraMake;
  final String? cameraModel;
  final String? lensModel;
  final double? focalLength;
  final double? aperture;
  final double? exposureTime;
  final int? iso;

  const ExifMetadata({
    this.cameraMake,
    this.cameraModel,
    this.lensModel,
    this.focalLength,
    this.aperture,
    this.exposureTime,
    this.iso,
  });

  /// Returns true if any camera information is available.
  bool get hasCameraInfo =>
      (cameraMake?.isNotEmpty ?? false) ||
      (cameraModel?.isNotEmpty ?? false) ||
      (lensModel?.isNotEmpty ?? false);

  /// Returns true if any exposure information is available.
  bool get hasExposureInfo =>
      (focalLength != null && focalLength! > 0) ||
      (aperture != null && aperture! > 0) ||
      (exposureTime != null && exposureTime! > 0) ||
      (iso != null && iso! > 0);

  /// Returns true if any metadata was extracted.
  bool get hasAnyMetadata => hasCameraInfo || hasExposureInfo;
}

/// Service for extracting EXIF metadata from photo files.
class ExifService {
  /// Extracts EXIF metadata from the given image bytes.
  ///
  /// Returns an [ExifMetadata] object containing the extracted data.
  /// Fields will be null if not present in the EXIF data.
  static Future<ExifMetadata> extractMetadata(Uint8List bytes) async {
    try {
      final data = await readExifFromBytes(bytes);
      if (data.isEmpty) {
        return const ExifMetadata();
      }

      return ExifMetadata(
        cameraMake: _extractString(data, 'Image Make'),
        cameraModel: _extractString(data, 'Image Model'),
        lensModel: _extractString(data, 'EXIF LensModel'),
        focalLength: _extractRational(data, 'EXIF FocalLength'),
        aperture: _extractRational(data, 'EXIF FNumber'),
        exposureTime: _extractRational(data, 'EXIF ExposureTime'),
        iso: _extractInt(data, 'EXIF ISOSpeedRatings'),
      );
    } catch (e) {
      // Return empty metadata if extraction fails
      return const ExifMetadata();
    }
  }

  static String? _extractString(Map<String, IfdTag> data, String key) {
    final tag = data[key];
    if (tag == null) return null;
    final value = tag.printable.trim();
    return value.isNotEmpty ? value : null;
  }

  static double? _extractRational(Map<String, IfdTag> data, String key) {
    final tag = data[key];
    if (tag == null) return null;

    final values = tag.values;
    if (values is IfdRatios && values.ratios.isNotEmpty) {
      final ratio = values.ratios.first;
      if (ratio.denominator != 0) {
        return ratio.numerator / ratio.denominator;
      }
    }
    return null;
  }

  static int? _extractInt(Map<String, IfdTag> data, String key) {
    final tag = data[key];
    if (tag == null) return null;

    final values = tag.values;
    if (values is IfdInts && values.ints.isNotEmpty) {
      return values.ints.first;
    }
    // Try parsing from printable as fallback
    final printable = tag.printable;
    return int.tryParse(printable);
  }
}
