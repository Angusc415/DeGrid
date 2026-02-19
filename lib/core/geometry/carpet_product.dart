/// A carpet product (roll) with fixed width. Used for carpet planning per room.
class CarpetProduct {
  final String name;
  /// Roll width in mm (dimension perpendicular to roll length when laid).
  final double rollWidthMm;
  /// Optional: roll length in metres (for ordering). Null = sold by length as needed.
  final double? rollLengthM;
  /// Optional: cost per m² or per linear m. Null = not set.
  final double? costPerSqm;
  /// Pattern repeat in mm for patterned carpet. Null = plain (no repeat).
  final double? patternRepeatMm;
  /// Minimum usable strip width in mm. Strips narrower than this are rejected/merged. Default ~100mm.
  final double? minStripWidthMm;
  /// Trim allowance per cut end in mm (e.g. 75–150mm each end).
  final double? trimAllowanceMm;

  CarpetProduct({
    required this.name,
    required this.rollWidthMm,
    this.rollLengthM,
    this.costPerSqm,
    this.patternRepeatMm,
    this.minStripWidthMm,
    this.trimAllowanceMm,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'rollWidthMm': rollWidthMm,
        'rollLengthM': rollLengthM,
        'costPerSqm': costPerSqm,
        'patternRepeatMm': patternRepeatMm,
        'minStripWidthMm': minStripWidthMm,
        'trimAllowanceMm': trimAllowanceMm,
      };

  factory CarpetProduct.fromJson(Map<String, dynamic> json) {
    return CarpetProduct(
      name: json['name'] as String? ?? 'Carpet',
      rollWidthMm: (json['rollWidthMm'] as num?)?.toDouble() ?? 4000,
      rollLengthM: (json['rollLengthM'] as num?)?.toDouble(),
      costPerSqm: (json['costPerSqm'] as num?)?.toDouble(),
      patternRepeatMm: (json['patternRepeatMm'] as num?)?.toDouble(),
      minStripWidthMm: (json['minStripWidthMm'] as num?)?.toDouble(),
      trimAllowanceMm: (json['trimAllowanceMm'] as num?)?.toDouble(),
    );
  }

  static List<CarpetProduct> listFromJson(List<dynamic>? list) {
    if (list == null) return [];
    return list
        .map((e) => CarpetProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Map<String, dynamic>> listToJson(List<CarpetProduct> products) {
    return products.map((p) => p.toJson()).toList();
  }

  CarpetProduct copyWith({
    String? name,
    double? rollWidthMm,
    double? rollLengthM,
    double? costPerSqm,
    double? patternRepeatMm,
    double? minStripWidthMm,
    double? trimAllowanceMm,
  }) {
    return CarpetProduct(
      name: name ?? this.name,
      rollWidthMm: rollWidthMm ?? this.rollWidthMm,
      rollLengthM: rollLengthM ?? this.rollLengthM,
      costPerSqm: costPerSqm ?? this.costPerSqm,
      patternRepeatMm: patternRepeatMm ?? this.patternRepeatMm,
      minStripWidthMm: minStripWidthMm ?? this.minStripWidthMm,
      trimAllowanceMm: trimAllowanceMm ?? this.trimAllowanceMm,
    );
  }
}
