
import 'package:flutter/material.dart';
import '../widgets/bottom_nav.dart';
import 'library_screen.dart';
import 'add_book_screen.dart';
import 'personal_screen.dart'; // Import the new screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Add PersonalScreen to the list of screens
  final List<Widget> _screens = [
    const LibraryScreen(),
    const AddBookScreen(),
    const PersonalScreen(), // Use the new screen
  ];

  void _onTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ), // Use IndexedStack to preserve state
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
