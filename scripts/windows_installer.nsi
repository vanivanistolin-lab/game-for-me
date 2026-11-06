Unicode True
!include "MUI2.nsh"
Name "Рубеж / GameForMe"
OutFile "build/GameForMe-Setup.exe"
InstallDir "C:\game"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\GameForMe.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Запустить игру"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Russian"
Section "Игра"
 SetOutPath "$INSTDIR"
 File "build/windows/GameForMe.exe"
 File /oname=README-GameForMe.md "README.md"
 File /oname=GameForMe-LICENSE.txt "LICENSE"
 WriteUninstaller "$INSTDIR\Uninstall-GameForMe.exe"
SectionEnd
Section "Uninstall"
 Delete "$INSTDIR\GameForMe.exe"
 Delete "$INSTDIR\README-GameForMe.md"
 Delete "$INSTDIR\GameForMe-LICENSE.txt"
 Delete "$INSTDIR\Uninstall-GameForMe.exe"
 RMDir "$INSTDIR"
SectionEnd
