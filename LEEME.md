# Logo Sequencer — plugin nativo para OBS Studio

Proyecto basado en la plantilla oficial `obs-plugintemplate` (licencia GPL-2.0).

## Qué hace

- Añade el dock **Logo Sequencer** al menú *Docks* (carga `data/Control_logo.html`).
- Añade **Herramientas → Logo Sequencer: crear / actualizar overlay**, que actualiza
  las fuentes del overlay y, si la escena actual no tiene una, la crea ahí.
- El overlay puede estar en **varias escenas**, cada una con sus propios logos y su
  propia posición y tamaño (por ejemplo, arriba a la derecha en una y abajo a la
  izquierda en otra).
- Registra atajos en *Ajustes → Atajos*: Iniciar, Pausar, Iniciar/Pausar,
  Siguiente, Anterior, Detener.
- Lee el puerto y la contraseña del servidor WebSocket de OBS y se los pasa al
  dock y al overlay: no hay que escribirlos.

Requisito en OBS: **Herramientas → Ajustes del servidor WebSocket → Activar servidor WebSocket**.

## Archivos propios (el resto es la plantilla)

| Archivo | Contenido |
|---|---|
| `src/plugin-main.cpp` | Todo el código del plugin |
| `src/browser-panel.hpp` | Cabecera de obs-browser para crear paneles de navegador (sin cambios) |
| `data/Control_logo.html` | Panel de control |
| `data/Overlay_logo.html` | Overlay |
| `installer/logo-sequencer.nsi` | Script del instalador `.exe` (NSIS) |
| `installer/icon.ico` | Icono del instalador |
| `installer/build-installer.ps1` | Compila y genera el instalador en un paso |
| `buildspec.json` | Nombre, versión y versión de OBS contra la que se compila |

## Compilar en Windows

Necesitas:

- **Visual Studio 2026** (o 2022) con la carga de trabajo **Desarrollo para el escritorio con C++**
  y el **SDK de Windows 10.0.22621** o posterior.
- **CMake 3.28 o posterior** y **Git**, ambos en el PATH.
- **NSIS 3** (https://nsis.sourceforge.io o `winget install NSIS.NSIS`) para generar el
  instalador `.exe`. Instálalo **antes** del primer `cmake --preset`, en su carpeta por defecto.

En PowerShell, en esta carpeta:

```
cmake --preset windows-x64-vs2026
cmake --build --preset windows-x64-vs2026 --target installer
```

(con Visual Studio 2022 usa el preset `windows-x64`). O todo en un paso:

```
powershell -ExecutionPolicy Bypass -File installer\build-installer.ps1
```

El primer `cmake --preset` descarga el código de OBS y sus dependencias (Qt6 incluido) y
compila `libobs`; tarda varios minutos y necesita internet. Solo ocurre la primera vez.

Resultado:

```
release\logo-sequencer-1.1.0-windows-x64-setup.exe
```

### Desde Visual Studio

1. Después del primer comando, abre `build_x64\logo-sequencer.slnx`.
2. Elige la configuración **RelWithDebInfo**.
3. En el *Explorador de soluciones*, carpeta **Packaging**, clic derecho en
   **installer → Compilar** (compila también el `.dll`). El `.exe` queda en `release`.

Si el proyecto **installer** no aparece, CMake no encontró NSIS: instálalo y vuelve a
ejecutar `cmake --preset`.

Si mueves la carpeta del proyecto, borra `build_x64` y `.deps\obs-studio-*\build_x86`
antes de volver a configurar (guardan rutas absolutas).

## Instalar

Ejecuta `logo-sequencer-1.1.0-windows-x64-setup.exe` con OBS cerrado (pide permisos de
administrador; si OBS está abierto, avisa y espera). Copia el plugin a:

```
C:\ProgramData\obs-studio\plugins\logo-sequencer\
    bin\64bit\logo-sequencer.dll
    data\Control_logo.html
    data\Overlay_logo.html
    data\locale\en-US.ini
```

Al actualizar borra los archivos de la versión anterior antes de copiar los nuevos, y
reemplaza la entrada del instalador antiguo (Inno Setup) si existía.
Se desinstala desde *Configuración → Aplicaciones → Logo Sequencer (plugin de OBS)*.

Windows SmartScreen avisa al abrir el `.exe` porque no está firmado:
*Más información → Ejecutar de todas formas*.

Sin instalador: cierra OBS y, en una consola **como administrador**,
`cmake --install build_x64 --config RelWithDebInfo`.

## Usar

1. Abre OBS. En *Docks* marca **Logo Sequencer**.
2. En la sección **Overlay en escenas** del dock, elige una escena y pulsa
   **Agregar overlay**. Repite para cada escena donde quieras los logos.
3. Carga los logos en el dock y pulsa Iniciar.
4. Opcional: asigna teclas en *Ajustes → Atajos* (busca "Logo Sequencer").

### Logos distintos en cada escena

En **Secuencia de fases**, el selector **Logos para** elige qué secuencia se edita:

- **Por defecto**: la usan todas las escenas que tengan marcado *Usar los mismos
  logos que por defecto* (es lo inicial).
- **Una escena**: desmarca *Usar los mismos logos que por defecto* y esa escena pasa
  a tener su propia secuencia (empieza como copia de la por defecto). Añade, quita o
  reordena sus fases sin afectar a las demás. Vuelve a marcar la casilla para
  descartarla y usar otra vez la por defecto.

Iniciar, Pausar, Siguiente, Anterior y Detener (y los atajos) actúan sobre todas las
escenas a la vez. Borrar un logo de la biblioteca lo quita de todas las secuencias.
La barra de arriba del dock muestra el estado del overlay que está en programa.

### Posición distinta en cada escena

En **Tamaño y escala**, el selector **Configurar para** elige qué se edita:

- **Por defecto**: lo usan las escenas que no tienen posición propia.
- **Una escena**: al cambiar cualquier valor (posición, tamaño, escala…) esa escena
  pasa a tener su **posición propia**. Desmarca *Posición y tamaño propios* para
  que vuelva a usar la configuración por defecto.

**Ver en OBS** cambia a esa escena para ver el resultado (en Modo Estudio, en la
vista previa; sin Modo Estudio pide confirmación porque cambia la escena en vivo).
El botón **Configurar** de cada escena en *Overlay en escenas* elige esa escena a la
vez en *Secuencia de fases* y en *Tamaño y escala*.

Cada escena tiene su propia fuente `Overlay Logos (Escena)` con `&scene=Escena` en la
URL. Si renombras una escena, pulsa **Vincular overlay en OBS**: la fuente se asocia
al nuevo nombre y conserva sus logos y su posición.

Si usabas la versión de archivos sueltos, quita el dock de navegador personalizado
antiguo y el script Lua para no tener controles duplicados. La fuente de overlay
antigua se reutiliza: *Vincular overlay en OBS* le cambia la URL y la asocia a la
escena donde está.

## Si algo falla

- *Ayuda → Archivos de registro → Ver el registro actual* y busca `logo-sequencer`.
- "El servidor WebSocket de OBS está desactivado": actívalo y reinicia OBS.
- El dock muestra un aviso sobre obs-browser: falta el plugin de navegador de OBS
  (viene incluido en la instalación normal de Windows).
- Si cambias la contraseña del WebSocket, reinicia OBS: el plugin vuelve a leerla
  y actualiza el dock y el overlay.

## Versión de OBS

`buildspec.json` compila contra OBS 31.1.1. Un plugin compilado así carga también
en OBS 32. Para compilar contra otra versión hay que cambiar la versión y su hash
en `buildspec.json` (ver la plantilla original).
