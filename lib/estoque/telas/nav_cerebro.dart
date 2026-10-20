import 'package:flutter/material.dart';

enum SecaoCerebro {
  visaoGeral('Visão geral', Icons.home_outlined),
  materiais('Materiais', Icons.inventory_2_outlined),
  movimentacoes('Movimentações', Icons.swap_horiz),
  listas('Listas de corte', Icons.description_outlined),
  pedidos('Pedidos', Icons.shopping_cart_outlined),
  configuracoes('Configurações', Icons.settings_outlined);

  const SecaoCerebro(this.rotulo, this.icone);
  final String rotulo;
  final IconData icone;
}

/// Estado de navegação do Cérebro: seção da barra lateral + o que está
/// aberto dentro dela. As telas pedem pra ir a outro lugar por aqui
/// (ex.: "Ver todas", abrir a lista do aviso, filtrar por cliente).
class NavCerebro extends ChangeNotifier {
  SecaoCerebro secao = SecaoCerebro.visaoGeral;

  /// Lista de corte aberta na conferência (seção `listas`).
  String? listaId;

  /// Material com a ficha aberta (seção `materiais`).
  String? materialId;

  /// Busca pré-preenchida em Materiais.
  String? buscaMateriais;

  /// Filtros pré-aplicados no livro-razão.
  String? filtroCliente;
  String? filtroMaterialId;

  /// Pedido em destaque (seção `pedidos`).
  String? pedidoId;

  void ir(
    SecaoCerebro s, {
    String? listaId,
    String? materialId,
    String? buscaMateriais,
    String? filtroCliente,
    String? filtroMaterialId,
    String? pedidoId,
  }) {
    secao = s;
    this.listaId = listaId;
    this.materialId = materialId;
    this.buscaMateriais = buscaMateriais;
    this.filtroCliente = filtroCliente;
    this.filtroMaterialId = filtroMaterialId;
    this.pedidoId = pedidoId;
    notifyListeners();
  }

  void abrirLista(String id) => ir(SecaoCerebro.listas, listaId: id);

  void fecharLista() {
    listaId = null;
    notifyListeners();
  }

  void abrirMaterial(String? id) {
    secao = SecaoCerebro.materiais;
    materialId = id;
    notifyListeners();
  }

  static NavCerebro of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NavCerebroScope>()!
      .notifier!;

  /// Sem registrar dependência (pra usar em callbacks).
  static NavCerebro ler(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NavCerebroScope>()!.notifier!;
}

class NavCerebroScope extends InheritedNotifier<NavCerebro> {
  const NavCerebroScope({
    super.key,
    required NavCerebro nav,
    required super.child,
  }) : super(notifier: nav);
}
