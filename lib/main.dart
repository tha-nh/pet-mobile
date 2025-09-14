import 'package:flutter/material.dart';
import 'package:pawfectcare_mobile/home/petintro.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawfectcare_mobile/login/login.dart';
import 'package:pawfectcare_mobile/login/register.dart';

import 'navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final int? userId = prefs.getInt("userId"); // check theo id

  runApp(PetCareApp(initialRoute: userId != null ? "/navigation" : "/login"));
  // runApp(PetCareApp(initialRoute: "/intro"));
}


class PetCareApp extends StatelessWidget {
  final String initialRoute;
  const PetCareApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Roboto',
      ),
      initialRoute: initialRoute,
      routes: {
        "/login": (context) => const LoginPage(),
        "/register": (context) => RegisterPage(),
        "/intro": (context) => const PetIntroPage(),
        "/navigation": (context) => const NavigationPage(), // Updated to use NavigationPage
      },
    );
  }
}