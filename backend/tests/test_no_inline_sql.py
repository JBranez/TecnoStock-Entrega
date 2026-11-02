from __future__ import annotations

import re
from pathlib import Path

APP_DIR = Path(__file__).resolve().parents[1] / "app"
_FORBIDDEN_SQL = re.compile(r"\b(select|insert|update|delete)\s+", re.IGNORECASE)


def test_python_application_has_no_inline_dml_or_select_statements() -> None:
    violations = []
    for path in APP_DIR.rglob("*.py"):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if _FORBIDDEN_SQL.search(line):
                violations.append(f"{path.relative_to(APP_DIR)}:{line_number}: {line.strip()}")
    assert violations == []
