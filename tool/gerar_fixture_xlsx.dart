// Gera test/fixtures/lista_generica.xlsx (XLSX mínimo, uma aba).
// Uso: dart run tool/gerar_fixture_xlsx.dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

void main() {
  const linhas = [
    ['Lista de materiais - Painel TV Souza'],
    ['Descrição', 'Quantidade', 'UN', 'Ref'],
    ['MDF Branco TX 18mm', '3', 'ch', '1050-18-BT'],
    ['MDP Cinza Cristal 15mm', '1', 'ch', ''],
    ['Fita de borda branca 22mm', '48', 'm', ''],
    ['Puxador perfil alumínio', '4', 'm', ''],
  ];
  final strings = <String>[];
  int idx(String s) {
    final i = strings.indexOf(s);
    if (i >= 0) return i;
    strings.add(s);
    return strings.length - 1;
  }

  String esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  final rows = StringBuffer();
  for (var r = 0; r < linhas.length; r++) {
    rows.write('<row r="${r + 1}">');
    for (var c = 0; c < linhas[r].length; c++) {
      final v = linhas[r][c];
      if (v.isEmpty) continue;
      final ref = '${String.fromCharCode(65 + c)}${r + 1}';
      final n = num.tryParse(v);
      rows.write(n != null
          ? '<c r="$ref"><v>$v</v></c>'
          : '<c r="$ref" t="s"><v>${idx(v)}</v></c>');
    }
    rows.write('</row>');
  }

  const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  final arquivos = {
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/></Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="$ns" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Lista" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/></Relationships>',
    'xl/worksheets/sheet1.xml':
        '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="$ns"><sheetData>$rows</sheetData></worksheet>',
    'xl/sharedStrings.xml':
        '<?xml version="1.0" encoding="UTF-8"?><sst xmlns="$ns" count="${strings.length}" uniqueCount="${strings.length}">${strings.map((s) => '<si><t>${esc(s)}</t></si>').join()}</sst>',
  };

  final zip = Archive();
  arquivos.forEach((nome, conteudo) {
    zip.add(ArchiveFile.bytes(nome, utf8.encode(conteudo)));
  });
  File('test/fixtures/lista_generica.xlsx').writeAsBytesSync(ZipEncoder().encodeBytes(zip));
  stdout.writeln('ok: test/fixtures/lista_generica.xlsx');
}
