/// Safe conversion for JSON decoded with `jsonDecode` / Dio (`_Map<dynamic, dynamic>`).
Map<String, dynamic> asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected JSON object, got ${value.runtimeType}');
}

Map<String, dynamic>? asJsonMapOrNull(dynamic value) {
  if (value == null) return null;
  return asJsonMap(value);
}

List<Map<String, dynamic>> asJsonMapList(dynamic value) {
  if (value == null) return [];
  if (value is! List) {
    throw FormatException('Expected JSON array, got ${value.runtimeType}');
  }
  return value.map((e) => asJsonMap(e)).toList();
}
