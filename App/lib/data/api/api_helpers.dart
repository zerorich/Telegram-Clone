/// Parses API `data` field as a list; treats null as empty (Go nil slices → JSON null).
List<T> parseDataList<T>(
  dynamic data,
  T Function(dynamic json) fromJson,
) {
  if (data == null) return [];
  if (data is! List) {
    throw FormatException('Expected list, got ${data.runtimeType}');
  }
  return data.map(fromJson).toList();
}
