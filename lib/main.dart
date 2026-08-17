import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:auto_updater/auto_updater.dart';
import 'screens/login/login_screen.dart';
import 'screens/inicio/dashboard_screen.dart';
import 'core/user_session.dart';
import 'core/theme.dart';
import 'firebase_options.dart';

/// URL do AppCast (feed de atualizações) para o auto_updater.
/// Aponta para o Firebase Hosting (mais confiável que raw.githubusercontent.com).
/// O AppCast segue o protocolo Sparkle (WinSparkle no Windows).
/// Para desabilitar a verificação de updates, deixe como string vazia.
const String kUpdateFeedUrl = 'https://dellalio-moveis-planejados.web.app/appcast.xml';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Use esta forma para evitar o erro de PathNotFound
  await initializeDateFormatting('pt_BR');

  // --- Configuração do Auto Updater ---
  if (kUpdateFeedUrl.isNotEmpty) {
    await autoUpdater.setFeedURL(kUpdateFeedUrl);
    // Verifica atualizações ao iniciar (em background para não travar o app)
    await autoUpdater.checkForUpdates(inBackground: true);
    // Verifica a cada 6 horas (21600 segundos). Mínimo: 3600. 0 = desabilitado.
    await autoUpdater.setScheduledCheckInterval(21600);
  }
  // ------------------------------------

  // Carrega a preferência de tema antes de iniciar o app
  await UserSession.loadDarkModePreference();
  final initialMode = UserSession.isDarkMode() ? ThemeMode.dark : ThemeMode.light;
  ThemeNotifier.instance.setMode(initialMode);

  runApp(const DellalioCerebroApp());
}

class DellalioCerebroApp extends StatefulWidget {
  const DellalioCerebroApp({super.key});

  @override
  State<DellalioCerebroApp> createState() => _DellalioCerebroAppState();
}

class _DellalioCerebroAppState extends State<DellalioCerebroApp> {
  @override
  void initState() {
    super.initState();
    ThemeNotifier.instance.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ThemeNotifier.instance.mode;
    return MaterialApp(
      title: 'Dellalio Cérebro',
      debugShowCheckedModeBanner: false,
      theme: DellalioTheme.lightTheme,
      darkTheme: DellalioTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// Verifica se já existe uma sessão do Firebase Auth ativa ao abrir o app.
/// Se sim, restaura o status de Admin salvo localmente e vai direto para o
/// Dashboard, evitando pedir login novamente a cada abertura do app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _resolveInitialScreen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await UserSession.loadPersistedAdminStatus();
      return const DashboardScreen();
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveInitialScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            ),
          );
        }
        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}
