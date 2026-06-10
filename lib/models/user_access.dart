class CurrentUserAccess {
  final String user;
  final String roleProfile;
  final List<String> roles;

  const CurrentUserAccess({
    required this.user,
    required this.roleProfile,
    this.roles = const [],
  });
}

class SalesIdentity {
  final String employee;
  final Map<String, dynamic> employeeProfile;
  final String salesPerson;

  const SalesIdentity({
    required this.employee,
    required this.employeeProfile,
    required this.salesPerson,
  });
}
