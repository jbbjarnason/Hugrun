import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/bootstrap.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppDatabase opens on real platform and bootstrap inserts Hugrún',
      (tester) async {
    final db = AppDatabase();
    addTearDown(db.close);

    await ensureDefaultChildProfile(db);
    final row = await db.childProfilesDao.readLatest();

    expect(row, isNotNull);
    expect(row!.name, 'Hugrún');
  });
}
