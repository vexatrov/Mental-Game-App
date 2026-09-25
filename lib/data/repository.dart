import 'package:sembast/sembast.dart';

import 'models/doc.dart';

/// The sembast stores that make up the app's data. Order matters only for
/// the layout of export files.
abstract final class Stores {
  static const journal = 'journal';
  static const mhh = 'mental_hand_histories';
  static const maps = 'emotion_maps';
  static const analyses = 'game_analyses';
  static const sessions = 'sessions';
  static const settings = 'settings';
  static const routines = 'routines';

  static const all = [
    journal,
    mhh,
    maps,
    analyses,
    sessions,
    routines,
    settings,
  ];

  static StoreRef<String, Map<String, Object?>> ref(String name) =>
      stringMapStoreFactory.store(name);
}

/// Typed CRUD over one store of JSON documents.
class DocRepository<T extends Doc> {
  DocRepository(
    this.db,
    String storeName,
    this.fromJson, {
    required this.sortField,
    this.descending = true,
  }) : store = Stores.ref(storeName);

  final Database db;
  final StoreRef<String, Map<String, Object?>> store;
  final T Function(Map<String, Object?> json) fromJson;
  final String sortField;
  final bool descending;

  Finder get _sorted =>
      Finder(sortOrders: [SortOrder(sortField, !descending)]);

  T _decode(RecordSnapshot<String, Map<String, Object?>> s) => fromJson(s.value);

  Stream<List<T>> watchAll() =>
      store.query(finder: _sorted).onSnapshots(db).map((l) => l.map(_decode).toList());

  Future<List<T>> getAll() async =>
      (await store.find(db, finder: _sorted)).map(_decode).toList();

  Stream<T?> watch(String id) => store
      .record(id)
      .onSnapshot(db)
      .map((s) => s == null ? null : _decode(s));

  Future<T?> get(String id) async {
    final value = await store.record(id).get(db);
    return value == null ? null : fromJson(value);
  }

  Future<void> save(T doc) => store.record(doc.id).put(db, doc.toJson());

  Future<void> delete(String id) => store.record(id).delete(db);
}
