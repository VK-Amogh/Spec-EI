// GENERATED CODE - WEB STUB VERSION
// This is a web-compatible stub that replaces the ObjectBox generated code
// ObjectBox is not supported on web platform

export 'database/entities.dart';

// Stub classes for web compatibility
class Store {
  static bool isOpen(String name) => false;
  static Store attach(dynamic model, String name) => Store._();
  Store._();
  Box<T> box<T>() => Box<T>();
}

class Box<T> {
  int put(T object) => 0;
  T? get(int id) => null;
  List<T> getAll() => [];
  bool remove(int id) => false;
  int removeAll() => 0;
}

Future<Store> openStore({
  String? directory,
  int? maxDBSizeInKB,
  int? maxDataSizeInKB,
  int? fileMode,
  int? maxReaders,
  bool queriesCaseSensitiveDefault = true,
  String? macosApplicationGroup,
}) async {
  return Store._();
}

dynamic getObjectBoxModel() => null;
