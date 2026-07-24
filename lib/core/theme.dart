import 'package:flutter/material.dart';

/// Azul petróleo — cor primária do app Dellalio.
const Color petroleoColor = Color.fromARGB(255, 0, 23, 88);
const Color petroleoDarkColor = Color.fromARGB(255, 0, 10, 39);
const Color petroleoLightColor = Color.fromARGB(255, 0, 23, 88);

/// Singleton que notifica os ouvintes quando o tema é alternado.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static final ThemeNotifier _instance = ThemeNotifier._();
  static ThemeNotifier get instance => _instance;

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
  }
}

class DellalioTheme {
  // Core color palette
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0D0D0D);
  static const Color darkPrimary = Color(0xFF1A1A1A);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textOnDark = Color(0xFFE0E0E0);

  // Light palette
  static const Color lightBackground = Color(0xFFF0F2F5);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // Mantido por compatibilidade com telas que ainda referenciam
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
  );

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBackground,
      primaryColor: petroleoColor,
      colorScheme: const ColorScheme.dark(
        primary: petroleoColor,
        secondary: accentGold,
        surface: darkSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: petroleoColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: titleStyle,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: accentGold,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        labelStyle: const TextStyle(
          color: accentGold,
          letterSpacing: 1,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: accentGold, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: petroleoColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: petroleoColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: lightBackground,
      primaryColor: petroleoColor,
      colorScheme: const ColorScheme.light(
        primary: petroleoColor,
        secondary: accentGold,
        surface: lightSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: petroleoColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: titleStyle,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: accentGold,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(
          color: petroleoColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFBDBDBD), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: petroleoColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: petroleoColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: petroleoColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  /// Cores disponíveis para projetos (seletor de cor).
  static const List<Map<String, dynamic>> projectColors = [
    {'label': 'AZUL PETRÓLEO', 'color': petroleoColor, 'hex': '#00695C'},
    {'label': 'DOURADO', 'color': accentGold, 'hex': '#D4AF37'},
    {'label': 'VERMELHO', 'color': Color(0xFFE53935), 'hex': '#E53935'},
    {'label': 'VERDE', 'color': Color(0xFF43A047), 'hex': '#43A047'},
    {'label': 'AZUL', 'color': Color(0xFF1E88E5), 'hex': '#1E88E5'},
    {'label': 'ROXO', 'color': Color(0xFF8E24AA), 'hex': '#8E24AA'},
    {'label': 'LARANJA', 'color': Color(0xFFFB8C00), 'hex': '#FB8C00'},
    {'label': 'ROSA', 'color': Color(0xFFD81B60), 'hex': '#D81B60'},
    {'label': 'CINZA', 'color': Color(0xFF757575), 'hex': '#757575'},
    {'label': 'MARROM', 'color': Color(0xFF6D4C41), 'hex': '#6D4C41'},
  ];

  /// Retorna a cor a partir do hex, ou a cor padrão (petróleo).
  static Color colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return petroleoColor;
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('0xFF$h'));
    } catch (_) {
      return petroleoColor;
    }
  }
}