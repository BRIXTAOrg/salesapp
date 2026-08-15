class AppUser {
  const AppUser({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.designation,
    required this.roles,
  });

  final String id;
  final String employeeCode;
  final String name;
  final String designation;
  final List<String> roles;
}
