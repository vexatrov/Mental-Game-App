import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  return databaseFactoryIo.openDatabase(p.join(dir.path, 'mental_game.db'));
}
