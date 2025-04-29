import 'package:do_x/screen/core/app_scaffold.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/home_screen.dart';
import 'package:do_x/screen/menu_screen.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulScreen implements ProviderWrapper {
  const MainScreen({super.key});

  static const path = "/main";

  @override
  State<MainScreen> createState() => _MainScreenState();

  @override
  Widget providerWrapper() {
    return ChangeNotifierProvider(
      create: (_) => MainViewModel(), //
      child: this,
    );
  }
}

class _MainScreenState extends ScreenState<MainScreen, MainViewModel> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  static final _widgetOptions = <Widget>[
    const HomeScreen().providerWrapper(), //
    const MenuScreen().providerWrapper(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
      child: _widgetOptions.elementAt(_selectedIndex),
    );
  }
}
