"""Erzeugt den eigenstaendigen HTML-Bericht der zuletzt verwendeten Ordner.

Die Ordner werden nach Zeitabschnitten gruppiert (Heute, Gestern, Diese Woche,
Vor N Wochen); jeder Abschnitt bildet eine visuell getrennte Sektion.

Alle Pfade werden HTML-escaped (Schutz vor eingeschleustem Markup ueber
Dateinamen). Ein Klick auf einen Ordner kopiert dessen vollstaendigen Pfad in
die Zwischenablage; als Ersatz fuer die moderne Zwischenablage-Schnittstelle
dient ``document.execCommand("copy")``.
"""

from __future__ import annotations

import html
import tempfile
from datetime import date, datetime
from pathlib import Path
from typing import Sequence

from recent_files.configuration import Configuration
from recent_files.file_types import CATEGORY_ORDER
from recent_files.folder_aggregation import DayCount, FolderEntry

_DATE_FORMAT = "%d.%m.%Y %H:%M"

# Deutsche Wochentagskuerzel (Mo=0 ... So=6), unabhaengig von der System-Locale.
_WEEKDAY_ABBR = ("Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa.", "So.")


def _format_timestamp(moment: datetime) -> str:
    """Formatiert einen Zeitstempel mit vorangestelltem Wochentagskuerzel.

    Beispiel: ``Mo. 03.08.2026 16:09``.
    """
    return f"{_WEEKDAY_ABBR[moment.weekday()]} {moment.strftime(_DATE_FORMAT)}"

# Feste Farbe je Dateityp-Kategorie (Apple-Systemfarben, gut unterscheidbar).
_CATEGORY_COLORS = {
    "Dokumente": "#0071e3",
    "PDF": "#ff3b30",
    "Tabellen": "#34c759",
    "Praesentationen": "#ff9500",
    "Bilder": "#af52de",
    "Medien": "#5ac8fa",
    "Archive": "#a2845e",
    "Code": "#ffcc00",
    "Sonstige": "#8e8e93",
}

_EMPTY_MESSAGE = "Im gewaehlten Zeitraum wurden keine bearbeiteten Dateien gefunden."


def bucket_label(newest_date: datetime, now: datetime) -> str:
    """Ordnet einem Datum einen Zeitabschnitt relativ zu ``now`` zu.

    Gruppierung nach Kalendertagen: Heute, Gestern, Diese Woche (bis 6 Tage) und
    darueber hinaus wochenweise (Vor 1 Woche, Vor 2 Wochen ...).
    """
    days_ago = (now.date() - newest_date.date()).days
    if days_ago <= 0:
        return "Heute"
    if days_ago == 1:
        return "Gestern"
    if days_ago < 7:
        return "Diese Woche"
    weeks_ago = days_ago // 7
    return "Vor 1 Woche" if weeks_ago == 1 else f"Vor {weeks_ago} Wochen"


def _group_into_buckets(
    entries: Sequence[FolderEntry], now: datetime
) -> list[tuple[str, list[FolderEntry]]]:
    """Fasst die (bereits absteigend sortierten) Eintraege je Zeitabschnitt zusammen."""
    buckets: list[tuple[str, list[FolderEntry]]] = []
    for entry in entries:
        label = bucket_label(entry.newest_date, now)
        if not buckets or buckets[-1][0] != label:
            buckets.append((label, []))
        buckets[-1][1].append(entry)
    return buckets


def _present_categories(daily_counts: Sequence[DayCount]) -> list[str]:
    """Ermittelt die tatsaechlich vorkommenden Kategorien in kanonischer Reihenfolge."""
    totals: dict[str, int] = {}
    for day in daily_counts:
        for category, count in day.counts_by_category.items():
            totals[category] = totals.get(category, 0) + count
    return [category for category in CATEGORY_ORDER if totals.get(category, 0) > 0]


def _day_anchor(day: date) -> str:
    """Anker-Kennung fuer einen Kalendertag in der Ordnerliste."""
    return f"tag-{day.isoformat()}"


