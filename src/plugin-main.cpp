/*
Logo Sequencer — plugin nativo para OBS Studio
Copyright (C) 2026 KaguroDev

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>
*/

/* ===========================================================================
 * Qué hace este plugin
 * ---------------------------------------------------------------------------
 * 1. Añade el dock "Logo Sequencer" al menú Docks de OBS. El dock es un panel
 *    de navegador (el mismo motor CEF de obs-browser) que carga
 *    data/Control_logo.html, incluido en el plugin.
 * 2. Añade "Logo Sequencer: crear / actualizar overlay" al menú Herramientas.
 *    Actualiza la URL de todas las fuentes del overlay y, si la escena actual
 *    (en Modo Estudio, la de vista previa) no tiene una, la crea ahí.
 *    Cada escena tiene su propia fuente con ?scene=<escena> en la URL, para
 *    que el overlay use la posición configurada para esa escena en el dock.
 * 3. Registra atajos de teclado (Ajustes → Atajos): Iniciar, Pausar,
 *    Iniciar/Pausar, Siguiente, Anterior, Detener. Van directo a la fuente
 *    del overlay con el procedimiento "javascript_event" de obs-browser.
 * 4. Lee el puerto y la contraseña del servidor WebSocket de OBS desde su
 *    archivo de configuración y los pasa por URL al dock y al overlay, así
 *    no hay que escribirlos a mano. El dock y el overlay siguen hablando
 *    entre sí por OBS WebSocket (BroadcastCustomEvent), por lo que el
 *    servidor WebSocket debe estar activado en
 *    Herramientas → Ajustes del servidor WebSocket.
 * ======================================================================== */

#include <obs-module.h>
#include <obs.hpp>
#include <obs-frontend-api.h>
#include <util/platform.h>
#include <util/util.hpp>
#include <plugin-support.h>

#include <QAction>
#include <QLabel>
#include <QMainWindow>
#include <QMessageBox>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QUrlQuery>

#include <string>
#include <vector>

#include "browser-panel.hpp"

OBS_DECLARE_MODULE()

/* ---------------------------------------------------------------------------
 * Idioma del plugin ("en" o "es")
 *   1. data/language.txt — lo escribe el instalador con el idioma elegido.
 *   2. Si no existe (p. ej. compilación de desarrollo): el idioma de OBS.
 * Los textos nativos salen de data/locale/en-US.ini y es-ES.ini; las páginas
 * del dock y del overlay reciben el idioma en la URL (?lang=en|es).
 * Equivale a OBS_MODULE_USE_DEFAULT_LOCALE, pero con el idioma elegido.
 * ------------------------------------------------------------------------ */
static lookup_t *obs_module_lookup = nullptr;
static std::string plugin_lang = "en";

static std::string detect_plugin_lang(const char *obs_locale)
{
	BPtr<char> path = obs_module_file("language.txt");
	if (path) {
		BPtr<char> text = os_quick_read_utf8_file(path);
		if (text) {
			std::string value(text.Get());
			size_t start = value.find_first_not_of(" \t\r\n\xEF\xBB\xBF");
			if (start != std::string::npos) {
				if (value.compare(start, 2, "es") == 0)
					return "es";
				if (value.compare(start, 2, "en") == 0)
					return "en";
			}
		}
	}
	return (obs_locale && strncmp(obs_locale, "es", 2) == 0) ? "es" : "en";
}

const char *obs_module_text(const char *val)
{
	const char *out = val;
	text_lookup_getstr(obs_module_lookup, val, &out);
	return out;
}

bool obs_module_get_string(const char *val, const char **out)
{
	return text_lookup_getstr(obs_module_lookup, val, out);
}

void obs_module_set_locale(const char *locale)
{
	plugin_lang = detect_plugin_lang(locale);
	if (obs_module_lookup)
		text_lookup_destroy(obs_module_lookup);
	obs_module_lookup = obs_module_load_locale(obs_current_module(), "en-US",
						   plugin_lang == "es" ? "es-ES" : "en-US");
}

void obs_module_free_locale(void)
{
	text_lookup_destroy(obs_module_lookup);
	obs_module_lookup = nullptr;
}

