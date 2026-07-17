/// A carpeted straight flight of stairs.
///
/// Carpet runs continuously over each tread and riser, so the material run
/// length per step is the going (tread depth) + riser height + a small nosing
/// wrap allowance. Total run length times the stair width gives the carpet
/// area. [carpetProductIndex] ties the flight to a project carpet product for
/// pricing; null means the carpet is counted but left unpriced.
class Staircase {
  final String name;
  final int steps;

  /// Tread depth (going) per step in mm.
  final double goingMm;

  /// Riser height per step in mm.
  final double riserMm;

  /// Stair width in mm.
  final double widthMm;

  /// Extra carpet per step wrapped over the nosing, in mm.
  final double nosingMm;

  /// Index into the project's carpet products; null = unpriced.
  final int? carpetProductIndex;

  const Staircase({
    required this.name,
    this.steps = 13,
    this.goingMm = 250,
    this.riserMm = 180,
    this.widthMm = 900,
    this.nosingMm = 25,
    this.carpetProductIndex,
  });

  /// Continuous carpet run length over the whole flight, in mm.
  double get carpetRunLengthMm => steps * (goingMm + riserMm + nosingMm);

  /// Carpet area for the flight, in m².
  double get carpetAreaSqm => (carpetRunLengthMm / 1000) * (widthMm / 1000);

  Map<String, dynamic> toJson() => {
        'name': name,
        'steps': steps,
        'goingMm': goingMm,
        'riserMm': riserMm,
        'widthMm': widthMm,
        'nosingMm': nosingMm,
        'carpetProductIndex': carpetProductIndex,
      };

  factory Staircase.fromJson(Map<String, dynamic> json) {
    const defaults = Staircase(name: 'Stairs');
    return Staircase(
      name: json['name'] as String? ?? 'Stairs',
      steps: (json['steps'] as num?)?.toInt() ?? defaults.steps,
      goingMm: (json['goingMm'] as num?)?.toDouble() ?? defaults.goingMm,
      riserMm: (json['riserMm'] as num?)?.toDouble() ?? defaults.riserMm,
      widthMm: (json['widthMm'] as num?)?.toDouble() ?? defaults.widthMm,
      nosingMm: (json['nosingMm'] as num?)?.toDouble() ?? defaults.nosingMm,
      carpetProductIndex: (json['carpetProductIndex'] as num?)?.toInt(),
    );
  }

  static List<Staircase> listFromJson(List<dynamic>? list) {
    if (list == null) return const [];
    return list
        .map((e) => Staircase.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Map<String, dynamic>> listToJson(List<Staircase> stairs) =>
      stairs.map((s) => s.toJson()).toList();

  Staircase copyWith({
    String? name,
    int? steps,
    double? goingMm,
    double? riserMm,
    double? widthMm,
    double? nosingMm,
    int? carpetProductIndex,
    bool clearCarpetProductIndex = false,
  }) {
    return Staircase(
      name: name ?? this.name,
      steps: steps ?? this.steps,
      goingMm: goingMm ?? this.goingMm,
      riserMm: riserMm ?? this.riserMm,
      widthMm: widthMm ?? this.widthMm,
      nosingMm: nosingMm ?? this.nosingMm,
      carpetProductIndex: clearCarpetProductIndex
          ? null
          : (carpetProductIndex ?? this.carpetProductIndex),
    );
  }
}
