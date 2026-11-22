; ============================================================
;  Logo Sequencer — instalador .exe del plugin para OBS
;  (NSIS 3). Lo genera el destino "installer" de CMake /
;  Visual Studio, que le pasa:
;    /DVERSION=1.2.1
;    /DPLUGIN_NAME=logo-sequencer
;    /DRUNDIR=<build_x64\rundir\RelWithDebInfo>
;    /DOUTDIR=<carpeta release>
;  Instala en C:\ProgramData\obs-studio\plugins\logo-sequencer\
;    bin\64bit\logo-sequencer.dll
;    data\Control_logo.html, Overlay_logo.html, locale\
;    data\language.txt  ← idioma elegido al instalar ("en" / "es")
;
;  Idiomas: al abrirse pregunta English / Español. El idioma
;  elegido se usa en el asistente, en el desinstalador y en el
;  plugin (menús, atajos, dock y overlay).
; ============================================================
Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

!ifndef VERSION
  !define VERSION "1.2.1"
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
!define PUBLISHER "KaguroDev"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PLUGIN_NAME}-obs-plugin"
; Instalador anterior (Inno Setup, mismo destino): se limpia su entrada al actualizar
!define INNOKEY   "Software\Microsoft\Windows\CurrentVersion\Uninstall\{FF7994DC-0438-41F8-9CA1-29D6B0539EF1}_is1"

Name "$(AppTitle)"
OutFile "${OUTDIR}\${PLUGIN_NAME}-${VERSION}-windows-x64-setup.exe"
; $INSTDIR = C:\ProgramData\obs-studio\plugins\${PLUGIN_NAME} (se fija en .onInit)
InstallDir "$PROGRAMFILES64\obs-studio\plugins\${PLUGIN_NAME}"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
BrandingText "${APPNAME} ${VERSION}"
ShowInstDetails show
ShowUninstDetails show

; ---------- Interfaz ----------
!define MUI_ICON   "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "$(WelcomeTitle)"
!define MUI_WELCOMEPAGE_TEXT  "$(WelcomeText)"
!define MUI_FINISHPAGE_TITLE  "$(FinishTitle)"
!define MUI_FINISHPAGE_TEXT   "$(FinishText)"
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "$(RunObs)"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchObs

; Selector de idioma: se muestra siempre (preselecciona el de la
; instalación anterior o el de Windows) y se recuerda en el registro
; para que el desinstalador use el mismo.
!define MUI_LANGDLL_ALWAYSSHOW
!define MUI_LANGDLL_REGISTRY_ROOT      HKLM
!define MUI_LANGDLL_REGISTRY_KEY       "${UNINSTKEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "InstallerLanguage"
!define MUI_LANGDLL_WINDOWTITLE "Logo Sequencer"
!define MUI_LANGDLL_INFO "Select the language / Selecciona el idioma:"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_RESERVEFILE_LANGDLL

; ---------- Textos (English / Español) ----------
LangString AppTitle ${LANG_ENGLISH} "${APPNAME} for OBS"
LangString AppTitle ${LANG_SPANISH} "${APPNAME} para OBS"

LangString WelcomeTitle ${LANG_ENGLISH} "Install ${APPNAME} for OBS"
LangString WelcomeTitle ${LANG_SPANISH} "Instalar ${APPNAME} para OBS"

LangString WelcomeText ${LANG_ENGLISH} "This wizard will install the ${APPNAME} ${VERSION} plugin into OBS Studio:$\r$\n$\r$\n  •  $\"Logo Sequencer$\" dock (Docks menu)$\r$\n  •  Tools > Logo Sequencer: create / update overlay$\r$\n  •  Hotkeys in Settings > Hotkeys (Start, Pause, Next, Previous, Stop)$\r$\n$\r$\nRequires OBS Studio 31 or later (64-bit). Close OBS before continuing."
LangString WelcomeText ${LANG_SPANISH} "Este asistente instalará el plugin ${APPNAME} ${VERSION} en OBS Studio:$\r$\n$\r$\n  •  Dock $\"Logo Sequencer$\" (menú Docks)$\r$\n  •  Herramientas > Logo Sequencer: crear / actualizar overlay$\r$\n  •  Atajos de teclado en Ajustes > Atajos (Iniciar, Pausar, Siguiente, Anterior, Detener)$\r$\n$\r$\nRequiere OBS Studio 31 o superior (64 bits). Cierra OBS antes de continuar."

