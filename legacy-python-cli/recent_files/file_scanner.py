"""Durchsucht den Verzeichnisbaum nach kuerzlich bearbeiteten Dateien.

Ausgewertet werden ausschliesslich Dateien. Das massgebliche Datum je Datei ist
das neuere aus Erstell- und Aenderungsdatum. Versteckte Objekte sowie bekannte
Junk-Dateien/-Ordner werden ausgeschlossen; Symlinks werden nicht verfolgt.
"""

from __future__ import annotations

import logging
import os
import stat as stat_module
from dataclasses import dataclass
from datetime import datetime, timedelta
from fnmatch import fnmatch
from pathlib import Path
from typing import Iterator

from recent_files.configuration import Configuration

logger = logging.getLogger(__name__)

# Windows-Attribut fuer versteckte Dateien; auf anderen Systemen nicht vorhanden.
_FILE_ATTRIBUTE_HIDDEN = getattr(stat_module, "FILE_ATTRIBUTE_HIDDEN", 0x2)


@dataclass(frozen=True)
class RelevantFile:
    """Eine im Zeitraum liegende Datei samt ihrem beinhaltenden Ordner."""

    path: Path
    folder: Path
    timestamp: datetime


def effective_timestamp(stat_result: os.stat_result) -> datetime:
    """Ermittelt das neuere aus Erstell- und Aenderungsdatum.

    Das Erstelldatum ist betriebssystemabhaengig: macOS nutzt ``st_birthtime``,
    Windows ``st_ctime``. Fehlt ``st_birthtime``, dient ``st_ctime`` als Ersatz.
    """
    created = getattr(stat_result, "st_birthtime", stat_result.st_ctime)
    modified = stat_result.st_mtime
    return datetime.fromtimestamp(max(created, modified))


def is_hidden(name: str, stat_result: os.stat_result | None = None) -> bool:
    """Prueft, ob ein Eintrag versteckt ist (Dotfile oder Windows-Attribut)."""
    if name.startswith("."):
        return True
    attributes = getattr(stat_result, "st_file_attributes", 0) if stat_result else 0
    return bool(attributes & _FILE_ATTRIBUTE_HIDDEN)


def is_excluded_file(name: str, excluded_files: frozenset[str]) -> bool:
    """Prueft einen Dateinamen gegen die Ausschlussmuster (inkl. Glob wie ``~$*``)."""
    return any(fnmatch(name, pattern) for pattern in excluded_files)


def matches_extension_filter(name: str, extension_filters: frozenset[str]) -> bool:
    """Prueft, ob die Endung einer Datei einem der Filter-Muster entspricht.

    Ist kein Filter gesetzt, gilt jede Datei als passend. Andernfalls wird die
    Endung (klein, ohne Punkt) per Glob gegen die Muster geprueft (``xls*`` passt
    auf ``xls`` und ``xlsx``).
    """
    if not extension_filters:
        return True
    extension = Path(name).suffix.lower().lstrip(".")
    return any(fnmatch(extension, pattern) for pattern in extension_filters)


def find_relevant_files(config: Configuration) -> Iterator[RelevantFile]:
    """Liefert alle Dateien im Wurzelbaum, deren Datum im Zeitraum liegt.

    Ausgeschlossene Ordner werden vor dem Abstieg entfernt. Nicht lesbare
    Eintraege werden uebersprungen und protokolliert; Symlinks werden nicht
    verfolgt.
    """
    cutoff = datetime.now() - timedelta(days=config.days)

    for current_dir, dir_names, file_names in os.walk(config.root_path, topdown=True):
        current_path = Path(current_dir)

        # Ausgeschlossene und versteckte Unterordner nicht betreten.
        dir_names[:] = [
            name
            for name in dir_names
            if name not in config.excluded_folders and not is_hidden(name)
        ]

        for file_name in file_names:
            if is_hidden(file_name) or is_excluded_file(file_name, config.excluded_files):
                continue
            if not matches_extension_filter(file_name, config.extension_filters):
                continue

            file_path = current_path / file_name
            if file_path.is_symlink():
                continue

            try:
                stat_result = file_path.stat()
            except OSError as error:
                logger.warning("Datei uebersprungen (%s): %s", file_path, error)
                continue

            timestamp = effective_timestamp(stat_result)
            if timestamp >= cutoff:
                yield RelevantFile(
                    path=file_path,
                    folder=current_path,
                    timestamp=timestamp,
                )


def list_directory_files(folder: Path, excluded_files: frozenset[str]) -> list[RelevantFile]:
    """Listet alle Dateien direkt im Ordner - ohne Zeitraum- oder Endungsfilter.

    Gedacht fuer die aufklappbare Detailansicht: es werden auch aeltere Dateien
    angezeigt. Versteckte Objekte und bekannte Junk-Dateien werden ausgelassen,
    Symlinks nicht verfolgt. Ergebnis nach Datum absteigend (juengste zuerst,
    bei Gleichstand alphabetisch).
    """
    files: list[RelevantFile] = []
    try:
        with os.scandir(folder) as iterator:
            for dir_entry in iterator:
                name = dir_entry.name
                if is_hidden(name) or is_excluded_file(name, excluded_files):
                    continue
                try:
                    if dir_entry.is_symlink() or not dir_entry.is_file():
                        continue
                    stat_result = dir_entry.stat()
                except OSError as error:
                    logger.warning("Datei uebersprungen (%s): %s", name, error)
                    continue
                files.append(
                    RelevantFile(
                        path=Path(dir_entry.path),
                        folder=folder,
                        timestamp=effective_timestamp(stat_result),
                    )
                )
    except OSError as error:
        logger.warning("Ordner nicht lesbar (%s): %s", folder, error)
        return []

    files.sort(key=lambda relevant_file: relevant_file.path.name.lower())
    files.sort(key=lambda relevant_file: relevant_file.timestamp, reverse=True)
    return files
