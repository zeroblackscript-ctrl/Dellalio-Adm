import 'package:DELLALIO/estoque/util/normalizar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizar', () {
    test('caixa, acento e medida colada', () {
      expect(normalizar('MDF LOURO FREIJÓ 18MM'), 'mdf louro freijo 18mm');
      expect(normalizar('Mdf Louro Freijo 18 mm'), 'mdf louro freijo 18mm');
      expect(
        normalizar('MDF LOURO FREIJÓ 18MM'),
        normalizar('Mdf Louro Freijo 18 mm'),
      );
    });

    test('pontuação vira espaço', () {
      expect(normalizar('Corrediça Telesc. 450mm'), 'corredica telesc 450mm');
      expect(normalizar('DOB CALCO 35 C/AMORT RETA'), 'dob calco 35 c amort reta');
    });

    test('x entre números', () {
      expect(normalizar('Parafuso 4×40 Philips'), 'parafuso 4x40 philips');
      expect(normalizar('Chapa 2750 X 1850'), 'chapa 2750x1850');
      expect(normalizar('2750mm x 1850mm'), '2750mmx1850mm');
      expect(normalizar('MDF TX 18mm'), 'mdf tx 18mm');
    });

    test('decimal entre dígitos é preservado', () {
      expect(normalizar('Fita 1,5 mm'), 'fita 1.5mm');
      expect(normalizar('11,4 m²'), '11.4m2');
    });

    test('espaços colapsados', () {
      expect(normalizar('  Fita   de  borda  '), 'fita de borda');
    });
  });

  group('tokens', () {
    test('sem palavras vazias', () {
      expect(tokens('Dobradiça 35mm c/ amortecedor'), {
        'dobradica',
        '35mm',
        'amortecedor',
      });
      expect(tokens('Fita de borda branca 22mm'), {'fita', 'borda', 'branca', '22mm'});
    });
  });

  group('medidasMm', () {
    test('espessura e comprimento, sem confundir com dimensão', () {
      expect(medidasMm('MDF Branco TX 18 mm'), {18});
      expect(medidasMm('Corrediça telescópica 450mm'), {450});
      expect(medidasMm('Chapa 2750x1850mm'), isEmpty);
    });
  });

  group('nomeLegivel', () {
    test('caixa alta vira título', () {
      expect(nomeLegivel('DOB CALCO 35 C/AMORT RETA'), 'Dob Calco 35 C/amort Reta');
      expect(nomeLegivel('MDF BRANCO TX 18MM'), 'MDF Branco TX 18mm');
    });

    test('texto já legível fica como está', () {
      expect(nomeLegivel('Corrediça telescópica 450mm'), 'Corrediça telescópica 450mm');
    });
  });
}
