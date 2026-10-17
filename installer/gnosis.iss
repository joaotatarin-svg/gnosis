; Instalador do GNOSIS — Inno Setup (https://jrsoftware.org/isinfo.php)
; 1) Exporte o jogo no Godot (builds/GNOSIS.exe + GNOSIS.pck)
; 2) Abra este arquivo no Inno Setup Compiler e clique em Compile
; Saída: installer/Output/GNOSIS-Setup-<versão>.exe (padrão 1.2.0; mude com /DAppVersion=x.y.z)

#define AppName "GNOSIS"
#ifndef AppVersion
#define AppVersion "1.2.0"
#endif
; Publicador: João Tatarin (decidido em 17/10/2026, versão 1.2.0).
; AppId: MANTIDO o mesmo desde o build 1.0.0 (não é um GUID hexadecimal de
; verdade, mas o Inno aceita qualquer texto). NUNCA troque: é por ele que o
; Windows reconhece a instalação anterior para atualizar/desinstalar — um
; AppId novo instalaria um 2º GNOSIS ao lado do antigo.
; Arquivo em UTF-8 COM BOM (o "ã" do publicador sai certo no Inno 6).
#define AppPublisher "João Tatarin"
#define AppExe "GNOSIS.exe"

[Setup]
AppId={{7C1E7A2A-GNOS-1S00-KENO-MA0000000001}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExe}
SetupIconFile=..\assets\icon_gnosis.ico

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\builds\GNOSIS.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\builds\GNOSIS.pck"; DestDir: "{app}"; Flags: ignoreversion
; Licenças que a distribuição EXIGE junto da obra: atribuições CC-BY das
; músicas/SFX (LICENSES.md) e o aviso MIT do motor Godot (LICENSE_godot.txt).
Source: "..\assets\LICENSES.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE_godot.txt"; DestDir: "{app}"; Flags: ignoreversion
; Patches menores: o jogo só monta patch_<versão>_*.pck da MESMA versão do
; projeto (ex.: patch_1.2.0_01.pck). Solte-os em builds/ e descomente:
; Source: "..\builds\patch_{#AppVersion}_*.pck"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
