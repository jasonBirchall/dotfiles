#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "typer",
#     "pathlib",
#     "gitpython",
#     "structlog"
# ]
# ///

# This script ensures my Zettelkasten directory stays in sync with my
# iCloud drive

import subprocess
import typer
from pathlib import Path
from git import Repo
import structlog


def send_notification(title: str, message: str):
    subprocess.run(
        ["osascript", "-e", f'display notification "{message}" with title "{title}"']
    )


def notify_on_error(logger, method_name, event_dict):
    if event_dict.get("level") in ("error", "warning"):
        event = event_dict.get("event", "Unknown event")
        details = ", ".join(
            f"{k}={v}"
            for k, v in event_dict.items()
            if k not in ("event", "level", "timestamp")
        )
        send_notification(
            f"sync-zettel {event_dict.get('level', 'alert')}",
            f"{event}: {details}" if details else event,
        )
    return event_dict


structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        notify_on_error,
        structlog.processors.JSONRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
)

log = structlog.get_logger("sync-zettel")

app = typer.Typer()
ZETTEL_DIR = Path.home() / "Documents" / "workarea" / "zettelkasten"


def zettel_dir_exists() -> bool:
    if Path(ZETTEL_DIR).exists():
        return True
    else:
        return False


def untracked_changes() -> bool:
    repo = Repo(ZETTEL_DIR)
    return repo.is_dirty(untracked_files=True)


def stash_changes():
    repo = Repo(ZETTEL_DIR)
    log.info("stashing_changes", directory=str(ZETTEL_DIR))
    repo.git.stash("push", "-u", "-m", "sync-zettel auto-stash")
    log.info("stash_complete")

    if untracked_changes():
        log.error("stash_failed", reason="There are still unstaged changes")


def changes_to_push() -> bool:
    log.info("checking_changes", directory=str(ZETTEL_DIR))
    repo = Repo(ZETTEL_DIR)
    branch = repo.active_branch
    tracking = branch.tracking_branch()
    if tracking is None:
        log.warning("no_tracking_branch", branch=branch.name)
        return False
    commits_ahead = list(repo.iter_commits(f"{tracking.name}..{branch.name}"))
    return len(commits_ahead) > 0


def push():
    repo = Repo(ZETTEL_DIR)
    branch = repo.active_branch
    log.info("pushing_changes", branch=branch.name)
    repo.remotes.origin.push()
    log.info("push_complete")


def pull_latest():
    repo = Repo(ZETTEL_DIR)
    branch = repo.active_branch
    log.info("pulling_latest", branch=branch.name)
    repo.remotes.origin.pull(rebase=True)
    log.info("pull_complete")


def unstash_changes():
    repo = Repo(ZETTEL_DIR)
    stash_list = repo.git.stash("list")
    if "sync-zettel auto-stash" in stash_list:
        log.info("unstashing_changes")
        repo.git.stash("pop")
        log.info("unstash_complete")


if __name__ == "__main__":
    if not zettel_dir_exists():
        raise FileExistsError

    if untracked_changes():
        stash_changes()

    pull_latest()

    if changes_to_push():
        push()

    unstash_changes()
