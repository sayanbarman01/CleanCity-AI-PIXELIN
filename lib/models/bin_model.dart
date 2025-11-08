class BinModel {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double fillPercent;
  final List<String> tags;

  BinModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.fillPercent,
    this.tags = const [],
  });
}