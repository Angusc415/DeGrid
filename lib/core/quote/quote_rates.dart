/// Per-project pricing rates for turning a take-off into a job quote.
///
/// All rates are optional: a null rate leaves that line unpriced on the quote
/// (quantity still shown) rather than silently pricing it at zero. Persisted
/// per project as JSON (see `quoteRatesJson`).
class QuoteRates {
  /// Underlay supply cost per m² of carpeted floor area.
  final double? underlayCostPerSqm;

  /// Gripper (smoothedge) cost per linear metre of carpeted room perimeter.
  final double? gripperCostPerM;

  /// Door bar / trim cost per doorway opening.
  final double? doorBarCostEach;

  /// Installation labour per m² of carpeted floor area.
  final double? labourCostPerSqm;

  /// Installation labour per stair step.
  final double? stairLabourPerStep;

  /// GST percent applied to the subtotal (default 10, AU).
  final double gstPercent;

  /// Whether GST is added to the quote total.
  final bool includeGst;

  const QuoteRates({
    this.underlayCostPerSqm,
    this.gripperCostPerM,
    this.doorBarCostEach,
    this.labourCostPerSqm,
    this.stairLabourPerStep,
    this.gstPercent = 10.0,
    this.includeGst = true,
  });

  /// True when at least one rate is set (a quote is worth showing).
  bool get hasAnyRates =>
      underlayCostPerSqm != null ||
      gripperCostPerM != null ||
      doorBarCostEach != null ||
      labourCostPerSqm != null ||
      stairLabourPerStep != null;

  Map<String, dynamic> toJson() => {
        'underlayCostPerSqm': underlayCostPerSqm,
        'gripperCostPerM': gripperCostPerM,
        'doorBarCostEach': doorBarCostEach,
        'labourCostPerSqm': labourCostPerSqm,
        'stairLabourPerStep': stairLabourPerStep,
        'gstPercent': gstPercent,
        'includeGst': includeGst,
      };

  factory QuoteRates.fromJson(Map<String, dynamic> json) {
    const defaults = QuoteRates();
    return QuoteRates(
      underlayCostPerSqm: (json['underlayCostPerSqm'] as num?)?.toDouble(),
      gripperCostPerM: (json['gripperCostPerM'] as num?)?.toDouble(),
      doorBarCostEach: (json['doorBarCostEach'] as num?)?.toDouble(),
      labourCostPerSqm: (json['labourCostPerSqm'] as num?)?.toDouble(),
      stairLabourPerStep: (json['stairLabourPerStep'] as num?)?.toDouble(),
      gstPercent:
          (json['gstPercent'] as num?)?.toDouble() ?? defaults.gstPercent,
      includeGst: json['includeGst'] as bool? ?? defaults.includeGst,
    );
  }

  /// Copy with selected fields replaced. Because null is a meaningful value
  /// (rate not set), nullable rates use a sentinel-free two-param style:
  /// pass `clearX: true` to null a rate out.
  QuoteRates copyWith({
    double? underlayCostPerSqm,
    bool clearUnderlayCostPerSqm = false,
    double? gripperCostPerM,
    bool clearGripperCostPerM = false,
    double? doorBarCostEach,
    bool clearDoorBarCostEach = false,
    double? labourCostPerSqm,
    bool clearLabourCostPerSqm = false,
    double? stairLabourPerStep,
    bool clearStairLabourPerStep = false,
    double? gstPercent,
    bool? includeGst,
  }) {
    return QuoteRates(
      underlayCostPerSqm: clearUnderlayCostPerSqm
          ? null
          : (underlayCostPerSqm ?? this.underlayCostPerSqm),
      gripperCostPerM:
          clearGripperCostPerM ? null : (gripperCostPerM ?? this.gripperCostPerM),
      doorBarCostEach:
          clearDoorBarCostEach ? null : (doorBarCostEach ?? this.doorBarCostEach),
      labourCostPerSqm: clearLabourCostPerSqm
          ? null
          : (labourCostPerSqm ?? this.labourCostPerSqm),
      stairLabourPerStep: clearStairLabourPerStep
          ? null
          : (stairLabourPerStep ?? this.stairLabourPerStep),
      gstPercent: gstPercent ?? this.gstPercent,
      includeGst: includeGst ?? this.includeGst,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is QuoteRates &&
        other.underlayCostPerSqm == underlayCostPerSqm &&
        other.gripperCostPerM == gripperCostPerM &&
        other.doorBarCostEach == doorBarCostEach &&
        other.labourCostPerSqm == labourCostPerSqm &&
        other.stairLabourPerStep == stairLabourPerStep &&
        other.gstPercent == gstPercent &&
        other.includeGst == includeGst;
  }

  @override
  int get hashCode => Object.hash(
        underlayCostPerSqm,
        gripperCostPerM,
        doorBarCostEach,
        labourCostPerSqm,
        stairLabourPerStep,
        gstPercent,
        includeGst,
      );
}
