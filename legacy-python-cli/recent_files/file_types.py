"""Ordnet Dateien anhand ihrer Endung einer Dateityp-Kategorie zu.

Die Kategorien buendeln viele Endungen zu wenigen, verstaendlichen Gruppen,
damit Diagramm und Legende uebersichtlich bleiben. ``CATEGORY_ORDER`` legt die
Reihenfolge fest (auch fuer Stapelung und Legende); nicht zugeordnete Endungen
fallen unter ``Sonstige``.
"""

from __future__ import annotations

from pathlib import Path

OTHER_CATEGORY = "Sonstige"

CATEGORY_ORDER: tuple[str, ...] = (
    "Dokumente",
    "PDF",
    "Tabellen",
    "Praesentationen",
    "Bilder",
    "Medien",
    "Archive",
    "Code",
    OTHER_CATEGORY,
)

# Endung (ohne Punkt, klein) -> Kategorie.
_EXTENSION_TO_CATEGORY: dict[str, str] = {
    # Dokumente
    "doc": "Dokumente", "docx": "Dokumente", "odt": "Dokumente", "rtf": "Dokumente",
    "txt": "Dokumente", "md": "Dokumente", "pages": "Dokumente",
    # PDF
    "pdf": "PDF",
    # Tabellen
    "xls": "Tabellen", "xlsx": "Tabellen", "ods": "Tabellen", "csv": "Tabellen",
    "numbers": "Tabellen",
    # Praesentationen
    "ppt": "Praesentationen", "pptx": "Praesentationen", "odp": "Praesentationen",
    "key": "Praesentationen",
    # Bilder
    "jpg": "Bilder", "jpeg": "Bilder", "png": "Bilder", "gif": "Bilder",
    "heic": "Bilder", "tiff": "Bilder", "tif": "Bilder", "bmp": "Bilder",
    "svg": "Bilder", "webp": "Bilder",
    # Medien (Audio/Video)
    "mp3": "Medien", "wav": "Medien", "m4a": "Medien", "aac": "Medien",
    "flac": "Medien", "mp4": "Medien", "mov": "Medien", "avi": "Medien",
    "mkv": "Medien", "m4v": "Medien",
    # Archive
    "zip": "Archive", "rar": "Archive", "7z": "Archive", "tar": "Archive",
    "gz": "Archive", "bz2": "Archive",
    # Code
    "py": "Code", "js": "Code", "ts": "Code", "java": "Code", "c": "Code",
    "cpp": "Code", "h": "Code", "hpp": "Code", "cs": "Code", "go": "Code",
    "rb": "Code", "php": "Code", "html": "Code", "css": "Code", "json": "Code",
    "xml": "Code", "yaml": "Code", "yml": "Code", "sh": "Code", "sql": "Code",
}


def category_for(path: Path) -> str:
    """Liefert die Dateityp-Kategorie fuer einen Pfad anhand der Endung."""
    extension = path.suffix.lower().lstrip(".")
    return _EXTENSION_TO_CATEGORY.get(extension, OTHER_CATEGORY)
