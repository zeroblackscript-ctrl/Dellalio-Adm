; Script de Instalação - Dellalio Cérebro ADM
; Gerado automaticamente para distribuição com auto_updater (WinSparkle)

#define MyAppName "Dellalio Cerebro ADM"
#define MyAppVersion "1.0.2"
#define MyAppPublisher "Dellalio Moveis Planejados"
#define MyAppURL "https://github.com/zeroblackscript-ctrl/Dellalio-Adm"
#define MyAppExeName "cerebro_adm.exe"

[Setup]
; NOTA: O valor de AppId deve ser único para cada aplicativo.
; Não use o mesmo AppId em instaladores de aplicativos diferentes.
AppId={{B8F4A3D2-7E6C-4A1B-9D5F-2C8E0A7B3F1D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
; "ArchitecturesAllowed=x64compatible" especifica que a instalação não pode ser executada
; em nada além de x64 e Windows 11 em ARM.
ArchitecturesAllowed=x64compatible
; "ArchitecturesInstallIn64BitMode=x64compatible" solicita que a instalação seja
; feita em "modo 64 bits" em x64 e Windows 11 em ARM,
; o que significa que deve usar o diretório nativo de 64 bits do Program Files.
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
; Remove as seguintes linhas para executar no modo administrativo (necessário para instaladores por máquina)
PrivilegesRequired=lowest
OutputDir=..\
OutputBaseFilename=DellalioCerebroADM_Setup_v1.0.2
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na &Area de Trabalho"; GroupDescription: "Atalhos adicionais:"

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTA: Não use "Flags: ignoreversion" em nenhum sistema de arquivos compartilhados

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Iniciar Dellalio Cérebro ADM"; Flags: nowait postinstall skipifsilent