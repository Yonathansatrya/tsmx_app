class NooRequestDraft {
  const NooRequestDraft({
    required this.requestDate,
    required this.company,
    required this.customerName,
    required this.addressLine1,
    this.salesPerson,
    this.customerCategory,
    this.defaultPaymentTermsTemplate,
    this.mobileNo,
  });

  final DateTime requestDate;
  final String company;
  final String? salesPerson;
  final String customerName;
  final String? customerCategory;
  final String? defaultPaymentTermsTemplate;
  final String? mobileNo;
  final String addressLine1;

  Map<String, dynamic> toFrappeJson() {
    return {
      'request_date': _date(requestDate),
      'company': company.trim(),
      'status': 'Pending Approval',
      'customer_name': customerName.trim(),
      'address_line1': addressLine1.trim(),
      if (_hasValue(salesPerson)) 'sales_person': salesPerson!.trim(),
      if (_hasValue(customerCategory))
        'customer_category': customerCategory!.trim(),
      if (_hasValue(defaultPaymentTermsTemplate))
        'default_payment_terms_template': defaultPaymentTermsTemplate!.trim(),
      if (_hasValue(mobileNo)) 'mobile_no': mobileNo!.trim(),
    };
  }

  static bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

  static String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
