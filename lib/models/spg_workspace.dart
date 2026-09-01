class SpgCustomerOption {
  final String id;
  final String name;
  final String address;

  const SpgCustomerOption({
    required this.id,
    required this.name,
    this.address = '',
  });

  factory SpgCustomerOption.fromJson(Map<String, dynamic> json) {
    final id = json['name']?.toString() ?? '';
    return SpgCustomerOption(
      id: id,
      name: json['customer_name']?.toString() ?? id,
      address: json['primary_address']?.toString() ?? '',
    );
  }
}