def _render_bar(
    day: DayCount,
    categories: Sequence[str],
    max_total: int,
    available_days: Sequence[date],
) -> str:
    """Erzeugt einen gestapelten Balken fuer einen Tag.

    Die Balkenhoehe richtet sich nach dem Tagesmaximum; die Segmenthoehe ist der
    Anteil der Kategorie am jeweiligen Tag. Ein Klick springt zum passenden Tag
    in der Ordnerliste, aber nur wenn fuer genau diesen Tag ein Ordner existiert.
    """
    label = day.day.strftime("%d.%m.%Y")
    total = day.total
    segments = []
    for category in categories:
        count = day.counts_by_category.get(category, 0)
        if count <= 0:
            continue
        segment_height = count / total * 100
        color = _CATEGORY_COLORS.get(category, _CATEGORY_COLORS["Sonstige"])
        file_word = "Datei" if count == 1 else "Dateien"
        segments.append(
            f'<div class="seg" style="height:{segment_height:.4f}%;background:{color}" '
            f'title="{label} &middot; {html.escape(category)}: {count} {file_word}"></div>'
        )
    bar_height = total / max_total * 100 if total else 0
    # Samstag (5) und Sonntag (6) hellgrau hinterlegen.
    weekend_class = " weekend" if day.day.weekday() >= 5 else ""

    interaction = ""
    clickable = ""
    # Nur klickbar, wenn fuer genau diesen Tag ein Ordner in der Liste existiert.
    if total > 0 and day.day in available_days:
        anchor = _day_anchor(day.day)
        clickable = " clickable"
        interaction = (
            f' role="button" tabindex="0" onclick="scrollToDay(\'{anchor}\')" '
            f'onkeydown="if(event.key===\'Enter\'||event.key===\' \')scrollToDay(\'{anchor}\')"'
        )

    return (
        f'<div class="bar-wrap{weekend_class}{clickable}" title="{label}"{interaction}>'
        f'<div class="bar" style="height:{bar_height:.4f}%">{"".join(segments)}</div>'
        "</div>"
    )


def _render_legend(categories: Sequence[str], daily_counts: Sequence[DayCount]) -> str:
    """Erzeugt die Legende mit Farbe, Kategoriename und Gesamtzahl je Typ."""
    totals: dict[str, int] = {}
    for day in daily_counts:
        for category, count in day.counts_by_category.items():
            totals[category] = totals.get(category, 0) + count

    items = []
    for category in categories:
        color = _CATEGORY_COLORS.get(category, _CATEGORY_COLORS["Sonstige"])
        items.append(
            '<span class="legend-item">'
            f'<span class="swatch" style="background:{color}"></span>'
            f"{html.escape(category)}"
            f'<span class="legend-count">{totals.get(category, 0)}</span>'
            "</span>"
        )
    return f'<div class="legend">{"".join(items)}</div>'


def _render_day_labels(daily_counts: Sequence[DayCount]) -> str:
    """Erzeugt die Tages-Beschriftungen (Tag des Monats) unter der X-Achse.

    Bei langen Zeitraeumen werden nur Wochenanfaenge und Monatserste beschriftet,
    damit die Achse lesbar bleibt; die Spalten bleiben aber deckungsgleich.
    """
    show_all = len(daily_counts) <= 45
    labels = []
    for day in daily_counts:
        current = day.day
        show = show_all or current.day == 1 or current.weekday() == 0
        text = str(current.day) if show else ""
        weekend_class = " weekend" if current.weekday() >= 5 else ""
        labels.append(f'<div class="day-label{weekend_class}">{text}</div>')
    return f'<div class="chart-days">{"".join(labels)}</div>'


def _render_chart(
    daily_counts: Sequence[DayCount], available_days: Sequence[date]
) -> str:
    """Erzeugt ein gestapeltes Balken-Verlaufsdiagramm der Dateitypen je Tag.

    Gibt eine leere Zeichenkette zurueck, wenn keine Dateien vorliegen.
    """
    categories = _present_categories(daily_counts)
    if not categories:
        return ""

    max_total = max(day.total for day in daily_counts)
    bars = "".join(
        _render_bar(day, categories, max_total, available_days) for day in daily_counts
    )
    day_labels = _render_day_labels(daily_counts)

    first_full = html.escape(daily_counts[0].day.strftime("%d.%m.%Y"))
    last_full = html.escape(daily_counts[-1].day.strftime("%d.%m.%Y"))
    return (
        '<section class="chart-card" aria-label="Verlauf der bearbeiteten Dateien je Tag und Dateityp">'
        '<div class="chart-head">'
        "<span>Bearbeitete Dateien je Tag</span>"
        f'<span class="chart-max">max. {max_total}</span>'
        "</div>"
        f'<div class="chart">{bars}</div>'
        f"{day_labels}"
        f'<div class="chart-range">{first_full} &ndash; {last_full}</div>'
        f"{_render_legend(categories, daily_counts)}"
        "</section>"
    )


