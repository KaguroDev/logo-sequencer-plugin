; ============================================================
;  Logo Sequencer — instalador .exe del plugin para OBS
;  (NSIS 3). Lo genera el destino "installer" de CMake /
;  Visual Studio, que le pasa:
;    /DVERSION=1.1.0
;    /DPLUGIN_NAME=logo-sequencer
;    /DRUNDIR=<build_x64\rundir\RelWithDebInfo>
;    /DOUTDIR=<carpeta release>
;  Instala en C:\ProgramData\obs-studio\plugins\logo-sequencer\
;    bin\64bit\logo-sequencer.dll
;    data\Control_logo.html, Overlay_logo.html, locale\
; ============================================================
Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

!ifndef VERSION
  !define VERSION "1.1.0"
!endif
!ifndef PLUGIN_NAME
  !define PLUGIN_NAME "logo-sequencer"
!endif
!ifndef RUNDIR
  !error "Falta /DRUNDIR=<carpeta rundir\<Config> de la compilación>"
!endif
!ifndef OUTDIR
  !define OUTDIR "."
!endif

!define APPNAME   "Logo Sequencer"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PLUGIN_NAME}-obs-plugin"
; Instalador anterior (Inno Setup, mismo destino): se limpia su entrada al actualizar
!define INNOKEY   "Software\Microsoft\Windows\CurrentVersion\Uninstall\{FF7994DC-0438-41F8-9CA1-29D6B0539EF1}_is1"

Name "${APPNAME} para OBS"
OutFile "${OUTDIR}\${PLUGIN_NAME}-${VERSION}-windows-x64-setup.exe"
; $INSTDIR = C:\ProgramData\obs-studio\plugins\${PLUGIN_NAME} (se fija en .onInit)
InstallDir "$PROGRAMFILES64\obs-studio\plugins\${PLUGIN_NAME}"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
BrandingText "${APPNAME} ${VERSION}"
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1034 "ProductName"     "${APPNAME} para OBS"
VIAddVersionKey /LANG=1034 "CompanyName"     "KaguroDev"
VIAddVersionKey /LANG=1034 "FileDescription" "Instalador del plugin ${APPNAME} para OBS Studio"
VIAddVersionKey /LANG=1034 "FileVersion"     "${VERSION}"
VIAddVersionKey /LANG=1034 "ProductVersion"  "${VERSION}"
VIAddVersionKey /LANG=1034 "LegalCopyright"  "GPL-2.0"

; ---------- Interfaz ----------
!define MUI_ICON   "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Instalar ${APPNAME} para OBS"
!define MUI_WELCOMEPAGE_TEXT "Este asistente instalará el plugin ${APPNAME} ${VERSION} en OBS Studio:$\r$\n$\r$\n  •  Dock $\"Logo Sequencer$\" (menú Docks)$\r$\n  •  Herramientas > Logo Sequencer: crear / actualizar overlay$\r$\n  •  Atajos de teclado en Ajustes > Atajos (Iniciar, Pausar, Siguiente, Anterior, Detener)$\r$\n$\r$\nRequiere OBS Studio 31 o superior (64 bits). Cierra OBS antes de continuar."
!define MUI_FINISHPAGE_TITLE "Instalación completada"
!define MUI_FINISHPAGE_TEXT "1. Abre OBS Studio.$\r$\n2. Herramientas > Ajustes del servidor WebSocket > Activar (si no lo está).$\r$\n3. Menú Docks > marca $\"Logo Sequencer$\".$\r$\n4. Herramientas > Logo Sequencer: crear / actualizar overlay.$\r$\n5. Carga los logos en el dock y pulsa Iniciar."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Abrir OBS Studio ahora"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchObs

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Spanish"

; ---------- OBS debe estar cerrado (el .dll queda bloqueado si está abierto) ----------
!macro CHECK_OBS_CLOSED
  check_obs:
    nsExec::ExecToStack `cmd /c tasklist /NH /FI "IMAGENAME eq obs64.exe" | find /I "obs64.exe"`
    Pop $0
    Pop $1
    ${If} $0 == 0
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "OBS Studio está abierto.$\r$\n$\r$\nCiérralo y pulsa Reintentar." IDRETRY check_obs
      Quit
    ${EndIf}
!macroend

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "Este plugin requiere Windows de 64 bits."
    Quit
  ${EndIf}
  SetRegView 64
  ; Carpeta de plugins de OBS 28+ para todos los usuarios: C:\ProgramData\obs-studio\plugins
  SetShellVarContext all
  StrCpy $INSTDIR "$APPDATA\obs-studio\plugins\${PLUGIN_NAME}"
  !insertmacro CHECK_OBS_CLOSED
FunctionEnd

Function un.onInit
  SetRegView 64
  SetShellVarContext all
  !insertmacro CHECK_OBS_CLOSED
FunctionEnd

Function LaunchObs
  ReadRegStr $0 HKLM "SOFTWARE\OBS Studio" ""
  ${If} ${FileExists} "$0\bin\64bit\obs64.exe"
    SetOutPath "$0\bin\64bit"
    Exec `"$0\bin\64bit\obs64.exe"`
  ${Else}
    MessageBox MB_OK|MB_ICONINFORMATION "No se encontró OBS Studio automáticamente. Ábrelo desde el menú Inicio."
  ${EndIf}
FunctionEnd

; ---------- Instalación ----------
Section "Instalar"
  ; Instalación previa hecha con el instalador de Inno Setup (misma carpeta):
  ; se quitan su desinstalador y su entrada para no tener dos en "Aplicaciones".
  ReadRegStr $2 HKLM "${INNOKEY}" "UninstallString"
  ${If} $2 != ""
    DetailPrint "Quitando la entrada del instalador anterior..."
    Delete "$INSTDIR\unins000.exe"
    Delete "$INSTDIR\unins000.dat"
    DeleteRegKey HKLM "${INNOKEY}"
  ${EndIf}

  ; Restos de una versión anterior (archivos que ya no existan en esta)
  RMDir /r "$INSTDIR\bin"
  RMDir /r "$INSTDIR\data"

  SetOutPath "$INSTDIR\bin\64bit"
  File "${RUNDIR}\${PLUGIN_NAME}.dll"
  File /nonfatal "${RUNDIR}\${PLUGIN_NAME}.pdb"

  SetOutPath "$INSTDIR\data"
  File /r "${RUNDIR}\${PLUGIN_NAME}\*.*"

  SetOutPath "$INSTDIR"
  File "icon.ico"
  WriteUninstaller "$INSTDIR\Desinstalar.exe"

  ; Entrada en "Aplicaciones instaladas"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayName"     "${APPNAME} (plugin de OBS)"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayVersion"  "${VERSION}"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayIcon"     "$INSTDIR\icon.ico"
  WriteRegStr   HKLM "${UNINSTKEY}" "Publisher"       "KaguroDev"
  WriteRegStr   HKLM "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${UNINSTKEY}" "UninstallString" `"$INSTDIR\Desinstalar.exe"`
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "EstimatedSize" 2400
SectionEnd

; ---------- Desinstalación ----------
Section "Uninstall"
  RMDir /r "$INSTDIR\bin"
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\icon.ico"
  Delete "$INSTDIR\Desinstalar.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKLM "${UNINSTKEY}"
  MessageBox MB_OK|MB_ICONINFORMATION "${APPNAME} se desinstaló.$\r$\n$\r$\nSi agregaste la fuente $\"Overlay Logos$\" a tus escenas, bórrala desde OBS (clic derecho > Eliminar)."
SectionEnd
