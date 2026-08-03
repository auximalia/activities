"""Tests fuer die HTML-Berichtserzeugung inkl. Escaping und Leerzustand."""

from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path

from recent_files.configuration import Configuration
from recent_files.file_scanner import RelevantFile
from recent_files.folder_aggregation import DayCount, FolderEntry
from recent_files.html_report import bucket_label, build_html, write_report


def _config(root: Path, extensions: frozenset[str] = frozenset()) -> Configuration:
    return Configuration(
        root_path=root,
        days=30,
        excluded_folders=frozenset(),
        excluded_files=frozenset(),
        extension_filters=extensions,
        output_path=None,
        open_in_browser=False,
    )


def test_html_contains_folder_paths(tmp_path: Path) -> None:
    entries = [
        FolderEntry(Path("/Users/test/Projekt"), datetime(2026, 6, 1, 9, 30), 3),
    ]
    html_content = build_html(entries, [], _config(tmp_path))

    assert "/Users/test/Projekt" in html_content
    # 01.06.2026 ist ein Montag -> Wochentagskuerzel vorangestellt.
    assert "Mo. 01.06.2026 09:30" in html_content
    assert ">3<" in html_content


def test_html_escapes_dangerous_names(tmp_path: Path) -> None:
    entries = [FolderEntry(Path("/tmp/<script>alert(1)</script>"), datetime(2026, 6, 1), 1)]
    html_content = build_html(entries, [], _config(tmp_path))

    assert "<script>alert(1)</script>" not in html_content
    assert "&lt;script&gt;" in html_content


def test_html_shows_empty_state(tmp_path: Path) -> None:
    html_content = build_html([], [], _config(tmp_path))
    assert "keine bearbeiteten Dateien gefunden" in html_content


def test_bucket_label_relative_to_now() -> None:
    now = datetime(2026, 8, 3, 12, 0)
    assert bucket_label(now, now) == "Heute"
    assert bucket_label(now - timedelta(days=1), now) == "Gestern"
    assert bucket_label(now - timedelta(days=3), now) == "Diese Woche"
    assert bucket_label(now - timedelta(days=7), now) == "Vor 1 Woche"
    assert bucket_label(now - timedelta(days=15), now) == "Vor 2 Wochen"


def test_html_groups_into_sections(tmp_path: Path) -> None:
    now = datetime.now()
    entries = [
        FolderEntry(Path("/a/heute"), now, 1),
        FolderEntry(Path("/a/aeltere"), now - timedelta(days=20), 2),
    ]
    html_content = build_html(entries, [], _config(tmp_path))

    assert "Heute" in html_content
    assert "Vor 2 Wochen" in html_content
    assert 'class="bucket-title"' in html_content


def test_html_renders_chart_when_counts_present(tmp_path: Path) -> None:
    from datetime import date

    entries = [FolderEntry(Path("/a"), datetime(2026, 8, 3, 9, 0), 2)]
    daily = [
        DayCount(date(2026, 8, 1), {}),
        DayCount(date(2026, 8, 2), {"Dokumente": 1}),
        DayCount(date(2026, 8, 3), {"Dokumente": 1, "Bilder": 1}),
    ]
    html_content = build_html(entries, daily, _config(tmp_path))

    assert 'class="chart"' in html_content
    assert "Bearbeitete Dateien je Tag" in html_content
    assert "max. 2" in html_content
    # Legende mit vorkommenden Kategorien.
    assert 'class="legend"' in html_content
    assert "Dokumente" in html_content
    assert "Bilder" in html_content
    # Nicht vorkommende Kategorien tauchen nicht auf.
    assert "Archive" not in html_content


def test_html_marks_weekend_days(tmp_path: Path) -> None:
    from datetime import date

    # 01.08.2026 ist ein Samstag, 02.08.2026 ein Sonntag, 03.08. ein Montag.
    entries = [FolderEntry(Path("/a"), datetime(2026, 8, 3, 9, 0), 1)]
    daily = [
        DayCount(date(2026, 8, 1), {"Dokumente": 1}),
        DayCount(date(2026, 8, 2), {"Dokumente": 1}),
        DayCount(date(2026, 8, 3), {"Dokumente": 1}),
    ]
    html_content = build_html(entries, daily, _config(tmp_path))

    assert html_content.count("bar-wrap weekend") == 2


