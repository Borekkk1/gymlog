import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final unitProvider = StateNotifierProvider<UnitNotifier, String>((ref) {
  return UnitNotifier();
});

class UnitNotifier extends StateNotifier<String> {
  UnitNotifier() : super('kg') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('unit') ?? 'kg';
  }

  Future<void> toggle() async {
    state = state == 'kg' ? 'lbs' : 'kg';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unit', state);
  }
}

double convertWeight(double kg, String unit) {
  if (unit == 'lbs') return kg * 2.20462;
  return kg;
}

String formatWeight(double kg, String unit) {
  final val = convertWeight(kg, unit);
  if (val == val.roundToDouble()) return '${val.toInt()} $unit';
  return '${val.toStringAsFixed(1)} $unit';
}
