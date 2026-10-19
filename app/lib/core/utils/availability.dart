import 'package:parkspot/core/constants/app_constants.dart';

/// How full a lot is, from its live free-slot count.
///
/// One rule shared by the map marker, the lot sheet and any list, so they
/// can't disagree. Colours live in `AppSemanticColors.availability`.
enum Availability {
  high,
  medium,
  low,
  full;

  factory Availability.fromCounts({required int free, required int total}) {
    if (free <= 0 || total <= 0) return Availability.full;
    final ratio = free / total;
    if (ratio > AppConstants.availabilityMediumRatio) return Availability.high;
    if (ratio >= AppConstants.availabilityLowRatio) return Availability.medium;
    return Availability.low;
  }
}
