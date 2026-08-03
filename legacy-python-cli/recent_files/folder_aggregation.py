"""Gruppiert relevante Dateien zu ihren beinhaltenden Ordnern.

Je Ordner werden das neueste Datum seiner relevanten Dateien und deren Anzahl
ermittelt. Das Ergebnis ist nach Datum absteigend sortiert.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Iterable, Mapping

from recent_files.file_scanner import RelevantFile
from recent_files.file_types import category_for


@dataclass(frozen=True)
class FolderEntry:
    """Ein Ordner mit dem neuesten Datum, der Anzahl und den einzelnen Dateien."""

    path: Path
    newest_date: datetime
    file_count: int
    files: tuple[RelevantFile, ...] = ()


@dataclass(frozen=True)
class DayCount:
    """Anzahl bearbeiteter Dateien an einem Kalendertag, aufgeschluesselt nach Typ."""

    day: date
    counts_by_category: Mapping[str, int] = field(default_factory=dict)

    @property
    def total(self) -> int:
        """Gesamtzahl der Dateien des Tages ueber alle Kategorien."""
        return sum(self.counts_by_category.values())


def group_by_folder(files: Iterable[RelevantFile]) -> list[FolderEntry]:
    """Fasst Dateien nach ihrem direkten Elternordner zusammen.

    ``file_count`` und ``newest_date`` beziehen sich auf die *relevanten* Dateien
    (im Zeitraum, gefiltert). Die vollstaendige Dateiliste fuer die Detailansicht
    wird separat ueber :func:`recent_files.file_scanner.list_directory_files`
    ermittelt und nachtraeglich gesetzt.

    Returns:
        Nach ``newest_date`` absteigend sortierte Ordnereintraege; bei gleichem
        Datum sekundaer alphabetisch nach Pfad fuer stabile Ausgabe.
    """
    newest_by_folder: dict[Path, datetime] = {}
    count_by_folder: dict[Path, int] = {}

    for relevant_file in files:
        folder = relevant_file.folder
        count_by_folder[folder] = count_by_folder.get(folder, 0) + 1
        previous = newest_by_folder.get(folder)
        if previous is None or relevant_file.timestamp > previous:
            newest_by_folder[folder] = relevant_file.timestamp

    entries = [
        FolderEntry(
            path=folder,
            newest_date=newest_by_folder[folder],
            file_count=count_by_folder[folder],
        )
        for folder in newest_by_folder
    ]

    entries.sort(key=lambda entry: (entry.newest_date, str(entry.path)), reverse=True)
    return entries


def count_files_per_day(
    files: Iterable[RelevantFile], days: int, reference: datetime | None = None
) -> list[DayCount]:
    """Zaehlt bearbeitete Dateien je Kalendertag, aufgeschluesselt nach Dateityp.

    Der Zeitraum umfasst ``days`` Tage bis einschliesslich heute; Tage ohne
    Dateien werden mit einer leeren Zaehlung aufgefuellt, damit der Verlauf
    luecklos ist. Dateien ausserhalb dieses Fensters werden nicht gezaehlt.

    Args:
        files: Die relevanten Dateien.
        days: Anzahl der Tage des Verlaufs (chronologisch aufsteigend).
        reference: Bezugszeitpunkt (Standard: jetzt) fuer den letzten Tag.

    Returns:
        Chronologisch aufsteigende :class:`DayCount`-Liste der Laenge ``days``.
    """
    end_day = (reference or datetime.now()).date()
    start_day = end_day - timedelta(days=days - 1)

    counts: dict[date, dict[str, int]] = {}
    for relevant_file in files:
        day = relevant_file.timestamp.date()
        if start_day <= day <= end_day:
            category = category_for(relevant_file.path)
            per_category = counts.setdefault(day, {})
            per_category[category] = per_category.get(category, 0) + 1

    result = []
    for offset in range(days):
        day = start_day + timedelta(days=offset)
        result.append(DayCount(day=day, counts_by_category=counts.get(day, {})))
    return result
