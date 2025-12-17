; ======================================================
;  INSTALADOR - FERIADOS (Flutter Windows)
;  Ajustado para diretório e executável fornecidos
; ======================================================

[Setup]
AppName=Feriados
AppVersion=1.0.0
DefaultDirName={commonpf}\Feriados
DefaultGroupName=Feriados
OutputDir=C:\flutter\feriados\dist
OutputBaseFilename=Feriados_Installer
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
DisableDirPage=no
DisableProgramGroupPage=no

; Ícone do instalador (opcional, caso exista)
SetupIconFile=C:\flutter\feriados\windows\runner\resources\app_icon.ico

[Files]
; Copia todo o conteúdo do diretório Release gerado pelo Flutter
Source: "C:\flutter\feriados\build\windows\x64\runner\Release\*"; \
DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
; Atalho no Menu Iniciar
Name: "{group}\Feriados"; \
Filename: "{app}\feriados.exe"

; Atalho na Área de Trabalho
Name: "{commondesktop}\Feriados"; \
Filename: "{app}\feriados.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; \
GroupDescription: "Opções adicionais:"

[Run]
; Executar app após instalação
Filename: "{app}\feriados.exe"; \
Description: "Executar agora"; Flags: nowait postinstall skipifsilent
