import 'package:equatable/equatable.dart';

enum IapProductType { lifetime, monthly, yearly }

/// Presentation-friendly product info. Loaded from Play Billing via
/// [IapService.loadProducts]. Decoupled from the `in_app_purchase`
/// `ProductDetails` type so screens never depend on the plugin directly.
class IapProduct extends Equatable {
  const IapProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.type,
    this.rawPrice,
    this.currencyCode,
  });

  final String id;
  final String title;
  final String description;

  /// Localized formatted price, e.g. `"$4.99"` or `"₹399.00"`. Pre-formatted
  /// by Play Billing — use as-is in the UI.
  final String price;

  /// Raw price (e.g. `"4.99"`) for comparisons / analytics. Optional.
  final String? rawPrice;

  /// ISO 4217 currency code (`"USD"`, `"INR"`, …). Optional.
  final String? currencyCode;

  final IapProductType type;

  @override
  List<Object?> get props => [id];
}
