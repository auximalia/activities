"""Tests fuer die Aggregation relevanter Dateien zu Ordnern."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from recent_files.file_scanner import RelevantFile
from recent_files.folder_aggregation import count_files_per_day, group_by_folder


def _relevant_file(folder: str, name: str, timestamp: datetime) -> RelevantFile:
    folder_path = Path(folder)
    return RelevantFile(path=folder_path / name, folder=folder_path, timestamp=timestamp)


def test_groups_files_by_folder_and_counts() -> None:
    files = [
        _relevant_file("/a", "1.txt", datetime(2026, 1, 1, 10, 0)),
        _relevant_file("/a", "2.txt", datetime(2026, 1, 2, 10, 0)),
        _relevant_file("/b", "3.txt", datetime(2026, 1, 3, 10, 0)),
    ]

    entries = group_by_folder(files)
    by_path = {entry.path: entry for entry in entries}

    assert by_path[Path("/a")].file_count == 2
    assert by_path[Path("/a")].newest_date == datetime(2026, 1, 2, 10, 0)
    assert by_path[Path("/b")].file_count == 1


def test_sorted_by_newest_date_descending() -> None:
    files = [
        _relevant_file("/alt", "x.txt", datetime(2026, 1, 1, 0, 0)),
        _relevant_file("/neu", "y.txt", datetime(2026, 6, 1, 0, 0)),
    ]

    entries = group_by_folder(files)

    assert [entry.path for entry in entries] == [Path("/neu"), Path("/alt")]


def test_empty_input_yields_empty_list() -> None:
    assert group_by_folder([]) == []


def test_count_files_per_day_fills_gaps() -> None:
    reference = datetime(2026, 8, 3, 12, 0)
    files = [
        _relevant_file("/a", "1.txt", datetime(2026, 8, 3, 9, 0)),
        _relevant_file("/a", "2.txt", datetime(2026, 8, 3, 18, 0)),
        _relevant_file("/b", "3.txt", datetime(2026, 8, 1, 10, 0)),
    ]

    result = count_files_per_day(files, days=3, reference=reference)

    assert [dc.total for dc in result] == [1, 0, 2]  # 01.08, 02.08, 03.08
    assert result[0].day.isoformat() == "2026-08-01"
    assert result[-1].day.isoformat() == "2026-08-03"


def test_count_files_per_day_splits_by_category() -> None:
    reference = datetime(2026, 8, 3, 12, 0)
    files = [
        _relevant_file("/a", "brief.docx", datetime(2026, 8, 3, 9, 0)),
        _relevant_file("/a", "foto.jpg", datetime(2026, 8, 3, 10, 0)),
        _relevant_file("/a", "foto2.png", datetime(2026, 8, 3, 11, 0)),
    ]

    result = count_files_per_day(files, days=1, reference=reference)

    assert result[-1].counts_by_category == {"Dokumente": 1, "Bilder": 2}
    assert result[-1].total == 3


def test_count_files_per_day_ignores_outside_window() -> None:
    reference = datetime(2026, 8, 3, 12, 0)
    files = [_relevant_file("/a", "alt.txt", datetime(2026, 7, 1, 9, 0))]

    result = count_files_per_day(files, days=3, reference=reference)

    assert sum(dc.total for dc in result) == 0
    assert len(result) == 3
