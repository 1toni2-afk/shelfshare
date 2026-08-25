#!/usr/bin/env python3
"""Merge scraped Carturesti metadata (enriched_all.json) into the `books` table.

Runs on a recurring schedule (every 3 days, see README) as the write-side
counterpart to nightly_run.py, which only ever SELECTs. This script is the
only place in the enrichment pipeline that writes to the DB.

Policy, keyed by isbn:
  - description / coverUrl / publisher / publishedYear / pageCount / language:
    filled in only where the DB column is currently NULL (COALESCE) - never
    clobbers existing data, scraped or original.
  - title / author: overwritten only when isbnVerified is true, i.e. the
    scraper matched the book by an exact ISBN hit on carturesti.ro, not by
    fuzzy title similarity. Fuzzy-matched entries (isbnVerified=false) are
    trusted enough for cover/description but not enough to relabel a book.

Usage:
    python import_enriched.py [--input enriched_all.json] [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError):
        pass

HERE = Path(__file__).resolve().parent
DEFAULT_INPUT = HERE / "enriched_all.json"

POSTGRES_CONTAINER = "shelfshare-postgres-1"
POSTGRES_USER = "shelfshare"
POSTGRES_DB = "shelfshare"

# Coloane pe care le completam DOAR daca sunt NULL in DB (nu suprascriem
# niciodata date existente, scrapuite sau nu).
FILL_IF_NULL_COLUMNS = [
    ("description", "description"),
    ("coverUrl", '"coverUrl"'),
    ("publisher", "publisher"),
    ("publishedYear", '"publishedYear"'),
    ("pageCount", '"pageCount"'),
    ("language", "language"),
]


def _sql_str(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def _sql_int(value: int | None) -> str:
    return "NULL" if value is None else str(int(value))


@dataclass
class Stats:
    total: int = 0
    skipped_error: int = 0
    skipped_no_isbn: int = 0
    metadata_statements: int = 0
    title_statements: int = 0


def build_statements(entries: list[dict]) -> tuple[list[str], Stats]:
    stats = Stats(total=len(entries))
    statements: list[str] = []

    for entry in entries:
        if entry.get("error"):
            stats.skipped_error += 1
            continue
        isbn = entry.get("isbn")
        if not isbn:
            stats.skipped_no_isbn += 1
            continue

        isbn_sql = _sql_str(isbn)

        set_clauses = []
        for field, column in FILL_IF_NULL_COLUMNS:
            value = entry.get(field)
            if value is None or value == "":
                continue
            literal = _sql_int(value) if field in ("publishedYear", "pageCount") else _sql_str(str(value))
            set_clauses.append(f"{column} = COALESCE({column}, {literal})")

        if set_clauses:
            statements.append(
                f"UPDATE books SET {', '.join(set_clauses)} WHERE isbn = {isbn_sql};"
            )
            stats.metadata_statements += 1

        if entry.get("isbnVerified") and entry.get("title"):
            title_clause = f"title = {_sql_str(entry['title'])}"
            author_clause = ""
            if entry.get("author"):
                author_clause = f", author = COALESCE(author, {_sql_str(entry['author'])})"
            statements.append(
                f"UPDATE books SET {title_clause}{author_clause} "
                f"WHERE isbn = {isbn_sql} AND title IS DISTINCT FROM {_sql_str(entry['title'])};"
            )
            stats.title_statements += 1

    return statements, stats


def run_psql(sql: str) -> str:
    result = subprocess.run(
        ["docker", "exec", "-i", POSTGRES_CONTAINER, "psql", "-U", POSTGRES_USER, "-d", POSTGRES_DB],
        input=sql.encode("utf-8"),
        capture_output=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"psql a esuat: {result.stderr.decode('utf-8', errors='replace')}")
    return result.stdout.decode("utf-8", errors="replace")


def count_missing() -> dict[str, int]:
    sql = (
        "SELECT "
        "count(*) FILTER (WHERE description IS NULL) AS no_desc, "
        'count(*) FILTER (WHERE "coverUrl" IS NULL) AS no_cover '
        "FROM books WHERE isbn IS NOT NULL;"
    )
    result = subprocess.run(
        ["docker", "exec", POSTGRES_CONTAINER, "psql", "-U", POSTGRES_USER, "-d", POSTGRES_DB,
         "-t", "-A", "-F,", "-c", sql],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"psql a esuat: {result.stderr}")
    no_desc, no_cover = result.stdout.strip().split(",")
    return {"no_desc": int(no_desc), "no_cover": int(no_cover)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", default=str(DEFAULT_INPUT), help="Fisier enriched_all.json de importat")
    parser.add_argument("--dry-run", action="store_true", help="Genereaza SQL-ul dar nu-l ruleaza")
    args = parser.parse_args()

    entries = json.loads(Path(args.input).read_text(encoding="utf-8"))
    statements, stats = build_statements(entries)

    print(
        f"[import] {stats.total} intrari citite - {stats.skipped_error} cu eroare, "
        f"{stats.skipped_no_isbn} fara isbn, {stats.metadata_statements} update-uri de metadate, "
        f"{stats.title_statements} update-uri de titlu (isbnVerified=true)"
    )

    if not statements:
        print("[import] nimic de importat")
        return

    if args.dry_run:
        print("\n".join(statements))
        return

    before = count_missing()
    sql = "BEGIN;\n" + "\n".join(statements) + "\nCOMMIT;\n"
    run_psql(sql)
    after = count_missing()

    print(
        f"[import] descrieri completate: {before['no_desc'] - after['no_desc']} "
        f"(NULL: {before['no_desc']} -> {after['no_desc']})"
    )
    print(
        f"[import] coperti completate: {before['no_cover'] - after['no_cover']} "
        f"(NULL: {before['no_cover']} -> {after['no_cover']})"
    )


if __name__ == "__main__":
    main()
