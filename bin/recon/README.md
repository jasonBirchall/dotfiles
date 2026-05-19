# Recon

Personal system-inspection tooling for Fedora. A small set of opinionated
drift detectors — "what runs at boot?", "what's listening?", "what's
connected outbound?" — each runnable by hand or on a schedule.

The point is not a generic monitoring stack. Each tool answers one focused
question and reports change against a baseline I've explicitly approved.

## Drift model

Each tool maintains a **baseline**: a sorted plain-text list of approved
state on this machine. On each run, the tool computes current state and
reports additions and removals against the baseline.

The baseline is **tracked intent**, not auto-rolling state. It only
updates when explicitly re-blessed. Anomalies stay flagged until I
acknowledge them; they don't silently become the new normal on the
next run.

## Conventions

- **First run** — tool reports `no baseline found at <path>, creating it`,
  writes current state, and exits 0. Nothing to drift against yet.
- **Subsequent runs** — report additions and removals; exit non-zero on
  drift so the result is wireable into notify-on-change later.
- **Re-bless** — every tool exposes `--bless`, which overwrites the
  baseline with current state. Use after legitimate changes (installed
  Steam, enabled tailscaled, etc.).
- **Output** — human summary to stdout; full diff to
  `/tmp/recon-<tool>.diff`. Keeps machine inventory out of accidental
  screenshots and pastes.
- **Paths** — scripts resolve paths relative to `__file__`, not cwd.
  `make` invokes them via `uv run --directory`, so cwd is not the
  script's directory.

## Privacy

This repo is public. Baselines are a fingerprint of this specific
machine (installed services, scheduled jobs, etc.) and are kept
private.

- Baselines live at `<tool>/baseline/` and are gitignored.
- No git history of approved state. If wanted later, a local-only
  `git init` inside a baseline directory is a 10-second upgrade.
- Tools default to writing full diffs to a file, not stdout — see
  Output above.

## Stack

Python 3.13, managed by `uv`. `pyproject.toml` at the suite root
(`bin/recon/`).

Per-tool layout:

    <tool>/
      <tool>.py        # entry point
      test_<tool>.py   # pytest; target the pure parsing layer
      fixtures/        # captured command output for tests
      baseline/        # gitignored, machine-specific

Tests focus on the parsing layer ("given this stdout, return this
list"). The subprocess call and filesystem I/O around it stay thin
and aren't where bugs hide.

## When drift fires

A desktop notification means a recon tool exited non-zero. The diff
file at `/tmp/recon-<tool>.diff` shows what changed (`+` added, `-`
removed since the last bless).

1. **See what changed** — `cat /tmp/recon-<tool>.diff`.
2. **Decide**:
   - Recognise it? A package install, `home-manager switch`, `flatpak
     install` you ran — it's intentional → bless.
   - Don't recognise it? Investigate. Each tool's module docstring
     (`bin/recon/<tool>/<tool>.py`) has the commands worth reaching
     for first.
3. **Act**:
   - **Bless** if intentional: `make recon-<tool>-bless` (e.g.
     `make recon-autostart-bless`). Overwrites the baseline with
     current state; next run is clean.
   - **Roll back** if not: revert the change (disable the unit,
     uninstall the package, etc.), then re-run the tool. No bless
     needed — the diff goes away on its own.

Investigate-then-bless. Blessing without investigating turns the
baseline into a lie.

## Tool-specific notes

Each tool's module docstring covers its scope, deferred surfaces, and
known gaps. Read those before extending a tool — some choices (e.g.
"list-membership only, no in-place modification detection") are
deliberate.
