import 'package:flutter/material.dart';

/// Cópia fiel de `theme/app_colors.dart` do app Dellalio Clientes — usada
/// só pelo preview "celular" do painel App Clientes, pra renderizar as
/// seções exatamente com as cores do app real (que são diferentes do tema
/// do próprio painel admin). Ver [[painel-app-clientes]].
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF0D2B3E);
  static const Color gold = Color(0xFFC7AD85);
  static const Color lightBg = Color(0xFFF7F3EC);
  static const Color ringTrack = Color(0xFF24455E);
  static const Color successGreen = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFF9A825);
  static const Color grayBlue = Color(0xFF5E7485);
  static const Color lightGray = Color(0xFFB7C4CE);
}
