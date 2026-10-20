import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'user_session.dart';

/// Azul-noite Dellalio — cor primária do app (igual nos dois modos).
const Color petroleoColor = Color(0xFF0C1A30);
const Color petroleoDarkColor = Color(0xFF070F1F);
const Color petroleoLightColor = Color(0xFF122240);

/// Dourado de destaque (usar com moderação: ações e estados ativos) —
/// igual nos dois modos, é a cor de assinatura da marca.
const Color dellalioGold = Color(0xFFC9A227);

/// ============================================================
/// TOKENS DO REDESIGN — agora sensíveis ao modo claro/escuro.
/// Mesmos nomes de antes (drop-in), mas cada um é um getter que
/// escolhe o valor certo com base em `UserSession.isDarkMode()`.
/// Isso significa que deixam de ser `const` — em qualquer lugar
/// que use um destes tokens dentro de uma expressão `const`,
/// remova o `const` daquele ponto (o flutter analyze aponta todos).
/// ============================================================
bool get _dark => UserSession.isDarkMode();

Color get dellalioGoldSoft =>
    _dark ? const Color(0xFFE4C766) : const Color(0xFFA6841E);

Color get inkPageBg =>
    _dark ? const Color(0xFF0B0B0C) : const Color(0xFFF6F3EC);
Color get inkSurface =>
    _dark ? const Color(0xFF1B1A1D) : const Color(0xFFFFFFFF);
Color get inkSurfaceHover =>
    _dark ? const Color(0xFF242327) : const Color(0xFFEEF0F4);

Color get hairline =>
    _dark ? const Color(0x12FFFFFF) : petroleoColor.withValues(alpha: 0.12);
Color get hairlineNavy =>
    _dark ? const Color(0x484A638C) : petroleoColor.withValues(alpha: 0.28);

/// Azul-petróleo usado em texto/ícone/borda (nunca em fundo grande).
/// No modo escuro é um steel-blue mais claro pra legibilidade; no modo
/// claro é a própria cor principal da marca.
Color get navyAccent => _dark ? const Color(0xFF4A6B99) : petroleoColor;

Color get panelIvory =>
    _dark ? const Color(0xFFF3EFE6) : const Color(0xFF1C1F26);
Color get panelSlate =>
    _dark ? const Color(0xFF7C8698) : const Color(0xFF5C6470);
Color get panelSlateDim =>
    _dark ? const Color(0xFF545B68) : const Color(0xFF8A93A0);

/// Cor de títulos de página e de seção. No modo escuro é o quase-branco de
/// sempre; no modo claro passa a ser o azul-marinho da marca, pra trazer a
/// cor principal de volta ao conteúdo (em detalhes: título, rótulo, linha).
Color get dellalioTitle => _dark ? const Color(0xFFF3EFE6) : petroleoColor;

/// Rótulo de seção / subtítulo. Escuro: cinza-azulado. Claro: azul-marinho
/// suave, pra marcar os detalhes com a cor da marca sem pesar.
Color get dellalioLabel =>
    _dark ? const Color(0xFF7C8698) : const Color(0xFF3A4A6B);

const Color panelRust = Color(0xFFC0553B);
const Color panelSage = Color(0xFF5C8862);

/// Cores do pipeline de status do cliente (Clientes) — mantém as 6 etapas
/// já usadas no app, só trocando os tons crus do Material pelos da marca.
/// (Iguais nos dois modos: são "tags" e precisam ficar reconhecíveis.)
Color get statusPedido => navyAccent;
const Color statusConferencia = Color(0xFF8D79C4);
const Color statusProducao = dellalioGold;
const Color statusMontagem = Color(0xFFC9863A);
const Color statusEntrega = panelSage;
const Color statusFinalizado = Color(0xFF9B4F63);

/// Alias genérico do violeta acima, pra usar fora do contexto de pipeline
/// de cliente (ex: badge "todos" em Tarefas).
const Color panelViolet = statusConferencia;

/// ============================================================
/// ESTOQUE — status semânticos e superfícies do Cérebro.
/// verde = tem tudo, âmbar = parcial/comprar, vermelho = falta,
/// dourado = ação/destaque. No claro os tons escurecem pra manter
/// contraste em fundo papel (sem reaproveitar os do escuro).
/// ============================================================
Color get estoqueOk => _dark ? const Color(0xFF3FB37F) : const Color(0xFF22805A);
Color get estoqueAlerta =>
    _dark ? const Color(0xFFE3A33B) : const Color(0xFFA9690A);
Color get estoqueFalta =>
    _dark ? const Color(0xFFE5604F) : const Color(0xFFC2452F);
Color get estoqueNeutro =>
    _dark ? const Color(0xFF77736B) : const Color(0xFF7E8592);

/// Dourado de destaque: no claro escurece pra ler sobre papel.
Color get estoqueOuro => _dark ? dellalioGold : const Color(0xFFA9861A);

/// Filete/realce neutro dos KPIs: dourado no escuro, navy no claro.
Color get destaqueNeutro => _dark ? dellalioGold : petroleoColor;

/// Verde do botão "Enviar no WhatsApp" (igual nos dois modos).
const Color whatsappVerde = Color(0xFF1F8F5A);

/// Superfície um tom acima do cartão (mini-cards dentro de painéis,
/// trilho de barras, campos do stepper).
Color get inkSurface2 =>
    _dark ? const Color(0xFF242329) : const Color(0xFFF3F0EA);
Color get inkSurface3 =>
    _dark ? const Color(0xFF2E2D33) : const Color(0xFFE9E4DA);

/// Barra lateral do Cérebro: carvão no escuro, navy no claro.
Color get sidebarFundo => _dark ? const Color(0xFF141416) : petroleoColor;
Color get sidebarTexto => _dark ? panelSlate : const Color(0xFFB9C1CF);
Color get sidebarAtivo => _dark ? dellalioGold : const Color(0xFFE2C25A);
Color get sidebarLinha => _dark ? hairline : const Color(0xFF24344F);
Color get sidebarNome => _dark ? panelIvory : Colors.white;

/// Ação principal: dourado no escuro, navy no claro (com texto claro).
Color get acaoPrincipal => _dark ? dellalioGold : petroleoColor;
Color get acaoPrincipalTexto =>
    _dark ? const Color(0xFF1B1503) : Colors.white;

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
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0D0D0D);
  static const Color darkPrimary = Color(0xFF1A1A1A);
  static const Color accentGold = dellalioGold;
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textOnDark = Color(0xFFE0E0E0);

  static const Color lightBackground = Color(0xFFF0F2F5);
  static const Color lightSurface = Color(0xFFFFFFFF);

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
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            headlineMedium: GoogleFonts.fraunces(
              fontWeight: FontWeight.w500,
              fontSize: 26,
            ),
            headlineSmall: GoogleFonts.fraunces(
              fontWeight: FontWeight.w500,
              fontSize: 20,
            ),
          ),
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
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
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
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
          .copyWith(
            headlineMedium: GoogleFonts.fraunces(
              fontWeight: FontWeight.w500,
              fontSize: 26,
            ),
            headlineSmall: GoogleFonts.fraunces(
              fontWeight: FontWeight.w500,
              fontSize: 20,
            ),
          ),
      colorScheme: const ColorScheme.light(
        primary: petroleoColor,
        onPrimary: Colors.white,
        secondary: accentGold,
        onSecondary: Colors.black,
        surface: lightSurface,
        onSurface: Colors.black87,
        onSurfaceVariant: Colors.black54,
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
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
