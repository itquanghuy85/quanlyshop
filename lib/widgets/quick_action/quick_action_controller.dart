import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuickActionController extends ChangeNotifier {
  static const _kSide = 'qab_side'; // 0 = left, 1 = right
  static const _kYFrac = 'qab_y';

  double side = 1.0;
  double yFraction = 0.45;
  bool isExpanded = false;
  bool isLoaded = false;
  bool enableRepair = false;
  String role = '';

  QuickActionController({this.enableRepair = false, this.role = ''}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    side = (prefs.getInt(_kSide) ?? 1).toDouble();
    yFraction = prefs.getDouble(_kYFrac) ?? 0.45;
    isLoaded = true;
    notifyListeners();
  }

  void updateConfig({required bool enableRepair, required String role}) {
    if (this.enableRepair != enableRepair || this.role != role) {
      this.enableRepair = enableRepair;
      this.role = role;
      notifyListeners();
    }
  }

  void toggle() {
    isExpanded = !isExpanded;
    notifyListeners();
  }

  void close() {
    if (isExpanded) {
      isExpanded = false;
      notifyListeners();
    }
  }

  void updatePosition(double newSide, double newYFraction) {
    side = newSide;
    yFraction = newYFraction.clamp(0.05, 0.93);
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSide, side.round());
    await prefs.setDouble(_kYFrac, yFraction);
  }
}
