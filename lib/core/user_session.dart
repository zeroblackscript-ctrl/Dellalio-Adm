import 'package:shared_preferences/shared_preferences.dart';

/// Controla o estado de sessão do usuário logado, incluindo se ele
/// possui privilégios de Administrador único.
///
/// O status de Admin é persistido localmente via SharedPreferences,
/// então permanece válido mesmo se o app for fechado e reaberto
/// (enquanto a sessão do Firebase Auth continuar ativa).
class UserSession {
  static String currentKey = "";

  // Chave exclusiva que libera os poderes de administrador único.
  // Aceita a chave em qualquer combinação de maiúsculas/minúsculas.
  static const String adminKey = "admin31102024";

  static const String _prefsAdminFlag = "dellalio_is_admin";

  static bool _isAdmin = false;

  static bool isAdmin() => _isAdmin;

  /// Valida a chave digitada no login. Se correta, marca a sessão
  /// como Admin e persiste esse estado localmente.
  /// A comparação é case-insensitive (aceita maiúsculas ou minúsculas).
  static Future<void> validateAndSetAdmin(String enteredKey) async {
    final bool matches = enteredKey.trim().toLowerCase() == adminKey.toLowerCase();

    _isAdmin = matches;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsAdminFlag, matches);
  }

  /// Carrega o status de Admin salvo localmente (chamado ao iniciar o app,
  /// quando já existe uma sessão do Firebase Auth ativa).
  static Future<void> loadPersistedAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isAdmin = prefs.getBool(_prefsAdminFlag) ?? false;
  }

  /// Limpa o estado de admin (usado no logout).
  static Future<void> clear() async {
    _isAdmin = false;
    currentKey = "";
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsAdminFlag);
  }
}
