
import 'package:demo/data/repositories/pi_repository.dart';
import 'package:demo/logic/connection/connection_cubit.dart';
import 'package:demo/logic/home/home_cubit.dart';
import 'package:demo/presentation/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/bottom_nav.dart';
import 'library_screen.dart';
import 'add_book_screen.dart';
import 'personal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _libraryRefreshKey = 0; // Key để force rebuild LibraryScreen

  List<Widget> get _screens => [
    BlocProvider(
      create: (context) => HomeCubit(),
      child: HomePage(
        onNavigateToLibrary: _navigateToLibrary,
      ),
    ),
    LibraryScreen(key: ValueKey(_libraryRefreshKey)),
    AddBookScreen(
      onSaveSuccess: _navigateToLibrary,
    ),
    const PersonalScreen(),
  ];

  void _onTap(int index) {
    setState(() {
      _currentIndex = index;
      // Force rebuild LibraryScreen khi chuyển sang tab Library
      if (index == 1) {
        _libraryRefreshKey++;
      }
    });
  }

  void _navigateToLibrary() {
    setState(() {
      _currentIndex = 1; // Library tab index
      _libraryRefreshKey++; // Force rebuild để refresh dữ liệu
    });
  }

  @override
  Widget build(BuildContext context) {
    // Try to get existing ConnectionCubit from parent
    ConnectionCubit? existingCubit;
    try {
      existingCubit = BlocProvider.of<ConnectionCubit>(context, listen: false);
    } catch (e) {
      // ConnectionCubit not found in parent, will create new one
      existingCubit = null;
    }
    
    // If existing cubit found, use it; otherwise create new one
    if (existingCubit != null) {
      return BlocProvider<ConnectionCubit>.value(
        value: existingCubit,
        child: _buildScaffold(),
      );
    } else {
      return BlocProvider<ConnectionCubit>(
        create: (context) => ConnectionCubit(PiRepository()),
        child: _buildScaffold(),
      );
    }
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