namespace {

/* Texto traducido como QString */
QString tr_text(const char *key)
{
	return QString::fromUtf8(obs_module_text(key));
}

const char *DOCK_ID = "logo-sequencer-dock";
const char *OVERLAY_FILE = "Overlay_logo.html";
const char *CONTROL_FILE = "Control_logo.html";
const char *OVERLAY_SOURCE_NAME = "Overlay Logos";
const char *JS_EVENT_NAME = "logoseq"; /* evento window que escucha el overlay */
const char *CHANNEL = "default";
const char *SAVE_KEY = "logo-sequencer";

struct HotkeyDef {
	const char *id;
	const char *label;
	const char *command;
	obs_hotkey_id hotkey;
};

HotkeyDef hotkeys[] = {
	/* label = clave en data/locale/*.ini */
	{"logoseq_play", "Hotkey.Play", "play", OBS_INVALID_HOTKEY_ID},
	{"logoseq_pause", "Hotkey.Pause", "pause", OBS_INVALID_HOTKEY_ID},
	{"logoseq_toggle", "Hotkey.Toggle", "toggle", OBS_INVALID_HOTKEY_ID},
	{"logoseq_next", "Hotkey.Next", "next", OBS_INVALID_HOTKEY_ID},
	{"logoseq_prev", "Hotkey.Prev", "prev", OBS_INVALID_HOTKEY_ID},
	{"logoseq_stop", "Hotkey.Stop", "stop", OBS_INVALID_HOTKEY_ID},
};

QCef *cef = nullptr;
bool dock_added = false;

/* ---------------------------------------------------------------------------
 * Configuración del servidor WebSocket de OBS
 * Se guarda en  <config de OBS>/plugin_config/obs-websocket/config.json
 * ------------------------------------------------------------------------ */
struct WebSocketConfig {
	bool found = false;
	bool enabled = false;
	int port = 4455;
	std::string password; /* vacío si la autenticación está desactivada */
};

WebSocketConfig read_websocket_config()
{
	WebSocketConfig cfg;
	/* obs_module_config_path da .../plugin_config/<este plugin>/...;
	 * subimos un nivel para llegar a la carpeta de obs-websocket. */
	BPtr<char> path = obs_module_config_path("../obs-websocket/config.json");
	if (!path || !os_file_exists(path))
		return cfg;

	OBSDataAutoRelease data = obs_data_create_from_json_file(path);
	if (!data)
		return cfg;

	cfg.found = true;
	cfg.enabled = obs_data_get_bool(data, "server_enabled");
	if (obs_data_has_user_value(data, "server_port"))
		cfg.port = (int)obs_data_get_int(data, "server_port");
	if (obs_data_get_bool(data, "auth_required"))
		cfg.password = obs_data_get_string(data, "server_password");
	return cfg;
}

/* Codifica un valor de la query para que URLSearchParams lo lea igual
 * (sin '+' ni '&' literales). */
QString encode_query_value(const QString &value)
{
	return QString::fromUtf8(QUrl::toPercentEncoding(value));
}

/* URL file:///…/data/<archivo>?host=…&port=…&password=…&channel=…[&scene=…] */
std::string build_page_url(const char *file, const QString &scene = QString())
{
	BPtr<char> path = obs_module_file(file);
	if (!path) {
		obs_log(LOG_ERROR, "no se encontró %s en la carpeta data del plugin", file);
		return {};
	}

	WebSocketConfig ws = read_websocket_config();

	QUrl url = QUrl::fromLocalFile(QString::fromUtf8(path.Get()));
	QUrlQuery query;
	query.addQueryItem("host", "127.0.0.1");
	query.addQueryItem("port", QString::number(ws.port));
	query.addQueryItem("channel", CHANNEL);
	query.addQueryItem("lang", QString::fromStdString(plugin_lang));
	if (!ws.password.empty())
		query.addQueryItem("password", encode_query_value(QString::fromStdString(ws.password)));
	if (!scene.isEmpty())
		query.addQueryItem("scene", encode_query_value(scene));
	url.setQuery(query);
	return url.toString(QUrl::FullyEncoded).toStdString();
}

/* ---------------------------------------------------------------------------
 * Fuente del overlay
 * ------------------------------------------------------------------------ */
bool is_overlay_source(obs_source_t *source)
{
	if (strcmp(obs_source_get_unversioned_id(source), "browser_source") != 0)
		return false;
	OBSDataAutoRelease settings = obs_source_get_settings(source);
	std::string where = std::string(obs_data_get_string(settings, "url")) + " " +
			    obs_data_get_string(settings, "local_file");
	return where.find(OVERLAY_FILE) != std::string::npos;
}

/* Valor de ?scene= en la URL actual de la fuente (lo pone el dock al
 * añadir el overlay a una escena). Se decodifica como URLSearchParams. */
QString overlay_scene_param(obs_source_t *source)
{
	OBSDataAutoRelease settings = obs_source_get_settings(source);
	QString url = QString::fromUtf8(obs_data_get_string(settings, "url"));
	int q = url.indexOf('?');
	if (q < 0)
		return {};
	const QStringList pairs = url.mid(q + 1).section('#', 0, 0).split('&');
	for (const QString &pair : pairs) {
		if (pair.section('=', 0, 0) != "scene")
			continue;
		QString raw = pair.section('=', 1);
		raw.replace('+', ' ');
		return QUrl::fromPercentEncoding(raw.toUtf8());
	}
	return {};
}

/* ¿La escena ya contiene alguna fuente del overlay? */
bool scene_has_overlay(obs_scene_t *scene)
{
	bool found = false;
	obs_scene_enum_items(
		scene,
		[](obs_scene_t *, obs_sceneitem_t *item, void *param) {
			if (is_overlay_source(obs_sceneitem_get_source(item))) {
				*static_cast<bool *>(param) = true;
				return false;
			}
			return true;
		},
		&found);
	return found;
}

/* Devuelve todas las fuentes de navegador que cargan Overlay_logo.html
 * (cada una con una referencia que el llamador debe liberar). */
std::vector<obs_source_t *> find_overlay_sources()
{
	std::vector<obs_source_t *> result;
	obs_enum_sources(
		[](void *param, obs_source_t *source) {
			auto *list = static_cast<std::vector<obs_source_t *> *>(param);
			if (is_overlay_source(source)) {
				obs_source_t *ref = obs_source_get_ref(source);
				if (ref)
					list->push_back(ref);
			}
			return true;
		},
		&result);
	return result;
}

/* Envía un comando al overlay sin pasar por WebSocket: obs-browser dispara en
 * la página  window.dispatchEvent(new CustomEvent("logoseq", {detail: …})) */
void send_command(const char *command)
{
	std::string json = std::string("{\"type\":\"") + command + "\",\"channel\":\"" + CHANNEL + "\"}";
	auto sources = find_overlay_sources();
	if (sources.empty())
		obs_log(LOG_WARNING, "no hay fuente de overlay; usa Herramientas -> Logo Sequencer");

	for (obs_source_t *source : sources) {
		proc_handler_t *ph = obs_source_get_proc_handler(source);
		calldata_t cd = {};
		calldata_set_string(&cd, "eventName", JS_EVENT_NAME);
		calldata_set_string(&cd, "jsonString", json.c_str());
		proc_handler_call(ph, "javascript_event", &cd);
		calldata_free(&cd);
		obs_source_release(source);
	}
}

/* Actualiza la URL de todas las fuentes del overlay (conservando su ?scene=)
 * y, si se pide, crea una en la escena actual cuando esta no tiene ninguna.
 * Devuelve un texto para mostrar al usuario. */
QString install_overlay(bool create_if_missing)
{
	if (build_page_url(OVERLAY_FILE).empty())
		return tr_text("Overlay.FileMissing").arg(OVERLAY_FILE);

	QStringList messages;
	auto sources = find_overlay_sources();
	if (!sources.empty()) {
		QStringList names;
		for (obs_source_t *source : sources) {
			std::string url = build_page_url(OVERLAY_FILE, overlay_scene_param(source));
			OBSDataAutoRelease settings = obs_data_create();
			obs_data_set_bool(settings, "is_local_file", false); /* modo URL: admite ?parámetros e imágenes file:/// */
			obs_data_set_string(settings, "url", url.c_str());
			obs_source_update(source, settings);
			names << QString::fromUtf8(obs_source_get_name(source));
			obs_source_release(source);
		}
		messages << tr_text("Overlay.Updated").arg(names.join(", "));
	}
	if (!create_if_missing)
		return messages.join("\n");

	OBSSourceAutoRelease scene_source = obs_frontend_preview_program_mode_active()
						    ? obs_frontend_get_current_preview_scene()
						    : obs_frontend_get_current_scene();
	obs_scene_t *scene = obs_scene_from_source(scene_source);
	if (!scene) {
		messages << tr_text("Overlay.NoScene");
		return messages.join("\n");
	}
	QString scene_name = QString::fromUtf8(obs_source_get_name(scene_source));
	if (scene_has_overlay(scene)) {
		messages << tr_text("Overlay.AlreadyInScene").arg(scene_name);
		return messages.join("\n");
	}

	std::string url = build_page_url(OVERLAY_FILE, scene_name);
	OBSDataAutoRelease settings = obs_data_create();
	obs_data_set_bool(settings, "is_local_file", false);
	obs_data_set_string(settings, "url", url.c_str());
	obs_video_info ovi = {};
	if (obs_get_video_info(&ovi)) { /* tamaño = lienzo base */
		obs_data_set_int(settings, "width", ovi.base_width);
		obs_data_set_int(settings, "height", ovi.base_height);
	}

	/* Nombre único: "Overlay Logos (Escena)", "Overlay Logos (Escena) 2"… */
	QString base = QString("%1 (%2)").arg(OVERLAY_SOURCE_NAME, scene_name);
	QString name = base;
	for (int n = 2;; n++) {
		OBSSourceAutoRelease existing = obs_get_source_by_name(name.toUtf8().constData());
		if (!existing)
			break;
		name = QString("%1 %2").arg(base).arg(n);
	}

	OBSSourceAutoRelease source = obs_source_create("browser_source", name.toUtf8().constData(), settings, nullptr);
	if (!source) {
		messages << tr_text("Overlay.CreateFailed");
		return messages.join("\n");
	}
	obs_scene_add(scene, source);
	messages << tr_text("Overlay.Created").arg(name, scene_name);
	return messages.join("\n");
}

/* ---------------------------------------------------------------------------
 * Dock
 * ------------------------------------------------------------------------ */
void add_dock()
{
	if (dock_added)
		return;

	auto *main_window = static_cast<QMainWindow *>(obs_frontend_get_main_window());
	QWidget *widget = nullptr;

	std::string url = build_page_url(CONTROL_FILE);
	cef = obs_browser_init_panel();
	if (cef && !url.empty()) {
		cef->init_browser();
		cef->wait_for_browser_init();
		widget = cef->create_widget(main_window, url);
	}
	if (!widget) {
		/* obs-browser no está disponible (o Wayland): se muestra un aviso en el dock */
		auto *label = new QLabel(tr_text("Dock.NoBrowser"), main_window);
		label->setAlignment(Qt::AlignCenter);
		label->setWordWrap(true);
		widget = label;
		obs_log(LOG_WARNING, "no se pudo crear el panel de navegador para el dock");
	}

	widget->setMinimumSize(280, 200);
	dock_added = obs_frontend_add_dock_by_id(DOCK_ID, "Logo Sequencer", widget);
	if (!dock_added)
		obs_log(LOG_ERROR, "no se pudo registrar el dock");
}

/* ---------------------------------------------------------------------------
 * Eventos del frontend y guardado de atajos
 * ------------------------------------------------------------------------ */
void on_frontend_event(enum obs_frontend_event event, void *)
{
	if (event == OBS_FRONTEND_EVENT_FINISHED_LOADING) {
		WebSocketConfig ws = read_websocket_config();
		if (!ws.found || !ws.enabled)
			obs_log(LOG_WARNING, "el servidor WebSocket de OBS está desactivado: actívalo en "
					     "Herramientas -> Ajustes del servidor WebSocket");
		add_dock();
		/* Por si cambió el puerto o la contraseña desde la última vez */
		install_overlay(false);
	}
}

void on_frontend_save(obs_data_t *save_data, bool saving, void *)
{
	if (saving) {
		OBSDataAutoRelease obj = obs_data_create();
		for (HotkeyDef &hk : hotkeys) {
			OBSDataArrayAutoRelease arr = obs_hotkey_save(hk.hotkey);
			obs_data_set_array(obj, hk.id, arr);
		}
		obs_data_set_obj(save_data, SAVE_KEY, obj);
	} else {
		OBSDataAutoRelease obj = obs_data_get_obj(save_data, SAVE_KEY);
		if (!obj)
			return;
		for (HotkeyDef &hk : hotkeys) {
			OBSDataArrayAutoRelease arr = obs_data_get_array(obj, hk.id);
			obs_hotkey_load(hk.hotkey, arr);
		}
	}
}

} // namespace

