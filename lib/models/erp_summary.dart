enum SummarySyncStatus { idle, syncing, completed, error }

class DocumentSummary {
  final double totalValue;
  final int documentCount;

  const DocumentSummary({this.totalValue = 0, this.documentCount = 0});

  Map<String, dynamic> toJson() => {
    'totalValue': totalValue,
    'documentCount': documentCount,
  };

  factory DocumentSummary.fromJson(Map<String, dynamic> json) {
    return DocumentSummary(
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      documentCount: (json['documentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardSummary {
  final double salesTotal;
  final double salesOpen;
  final double salesCompleted;
  final int salesDraftCount;
  final int salesOpenCount;
  final int salesCompletedCount;
  final double purchaseTotal;
  final double purchasePending;
  final double purchaseDelayed;
  final int purchaseDraftCount;
  final int purchasePendingCount;
  final int purchaseCompletedCount;
  final int unpaidSalesInvoices;
  final int overduePurchaseInvoices;
  final int stockAlerts;

  const DashboardSummary({
    this.salesTotal = 0,
    this.salesOpen = 0,
    this.salesCompleted = 0,
    this.salesDraftCount = 0,
    this.salesOpenCount = 0,
    this.salesCompletedCount = 0,
    this.purchaseTotal = 0,
    this.purchasePending = 0,
    this.purchaseDelayed = 0,
    this.purchaseDraftCount = 0,
    this.purchasePendingCount = 0,
    this.purchaseCompletedCount = 0,
    this.unpaidSalesInvoices = 0,
    this.overduePurchaseInvoices = 0,
    this.stockAlerts = 0,
  });

  Map<String, dynamic> toJson() => {
    'salesTotal': salesTotal,
    'salesOpen': salesOpen,
    'salesCompleted': salesCompleted,
    'salesDraftCount': salesDraftCount,
    'salesOpenCount': salesOpenCount,
    'salesCompletedCount': salesCompletedCount,
    'purchaseTotal': purchaseTotal,
    'purchasePending': purchasePending,
    'purchaseDelayed': purchaseDelayed,
    'purchaseDraftCount': purchaseDraftCount,
    'purchasePendingCount': purchasePendingCount,
    'purchaseCompletedCount': purchaseCompletedCount,
    'unpaidSalesInvoices': unpaidSalesInvoices,
    'overduePurchaseInvoices': overduePurchaseInvoices,
    'stockAlerts': stockAlerts,
  };

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    int asInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    double asDouble(String key) => (json[key] as num?)?.toDouble() ?? 0;

    return DashboardSummary(
      salesTotal: asDouble('salesTotal'),
      salesOpen: asDouble('salesOpen'),
      salesCompleted: asDouble('salesCompleted'),
      salesDraftCount: asInt('salesDraftCount'),
      salesOpenCount: asInt('salesOpenCount'),
      salesCompletedCount: asInt('salesCompletedCount'),
      purchaseTotal: asDouble('purchaseTotal'),
      purchasePending: asDouble('purchasePending'),
      purchaseDelayed: asDouble('purchaseDelayed'),
      purchaseDraftCount: asInt('purchaseDraftCount'),
      purchasePendingCount: asInt('purchasePendingCount'),
      purchaseCompletedCount: asInt('purchaseCompletedCount'),
      unpaidSalesInvoices: asInt('unpaidSalesInvoices'),
      overduePurchaseInvoices: asInt('overduePurchaseInvoices'),
      stockAlerts: asInt('stockAlerts'),
    );
  }
}
