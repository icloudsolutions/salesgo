import 'package:salesgo/models/discount.dart';
import 'package:salesgo/models/product.dart';


class CartItem {
  final String id;
  final Product product;
  Discount? discount;

  CartItem({
    required this.id,
    required this.product,
    this.discount,
  });
}
