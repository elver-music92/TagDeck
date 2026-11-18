; TagDeck - Windows setup (Inno Setup 6). Built by .github/workflows/build.yml:
;   iscc /DAppVersion=1.2.2 /DSrcDir=<folder with TagDeck.exe and _internal> /DIconFile=<.ico> installer\TagDeck.iss
; Installs for the current user only (no administrator rights), into %LOCALAPPDATA%\Programs\TagDeck,
; because TagDeck keeps its settings, logs and backups next to TagDeck.exe.
; An update replaces only TagDeck.exe and _internal: settings, undo logs, backups and caches stay.
; Uninstalling removes the program; the settings and backups it made are left in the folder.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SrcDir
  #define SrcDir "..\build\dist\TagDeck"
#endif
#ifndef IconFile
  #define IconFile "..\build\tagdeck.ico"
#endif

[Setup]
AppId={{698E4873-4BEE-4099-9A53-410ABC895391}
AppName=TagDeck
AppVersion={#AppVersion}
AppVerName=TagDeck {#AppVersion}
AppPublisher=Thanasis Karageorgos
AppCopyright=(c) 2026 Thanasis Karageorgos
AppComments=Chip Tagging and Crate Tools for Serato DJ
VersionInfoVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\TagDeck
DefaultGroupName=TagDeck
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
LicenseFile=..\LICENSE
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\TagDeck.exe
UninstallDisplayName=TagDeck
OutputDir=..\build\setup
OutputBaseFilename=TagDeck-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; the program files of the version before (never the settings, logs or backups)
Type: filesandordirs; Name: "{app}\_internal"

[Files]
Source: "{#SrcDir}\TagDeck.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\_internal\*"; DestDir: "{app}\_internal"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\TagDeck"; Filename: "{app}\TagDeck.exe"
Name: "{autodesktop}\TagDeck"; Filename: "{app}\TagDeck.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\TagDeck.exe"; Description: "{cm:LaunchProgram,TagDeck}"; Flags: nowait postinstall skipifsilent
