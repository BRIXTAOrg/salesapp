class AppUser {
  const AppUser({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.designation,
    required this.roles,
    this.department,
  });
  final String id, employeeCode, name, designation;
  final String? department;
  final List<String> roles;
}
