"""Drift-detection scaffolding shared by recon tools.

Each tool defines:

- A domain type ``T`` with ``.serialize() -> str`` and a classmethod
  ``deserialize(line: str) -> T``. ``T`` must be hashable and orderable
  (frozen ``@dataclass(frozen=True, order=True)`` is the default shape).
- A ``fetch() -> list[T]`` function that runs whatever subprocess is
  appropriate and returns the current state.

Then ``run_cli(...)`` wires the standard argparse + first-run +
diff + ``--bless`` flow. The drift contract (file format, exit codes,
output discipline) is defined here and shared by every tool.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Generic, Hashable, TypeVar

T = TypeVar("T", bound=Hashable)


@dataclass(frozen=True)
class Drift(Generic[T]):
    added: tuple[T, ...]
    removed: tuple[T, ...]

    @property
    def has_drift(self) -> bool:
        return bool(self.added or self.removed)


def diff(baseline: list[T], current: list[T]) -> Drift[T]:
    base_set = set(baseline)
    curr_set = set(current)
    return Drift(
        added=tuple(sorted(curr_set - base_set)),  # type: ignore[type-var]
        removed=tuple(sorted(base_set - curr_set)),  # type: ignore[type-var]
    )


def read_baseline(
    path: Path, deserialize: Callable[[str], T]
) -> list[T] | None:
    if not path.exists():
        return None
    return [
        deserialize(line.strip())
        for line in path.read_text().splitlines()
        if line.strip()
    ]


def write_baseline(
    path: Path, items: list[T], serialize: Callable[[T], str]
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sorted_items = sorted(items)  # type: ignore[type-var]
    path.write_text("\n".join(serialize(i) for i in sorted_items) + "\n")


def format_diff(drift: Drift[T], serialize: Callable[[T], str]) -> str:
    lines = [f"-{serialize(it)}" for it in drift.removed]
    lines += [f"+{serialize(it)}" for it in drift.added]
    return "\n".join(lines) + "\n"


def run_cli(
    *,
    description: str,
    noun: str,
    baseline_path: Path,
    diff_path: Path,
    fetch: Callable[[], list[T]],
    serialize: Callable[[T], str],
    deserialize: Callable[[str], T],
) -> int:
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "--bless",
        action="store_true",
        help="Overwrite the baseline with current state.",
    )
    args = parser.parse_args()

    current = fetch()

    if args.bless:
        write_baseline(baseline_path, current, serialize)
        print(f"blessed baseline: {len(current)} {noun} at {baseline_path}")
        return 0

    baseline = read_baseline(baseline_path, deserialize)
    if baseline is None:
        write_baseline(baseline_path, current, serialize)
        print(f"no baseline found at {baseline_path}, creating it")
        return 0

    drift = diff(baseline, current)
    if not drift.has_drift:
        print(f"no drift ({len(current)} {noun})")
        return 0

    diff_path.write_text(format_diff(drift, serialize))
    print(
        f"drift detected: +{len(drift.added)} -{len(drift.removed)} "
        f"(full diff: {diff_path})",
    )
    return 1