def _render_file_tree(entry: FolderEntry) -> str:
    """Erzeugt die eingerueckte, tree-artige Dateiliste eines Ordners.

    Die Dateien sind bereits nach Datum absteigend (juengste zuerst) sortiert.
    """
    if not entry.files:
        return ""
    last_index = len(entry.files) - 1
    rows = []
    for index, relevant_file in enumerate(entry.files):
        branch = "&#9492;&#9472;" if index == last_index else "&#9500;&#9472;"  # tree └─ / ├─
        name = html.escape(relevant_file.path.name)
        full = html.escape(str(relevant_file.path), quote=True)
        date_text = html.escape(_format_timestamp(relevant_file.timestamp))
        rows.append(
            f'<div class="file-row" title="{full}">'
            f'<span class="fname"><span class="branch" aria-hidden="true">{branch}</span> {name}</span>'
            f'<span class="fdate">{date_text}</span>'
            "</div>"
        )
    return f'<div class="folder-files">{"".join(rows)}</div>'


def _render_folder(entry: FolderEntry, anchor_id: str | None = None) -> str:
    """Erzeugt einen aufklappbaren Ordner-Eintrag mit eingebetteter Dateiliste.

    ``anchor_id`` setzt eine Sprungmarke, damit das Diagramm zum Tag scrollen kann.
    """
    path_text = html.escape(str(entry.path))
    # Roher Pfad als Attribut, damit Zeilen- und Balken-Klick ihn kopieren koennen.
    path_attr = html.escape(str(entry.path), quote=True)
    date_text = html.escape(_format_timestamp(entry.newest_date))
    file_word = "Datei" if entry.file_count == 1 else "Dateien"
    id_attr = f' id="{anchor_id}"' if anchor_id else ""
    return (
        '<div class="folder-item">'
        f'<div class="folder"{id_attr} role="button" tabindex="0" '
        f'data-path="{path_attr}" '
        f'onclick="selectFolder(this)" '
        f'onkeydown="if(event.key===\'Enter\'||event.key===\' \')selectFolder(this)" '
        'title="Klicken: Dateien ein-/ausblenden, auswaehlen und Pfad kopieren">'
        '<div class="folder-main">'
        '<span class="chevron" aria-hidden="true">&rsaquo;</span>'
        '<span class="copy-icon" aria-hidden="true">&#128203;</span>'
        f'<span class="path">{path_text}</span>'
        "</div>"
        '<div class="folder-meta">'
        f'<span class="date">{date_text}</span>'
        f'<span class="badge">{entry.file_count}</span>'
        f'<span class="file-word">{file_word}</span>'
        "</div>"
        "</div>"
        f"{_render_file_tree(entry)}"
        "</div>"
    )


def _render_sections(entries: Sequence[FolderEntry], now: datetime) -> str:
    """Erzeugt die nach Zeitabschnitten getrennten Sektionen.

    Der jeweils erste Ordner eines Kalendertags erhaelt eine Sprungmarke, sodass
    das Diagramm gezielt dorthin scrollen kann.
    """
    if not entries:
        return f'<div class="empty">{_EMPTY_MESSAGE}</div>'

    seen_days: set[date] = set()
    sections = []
    for label, bucket_entries in _group_into_buckets(entries, now):
        rendered = []
        for entry in bucket_entries:
            day = entry.newest_date.date()
            anchor = None
            if day not in seen_days:
                seen_days.add(day)
                anchor = _day_anchor(day)
            rendered.append(_render_folder(entry, anchor))
        sections.append(
            '<section class="bucket">'
            f'<h2 class="bucket-title">{html.escape(label)}'
            f'<span class="bucket-count">{len(bucket_entries)}</span></h2>'
            f'<div class="folders">{chr(10).join(rendered)}</div>'
            "</section>"
        )
    return "\n".join(sections)