bool obs_module_load(void)
{
	for (HotkeyDef &hk : hotkeys) {
		hk.hotkey = obs_hotkey_register_frontend(
			hk.id, obs_module_text(hk.label),
			[](void *data, obs_hotkey_id, obs_hotkey_t *, bool pressed) {
				if (pressed)
					send_command(static_cast<const char *>(data));
			},
			const_cast<char *>(hk.command));
	}

	obs_frontend_add_event_callback(on_frontend_event, nullptr);
	obs_frontend_add_save_callback(on_frontend_save, nullptr);

	auto *action = static_cast<QAction *>(
		obs_frontend_add_tools_menu_qaction(obs_module_text("Menu.CreateOverlay")));
	QObject::connect(action, &QAction::triggered, []() {
		QString message = install_overlay(true);
		QMessageBox::information(static_cast<QWidget *>(obs_frontend_get_main_window()), "Logo Sequencer",
					 message);
	});

	obs_log(LOG_INFO, "plugin cargado (versión %s, idioma %s)", PLUGIN_VERSION, plugin_lang.c_str());
	return true;
}

void obs_module_unload(void)
{
	obs_frontend_remove_event_callback(on_frontend_event, nullptr);
	obs_frontend_remove_save_callback(on_frontend_save, nullptr);
	for (HotkeyDef &hk : hotkeys)
		obs_hotkey_unregister(hk.hotkey);
	obs_log(LOG_INFO, "plugin descargado");
}

const char *obs_module_name(void)
{
	return "Logo Sequencer";
}

const char *obs_module_description(void)
{
	return obs_module_text("Description");
}
