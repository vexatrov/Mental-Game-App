/// A record persisted as a JSON document in one sembast store.
abstract interface class Doc {
  String get id;
  Map<String, Object?> toJson();
}

String readString(Object? v) => v is String ? v : '';

String? readNullableString(Object? v) => v is String && v.isNotEmpty ? v : null;

int readInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

DateTime readDate(Object? v) => v is num
    ? DateTime.fromMillisecondsSinceEpoch(v.toInt())
    : DateTime.fromMillisecondsSinceEpoch(0);

List<String> readStringList(Object? v) =>
    v is List ? v.whereType<String>().toList() : const [];
