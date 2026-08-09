import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _CountingViewModel extends CoreViewModel {
  int value = 0;

  void bump() {
    value++;
    notifyListenersSafe();
  }
}

/// Stands in for a `ScreenState`: it calls into the view model from
/// `initState`, which the framework runs in the middle of a build.
class _NotifyingInInitState extends StatefulWidget {
  const _NotifyingInInitState();

  @override
  State<_NotifyingInInitState> createState() => _NotifyingInInitStateState();
}

class _NotifyingInInitStateState extends State<_NotifyingInInitState> {
  @override
  void initState() {
    super.initState();
    context.read<_CountingViewModel>().bump();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('a notification raised during a build reaches the widgets', (
    tester,
  ) async {
    final vm = _CountingViewModel();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              // Reads first, so it is built before the notification is raised
              // and can only show the new value if that notification survives.
              Consumer<_CountingViewModel>(
                builder: (context, vm, child) => Text('${vm.value}'),
              ),
              const _NotifyingInInitState(),
            ],
          ),
        ),
      ),
    );

    // The second child notified from its initState, i.e. mid-build. Nothing may
    // be thrown, and the new value must show up on the next frame instead of
    // being lost with a notification the framework rejects.
    expect(tester.takeException(), isNull);
    expect(find.text('0'), findsOneWidget);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}
