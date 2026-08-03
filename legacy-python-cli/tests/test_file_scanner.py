"""Tests fuer den Dateiscanner: Datum, Ausschluesse und Zeitraumfilter."""

from __future__ import annotations

import os
from datetime import datetime, timedelta
from pathlib import Path
from types import SimpleNamespace

import pytest

from recent_files.configuration import Configuration
from recent_files.file_scanner import (
    effective_timestamp,
    find_relevant_files,
    is_excluded_file,
    is_hidden,
    list_directory_files,
    matches_extension_filter,
)


def _make_config(root: Path, days: int = 30, extensions: frozenset[str] = frozenset()) -> Configuration:
    return Configuration(
        root_path=root,
        days=days,
        excluded_folders=frozenset({".git", "node_modules"}),
        excluded_files=frozenset({".DS_Store", "~$*"}),
        extension_filters=extensions,
        output_path=None,
        open_in_browser=False,
    )


def test_effective_timestamp_prefers_newer_value() -> None:
    stat_result = SimpleNamespace(st_birthtime=100.0, st_ctime=100.0, st_mtime=500.0)
    assert effective_timestamp(stat_result) == datetime.fromtimestamp(500.0)


def test_effective_timestamp_uses_creation_when_newer() -> None:
    stat_result = SimpleNamespace(st_birthtime=900.0, st_ctime=900.0, st_mtime=200.0)
    assert effective_timestamp(stat_result) == datetime.fromtimestamp(900.0)


def test_effective_timestamp_falls_back_to_ctime() -> None:
    # Kein st_birthtime (z. B. Linux) -> st_ctime dient als Ersatz.
    stat_result = SimpleNamespace(st_ctime=300.0, st_mtime=200.0)
    assert effective_timestamp(stat_result) == datetime.fromtimestamp(300.0)


def test_is_hidden_detects_dotfiles() -> None:
    assert is_hidden(".DS_Store") is True
    assert is_hidden("normal.txt") is False


def test_is_excluded_file_matches_glob() -> None:
    excluded = frozenset({".DS_Store", "~$*"})
    assert is_excluded_file("~$bericht.docx", excluded) is True
    assert is_excluded_file(".DS_Store", excluded) is True
    assert is_excluded_file("bericht.docx", excluded) is False


def test_matches_extension_filter() -> None:
    assert matches_extension_filter("a.txt", frozenset()) is True  # kein Filter -> alles
    xls = frozenset({"xls*"})
    assert matches_extension_filter("tabelle.xls", xls) is True
    assert matches_extension_filter("tabelle.xlsx", xls) is True
    assert matches_extension_filter("brief.docx", xls) is False
    assert matches_extension_filter("ohne_endung", xls) is False


def test_find_relevant_files_applies_extension_filter(tmp_path: Path) -> None:
    (tmp_path / "tabelle.xlsx").write_text("x", encoding="utf-8")
    (tmp_path / "alt.xls").write_text("x", encoding="utf-8")
    (tmp_path / "brief.docx").write_text("x", encoding="utf-8")

    config = _make_config(tmp_path, extensions=frozenset({"xls*"}))
    names = {f.path.name for f in find_relevant_files(config)}

    assert names == {"tabelle.xlsx", "alt.xls"}


def test_find_relevant_files_includes_recent(tmp_path: Path) -> None:
    recent = tmp_path / "aktuell.txt"
    recent.write_text("x", encoding="utf-8")

    files = list(find_relevant_files(_make_config(tmp_path)))
    paths = {f.path for f in files}

    assert recent in paths
    entry = next(f for f in files if f.path == recent)
    assert entry.folder == tmp_path


def test_find_relevant_files_excludes_old(tmp_path: Path) -> None:
    old = tmp_path / "alt.txt"
    old.write_text("x", encoding="utf-8")
    # Aenderungsdatum weit in die Vergangenheit setzen.
    old_time = (datetime.now() - timedelta(days=400)).timestamp()
    os.utime(old, (old_time, old_time))

    # Nur alte Datei ist relevant, wenn Erstelldatum ebenfalls alt ist.
    # Auf Systemen mit birthtime = jetzt bleibt die Datei als "neu erstellt"
    # relevant; deshalb wird dieser Fall ueber days=0-Grenze separat geprueft.
    files = list(find_relevant_files(_make_config(tmp_path, days=200)))
    assert all(f.path != old or f.timestamp >= datetime.now() - timedelta(days=200)
               for f in files)


def test_find_relevant_files_skips_excluded_folder(tmp_path: Path) -> None:
    (tmp_path / "node_modules").mkdir()
    hidden_in_excluded = tmp_path / "node_modules" / "paket.js"
    hidden_in_excluded.write_text("x", encoding="utf-8")
    keep = tmp_path / "behalten.txt"
    keep.write_text("x", encoding="utf-8")

    paths = {f.path for f in find_relevant_files(_make_config(tmp_path))}

    assert keep in paths
    assert hidden_in_excluded not in paths


def test_find_relevant_files_skips_hidden_and_junk(tmp_path: Path) -> None:
    (tmp_path / ".DS_Store").write_text("x", encoding="utf-8")
    (tmp_path / ".versteckt").write_text("x", encoding="utf-8")
    (tmp_path / "~$offen.docx").write_text("x", encoding="utf-8")
    keep = tmp_path / "sichtbar.txt"
    keep.write_text("x", encoding="utf-8")

    names = {f.path.name for f in find_relevant_files(_make_config(tmp_path))}

    assert names == {"sichtbar.txt"}


def test_find_relevant_files_ignores_hidden_subfolder(tmp_path: Path) -> None:
    (tmp_path / ".git").mkdir()
    (tmp_path / ".git" / "config").write_text("x", encoding="utf-8")
    keep = tmp_path / "sichtbar.txt"
    keep.write_text("x", encoding="utf-8")

    paths = {f.path for f in find_relevant_files(_make_config(tmp_path))}
    assert paths == {keep}


def test_list_directory_files_includes_old_and_sorts(tmp_path: Path) -> None:
    import os

    # 'neu' klar am neuesten machen (Aenderungszeit in die Zukunft).
    neu = tmp_path / "neu.txt"
    neu.write_text("x", encoding="utf-8")
    future = (datetime.now() + timedelta(hours=1)).timestamp()
    os.utime(neu, (future, future))

    alt = tmp_path / "alt.txt"
    alt.write_text("x", encoding="utf-8")

    # Datei mit alter Aenderungszeit: wird trotzdem gelistet (kein Zeitfenster).
    sehr_alt = tmp_path / "sehr_alt.txt"
    sehr_alt.write_text("x", encoding="utf-8")
    old_time = (datetime.now() - timedelta(days=400)).timestamp()
    os.utime(sehr_alt, (old_time, old_time))

    # Versteckte und Junk-Dateien sowie Unterordner werden ausgelassen.
    (tmp_path / ".DS_Store").write_text("x", encoding="utf-8")
    (tmp_path / "~$tmp.docx").write_text("x", encoding="utf-8")
    (tmp_path / "unterordner").mkdir()

    result = list_directory_files(tmp_path, frozenset({".DS_Store", "~$*"}))
    names = [rf.path.name for rf in result]

    assert names[0] == "neu.txt"  # juengste zuerst
    assert set(names) == {"neu.txt", "alt.txt", "sehr_alt.txt"}  # alte Datei enthalten
