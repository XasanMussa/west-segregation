import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:west_segregation/authentication_screen.dart';
import 'package:west_segregation/notification_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();
  await _requestNotificationPermission();
  runApp(const MaterialSegregationApp());
}

Future<void> _requestNotificationPermission() async {
  if (Platform.isAndroid) {
    // Only needed for Android 13+ (API 33+)
    const int androidTiramisu = 33;
    try {
      final int sdkInt = await _getAndroidSdkInt();
      if (sdkInt >= androidTiramisu) {
        final MethodChannel channel =
            MethodChannel('dexterous.com/flutter/local_notifications');
        await channel.invokeMethod('requestPermission');
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }
}

Future<int> _getAndroidSdkInt() async {
  const MethodChannel channel =
      MethodChannel('com.example.west_segregation/device_info');
  try {
    final int sdkInt = await channel.invokeMethod<int>('getAndroidSdkInt') ?? 0;
    return sdkInt;
  } catch (e) {
    debugPrint('Error getting Android SDK version: $e');
    return 0;
  }
}
