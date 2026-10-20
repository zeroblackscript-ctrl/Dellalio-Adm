import 'package:DELLALIO/estoque/models/enums.dart';
import 'package:DELLALIO/estoque/services/saldo.dart';
import 'package:DELLALIO/estoque/util/quantidade.dart';
import 'package:flutter_test/flutter_test.dart';

CalculoSaldo _s(double fisico, double reservado, [double custo = 0]) =>
    CalculoSaldo(
      fisico: fisico,
      reservado: reservado,
      custoMedio: custo,
      unidade: UnidadeEstoque.ch,
    );

void main() {
  test('entrada recalcula custo médio ponderado', () {
    final r = _s(4, 0, 300).entrada(6, custoUnitario: 350);
    expect(r.fisico, 10);
    expect(r.custoMedio, closeTo(330, 1e-9));
  });

  test('entrada sem custo mantém o custo médio', () {
    expect(_s(4, 0, 300).entrada(2).custoMedio, 300);
  });

  test('reserva só o disponível', () {
    final r = _s(4, 3).reservar(5);
    expect(r.efetiva, 1);
    expect(r.reservado, 4);
  });

  test('reserva com disponível zero não reserva nada', () {
    expect(_s(4, 4).reservar(2).efetiva, 0);
  });

  test('saída maior que o físico registra até o físico e alerta', () {
    final r = _s(3, 0).saida(5);
    expect(r.efetiva, 3);
    expect(r.fisico, 0);
    expect(r.alerta, isNotNull);
  });

  test('saída consumindo reserva baixa físico e reservado', () {
    final r = _s(10, 4).saida(4, consumirReserva: true);
    expect(r.fisico, 6);
    expect(r.reservado, 0);
    expect(r.alerta, isNull);
  });

  test('saída sem consumir reserva nunca deixa reservado > físico', () {
    final r = _s(5, 4).saida(3);
    expect(r.fisico, 2);
    expect(r.reservado, 2);
    expect(r.alerta, isNotNull);
  });

  test('liberar não passa do reservado', () {
    final r = _s(5, 2).liberar(3);
    expect(r.efetiva, 2);
    expect(r.reservado, 0);
  });

  test('ajuste gera diferença com sinal e corta reserva se preciso', () {
    final baixo = _s(10, 6).ajustar(4);
    expect(baixo.efetiva, 6);
    expect(baixo.sinal, -1);
    expect(baixo.reservado, 4);
    expect(baixo.alerta, isNotNull);

    final alto = _s(10, 0).ajustar(12);
    expect(alto.efetiva, 2);
    expect(alto.sinal, 1);
  });

  test('quantidades negativas viram zero', () {
    expect(_s(5, 0).saida(-2).efetiva, 0);
    expect(_s(5, 0).ajustar(-1).fisico, 0);
  });

  test('unidades inteiras arredondam pra cima', () {
    expect(arredondarParaUnidade(2.1, UnidadeEstoque.ch), 3);
    expect(arredondarParaUnidade(3.0, UnidadeEstoque.un), 3);
    expect(arredondarParaUnidade(1.2345, UnidadeEstoque.m), 1.235);
  });
}
