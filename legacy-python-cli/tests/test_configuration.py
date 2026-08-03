"""Tests fuer das Laden und Validieren der Konfiguration."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from recent_files.configuration import (
    ConfigurationError,
    default_documents_path,
    load_configuration,
    normalize_extension_pattern,
)


@pytest.fixture
def config_file(tmp_path: Path) -> Path:
    """Schreibt eine minimale, gueltige Standard-Konfiguration."""
    path = tmp_path / "default.json"
    path.write_text(
        json.dumps(
            {
                "days": 30,
                "excluded_folders": [".git", "node_modules"],
                "excluded_files": [".DS_Store", "~$*"],
            }
        ),
        encoding="utf-8",
    )
    return path


def test_default_documents_path_points_to_documents() -> None:
    assert default_documents_path().name == "Documents"


def test_load_uses_defaults(tmp_path: Path, config_file: Path) -> None:
    config = load_configuration(root_path=tmp_path, config_file=config_file)

    assert config.days == 30
    assert config.root_path == tmp_path.resolve()
    assert ".git" in config.excluded_folders
    assert "~$*" in config.excluded_files
    assert config.open_in_browser is True


def test_days_argument_overrides_default(tmp_path: Path, config_file: Path) -> None:
    config = load_configuration(root_path=tmp_path, days=7, config_file=config_file)
    assert config.days == 7


def test_normalize_extension_pattern() -> None:
    assert normalize_extension_pattern("xls*") == "xls*"
    assert normalize_extension_pattern(".xls") == "xls"
    assert normalize_extension_pattern("*.xlsx") == "xlsx"
    assert normalize_extension_pattern("  DOCX ") == "docx"


def test_extension_filters_are_normalized(tmp_path: Path, config_file: Path) -> None:
    config = load_configuration(
        root_path=tmp_path,
        extension_filters=["*.PDF", ".Docx", "xls*"],
        config_file=config_file,
    )
    assert config.extension_filters == frozenset({"pdf", "docx", "xls*"})


def test_extension_filters_default_empty(tmp_path: Path, config_file: Path) -> None:
    config = load_configuration(root_path=tmp_path, config_file=config_file)
    assert config.extension_filters == frozenset()


def test_missing_root_path_raises(tmp_path: Path, config_file: Path) -> None:
    missing = tmp_path / "gibt-es-nicht"
    with pytest.raises(ConfigurationError, match="existiert nicht"):
        load_configuration(root_path=missing, config_file=config_file)


def test_file_as_root_path_raises(tmp_path: Path, config_file: Path) -> None:
    a_file = tmp_path / "datei.txt"
    a_file.write_text("x", encoding="utf-8")
    with pytest.raises(ConfigurationError, match="kein Verzeichnis"):
        load_configuration(root_path=a_file, config_file=config_file)


def test_non_positive_days_raises(tmp_path: Path, config_file: Path) -> None:
    with pytest.raises(ConfigurationError, match="groesser als 0"):
        load_configuration(root_path=tmp_path, days=0, config_file=config_file)


def test_missing_config_file_raises(tmp_path: Path) -> None:
    with pytest.raises(ConfigurationError, match="fehlt"):
        load_configuration(root_path=tmp_path, config_file=tmp_path / "fehlt.json")


def test_invalid_json_raises(tmp_path: Path) -> None:
    bad = tmp_path / "bad.json"
    bad.write_text("{ kein json", encoding="utf-8")
    with pytest.raises(ConfigurationError, match="gueltiges JSON"):
        load_configuration(root_path=tmp_path, config_file=bad)
