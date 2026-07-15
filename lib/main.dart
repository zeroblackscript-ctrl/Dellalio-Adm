import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:auto_updater/auto_updater.dart';
import 'screens/login/login_screen.dart';
import 'screens/inicio/dashboard_screen.dart';
import 'core/user_session.dart';
import 'firebase_options.dart';

/// URL do AppCast (feed de atualizações) para o auto_updater.
/// Aponta para o arquivo appcast.xml hospedado no GitHub Releases.
/// O AppCast segue o protocolo Sparkle (WinSparkle no Windows).
/// Para desabilitar a verificação de updates, deixe como string vazia.
const String kUpdateFeedUrl = 'https://raw.githubusercontent.com/zeroblackscript-ctrl/Dellalio-Adm/master/appcast.xml';

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

  runApp(const DellalioCerebroApp());
}

class DellalioCerebroApp extends StatelessWidget {
  const DellalioCerebroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      
      title: 'Dellalio Cérebro',
      debugShowCheckedModeBanner: false,
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
