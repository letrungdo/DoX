import 'package:auto_route/auto_route.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/news_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class NewsScreen extends StatefulScreen implements AutoRouteWrapper {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NewsViewModel(), //
      child: this,
    );
  }
}

class _NewsScreenState<V extends NewsViewModel> extends ScreenState<NewsScreen, V> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15), //
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(child: Text("COMING SOON!")), //
      ],
    );
  }
}
