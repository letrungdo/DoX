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

  // Stored dates are lunar values but the shift is a real, physical number of
  // days, so it has to be applied in the solar calendar and converted back —
  // adding the duration to the lunar DateTime would drift by however much the
  // lunar and solar months differ in length.
  test('shifts vaccination dates by real days, not lunar ones', () {
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

    // Lunar month 7 of 2026 ends on the 29th, so three real days later is the
    // 3rd of lunar month 8. (Adding 3 days to the raw DateTime would say
    // 2026-08-01, because the *solar* July has 31 days — the drift this
    // conversion exists to avoid.)
    expect(shifted.vaccinations.single.scheduledDate, DateTime(2026, 8, 3));
  });

  test('shifting by zero leaves the schedule untouched', () {
    final scheduled = DateTime(2026, 7, 29);
    final batch = ChickenBatch(
      id: 'batch-1',
      name: 'Lứa 1',
      incubationDate: DateTime(2026, 7, 1),
      quantity: 10,
      vaccinations: [
        Vaccination(
          id: 'vaccination-1',
          title: 'Gumboro',
          scheduledDate: scheduled,
        ),
      ],
    );

    expect(
      batch
          .shiftVaccinationSchedule(Duration.zero)
          .vaccinations
          .single
          .scheduledDate,
      scheduled,
    );
  });
}
