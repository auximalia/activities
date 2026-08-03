"""Smoke-Test fuer den kompletten Ablauf ueber die Kommandozeile."""

from __future__ import annotations

from pathlib import Path

from recent_files.cli import main


def test_cli_creates_report_without_browser(tmp_path: Path) -> None:
    (tmp_path / "unterordner").mkdir()
    (tmp_path / "unterordner" / "notiz.txt").write_text("x", encoding="utf-8")
    output = tmp_path / "bericht.html"

    exit_code = main([str(tmp_path), "--ausgabe", str(output), "--kein-browser"])

    assert exit_code == 0
    assert output.exists()
    content = output.read_text(encoding="utf-8")
    assert "unterordner" in content
    assert "Zuletzt verwendete Dateien" in content


def test_cli_reports_missing_path(tmp_path: Path) -> None:
    missing = tmp_path / "fehlt"
    exit_code = main([str(missing), "--kein-browser"])
    assert exit_code == 2
