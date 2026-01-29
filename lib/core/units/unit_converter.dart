/// Utility for converting between measurement units.
/// 
/// Internal storage is always in millimeters (mm) for precision.
/// Display can be in metric (mm/cm) or imperial (ft-in).
class UnitConverter {
  // Conversion constants
  static const double mmPerInch = 25.4;
  static const double mmPerFoot = 304.8; // 12 * 25.4
  static const double mmPerCm = 10.0;
  static const double cmPerM = 100.0;

  /// Format a distance in mm to a human-readable string.
  /// 
  /// [distanceMm] - distance in millimeters
  /// [useImperial] - if true, format as ft-in; if false, format as mm/cm
  static String formatDistance(double distanceMm, {bool useImperial = false}) {
    if (useImperial) {
      return _formatImperial(distanceMm);
    } else {
      return _formatMetric(distanceMm);
    }
  }

  /// Format as imperial (feet and inches).
  static String _formatImperial(double mm) {
    final totalInches = mm / mmPerInch;
    final feet = (totalInches / 12).floor();
    final inches = (totalInches % 12).round();
    
    if (feet == 0) {
      return '$inches"';
    } else if (inches == 0) {
      return "$feet'";
    } else {
      return "$feet' $inches\"";
    }
  }

  /// Format as metric (mm or cm).
  static String _formatMetric(double mm) {
    if (mm < 100) {
      // Use mm for small distances
      return '${mm.round()}mm';
    } else {
      // Use cm for larger distances
      final cm = mm / mmPerCm;
      if (cm % 1 == 0) {
        return '${cm.round()}cm';
      } else {
        return '${cm.toStringAsFixed(1)}cm';
      }
    }
  }

  /// Format area in square millimeters to a human-readable string.
  static String formatArea(double areaMm2, {bool useImperial = false}) {
    if (useImperial) {
      // Convert to square feet
      final sqFt = areaMm2 / (mmPerFoot * mmPerFoot);
      if (sqFt < 1) {
        final sqIn = areaMm2 / (mmPerInch * mmPerInch);
        return '${sqIn.round()} sq in';
      } else if (sqFt % 1 == 0) {
        return '${sqFt.round()} sq ft';
      } else {
        return '${sqFt.toStringAsFixed(1)} sq ft';
      }
    } else {
      // Use square meters for large areas, cm² for small
      final sqM = areaMm2 / (cmPerM * cmPerM * mmPerCm * mmPerCm);
      if (sqM >= 1) {
        if (sqM % 1 == 0) {
          return '${sqM.round()} m²';
        } else {
          return '${sqM.toStringAsFixed(2)} m²';
        }
      } else {
        // Use cm² for small areas
        final sqCm = areaMm2 / (mmPerCm * mmPerCm);
        if (sqCm % 1 == 0) {
          return '${sqCm.round()} cm²';
        } else {
          return '${sqCm.toStringAsFixed(1)} cm²';
        }
      }
    }
  }
}
