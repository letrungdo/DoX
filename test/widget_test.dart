import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/vaccination.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists vaccination notification setting', () async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();

    expect(storageService.getChickenNotificationsEnabled(), isFalse);

    await storageService.setChickenNotificationsEnabled(true);
    expect(storageService.getChickenNotificationsEnabled(), isTrue);
  });

  test('shifts vaccination dates with incubation date changes', () {
    final batch = ChickenBatch(
      id: 'batch-1',
      name: 'Lứa 1',
      incubationDate: DateTime(2026, 7, 1),
      quantity: 10,
      vaccinations: [
        Vaccination(
          id: 'vaccination-1',
          title: 'Gumboro',
          scheduledDate: DateTime(2026, 7, 29),
        ),
      ],
    );

    final shifted = batch.shiftVaccinationSchedule(const Duration(days: 3));

    expect(shifted.vaccinations.single.scheduledDate, DateTime(2026, 8, 1));
  });
}
