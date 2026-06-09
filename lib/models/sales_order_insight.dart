class CustomerSalesInsight {
  final double creditLimit;
  final double outstanding;
  final String company;
  final String currency;
  final String priceList;
  final String priceListCurrency;
  final List<CustomerPurchaseHistory> history;

  const CustomerSalesInsight({
    this.creditLimit = 0,
    this.outstanding = 0,
    this.company = '',
    this.currency = '',
    this.priceList = '',
    this.priceListCurrency = '',
    this.history = const [],
  });

  double get availableCredit => creditLimit > 0 ? creditLimit - outstanding : 0;

  double projectedOutstanding(double orderTotal) => outstanding + orderTotal;

  double projectedAvailableCredit(double orderTotal) =>
      creditLimit > 0 ? creditLimit - projectedOutstanding(orderTotal) : 0;
}

class CustomerPurchaseHistory {
  final String id;
  final String doctype;
  final String date;
  final String status;
  final double total;
  final double outstanding;
  final int itemsCount;

  const CustomerPurchaseHistory({
    required this.id,
    this.doctype = 'Sales Order',
    required this.date,
    required this.status,
    required this.total,
    this.outstanding = 0,
    this.itemsCount = 0,
  });
}

class ItemSalesInsight {
  final String itemCode;
  final String priceList;
  final double priceListRate;
  final double price;
  final String currency;
  final double discountPercentage;
  final String pricingRule;
  final List<WarehouseStockInsight> stocks;

  const ItemSalesInsight({
    required this.itemCode,
    this.priceList = '',
    this.priceListRate = 0,
    this.price = 0,
    this.currency = '',
    this.discountPercentage = 0,
    this.pricingRule = '',
    this.stocks = const [],
  });
}

class WarehouseStockInsight {
  final String warehouse;
  final double actualQty;
  final double reservedQty;
  final double projectedQty;

  const WarehouseStockInsight({
    required this.warehouse,
    required this.actualQty,
    required this.reservedQty,
    required this.projectedQty,
  });
}
