import 'package:DELLALIO/estoque/importacao/conversor_unidades.dart';
import 'package:DELLALIO/estoque/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialEstoque _m(
  UnidadeEstoque u, {
  double? larg,
  double? alt,
  Map<String, double> fator = const {},
}) => MaterialEstoque(
  id: 'x',
  nome: 'x',
  categoria: CategoriaMaterial.chapa,
  unidade: u,
  larguraMm: larg,
  alturaMm: alt,
  fatorEmbalagem: fator,
);

Conversao _c(double q, String un, MaterialEstoque m, {double? l, double? a}) =>
    ConversorUnidades.paraUnidadeDoEstoque(
      quantidade: q,
      unidadeOriginal: un,
      larguraItemMm: l,
      alturaItemMm: a,
      material: m,
    );

void main() {
  group('m² → chapas', () {
    test('usa a medida do material e arredonda pra cima', () {
      // 2750×1850 = 5,0875 m²; 11,4 / 5,0875 = 2,24 → 3 chapas
      final r = _c(11.4, 'm²', _m(UnidadeEstoque.ch, larg: 2750, alt: 1850));
      expect(r.quantidade, 3);
      expect(r.conferir, isFalse);
      expect(r.observacao, 'veio como 11,4 m² → 3 chapas');
    });

    test('sem medida no material usa a do item', () {
      final r = _c(5, 'm2', _m(UnidadeEstoque.ch), l: 2440, a: 1220);
      // 2,9768 m² por chapa → 1,68 → 2
      expect(r.quantidade, 2);
      expect(r.conferir, isFalse);
    });

    test('sem medida nenhuma usa a chapa padrão e marca pra conferir', () {
      final r = _c(5.0875, 'm²', _m(UnidadeEstoque.ch));
      expect(r.quantidade, 1);
      expect(r.conferir, isTrue);
    });
  });

  group('metros de fita', () {
    test('m continua m', () {
      expect(_c(48, 'm', _m(UnidadeEstoque.m)).quantidade, 48);
      expect(_c(36, 'metros lineares', _m(UnidadeEstoque.m)).quantidade, 36);
      expect(_c(36, 'ml', _m(UnidadeEstoque.m)).quantidade, 36);
    });

    test('mm e cm viram m', () {
      expect(_c(4800, 'mm', _m(UnidadeEstoque.m)).quantidade, 4.8);
      expect(_c(250, 'cm', _m(UnidadeEstoque.m)).quantidade, 2.5);
    });
  });

  group('contáveis', () {
    test('peça vira un, par vira par', () {
      expect(_c(12, 'pç', _m(UnidadeEstoque.un)).quantidade, 12);
      expect(_c(12, 'Peças', _m(UnidadeEstoque.un)).quantidade, 12);
      expect(_c(8, 'pr', _m(UnidadeEstoque.par)).quantidade, 8);
    });

    test('par → un dobra', () {
      expect(_c(8, 'par', _m(UnidadeEstoque.un)).quantidade, 16);
    });

    test('inteiras arredondam pra cima', () {
      expect(_c(2.2, 'ch', _m(UnidadeEstoque.ch)).quantidade, 3);
    });

    test('caixa com fator aprendido', () {
      final r = _c(2, 'CX', _m(UnidadeEstoque.un, fator: {'CX': 100}));
      expect(r.quantidade, 200);
      expect(r.desconhecida, isFalse);
    });
  });

  test('unidade desconhecida vai pra confirmar', () {
    final r = _c(3, 'rolo', _m(UnidadeEstoque.m));
    expect(r.desconhecida, isTrue);
    expect(r.quantidade, 3);
  });
}
