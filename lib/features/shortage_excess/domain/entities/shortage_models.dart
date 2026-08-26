enum AtmHardwareType { ncr, crm, unknown }

class ShortageExcessResult {
  final List<Map<String, dynamic>> cbsOnly;
  final List<Map<String, dynamic>> switchOnly;
  final List<Map<String, dynamic>> matched;
  final List<String> cbsHeaders;
  final List<String> switchHeaders;

  const ShortageExcessResult({
    required this.cbsOnly,
    required this.switchOnly,
    required this.matched,
    this.cbsHeaders = const [],
    this.switchHeaders = const [],
  });
}
