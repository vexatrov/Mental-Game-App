import 'package:sembast/sembast_memory.dart';

int _dbCounter = 0;

/// A fresh, isolated in-memory database.
Future<Database> memoryDb() =>
    newDatabaseFactoryMemory().openDatabase('test_${_dbCounter++}.db');
