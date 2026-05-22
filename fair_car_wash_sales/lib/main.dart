import 'package:flutter/material.dart';
import 'screens/login_page.dart';

void main() {
  runApp(const FairCarWashApp());
}

class FairCarWashApp extends StatelessWidget {
  const FairCarWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fair Car Wash Sales',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}
