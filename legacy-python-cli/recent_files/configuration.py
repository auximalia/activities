"""Laedt und validiert die Konfiguration und ermittelt den Dokumente-Ordner.

Zusammengefuehrt werden die Standardwerte aus ``config/default.json`` und die
optionalen Ueberschreibungen von der Kommandozeile. Ungueltige Werte fuehren zu
einem sofortigen, aussagekraeftigen Fehler (Fail-Fast).
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

# Standard-Konfigurationsdatei relativ zum Projekt-Root (eine Ebene ueber dem Paket).
_DEFAULT_CONFIG_FILE = Path(__file__).resolve().parent.parent / "config" / "default.json"


class ConfigurationError(Exception):
    """Fehler beim Laden oder Validieren der Konfiguration."""


@dataclass(frozen=True)
class Configuration:
    """Vollstaendig aufgeloeste, unveraenderliche Laufzeit-Konfiguration."""

    root_path: Path
    days: int
    excluded_folders: frozenset[str]
    excluded_files: frozenset[str]
    extension_filters: frozenset[str]
    output_path: Path | None
    open_in_browser: bool


def normalize_extension_pattern(pattern: str) -> str:
    """Normalisiert ein Endungs-Muster auf die reine Endung (klein, ohne Punkt).

    Akzeptiert Eingaben wie ``xls``, ``.xls``, ``*.xls`` oder ``xls*`` und liefert
    ein auf die Endung anwendbares Glob-Muster (z. B. ``xls`` bzw. ``xls*``).
    """
    cleaned = pattern.strip().lower()
    if cleaned.startswith("*."):
        cleaned = cleaned[2:]
    return cleaned.lstrip(".")


def default_documents_path() -> Path:
    """Liefert den Dokumente-Ordner des aktuellen Benutzers.

    Der Dateisystemname ist auch bei deutscher Anzeige technisch ``Documents``.
    """
    return Path.home() / "Documents"


def _load_defaults(config_file: Path) -> dict:
    """Liest die JSON-Standardwerte und validiert das Grundschema."""
    try:
        raw = config_file.read_text(encoding="utf-8")
    except FileNotFoundError as error:
        raise ConfigurationError(
            f"Konfigurationsdatei fehlt: {config_file}"
        ) from error

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as error:
        raise ConfigurationError(
            f"Konfigurationsdatei ist kein gueltiges JSON ({config_file}): {error}"
        ) from error

    if not isinstance(data, dict):
        raise ConfigurationError(
            f"Konfiguration muss ein JSON-Objekt sein, gefunden: {type(data).__name__}"
        )
    return data


def _as_string_set(value: object, key: str) -> frozenset[str]:
    """Stellt sicher, dass ein Konfigurationswert eine Liste von Zeichenketten ist."""
    if value is None:
        return frozenset()
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ConfigurationError(
            f"Konfigurationsschluessel '{key}' muss eine Liste von Zeichenketten sein."
        )
    return frozenset(value)


def load_configuration(
    *,
    root_path: Path | None = None,
    days: int | None = None,
    extension_filters: list[str] | None = None,
    output_path: Path | None = None,
    open_in_browser: bool = True,
    config_file: Path | None = None,
) -> Configuration:
    """Fuehrt Standardwerte und Kommandozeilen-Ueberschreibungen zusammen.

    Args:
        root_path: Zu durchsuchender Wurzelordner; ``None`` = Dokumente-Ordner.
        days: Zeitraum in Tagen rueckwaerts; ``None`` = Wert aus der Konfigurationsdatei.
        extension_filters: Optionale Endungs-Muster (z. B. ``["xls*"]``); leer = alle.
        output_path: Zielpfad der HTML-Datei; ``None`` = temporaeres Verzeichnis.
        open_in_browser: Ob der Bericht automatisch geoeffnet wird.
        config_file: Alternative Konfigurationsdatei; ``None`` = Standarddatei.

    Returns:
        Eine validierte, unveraenderliche :class:`Configuration`.

    Raises:
        ConfigurationError: Bei fehlender Datei, ungueltigem Schema, ungueltigem
            Zeitraum oder nicht existierendem Wurzelordner.
    """
    defaults = _load_defaults(config_file or _DEFAULT_CONFIG_FILE)

    resolved_days = days if days is not None else defaults.get("days", 30)
    if not isinstance(resolved_days, int) or isinstance(resolved_days, bool):
        raise ConfigurationError("Zeitraum 'days' muss eine ganze Zahl sein.")
    if resolved_days <= 0:
        raise ConfigurationError(
            f"Zeitraum 'days' muss groesser als 0 sein, erhalten: {resolved_days}."
        )

    resolved_root = (root_path or default_documents_path()).expanduser()
    if not resolved_root.exists():
        raise ConfigurationError(f"Wurzelordner existiert nicht: {resolved_root}")
    if not resolved_root.is_dir():
        raise ConfigurationError(f"Wurzelordner ist kein Verzeichnis: {resolved_root}")

    normalized_filters = frozenset(
        normalize_extension_pattern(pattern)
        for pattern in (extension_filters or [])
        if normalize_extension_pattern(pattern)
    )

    return Configuration(
        root_path=resolved_root.resolve(),
        days=resolved_days,
        excluded_folders=_as_string_set(defaults.get("excluded_folders"), "excluded_folders"),
        excluded_files=_as_string_set(defaults.get("excluded_files"), "excluded_files"),
        extension_filters=normalized_filters,
        output_path=output_path,
        open_in_browser=open_in_browser,
    )
