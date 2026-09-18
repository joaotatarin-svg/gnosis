; Instalador do GNOSIS — Inno Setup (https://jrsoftware.org/isinfo.php)
; 1) Exporte o jogo no Godot (builds/GNOSIS.exe + GNOSIS.pck)
; 2) Abra este arquivo no Inno Setup Compiler e clique em Compile
; Saída: installer/Output/GNOSIS-Setup-0.1.0.exe

#define AppName "GNOSIS"
#ifndef AppVersion
#define AppVersion "1.0.0"
#endif
#define AppPublisher "Estudio Jogo"
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
; Patches menores: solte patch_*.pck em builds/ e descomente:
; Source: "..\builds\patch_*.pck"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
