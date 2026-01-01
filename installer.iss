[Setup]
AppName=Encyclopedia Editor
AppVersion=1.0.0
AppPublisher=Your Name
DefaultDirName={pf}\EncyclopediaEditor
DefaultGroupName=Encyclopedia Editor
OutputDir=installer
OutputBaseFilename=EncyclopediaEditor_Setup
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Encyclopedia Editor"; Filename: "{app}\arted.exe"
Name: "{commondesktop}\Encyclopedia Editor"; Filename: "{app}\arted.exe"

[Run]
Filename: "{app}\arted.exe"; Description: "Launch Encyclopedia Editor"; Flags: nowait postinstall skipifsilent
