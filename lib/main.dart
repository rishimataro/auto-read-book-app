import 'package:demo/presentation/screens/connection_screen.dart';
import 'package:demo/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Book',
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(),
    ),
      home: const SplashScreen(),
    );
  }
}
