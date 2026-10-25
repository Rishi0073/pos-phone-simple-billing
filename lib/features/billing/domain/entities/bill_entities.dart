import 'package:simple_billing/core/errors/app_failures.dart';

class BillItem {
  const BillItem({
    this.id,
    this.billId,
    required this.itemOrder,
    required this.price,
    required this.quantity,
  });

  final int? id;
  final int? billId;
  final int itemOrder;
  final int price;
  final int quantity;

  int get lineTotal => price * quantity;

  BillItem copyWith({
    int? id,
    int? billId,
    int? itemOrder,
    int? price,
    int? quantity,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      itemOrder: itemOrder ?? this.itemOrder,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BillItem &&
      other.id == id &&
      other.billId == billId &&
      other.itemOrder == itemOrder &&
      other.price == price &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(id, billId, itemOrder, price, quantity);

  @override
  String toString() => 'BillItem($price x $quantity = $lineTotal)';
}

class CurrentItem {
  const CurrentItem({
    required this.price,
    required this.quantity,
    this.quantityMode = false,
  });

  /// [quantity] is the typed quantity; 0 means "not typed" and reads as 1.
  /// [quantityMode] is true after the user pressed "×": digits go to quantity.
  final int price;
  final int quantity;
  final bool quantityMode;

  int get effectiveQuantity => quantity == 0 ? 1 : quantity;

  int get lineTotal => price * effectiveQuantity;

  bool get hasInput => price > 0;

  bool get isValid => price >= 0 && effectiveQuantity > 0;

  bool get quantityTyped => quantity > 0;

  BillItem toBillItem({int? id, int? billId, required int itemOrder}) {
    if (!isValid) {
      if (effectiveQuantity <= 0) {
        throw const InvalidQuantity();
      }
      throw const InvalidPrice();
    }
    return BillItem(
      id: id,
      billId: billId,
      itemOrder: itemOrder,
      price: price,
      quantity: effectiveQuantity,
    );
  }

  @override
  String toString() => 'CurrentItem($price x $effectiveQuantity = $lineTotal)';
}

enum PaymentMethod { cash, upi }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'CASH',
        PaymentMethod.upi => 'UPI',
      };
}

enum PaymentStatus { pending, paid }

class Bill {
  const Bill({
    required this.id,
    required this.billNumber,
    required this.createdAt,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    this.notes,
    this.items = const [],
  });

  final int id;
  final int billNumber;
  final DateTime createdAt;
  final int subtotal;
  final int discountAmount;
  final int total;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? notes;
  final List<BillItem> items;

  Bill copyWith({
    int? id,
    int? billNumber,
    DateTime? createdAt,
    int? subtotal,
    int? discountAmount,
    int? total,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    String? notes,
    List<BillItem>? items,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      createdAt: createdAt ?? this.createdAt,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }
}