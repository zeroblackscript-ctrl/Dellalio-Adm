# Copia a camada de dados do estoque (modelos, utilitarios e servicos) do
# Cerebro para o Gerenciador. O Cerebro e a fonte: edite aqui e rode este
# script; nunca edite as copias no Gerenciador.
#
# Uso: powershell -File tool\sincronizar_estoque.ps1 [-Destino <pasta do Gerenciador>]
param(
  [string]$Destino = 'D:\cerebro-20260901T160718Z-1-001\cerebro'
)

$origem = Join-Path $PSScriptRoot '..\lib\estoque'
$alvo = Join-Path $Destino 'lib\estoque'

$arquivos = @(
  'models\aviso.dart',
  'models\enums.dart',
  'models\fornecedor.dart',
  'models\leitura.dart',
  'models\lista_corte.dart',
  'models\material_estoque.dart',
  'models\models.dart',
  'models\movimentacao.dart',
  'models\nota_fiscal.dart',
  'models\pedido_compra.dart',
  'util\normalizar.dart',
  'util\quantidade.dart',
  'util\datas.dart',
  'services\aviso_service.dart',
  'services\consultas.dart',
  'services\estoque_service.dart',
  'services\lista_service.dart',
  'services\pedido_service.dart',
  'services\reserva_service.dart',
  'services\responsavel.dart',
  'services\saldo.dart',
  'ui\formatos.dart'
)

$aviso = "// COPIA do Cerebro (Dellalio Moveis Planejados/lib/estoque). Nao edite aqui:`n// edite la e rode tool/sincronizar_estoque.ps1.`n"
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($a in $arquivos) {
  $de = Join-Path $origem $a
  $para = Join-Path $alvo $a
  New-Item -ItemType Directory -Force (Split-Path $para) | Out-Null
  $conteudo = [IO.File]::ReadAllText($de, $utf8)
  [IO.File]::WriteAllText($para, $aviso + $conteudo, $utf8)
  "ok  $a"
}
