class NooRequestDraft {
  const NooRequestDraft({
    required this.requestDate,
    required this.company,
    required this.customerName,
    required this.addressLine1,
    this.salesPerson,
    this.customerType = 'Company',
    this.customerGroup,
    this.territory,
    this.taxId,
    this.contactPerson,
    this.mobileNo,
    this.emailId,
    this.city,
    this.province,
    this.pincode,
    this.latitude,
    this.longitude,
    this.notes,
  });

  final DateTime requestDate;
  final String company;
  final String? salesPerson;
  final String customerName;
  final String customerType;
  final String? customerGroup;
  final String? territory;
  final String? taxId;
  final String? contactPerson;
  final String? mobileNo;
  final String? emailId;
  final String addressLine1;
  final String? city;
  final String? province;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final String? notes;

  Map<String, dynamic> toFrappeJson() {
    return {
      'request_date': _date(requestDate),
      'company': company.trim(),
      'status': 'Pending Approval',
      'customer_name': customerName.trim(),
      'customer_type': customerType.trim().isEmpty ? 'Company' : customerType,
      'address_line1': addressLine1.trim(),
      if (_hasValue(salesPerson)) 'sales_person': salesPerson!.trim(),
      if (_hasValue(customerGroup)) 'customer_group': customerGroup!.trim(),
      if (_hasValue(territory)) 'territory': territory!.trim(),
      if (_hasValue(taxId)) 'tax_id': taxId!.trim(),
      if (_hasValue(contactPerson)) 'contact_person': contactPerson!.trim(),
      if (_hasValue(mobileNo)) 'mobile_no': mobileNo!.trim(),
      if (_hasValue(emailId)) 'email_id': emailId!.trim(),
      if (_hasValue(city)) 'city': city!.trim(),
      if (_hasValue(province)) 'province': province!.trim(),
      if (_hasValue(pincode)) 'pincode': pincode!.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (_hasValue(notes)) 'notes': notes!.trim(),
    };
  }

  static bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

  static String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
