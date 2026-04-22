import 'package:flutter/material.dart';

enum PaymentType { cash, card, wallet, polar }

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

  /// Returns the appropriate icon for each payment type.
  IconData get icon {
    switch (type) {
      case PaymentType.cash:
        return Icons.money;
      case PaymentType.card:
        return Icons.credit_card;
      case PaymentType.wallet:
        return Icons.account_balance_wallet;
      case PaymentType.polar:
        return Icons.electric_bolt;
    }
  }
}
