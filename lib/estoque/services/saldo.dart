import '../models/enums.dart';

/// Resultado de aplicar uma operação ao saldo de um material.
class NovoSaldo {
  final double fisico;
  final double reservado;
  final double custoMedio;

  /// Quanto de fato foi movimentado (pode ser menor que o pedido).
  final double efetiva;

  /// +1/−1 (só importa no ajuste).
  final int sinal;

  /// A operação foi limitada pelas regras (ex.: saída maior que o físico,
  /// reserva cortada por um ajuste). Vira aviso, nunca exceção.
  final String? alerta;

  const NovoSaldo({
    required this.fisico,
    required this.reservado,
    required this.custoMedio,
    required this.efetiva,
    this.sinal = 1,
    this.alerta,
  });
}

/// Regras de saldo, puras (sem Firestore) pra poderem ser testadas.
///
/// Invariantes (regra 2): `0 <= reservado <= fisico`. Nada aqui lança:
/// quando o pedido excede o possível, faz o possível e devolve [NovoSaldo.alerta].
class CalculoSaldo {
  final double fisico;
  final double reservado;
  final double custoMedio;
  final UnidadeEstoque unidade;

  const CalculoSaldo({
    required this.fisico,
    required this.reservado,
    required this.custoMedio,
    required this.unidade,
  });

  double get disponivel => _pos(fisico - reservado);

  NovoSaldo entrada(double qtd, {double? custoUnitario}) {
    final q = _pos(qtd);
    final novoFisico = fisico + q;
    var custo = custoMedio;
    if (custoUnitario != null && custoUnitario > 0 && novoFisico > 0) {
      // Média ponderada; estoque negativo/zero não pesa.
      final base = fisico.clamp(0, double.infinity);
      custo = (base * custoMedio + q * custoUnitario) / (base + q);
    }
    return NovoSaldo(
      fisico: novoFisico,
      reservado: reservado,
      custoMedio: custo,
      efetiva: q,
    );
  }

  /// Saída/perda. Com [consumirReserva] baixa também o reservado (projeto
  /// cortado). Sem ela, se a saída comer estoque reservado, o reservado é
  /// cortado até caber e isso vira alerta.
  NovoSaldo saida(double qtd, {bool consumirReserva = false}) {
    final pedido = _pos(qtd);
    final efetiva = pedido > fisico ? _pos(fisico) : pedido;
    final novoFisico = fisico - efetiva;
    var novoReservado = consumirReserva
        ? (reservado - efetiva).clamp(0, double.infinity).toDouble()
        : reservado;
    String? alerta;
    if (efetiva < pedido) {
      alerta =
          'Saída de ${_f(pedido)} ${unidade.sigla} maior que o físico '
          '(${_f(fisico)}). Registrado só ${_f(efetiva)}.';
    }
    if (novoReservado > novoFisico) {
      final corte = novoReservado - novoFisico;
      novoReservado = novoFisico;
      alerta = [
        ?alerta,
        'Reserva reduzida em ${_f(corte)} ${unidade.sigla}: o físico não '
            'cobre mais o que estava reservado.',
      ].join(' ');
    }
    return NovoSaldo(
      fisico: novoFisico,
      reservado: novoReservado,
      custoMedio: custoMedio,
      efetiva: efetiva,
      alerta: alerta,
    );
  }

  /// Reserva `min(desejada, disponível)`.
  NovoSaldo reservar(double desejada) {
    final q = _pos(desejada);
    final r = q > disponivel ? disponivel : q;
    return NovoSaldo(
      fisico: fisico,
      reservado: reservado + r,
      custoMedio: custoMedio,
      efetiva: r,
    );
  }

  NovoSaldo liberar(double qtd) {
    final q = _pos(qtd);
    final l = q > reservado ? reservado.clamp(0, double.infinity).toDouble() : q;
    return NovoSaldo(
      fisico: fisico,
      reservado: reservado - l,
      custoMedio: custoMedio,
      efetiva: l,
    );
  }

  /// Ajuste pra um novo físico (inventário). Gera a diferença com sinal.
  NovoSaldo ajustar(double novoFisico) {
    final alvo = _pos(novoFisico);
    final diferenca = alvo - fisico;
    var novoReservado = reservado;
    String? alerta;
    if (novoReservado > alvo) {
      alerta =
          'Ajuste deixou o físico (${_f(alvo)} ${unidade.sigla}) abaixo do '
          'reservado (${_f(reservado)}). Reserva reduzida.';
      novoReservado = alvo;
    }
    return NovoSaldo(
      fisico: alvo,
      reservado: novoReservado,
      custoMedio: custoMedio,
      efetiva: diferenca.abs(),
      sinal: diferenca < 0 ? -1 : 1,
      alerta: alerta,
    );
  }

  static double _pos(double v) => v.isNaN || v < 0 ? 0 : v;

  static String _f(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
