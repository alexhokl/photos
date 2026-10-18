/// Formatting for the EXIF values shown in the photo info views.
library;

/// "1/1000s" for fractions of a second, "2.0s" otherwise; empty when unknown.
String formatExposureTime(double exposureTime) {
  if (exposureTime <= 0) return '';
  if (exposureTime >= 1) {
    return '${exposureTime.toStringAsFixed(1)}s';
  }
  // Convert to fraction (e.g., 0.001 -> 1/1000)
  final denominator = (1 / exposureTime).round();
  return '1/${denominator}s';
}

/// "f/1.8"; empty when unknown.
String formatAperture(double aperture) {
  if (aperture <= 0) return '';
  return 'f/${aperture.toStringAsFixed(1)}';
}

/// "26.0mm"; empty when unknown.
String formatFocalLength(double focalLength) {
  if (focalLength <= 0) return '';
  return '${focalLength.toStringAsFixed(1)}mm';
}
