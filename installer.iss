[Setup]
AppName=Interlogue
AppVersion=1.0.0
AppPublisher=Joshua
DefaultDirName={pf}\Interlogue
DefaultGroupName=Interlogue
OutputDir=installer
OutputBaseFilename=Interlogue_setup
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Interlogue"; Filename: "{app}\Interlogue.exe"
Name: "{commondesktop}\Interlogue"; Filename: "{app}\Interlogue.exe"

[Run]
Filename: "{app}\Interlogue.exe"; Description: "Launch Interlogue"; Flags: nowait postinstall skipifsilent
