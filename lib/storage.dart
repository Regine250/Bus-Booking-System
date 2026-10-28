import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bus.dart';

// Saving on the phone (Part 2). One key, 'buses', holds every bus as text,
// and each bus carries its own bookings and waitlist inside it.

Future<void> saveBuses(List<Bus> buses) async {
  final prefs = await SharedPreferences.getInstance();
  final list = buses.map((bus) => bus.toJson()).toList(); // List<Bus> -> List<Map>
  await prefs.setString('buses', jsonEncode(list)); // -> text
}

// Returns the saved buses, or null the very first time.
Future<List<Bus>?> loadBuses() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('buses');
  if (saved == null) return null;
  final list = jsonDecode(saved) as List; // text -> List<Map>
  return list.map((x) => Bus.fromJson(x as Map<String, dynamic>)).toList();
}