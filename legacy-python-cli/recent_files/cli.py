"""Kommandozeilen-Einstieg und Orchestrierung des Ablaufs.

Diese Ebene enthaelt keine Fachlogik, sondern koordiniert nur den Workflow:
Argumente lesen, Konfiguration laden, scannen, aggregieren, HTML erzeugen und
den Bericht optional im Browser oeffnen.
"""

from __future__ import annotations

import argparse
import logging
import webbrowser
from dataclasses import replace
from pathlib import Path

from recent_files import __version__
from recent_files.configuration import ConfigurationError, load_configuration
from recent_files.file_scanner import find_relevant_files, list_directory_files
from recent_files.folder_aggregation import count_files_per_day, group_by_folder
from recent_files.html_report import build_html, write_report

logger = logging.getLogger(__name__)


def _build_parser() -> argparse.ArgumentParser:
    """Definiert die Kommandozeilen-Argumente."""
    parser = argparse.ArgumentParser(
        prog="recent_files",
        description="Erzeugt einen HTML-Bericht der zuletzt bearbeiteten Ordner.",
    )
    parser.add_argument(
        "path",
        nargs="?",
        type=Path,
        default=None,
        help="Zu durchsuchender Wurzelordner (Standard: Dokumente-Ordner).",
    )
    parser.add_argument(
        "--tage",
        dest="days",
        type=int,
        default=None,
        metavar="N",
        help="Zeitraum in Tagen rueckwaerts (Standard: 30).",
    )
    parser.add_argument(
        "--endung",
        dest="extensions",
        nargs="+",
        default=None,
        metavar="MUSTER",
        help="Nur bestimmte Dateiendungen (z. B. 'xls*' fuer xls und xlsx). Mehrere moeglich.",
    )
    parser.add_argument(
        "--ausgabe",
        dest="output",
        type=Path,
        default=None,
        metavar="DATEI",
        help="Zielpfad der HTML-Datei (Standard: temporaeres Verzeichnis).",
    )
    parser.add_argument(
        "--config",
        dest="config_file",
        type=Path,
        default=None,
        metavar="DATEI",
        help="Alternative Konfigurationsdatei.",
    )
    parser.add_argument(
        "--kein-browser",
        dest="open_in_browser",
        action="store_false",
        help="Bericht nur erzeugen, nicht im Browser oeffnen.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Ausfuehrlichere Protokollierung.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return parser


def main(argv: list[str] | None = None) -> int:
    """Fuehrt den kompletten Ablauf aus und liefert einen Exit-Code."""
    args = _build_parser().parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    try:
        # 1. Konfiguration aus Standardwerten und Argumenten zusammenfuehren.
        config = load_configuration(
            root_path=args.path,
            days=args.days,
            extension_filters=args.extensions,
            output_path=args.output,
            open_in_browser=args.open_in_browser,
            config_file=args.config_file,
        )
    except ConfigurationError as error:
        logger.error("Konfigurationsfehler: %s", error)
        return 2

    logger.info("Durchsuche %s (letzte %d Tage) ...", config.root_path, config.days)

    # 2. Relevante Dateien sammeln, zu Ordnern und zu Tageszaehlungen aggregieren.
    files = list(find_relevant_files(config))
    entries = group_by_folder(files)
    # Fuer die aufklappbare Detailansicht den vollstaendigen Ordnerinhalt anhaengen.
    entries = [
        replace(entry, files=tuple(list_directory_files(entry.path, config.excluded_files)))
        for entry in entries
    ]
    daily_counts = count_files_per_day(files, config.days)
    logger.info("Gefundene Ordner: %d", len(entries))

    # 3. HTML erzeugen und schreiben.
    report_path = write_report(build_html(entries, daily_counts, config), config.output_path)
    logger.info("Bericht erstellt: %s", report_path)

    # 4. Bericht optional im Standardbrowser oeffnen.
    if config.open_in_browser:
        webbrowser.open(report_path.as_uri())

    return 0
