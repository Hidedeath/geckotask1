import 'package:flutter/material.dart';
import 'dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriWatch Energy Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), 
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent, 
          secondary: Colors.yellowAccent, 
          surface: Color(0xFF1E293B), 
        ),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}