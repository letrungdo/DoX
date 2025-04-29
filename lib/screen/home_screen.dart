import 'dart:io';

import 'package:do_x/screen/core/app_scaffold.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/home_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulScreen implements ProviderWrapper {
  const HomeScreen({super.key});

  static const path = "/home";

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  @override
  Widget providerWrapper() {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(), //
      child: this,
    );
  }
}

class _HomeScreenState<V extends HomeViewModel> extends ScreenState<HomeScreen, V> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: DoAppBar(title: "Home"), //
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final media = context.select((V vm) => vm.media);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            color: Colors.grey,
            height: 200, //
            child:
                media == null
                    ? SizedBox.expand()
                    : kIsWeb
                    ? Image.network(media.path)
                    : Image.file(File(media.path)),
          ),
        ),
        ElevatedButton(
          onPressed: () => vm.pickMedia(), //
          child: Text('Select Media'),
        ),

        SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => vm.upload(), //
          child: Text('Upload'),
        ),
      ],
    );
  }
}
