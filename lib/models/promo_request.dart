class PromoRequestDraft {
  const PromoRequestDraft({
    required this.requestDate,
    required this.company,
    required this.validFrom,
    required this.validUpto,
    required this.items,
    this.salesPerson,
    this.customerGroup,
    this.customer,
    this.promoNote,
  });

  final DateTime requestDate;
  final String company;
  final DateTime validFrom;
  final DateTime validUpto;
  final String? salesPerson;
  final String? customerGroup;
  final String? customer;
  final String? promoNote;
  final List<PromoRequestItemDraft> items;

  Map<String, dynamic> toFrappeJson() => {
    'request_date': _date(requestDate),
    'company': company.trim(),
    'valid_from': _date(validFrom),
    'valid_upto': _date(validUpto),
    'status': 'Pending Approval',
    if (_hasValue(salesPerson)) 'sales_person': salesPerson!.trim(),
    if (_hasValue(customerGroup)) 'customer_group': customerGroup!.trim(),
    if (_hasValue(customer)) 'customer': customer!.trim(),
    if (_hasValue(promoNote)) 'promo_note': promoNote!.trim(),
    'items': items.map((item) => item.toFrappeJson()).toList(),
  };

  static String _date(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class PromoRequestItemDraft {
  const PromoRequestItemDraft({
    required this.itemCode,
    this.uom,
    this.priceListRate,
    this.requestedDiscount,
    this.requestedRate,
  });

  final String itemCode;
  final String? uom;
  final double? priceListRate;
  final double? requestedDiscount;
  final double? requestedRate;

  Map<String, dynamic> toFrappeJson() => {
    'item_code': itemCode.trim(),
    if (_hasValue(uom)) 'uom': uom!.trim(),
    if (priceListRate != null) 'price_list_rate': priceListRate,
    if (requestedDiscount != null) 'requested_discount': requestedDiscount,
    'requested_rate': requestedRate ?? _rateAfterDiscount(),
  };

  double _rateAfterDiscount() {
    final baseRate = priceListRate ?? 0;
    final discount = requestedDiscount ?? 0;
    if (baseRate <= 0) return 0;
    final rate = baseRate - discount;
    return rate > 0 ? rate : 0;
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;
}