LangString FinishTitle ${LANG_ENGLISH} "Installation complete"
LangString FinishTitle ${LANG_SPANISH} "Instalación completada"

LangString FinishText ${LANG_ENGLISH} "1. Open OBS Studio.$\r$\n2. Tools > WebSocket Server Settings > Enable (if it isn't already).$\r$\n3. Docks menu > check $\"Logo Sequencer$\".$\r$\n4. Tools > Logo Sequencer: create / update overlay.$\r$\n5. Load your logos in the dock and press Start."
LangString FinishText ${LANG_SPANISH} "1. Abre OBS Studio.$\r$\n2. Herramientas > Ajustes del servidor WebSocket > Activar (si no lo está).$\r$\n3. Menú Docks > marca $\"Logo Sequencer$\".$\r$\n4. Herramientas > Logo Sequencer: crear / actualizar overlay.$\r$\n5. Carga los logos en el dock y pulsa Iniciar."

LangString RunObs ${LANG_ENGLISH} "Open OBS Studio now"
LangString RunObs ${LANG_SPANISH} "Abrir OBS Studio ahora"

LangString ObsOpen ${LANG_ENGLISH} "OBS Studio is running.$\r$\n$\r$\nClose it and press Retry."
LangString ObsOpen ${LANG_SPANISH} "OBS Studio está abierto.$\r$\n$\r$\nCiérralo y pulsa Reintentar."

LangString Need64 ${LANG_ENGLISH} "This plugin requires 64-bit Windows."
LangString Need64 ${LANG_SPANISH} "Este plugin requiere Windows de 64 bits."

LangString ObsNotFound ${LANG_ENGLISH} "OBS Studio could not be found automatically. Open it from the Start menu."
LangString ObsNotFound ${LANG_SPANISH} "No se encontró OBS Studio automáticamente. Ábrelo desde el menú Inicio."

LangString RemovingOld ${LANG_ENGLISH} "Removing the previous installer's entry..."
LangString RemovingOld ${LANG_SPANISH} "Quitando la entrada del instalador anterior..."

LangString RegDisplayName ${LANG_ENGLISH} "${APPNAME} (OBS plugin)"
LangString RegDisplayName ${LANG_SPANISH} "${APPNAME} (plugin de OBS)"

LangString Uninstalled ${LANG_ENGLISH} "${APPNAME} was uninstalled.$\r$\n$\r$\nIf you added the $\"Overlay Logos$\" source to your scenes, delete it in OBS (right-click > Remove)."
LangString Uninstalled ${LANG_SPANISH} "${APPNAME} se desinstaló.$\r$\n$\r$\nSi agregaste la fuente $\"Overlay Logos$\" a tus escenas, bórrala desde OBS (clic derecho > Eliminar)."

