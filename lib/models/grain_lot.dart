// ration_safe_mobile_app/lib/models/grain_lot.dart

class GrainLotItem {
  final String id;
  final String name;
  final String grainType;
  final double totalQuantity;
  final double remainingQuantity;

  const GrainLotItem({
    required this.id,
    required this.name,
    required this.grainType,
    required this.totalQuantity,
    required this.remainingQuantity,
  });

  factory GrainLotItem.fromJson(Map<String, dynamic> json) {
    return GrainLotItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      grainType: json['grain_type']?.toString() ?? 'Wheat',
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0.0,
      remainingQuantity: (json['remaining_quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'grain_type': grainType,
      'total_quantity': totalQuantity,
      'remaining_quantity': remainingQuantity,
    };
  }
}
