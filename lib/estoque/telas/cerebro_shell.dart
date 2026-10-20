import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../../core/user_session.dart';
import '../../screens/login/login_screen.dart';
import '../../screens/login/meu_usuario_screen.dart';
import '../importacao/automacao.dart';
import '../models/models.dart';
import '../services/consultas.dart';
import '../services/migracao.dart';
import '../services/responsavel.dart';
import '../ui/kit_estoque.dart';
import 'nav_cerebro.dart';

/// Casca do Cérebro: barra lateral com as 5 seções + configurações e o
/// usuário no rodapé.
class CerebroShell extends StatefulWidget {
  const CerebroShell({super.key});

  @override
  State<CerebroShell> createState() => _CerebroShellState();
}

class _CerebroShellState extends State<CerebroShell> {
  final NavCerebro _nav = NavCerebro();
  bool _arrastando = false;

  @override
  void initState() {
    super.initState();
    // Converte o estoque antigo uma única vez (flag em config/migracoes),
    // depois começa a vigiar as pastas.
    migrarEstoqueAntigo()
        .catchError((_) => 0)
        .whenComplete(Automacao.instancia.iniciar);
  }

  Future<void> _soltou(DropDoneDetails d) async {
    setState(() => _arrastando = false);
    for (final f in d.files) {
      final arquivo = File(f.path);
      if (!Automacao.instancia.vigiaListas.aceita(arquivo.path) &&
          !f.path.toLowerCase().endsWith('.xml')) {
        if (mounted) avisar(context, '${f.name}: formato não aceito.', erro: true);
        continue;
      }
      if (mounted) avisar(context, 'Lendo ${f.name}…');
      final id = await Automacao.instancia.importarArquivo(arquivo);
      if (!mounted) return;
      avisar(context, id == null ? '${f.name} já tinha sido importado.' : '${f.name} importado.');
    }
  }

  @override
  void dispose() {
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavCerebroScope(
      nav: _nav,
      child: Scaffold(
        backgroundColor: inkPageBg,
        body: DropTarget(
          onDragEntered: (_) => setState(() => _arrastando = true),
          onDragExited: (_) => setState(() => _arrastando = false),
          onDragDone: _soltou,
          child: Stack(
            children: [
              Row(
                children: [
                  const _BarraLateral(),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _nav,
                      builder: (context, _) => KeyedSubtree(
                        key: ValueKey(_nav.secao),
                        child: _pagina(_nav.secao),
                      ),
                    ),
                  ),
                ],
              ),
              if (_arrastando) const _SoltarAqui(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagina(SecaoCerebro s) => _PaginaProvisoria(secao: s);
}

/// Véu que aparece ao arrastar um arquivo sobre a janela.
class _SoltarAqui extends StatelessWidget {
  const _SoltarAqui();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: inkPageBg.withValues(alpha: 0.86),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
            decoration: BoxDecoration(
              color: inkSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: estoqueOuro, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download_outlined, size: 40, color: estoqueOuro),
                const SizedBox(height: 12),
                Text('Solte para importar', style: fraunces(26)),
                const SizedBox(height: 6),
                Text(
                  'Lista do DinaBox (PDF, CSV, XLSX) ou nota fiscal (XML, PDF)',
                  style: TextStyle(color: panelSlate),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginaProvisoria extends StatelessWidget {
  final SecaoCerebro secao;
  const _PaginaProvisoria({required this.secao});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 26, 34, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(secao.rotulo, style: fraunces(34)),
          const SizedBox(height: 8),
          Text('Em construção.', style: TextStyle(color: panelSlate)),
        ],
      ),
    );
  }
}

class _BarraLateral extends StatelessWidget {
  const _BarraLateral();

  @override
  Widget build(BuildContext context) {
    final nav = NavCerebro.of(context);
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: sidebarFundo,
        border: Border(right: BorderSide(color: sidebarLinha)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Dellalio', style: fraunces(30, cor: sidebarAtivo)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 26),
            child: Text(
              'ESTOQUE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: sidebarTexto.withValues(alpha: 0.7),
              ),
            ),
          ),
          for (final (i, s) in SecaoCerebro.values.indexed)
            if (s != SecaoCerebro.configuracoes)
              _ItemNav(
                secao: s,
                ativo: nav.secao == s,
                indice: i,
                badge: s == SecaoCerebro.listas ? const _BadgeConfirmar() : null,
              ),
          const Spacer(),
          _ItemNav(
            secao: SecaoCerebro.configuracoes,
            ativo: nav.secao == SecaoCerebro.configuracoes,
            indice: 6,
          ),
          const SizedBox(height: 10),
          Divider(color: sidebarLinha, height: 1),
          const _Usuario(),
        ],
      ),
    );
  }
}

class _ItemNav extends StatefulWidget {
  final SecaoCerebro secao;
  final bool ativo;
  final int indice;
  final Widget? badge;
  const _ItemNav({
    required this.secao,
    required this.ativo,
    required this.indice,
    this.badge,
  });

  @override
  State<_ItemNav> createState() => _ItemNavState();
}

class _ItemNavState extends State<_ItemNav> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = widget.ativo || _hover ? sidebarAtivo : sidebarTexto;
    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => NavCerebro.ler(context).ir(widget.secao),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: widget.ativo
                ? sidebarAtivo.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.ativo
                  ? sidebarAtivo.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.secao.icone, size: 18, color: cor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.secao.rotulo,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: cor,
                  ),
                ),
              ),
              ?widget.badge,
            ],
          ),
        ),
      ),
    );
    if (semAnimacao(context)) return item;
    return item
        .animate(delay: (50 * widget.indice).ms)
        .fadeIn(duration: 320.ms)
        .slideX(begin: -0.06, end: 0, curve: Curves.easeOut);
  }
}

/// Número de itens a confirmar nas listas ativas.
class _BadgeConfirmar extends StatelessWidget {
  const _BadgeConfirmar();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ListaCorte>>(
      stream: Consultas.instancia.listasAtivas(),
      builder: (context, snap) {
        final n = (snap.data ?? const <ListaCorte>[]).fold<int>(
          0,
          (s, l) => s + l.resumo.confirmar,
        );
        if (n == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: dellalioGold,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              color: Color(0xFF1B1503),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

class _Usuario extends StatelessWidget {
  const _Usuario();

  Future<void> _sair(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await UserSession.clear();
    Responsavel.limparCache();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Responsavel>(
      future: Responsavel.atual(),
      builder: (context, snap) {
        final nome = snap.data?.nome ?? '';
        final iniciais = nome
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join();
        return PopupMenuButton<String>(
          tooltip: 'Conta',
          color: inkSurface,
          position: PopupMenuPosition.over,
          offset: const Offset(0, -110),
          onSelected: (v) {
            if (v == 'perfil') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            } else if (v == 'sair') {
              _sair(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'perfil',
              child: Text('Meu perfil', style: TextStyle(color: panelIvory)),
            ),
            PopupMenuItem(
              value: 'sair',
              child: Text('Sair', style: TextStyle(color: estoqueFalta)),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _dark ? inkSurface3 : const Color(0xFF1D2C45),
                  child: Text(
                    iniciais,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sidebarAtivo,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sidebarNome,
                        ),
                      ),
                      Text(
                        UserSession.isAdmin() ? 'Administrador' : 'Equipe',
                        style: TextStyle(fontSize: 12, color: sidebarTexto),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _dark => UserSession.isDarkMode();
}
