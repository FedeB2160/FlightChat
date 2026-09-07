// lib/main.dart — App entry point with Provider setup
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: const [],
      child: const FlightChatApp(),
    ),
  );
}