def test_html_chart_has_day_labels_and_scroll_anchor(tmp_path: Path) -> None:
    from datetime import date

    day = datetime(2026, 8, 3, 9, 0)
    entries = [FolderEntry(Path("/a/projekt"), day, 1)]
    daily = [DayCount(date(2026, 8, 3), {"Dokumente": 1})]
    html_content = build_html(entries, daily, _config(tmp_path))

    # Tageslabels unter der X-Achse.
    assert 'class="chart-days"' in html_content
    assert 'class="day-label' in html_content
    # Balken ist klickbar und springt zum Tag-Anker, der in der Liste existiert.
    assert "scrollToDay('tag-2026-08-03')" in html_content
    assert 'id="tag-2026-08-03"' in html_content
    assert "function scrollToDay" in html_content
    # Zieleintrag wird dauerhaft als ausgewaehlt markiert.
    assert '.folder.selected' in html_content
    assert 'classList.add("selected")' in html_content
    # Pfad wird am Eintrag hinterlegt und beim Balken-Klick vorsorglich kopiert.
    assert 'data-path="/a/projekt"' in html_content
    assert "if (el.dataset.path) copyPath(el.dataset.path)" in html_content
    # Zeilen-Klick waehlt aus und kopiert; Auswahl wird dabei aktualisiert.
    assert 'onclick="selectFolder(this)"' in html_content
    assert "function selectFolder" in html_content
    assert "function markSelected" in html_content
    # Toggle: erneuter Balken-Klick auf denselben Tag hebt die Auswahl auf.
    assert 'el.classList.contains("selected")' in html_content
    # "Nach oben"-Button vorhanden.
    assert 'id="to-top"' in html_content
    assert "function scrollToTop" in html_content
    assert "Nach oben" in html_content


def test_html_bar_clickable_only_on_exact_day(tmp_path: Path) -> None:
    from datetime import date

    # Ordner nur am 05.08.; der Balken vom 03.08. hat Dateien, aber keinen Ordner-Tag.
    entries = [FolderEntry(Path("/a/projekt"), datetime(2026, 8, 5, 9, 0), 1)]
    daily = [
        DayCount(date(2026, 8, 3), {"Dokumente": 1}),
        DayCount(date(2026, 8, 5), {"Dokumente": 1}),
    ]
    html_content = build_html(entries, daily, _config(tmp_path))

    # Exakter Tag ist klickbar, der Tag ohne Ordner nicht.
    assert "scrollToDay('tag-2026-08-05')" in html_content
    assert "scrollToDay('tag-2026-08-03')" not in html_content
    assert 'id="tag-2026-08-05"' in html_content


def test_html_renders_expandable_file_tree(tmp_path: Path) -> None:
    folder = Path("/a/projekt")
    files = (
        RelevantFile(folder / "neu.txt", folder, datetime(2026, 8, 3, 12, 0)),
        RelevantFile(folder / "alt.txt", folder, datetime(2026, 8, 1, 9, 0)),
    )
    entry = FolderEntry(folder, datetime(2026, 8, 3, 12, 0), 2, files)
    html_content = build_html([entry], [], _config(tmp_path))

    # Aufklappbare Struktur mit Dateiliste.
    assert 'class="folder-item"' in html_content
    assert 'class="folder-files"' in html_content
    assert "neu.txt" in html_content
    assert "alt.txt" in html_content
    # Juengste Datei erscheint vor der aelteren.
    assert html_content.index("neu.txt") < html_content.index("alt.txt")
    # Datei-Zeitstempel mit Wochentagskuerzel (03.08.2026 ist ein Montag).
    assert "Mo. 03.08.2026 12:00" in html_content
    # Datei-Datumsspalte als Grid, damit die Zeitstempel untereinander stehen.
    assert "grid-template-columns: 1fr max-content 2.75rem 4.5rem" in html_content
    # Toggle-Verdrahtung ueber selectFolder (Auf-/Zuklappen).
    assert 'item.classList.toggle("open")' in html_content
    # Balken-Klick klappt den angesprungenen Eintrag auf.
    assert 'item.classList.add("open")' in html_content


def test_html_shows_filter_chip(tmp_path: Path) -> None:
    from datetime import date

    entries = [FolderEntry(Path("/a"), datetime(2026, 8, 3, 9, 0), 1)]
    daily = [DayCount(date(2026, 8, 3), {"Tabellen": 1})]
    html_content = build_html(entries, daily, _config(tmp_path, extensions=frozenset({"xls*"})))

    assert "Endungen:" in html_content
    assert "xls*" in html_content


def test_html_omits_chart_when_no_counts(tmp_path: Path) -> None:
    from datetime import date

    entries = [FolderEntry(Path("/a"), datetime(2026, 8, 3, 9, 0), 1)]
    daily = [DayCount(date(2026, 8, 1), {}), DayCount(date(2026, 8, 2), {})]
    html_content = build_html(entries, daily, _config(tmp_path))

    assert 'class="chart"' not in html_content


def test_write_report_to_given_path(tmp_path: Path) -> None:
    target = tmp_path / "bericht.html"
    result = write_report("<html></html>", target)

    assert result == target
    assert target.read_text(encoding="utf-8") == "<html></html>"


def test_write_report_to_temp(tmp_path: Path) -> None:
    result = write_report("<html></html>", None)
    try:
        assert result.exists()
        assert result.suffix == ".html"
    finally:
        result.unlink(missing_ok=True)
