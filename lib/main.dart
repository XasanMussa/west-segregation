import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:west_segregation/authentication_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaterialSegregationApp());
}
