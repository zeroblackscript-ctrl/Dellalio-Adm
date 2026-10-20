import 'package:auto_updater/auto_updater.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/user_session.dart';
import '../importacao/automacao.dart';
import '../importacao/conversor_unidades.dart';
import '../importacao/vigia_pasta.dart';
import '../models/models.dart';
import '../services/cadastro_service.dart';
import '../services/consultas.dart';
import '../ui/kit_estoque.dart';
import '../util/quantidade.dart';
import 'dialogos.dart';

/// Versão do app (igual ao pubspec).
const String kAppVersion = '2.0.0';

class ConfiguracoesTela extends StatelessWidget {
  const ConfiguracoesTela({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(34, 26, 34, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Cascata(
            indice: 0,
            child: CabecalhoPagina(titulo: 'Configurações', subtitulo: 'Pastas, fornecedores e padrões desta máquina'),
          ),
          const SizedBox(height: 22),
          Cascata(
            indice: 1,
            child: PainelEstoque(
              titulo: 'Pastas vigiadas',
              child: Column(
                children: [
                  _Pasta(rotulo: 'Listas do DinaBox', vigia: Automacao.instancia.vigiaListas),
                  Divider(color: hairlineNavy, height: 24),
                  _Pasta(rotulo: 'Notas fiscais (XML/PDF)', vigia: Automacao.instancia.fonteNotas.vigia),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Cascata(indice: 2, child: _Fornecedores()),
          const SizedBox(height: 18),
          const Cascata(indice: 3, child: _ChapaPadrao()),
          const SizedBox(height: 18),
          Cascata(
            indice: 4,
            child: PainelEstoque(
              titulo: 'Aparência e atualizações',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dellalio Estoque $kAppVersion · tema ${UserSession.isDarkMode() ? 'escuro' : 'claro'}',
                      style: TextStyle(color: panelSlate),
                    ),
                  ),
                  BotaoEstoque(
                    rotulo: UserSession.isDarkMode() ? 'Usar modo claro' : 'Usar modo escuro',
                    icone: UserSession.isDarkMode() ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    onPressed: () async {
                      await UserSession.toggleDarkMode();
                      ThemeNotifier.instance.toggle();
                    },
                  ),
                  const SizedBox(width: 10),
                  BotaoEstoque(
                    rotulo: 'Verificar atualizações',
                    icone: Icons.refresh,
                    variante: VarianteBotao.fantasma,
                    onPressed: () async {
                      try {
                        await autoUpdater.checkForUpdates();
                        if (context.mounted) avisar(context, 'Verificando atualizações…');
                      } catch (e) {
                        if (context.mounted) avisar(context, 'Erro ao verificar: $e', erro: true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pasta extends StatelessWidget {
  final String rotulo;
  final VigiaPasta vigia;
  const _Pasta({required this.rotulo, required this.vigia});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoVigia>(
      valueListenable: vigia.estado,
      builder: (context, v, _) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rotulo, style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(v.caminho ?? '—', style: TextStyle(color: panelSlate, fontSize: 13)),
                if (v.erro != null) Text(v.erro!, style: TextStyle(color: estoqueFalta, fontSize: 12.5)),
              ],
            ),
          ),
          PilulaStatus(
            rotulo: v.ativo ? 'vigiando' : (v.erro != null ? 'com erro' : 'inativo'),
            cor: v.ativo ? estoqueOk : estoqueFalta,
          ),
          const SizedBox(width: 12),
          BotaoEstoque(
            rotulo: 'Abrir',
            variante: VarianteBotao.fantasma,
            pequeno: true,
            onPressed: v.caminho == null ? null : () => launchUrl(Uri.file(v.caminho!)),
          ),
          const SizedBox(width: 8),
          BotaoEstoque(
            rotulo: 'Trocar pasta',
            icone: Icons.folder_open_outlined,
            pequeno: true,
            onPressed: () async {
              final p = await FilePicker.getDirectoryPath(dialogTitle: rotulo, initialDirectory: v.caminho);
              if (p != null) await vigia.trocarPasta(p);
            },
          ),
        ],
      ),
    );
  }
}

class _Fornecedores extends StatelessWidget {
  const _Fornecedores();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Fornecedor>>(
      stream: Consultas.instancia.fornecedores(),
      builder: (context, snap) {
        final fs = snap.data ?? const <Fornecedor>[];
        return PainelEstoque(
          titulo: 'Fornecedores',
          link: '+ Novo fornecedor',
          onLink: () => editarFornecedor(context),
          child: fs.isEmpty
              ? Text(
                  'Nenhum fornecedor ainda. Eles também são criados sozinhos pela primeira nota fiscal de cada um.',
                  style: TextStyle(color: panelSlate),
                )
              : Column(
                  children: [
                    for (final (i, f) in fs.indexed)
                      InkWell(
                        onTap: () => editarFornecedor(context, f: f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: i == 0 ? Colors.transparent : hairlineNavy)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(f.nome, style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text(f.cnpj ?? 'sem CNPJ', style: TextStyle(color: panelSlate, fontSize: 13))),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  f.whatsappFormatado ?? 'sem WhatsApp',
                                  style: TextStyle(color: f.whatsapp == null ? estoqueAlerta : panelSlate, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${f.codigosProduto.length} códigos aprendidos',
                                  style: TextStyle(color: panelSlateDim, fontSize: 12.5),
                                ),
                              ),
                              Icon(Icons.edit_outlined, size: 16, color: panelSlateDim),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _ChapaPadrao extends StatefulWidget {
  const _ChapaPadrao();
  @override
  State<_ChapaPadrao> createState() => _ChapaPadraoState();
}

class _ChapaPadraoState extends State<_ChapaPadrao> {
  late final _larg = TextEditingController(text: fmtNumero(ChapaPadrao.larguraMm).replaceAll('.', ''));
  late final _alt = TextEditingController(text: fmtNumero(ChapaPadrao.alturaMm).replaceAll('.', ''));

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String r) => InputDecoration(
      labelText: r,
      suffixText: 'mm',
      isDense: true,
      filled: true,
      fillColor: inkSurface2,
      labelStyle: TextStyle(color: panelSlate),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: hairlineNavy)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: estoqueOuro)),
    );
    return PainelEstoque(
      titulo: 'Chapa padrão',
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Usada pra converter m² em chapas quando nem o material nem a lista trazem a medida. '
              'Itens convertidos com ela ficam marcados pra conferir.',
              style: TextStyle(color: panelSlate, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 130, child: TextField(controller: _larg, style: TextStyle(color: panelIvory), decoration: dec('Largura'))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('×', style: TextStyle(color: panelSlate))),
          SizedBox(width: 130, child: TextField(controller: _alt, style: TextStyle(color: panelIvory), decoration: dec('Altura'))),
          const SizedBox(width: 12),
          BotaoEstoque(
            rotulo: 'Salvar',
            onPressed: () async {
              final l = double.tryParse(_larg.text.replaceAll(',', '.'));
              final a = double.tryParse(_alt.text.replaceAll(',', '.'));
              if (l == null || a == null || l <= 0 || a <= 0) return;
              await CadastroService.instancia.salvarChapaPadrao(l, a);
              if (context.mounted) avisar(context, 'Chapa padrão: ${l.toInt()} × ${a.toInt()} mm.');
            },
          ),
        ],
      ),
    );
  }
}
