import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/catalog/domain/entities/product.dart';
import 'package:zivlo/features/checkout/domain/repositories/cart_repository.dart';
/// In-Memory Implementation of ICartRepository
/// 
/// Stores cart items in memory for fast access
/// This is a temporary implementation - can be replaced with Hive for persistence
/// 
/// Note: Cart data will be lost when the app is closed
class InMemoryCartRepository implements ICartRepository {
  final Map<String, CartItem> _items = {};
  double _discount = 0.0;
  bool _discountIsPercentage = false;
  final Uuid uuid;

  InMemoryCartRepository({Uuid? uuid}) : uuid = uuid ?? const Uuid();

  @override
  Future<Either<Failure, List<CartItem>>> getItems() async {
    try {
      return right(_items.values.toList());
    } catch (e) {
      return left(CartOperationFailure('get_items',
        message: 'Failed to get cart items: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, int>> getItemCount() async {
    try {
      return right(_items.length);
    } catch (e) {
      return left(CartOperationFailure('get_item_count',
        message: 'Failed to get item count: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, double>> getSubtotal() async {
    try {
      final subtotal = _items.values.fold<double>(
        0.0,
        (sum, item) => sum + item.subtotal,
      );
      return right(subtotal);
    } catch (e) {
      return left(CartOperationFailure('get_subtotal',
        message: 'Failed to get subtotal: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, double>> getDiscount() async {
    try {
      if (_discountIsPercentage) {
        final subtotalResult = await getSubtotal();
        final subtotal = subtotalResult.getOrElse((_) => 0.0);
        return right(subtotal * (_discount / 100));
      }
      return right(_discount);
    } catch (e) {
      return left(CartOperationFailure('get_discount',
        message: 'Failed to get discount: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, double>> getTotal() async {
    try {
      final subtotalResult = await getSubtotal();
      final discountResult = await getDiscount();

      final subtotal = subtotalResult.getOrElse((_) => 0.0);
      final discount = discountResult.getOrElse((_) => 0.0);

      final total = subtotal - discount;
      return right(total < 0 ? 0.0 : total);
    } catch (e) {
      return left(CartOperationFailure('get_total',
        message: 'Failed to get total: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, CartItem>> addProduct(
    Product product, {
    int quantity = 1,
  }) async {
    try {
      if (quantity <= 0 || !product.price.isFinite || product.price < 0) {
        return left(const CartOperationFailure('add_product', message: 'Cantidad o precio inválido'));
      }
      if (quantity > product.stock) {
        return left(const CartOperationFailure('add_product', message: 'Stock insuficiente'));
      }
      // Check if product is already in cart
      final existingItem = _items.values.firstWhere(
        (item) => item.product.id == product.id,
        orElse: () => CartItem(id: '', product: Product(id: '', name: '', price: 0, stock: 0, createdAt: DateTime(0)), quantity: 0),
      );

      if (existingItem.id.isNotEmpty) {
        // Update quantity
        final newQuantity = existingItem.quantity + quantity;
        return updateQuantity(existingItem.id, newQuantity);
      }

      // Add new item
      final item = CartItem(
        id: uuid.v4(),
        product: product,
        quantity: quantity,
      );
      _items[item.id] = item;
      return right(item);
    } catch (e) {
      return left(CartOperationFailure('add_product',
        message: 'Failed to add product to cart: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, CartItem>> updateQuantity(
    String itemId,
    int quantity,
  ) async {
    try {
      if (!_items.containsKey(itemId)) {
        return left(CartOperationFailure('update_quantity',
          message: 'Item not found in cart'));
      }

      if (quantity <= 0) {
        return left(const CartOperationFailure('update_quantity',
          message: 'La cantidad debe ser positiva'));
      }

      final existingItem = _items[itemId]!;
      if (quantity > existingItem.product.stock) {
        return left(const CartOperationFailure('update_quantity', message: 'Stock insuficiente'));
      }
      final updatedItem = existingItem.copyWith(quantity: quantity);
      _items[itemId] = updatedItem;

      return right(updatedItem);
    } catch (e) {
      return left(CartOperationFailure('update_quantity',
        message: 'Failed to update quantity: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeItem(String itemId) async {
    try {
      _items.remove(itemId);
      return right(unit);
    } catch (e) {
      return left(CartOperationFailure('remove_item',
        message: 'Failed to remove item: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> clear() async {
    try {
      _items.clear();
      _discount = 0.0;
      _discountIsPercentage = false;
      return right(unit);
    } catch (e) {
      return left(CartOperationFailure('clear',
        message: 'Failed to clear cart: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, double>> applyDiscount(
    double discount, {
    bool isPercentage = false,
  }) async {
    try {
      if (!discount.isFinite || discount < 0) {
        return left(CartOperationFailure('apply_discount',
          message: 'Discount cannot be negative'));
      }

      if (isPercentage && discount > 100) {
        return left(CartOperationFailure('apply_discount',
          message: 'Percentage discount cannot exceed 100%'));
      }

      _discount = discount;
      _discountIsPercentage = isPercentage;

      final discountResult = await getDiscount();
      return discountResult;
    } catch (e) {
      return left(CartOperationFailure('apply_discount',
        message: 'Failed to apply discount: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeDiscount() async {
    try {
      _discount = 0.0;
      _discountIsPercentage = false;
      return right(unit);
    } catch (e) {
      return left(CartOperationFailure('remove_discount',
        message: 'Failed to remove discount: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  /// Clears the cart (for testing)
  void clearSync() {
    _items.clear();
    _discount = 0.0;
    _discountIsPercentage = false;
  }
}
