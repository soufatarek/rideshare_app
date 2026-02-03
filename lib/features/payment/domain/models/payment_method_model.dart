enum PaymentType { cash, card, wallet }

class PaymentMethod {
  final String id;
  final String name;
  final PaymentType type;
  final String? subtitle;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    this.subtitle,
  });
}
