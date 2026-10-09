; BetterNotes Windows installer (Inno Setup 6).
; Build:  ISCC.exe /DAppVersion=1.0.2 installer\BetterNotes.iss
; Expects a finished `flutter build windows --release` in build\windows\x64\runner\Release.
; The installer is per-user by default (no administrator needed) and upgrades
; in place. Notes live in %APPDATA%\dev.betternotes and are never removed.

#ifndef AppVersion
  #define AppVersion "1.0.2"
#endif
#define AppName "BetterNotes"
#define AppExe "better_notes.exe"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{6F1B6B7A-3C1E-4D58-9B52-BE77E27A0C11}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=BetterNotes
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=BetterNotes-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Close a running BetterNotes (it saves its notes on a normal close) before
; replacing files, and offer to start it again afterwards.
CloseApplications=yes
CloseApplicationsFilter={#AppExe}
RestartApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
; The AppUserModelID matches the runner, so the taskbar "New note" jump list
; (registered by the app at each start) belongs to this shortcut.
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "BetterNotes.Desktop"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "BetterNotes.Desktop"; Tasks: desktopicon

[Code]
// The app runs its own save-then-exit routine, which Windows' Restart Manager
// does not wait for. Ask a running copy to quit first (`--quit`), then wait
// for its window to go away. Older builds ignore this and fall back to the
// Restart Manager prompt.
procedure CloseRunningApp();
var
  ResultCode, I: Integer;
  Exe: String;
begin
  Exe := ExpandConstant('{app}\{#AppExe}');
  if not FileExists(Exe) then Exit;
  if FindWindowByWindowName('better_notes') = 0 then Exit;
  Exec(Exe, '--quit', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  for I := 1 to 60 do
  begin
    if FindWindowByWindowName('better_notes') = 0 then Break;
    Sleep(500);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  CloseRunningApp();
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  CloseRunningApp();
  Result := True;
end;

[Run]
Filename: "{app}\{#AppExe}"; Description: "Start {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Remove what the app itself may have registered for this user.
Filename: "powershell.exe"; Parameters: "-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ""Unregister-ScheduledTask -TaskName 'BetterNotes Reminders' -Confirm:$false -ErrorAction SilentlyContinue"""; Flags: runhidden; RunOnceId: "RemoveReminderTask"
Filename: "reg.exe"; Parameters: "delete ""HKCU\Software\Microsoft\Windows\CurrentVersion\Run"" /v BetterNotes /f"; Flags: runhidden; RunOnceId: "RemoveAutoStart"

[UninstallDelete]
; Logs are diagnostics, not notes; the notes database is left in place.
Type: filesandordirs; Name: "{userappdata}\dev.betternotes\better_notes\logs"
