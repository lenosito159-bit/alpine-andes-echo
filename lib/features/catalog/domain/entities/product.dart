import 'package:equatable/equatable.dart';

/// Product Entity
/// Represents a sellable product in the catalog
/// Immutable - changes create a new instance
class Product extends Equatable {
  final String id;              // UUID, inmutable
  final String name;            // Max 60 chars
  final double price;           // Precio de venta (no negativo)
  final String? barcode;        // Código de barras (puede ser null)
  final String? category;       // Categoría libre
  final int stock;              // Cantidad disponible (no negativo)
  final DateTime createdAt;     // Fecha de creación
  
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.barcode,
    this.category,
    required this.stock,
    required this.createdAt,
  });
  
  /// Creates a new Product with updated name
  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? barcode,
    String? category,
    int? stock,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  /// Validates product invariants
  /// Returns true if product is valid
  bool get isValid {
    return name.trim().isNotEmpty &&
           name.length <= 60 &&
           price.isFinite && price >= 0 &&
           stock >= 0;
  }
  
  /// Returns formatted price for display
  String get formattedPrice {
    return '\$${price.toStringAsFixed(2)}';
  }
  
  @override
  List<Object?> get props => [
    id,
    name,
    price,
    barcode,
    category,
    stock,
    createdAt,
  ];
  
  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, barcode: $barcode, stock: $stock)';
  }
}