; ---------- Información de versión del .exe ----------
VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName"     "${APPNAME} for OBS"
VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName"     "${PUBLISHER}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "${APPNAME} plugin installer for OBS Studio"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion"     "${VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductVersion"  "${VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright"  "GPL-2.0"
VIAddVersionKey /LANG=${LANG_SPANISH} "ProductName"     "${APPNAME} para OBS"
VIAddVersionKey /LANG=${LANG_SPANISH} "CompanyName"     "${PUBLISHER}"
VIAddVersionKey /LANG=${LANG_SPANISH} "FileDescription" "Instalador del plugin ${APPNAME} para OBS Studio"
VIAddVersionKey /LANG=${LANG_SPANISH} "FileVersion"     "${VERSION}"
VIAddVersionKey /LANG=${LANG_SPANISH} "ProductVersion"  "${VERSION}"
VIAddVersionKey /LANG=${LANG_SPANISH} "LegalCopyright"  "GPL-2.0"

; ---------- OBS debe estar cerrado (el .dll queda bloqueado si está abierto) ----------
!macro CHECK_OBS_CLOSED
  check_obs:
    nsExec::ExecToStack `cmd /c tasklist /NH /FI "IMAGENAME eq obs64.exe" | find /I "obs64.exe"`
    Pop $0
    Pop $1
    ${If} $0 == 0
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$(ObsOpen)" IDRETRY check_obs
      Quit
    ${EndIf}
!macroend

Function .onInit
  SetRegView 64
  ; Primero el idioma: los mensajes siguientes ya salen traducidos
  !insertmacro MUI_LANGDLL_DISPLAY
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "$(Need64)"
    Quit
  ${EndIf}
  ; Carpeta de plugins de OBS 28+ para todos los usuarios: C:\ProgramData\obs-studio\plugins
  SetShellVarContext all
  StrCpy $INSTDIR "$APPDATA\obs-studio\plugins\${PLUGIN_NAME}"
  !insertmacro CHECK_OBS_CLOSED
FunctionEnd

Function un.onInit
  SetRegView 64
  !insertmacro MUI_UNGETLANGUAGE
  SetShellVarContext all
  !insertmacro CHECK_OBS_CLOSED
FunctionEnd

Function LaunchObs
  ReadRegStr $0 HKLM "SOFTWARE\OBS Studio" ""
  ${If} ${FileExists} "$0\bin\64bit\obs64.exe"
    SetOutPath "$0\bin\64bit"
    Exec `"$0\bin\64bit\obs64.exe"`
  ${Else}
    MessageBox MB_OK|MB_ICONINFORMATION "$(ObsNotFound)"
  ${EndIf}
FunctionEnd

; ---------- Instalación ----------
Section "Install"
  ; Instalación previa hecha con el instalador de Inno Setup (misma carpeta):
  ; se quitan su desinstalador y su entrada para no tener dos en "Aplicaciones".
  ReadRegStr $2 HKLM "${INNOKEY}" "UninstallString"
  ${If} $2 != ""
    DetailPrint "$(RemovingOld)"
    Delete "$INSTDIR\unins000.exe"
    Delete "$INSTDIR\unins000.dat"
    DeleteRegKey HKLM "${INNOKEY}"
  ${EndIf}

  ; Restos de una versión anterior (archivos que ya no existan en esta)
  RMDir /r "$INSTDIR\bin"
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\Desinstalar.exe"   ; nombre del desinstalador en la versión 1.1.0

  SetOutPath "$INSTDIR\bin\64bit"
  File "${RUNDIR}\${PLUGIN_NAME}.dll"
  File /nonfatal "${RUNDIR}\${PLUGIN_NAME}.pdb"

  SetOutPath "$INSTDIR\data"
  File /r "${RUNDIR}\${PLUGIN_NAME}\*.*"

  ; Idioma del plugin (lo lee el .dll al cargar OBS)
  FileOpen $3 "$INSTDIR\data\language.txt" w
  ${If} $LANGUAGE == ${LANG_SPANISH}
    FileWrite $3 "es"
  ${Else}
    FileWrite $3 "en"
  ${EndIf}
  FileClose $3

  SetOutPath "$INSTDIR"
  File "icon.ico"
  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; Entrada en "Aplicaciones instaladas"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayName"     "$(RegDisplayName)"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayVersion"  "${VERSION}"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayIcon"     "$INSTDIR\icon.ico"
  WriteRegStr   HKLM "${UNINSTKEY}" "Publisher"       "${PUBLISHER}"
  WriteRegStr   HKLM "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${UNINSTKEY}" "UninstallString" `"$INSTDIR\uninstall.exe"`
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "EstimatedSize" 2400
SectionEnd

; ---------- Desinstalación ----------
Section "Uninstall"
  RMDir /r "$INSTDIR\bin"
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\icon.ico"
  Delete "$INSTDIR\uninstall.exe"
  Delete "$INSTDIR\Desinstalar.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKLM "${UNINSTKEY}"
  MessageBox MB_OK|MB_ICONINFORMATION "$(Uninstalled)"
SectionEnd
