import 'package:do_x/view_model/movie/movie_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Closing the search box clears the query, and a query that was never set
/// has nothing to go back to — so it must not refetch the list on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearing a query that was never set fetches nothing', () async {
    final vm = MovieViewModel();
    addTearDown(vm.dispose);

    await vm.setSearchQuery('');
    await vm.setSearchQuery('   ');

    expect(vm.searchQuery, isEmpty);
    expect(vm.isFetching, isFalse);
  });
}