def build_html(
    entries: Sequence[FolderEntry],
    daily_counts: Sequence[DayCount],
    config: Configuration,
) -> str:
    """Baut das vollstaendige HTML-Dokument des Berichts."""
    now = datetime.now()
    created_at = html.escape(now.strftime(_DATE_FORMAT))
    root_text = html.escape(str(config.root_path))
    available_days = sorted({entry.newest_date.date() for entry in entries})
    chart = _render_chart(daily_counts, available_days)
    sections = _render_sections(entries, now)

    filter_chip = ""
    if config.extension_filters:
        patterns = ", ".join(sorted(config.extension_filters))
        filter_chip = f'<span class="chip">Endungen: <strong>{html.escape(patterns)}</strong></span>'

    return f"""<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Zuletzt verwendete Dateien</title>
<style>
  :root {{
    --bg: #f5f5f7;
    --surface: #ffffff;
    --text: #1d1d1f;
    --muted: #6e6e73;
    --border: #e5e5ea;
    --accent: #0071e3;
    --accent-soft: #eaf3ff;
    --badge-bg: #eef0f3;
    --axis: #b8b8bd;
    --shadow: 0 1px 3px rgba(0,0,0,0.06), 0 8px 24px rgba(0,0,0,0.05);
    --radius: 14px;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #1c1c1e;
      --surface: #2c2c2e;
      --text: #f5f5f7;
      --muted: #98989d;
      --border: #3a3a3c;
      --accent: #0a84ff;
      --accent-soft: #10344f;
      --badge-bg: #3a3a3c;
      --axis: #5a5a5e;
      --shadow: 0 1px 3px rgba(0,0,0,0.4), 0 8px 24px rgba(0,0,0,0.35);
    }}
  }}
  * {{ box-sizing: border-box; }}
  html {{ scroll-behavior: smooth; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    background: var(--bg); color: var(--text); margin: 0;
    padding: 1.75rem 1.25rem; line-height: 1.35;
    -webkit-font-smoothing: antialiased;
  }}
  .container {{ max-width: 1080px; margin: 0 auto; }}
  header {{ margin-bottom: 1.1rem; }}
  h1 {{ font-size: 1.35rem; font-weight: 700; margin: 0 0 0.55rem; letter-spacing: -0.02em; }}
  .chips {{ display: flex; flex-wrap: wrap; gap: 0.4rem; margin-bottom: 0.45rem; }}
  .chip {{
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 999px; padding: 0.22rem 0.65rem; font-size: 0.78rem; color: var(--muted);
  }}
  .chip strong {{ color: var(--text); font-weight: 600; }}
  .hint {{ font-size: 0.82rem; color: var(--muted); margin: 0.2rem 0 0; }}
  .chart-card {{
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); box-shadow: var(--shadow);
    padding: 0.8rem 1rem 0.6rem; margin-bottom: 0.4rem;
  }}
  .chart-head {{
    display: flex; justify-content: space-between; align-items: baseline;
    font-size: 0.8rem; color: var(--muted); margin-bottom: 0.6rem;
  }}
  .chart-max {{ font-variant-numeric: tabular-nums; }}
  .chart {{
    display: flex; align-items: flex-end; gap: 2px;
    height: 96px; border-bottom: 2px solid var(--axis);
  }}
  .bar-wrap {{
    flex: 1 1 0; height: 100%; display: flex; align-items: flex-end;
    min-width: 0; border-radius: 3px;
  }}
  .bar-wrap.weekend {{ background: rgba(128,128,128,0.14); }}
  .bar-wrap.clickable {{ cursor: pointer; }}
  .bar-wrap.clickable:focus {{ outline: 2px solid var(--accent); outline-offset: 1px; }}
  .bar {{
    width: 100%; min-height: 2px; display: flex; flex-direction: column-reverse;
    border-radius: 3px 3px 0 0; overflow: hidden;
  }}
  .bar-wrap:hover .bar {{ filter: brightness(1.08); }}
  .seg {{ width: 100%; }}
  .chart-days {{ display: flex; gap: 2px; margin-top: 0.3rem; }}
  .day-label {{
    flex: 1 1 0; min-width: 0; text-align: center;
    font-size: 0.6rem; color: var(--muted); font-variant-numeric: tabular-nums;
    overflow: hidden;
  }}
  .day-label.weekend {{ color: var(--axis); }}
  .chart-range {{
    text-align: center; font-size: 0.72rem; color: var(--muted); margin-top: 0.2rem;
  }}
  .legend {{
    display: flex; flex-wrap: wrap; gap: 0.4rem 1rem;
    margin-top: 0.75rem; padding-top: 0.6rem; border-top: 1px solid var(--border);
    font-size: 0.78rem; color: var(--muted);
  }}
  .legend-item {{ display: inline-flex; align-items: center; gap: 0.35rem; }}
  .swatch {{ width: 0.7rem; height: 0.7rem; border-radius: 3px; flex: none; }}
  .legend-count {{ color: var(--text); font-weight: 600; font-variant-numeric: tabular-nums; }}
  .bucket {{ margin-top: 1.15rem; }}
  .bucket-title {{
    display: flex; align-items: center; gap: 0.5rem;
    font-size: 0.78rem; font-weight: 600; text-transform: uppercase;
    letter-spacing: 0.06em; color: var(--muted);
    margin: 0 0 0.4rem; padding-top: 0.7rem; border-top: 1px solid var(--border);
  }}
  .bucket-count {{
    background: var(--badge-bg); color: var(--muted);
    border-radius: 999px; padding: 0.05rem 0.5rem; font-size: 0.72rem; font-weight: 600;
  }}
  .folders {{
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); box-shadow: var(--shadow); overflow: hidden;
  }}
  .folder {{
    display: flex; align-items: center; justify-content: space-between; gap: 0.75rem;
    padding: 0.45rem 0.9rem; cursor: pointer; border-top: 1px solid var(--border);
    transition: background 0.12s ease; scroll-margin-top: 1rem;
  }}
  .folder:first-child {{ border-top: none; }}
  .folder:hover, .folder:focus {{ background: var(--accent-soft); outline: none; }}
  .folder.selected {{
    background: var(--accent-soft); box-shadow: inset 3px 0 0 var(--accent);
  }}
  .folder-main {{ display: flex; align-items: center; gap: 0.6rem; min-width: 0; }}
  .chevron {{
    color: var(--muted); font-size: 1rem; flex: none; line-height: 1;
    transition: transform 0.15s ease; display: inline-block;
  }}
  .folder-item.open .chevron {{ transform: rotate(90deg); }}
  .copy-icon {{ opacity: 0.5; font-size: 0.95rem; flex: none; }}
  .folder:hover .copy-icon {{ opacity: 0.9; }}
  .folder-files {{ display: none; background: var(--surface); }}
  .folder-item.open .folder-files {{ display: block; }}
  .file-row {{
    display: grid; grid-template-columns: 1fr max-content 2.75rem 4.5rem;
    align-items: baseline; gap: 0.6rem;
    padding: 0.22rem 0.9rem 0.22rem 2.3rem; border-top: 1px solid var(--border);
    font-size: 0.8rem;
  }}
  .file-row .fname {{ min-width: 0; word-break: break-all; color: var(--text); }}
  .file-row .branch {{
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    color: var(--muted); margin-right: 0.15rem;
  }}
  .file-row .fdate {{
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 0.78rem; color: var(--muted); white-space: nowrap; text-align: right;
  }}
  .path {{
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 0.86rem; word-break: break-all;
  }}
  .folder-meta {{
    display: grid; grid-template-columns: max-content 2.75rem 4.5rem;
    align-items: center; gap: 0.6rem; flex: none;
  }}
  .date {{
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 0.78rem; color: var(--muted); white-space: nowrap; text-align: right;
  }}
  .badge {{
    justify-self: end;
    background: var(--accent); color: #fff; border-radius: 999px;
    padding: 0.05rem 0.5rem; font-size: 0.75rem; font-weight: 600; min-width: 1.4rem; text-align: center;
  }}
  .file-word {{ font-size: 0.78rem; color: var(--muted); text-align: left; }}
  .empty {{
    background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius);
    padding: 3rem 1.5rem; text-align: center; color: var(--muted); font-style: italic;
  }}
  #toast {{
    position: fixed; bottom: 1.5rem; left: 50%; transform: translateX(-50%) translateY(1rem);
    background: var(--text); color: var(--bg); padding: 0.6rem 1.1rem; border-radius: 10px;
    font-size: 0.85rem; opacity: 0; transition: opacity 0.2s, transform 0.2s;
    pointer-events: none; box-shadow: var(--shadow);
  }}
  #toast.show {{ opacity: 1; transform: translateX(-50%) translateY(0); }}
  #to-top {{
    position: fixed; bottom: 1.5rem; right: 1.5rem;
    background: var(--surface); color: var(--text); border: 1px solid var(--border);
    border-radius: 999px; padding: 0.55rem 0.95rem; font-size: 0.85rem; font-weight: 600;
    box-shadow: var(--shadow); cursor: pointer;
    opacity: 0; transform: translateY(0.5rem); transition: opacity 0.2s, transform 0.2s;
    pointer-events: none;
  }}
  #to-top.show {{ opacity: 1; transform: translateY(0); pointer-events: auto; }}
  #to-top:hover {{ border-color: var(--accent); color: var(--accent); }}
  @media (max-width: 560px) {{
    .folder {{ flex-direction: column; align-items: flex-start; gap: 0.4rem; }}
    .folder-meta {{ align-self: flex-start; }}
  }}
</style>
</head>
<body>
<div class="container">
<header>
  <h1>Zuletzt verwendete Dateien</h1>
  <div class="chips">
    <span class="chip">Ordner: <strong>{root_text}</strong></span>
    <span class="chip">Zeitraum: letzte <strong>{config.days}</strong> Tage</span>
    <span class="chip">Gefundene Ordner: <strong>{len(entries)}</strong></span>
    {filter_chip}
    <span class="chip">Erstellt: <strong>{created_at}</strong></span>
  </div>
  <p class="hint">Klicke auf eine Zeile, um den Ordnerpfad in die Zwischenablage zu kopieren.</p>
</header>
{chart}
<main>
{sections}
</main>
</div>
<button id="to-top" onclick="scrollToTop()" title="Nach oben">&uarr; Nach oben</button>
<div id="toast">Pfad kopiert</div>
<script>
function showToast(text) {{
  var toast = document.getElementById("toast");
  toast.textContent = text;
  toast.classList.add("show");
  setTimeout(function () {{ toast.classList.remove("show"); }}, 1500);
}}
function fallbackCopy(text) {{
  var area = document.createElement("textarea");
  area.value = text;
  area.style.position = "fixed";
  area.style.opacity = "0";
  document.body.appendChild(area);
  area.focus();
  area.select();
  var ok = false;
  try {{ ok = document.execCommand("copy"); }} catch (e) {{ ok = false; }}
  document.body.removeChild(area);
  return ok;
}}
function copyPath(path) {{
  if (navigator.clipboard && navigator.clipboard.writeText) {{
    navigator.clipboard.writeText(path).then(
      function () {{ showToast("Pfad kopiert"); }},
      function () {{ showToast(fallbackCopy(path) ? "Pfad kopiert" : "Kopieren fehlgeschlagen"); }}
    );
  }} else {{
    showToast(fallbackCopy(path) ? "Pfad kopiert" : "Kopieren fehlgeschlagen");
  }}
}}
function markSelected(el) {{
  var previous = document.querySelector(".folder.selected");
  if (previous && previous !== el) previous.classList.remove("selected");
  el.classList.add("selected");
}}
function selectFolder(el) {{
  var item = el.parentElement;
  var willOpen = !item.classList.contains("open");
  item.classList.toggle("open");
  if (willOpen) {{
    markSelected(el);
    if (el.dataset.path) copyPath(el.dataset.path);
  }}
}}
function scrollToDay(id) {{
  var el = document.getElementById(id);
  if (!el) return;
  var item = el.parentElement;
  if (el.classList.contains("selected")) {{
    // Toggle: erneuter Klick auf denselben Balken hebt Auswahl auf und klappt ein.
    el.classList.remove("selected");
    item.classList.remove("open");
    return;
  }}
  markSelected(el);
  item.classList.add("open");
  el.scrollIntoView({{ behavior: "smooth", block: "start" }});
  if (el.dataset.path) copyPath(el.dataset.path);
}}
function scrollToTop() {{
  window.scrollTo({{ top: 0, behavior: "smooth" }});
}}
window.addEventListener("scroll", function () {{
  var button = document.getElementById("to-top");
  if (window.scrollY > 400) button.classList.add("show");
  else button.classList.remove("show");
}});
</script>
</body>
</html>
"""


def write_report(html_content: str, output_path: Path | None) -> Path:
    """Schreibt den HTML-Bericht und liefert den tatsaechlichen Pfad zurueck.

    Ohne ``output_path`` wird eine Datei im temporaeren Verzeichnis erzeugt.
    """
    if output_path is None:
        handle = tempfile.NamedTemporaryFile(
            prefix="zuletzt_verwendet_",
            suffix=".html",
            delete=False,
            mode="w",
            encoding="utf-8",
        )
        with handle:
            handle.write(html_content)
        return Path(handle.name)

    output_path.write_text(html_content, encoding="utf-8")
    return output_path
