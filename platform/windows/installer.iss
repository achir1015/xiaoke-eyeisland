; 小柯機器人眼動探險島 Windows 安裝程式（Inno Setup 6）
; 用法：ISCC /DAppVersion=1.0.0 installer.iss
; 安裝到使用者資料夾，不需系統管理員權限；遊戲內更新會用 /SILENT 覆蓋安裝並自動重開。

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppName "小柯機器人眼動探險島"
#define AppExe "XiaokeEyeIsland.exe"

[Setup]
AppId={{5E1C7A93-2B4D-4F86-9C0E-3D7A1B6F2E48}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=吳玉柱 先生 與 Claude AI Opus 5.5
AppPublisherURL=https://achir1015.github.io/xiaoke-eyeisland/
AppSupportURL=https://github.com/achir1015/xiaoke-eyeisland
AppUpdatesURL=https://github.com/achir1015/xiaoke-eyeisland/releases
DefaultDirName={localappdata}\Programs\XiaokeEyeIsland
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\..\build\release
OutputBaseFilename=XiaokeEyeIsland-Setup
SetupIconFile=..\icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}.0
VersionInfoProductName={#AppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "cht"; MessagesFile: "ChineseTraditional.isl"

[Tasks]
Name: "desktopicon"; Description: "建立桌面捷徑"; GroupDescription: "其他工作："

[Files]
Source: "..\..\..\build\windows\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\解除安裝 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; 不加 skipifsilent：遊戲內更新（/SILENT）完成後也會自動重新開啟遊戲
Filename: "{app}\{#AppExe}"; Description: "立即開始探險"; Flags: nowait postinstall
