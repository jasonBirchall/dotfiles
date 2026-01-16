#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# ///
"""Simple CLI tool to check internet connection status."""

import argparse
import socket
import time
import sys

# ANSI color codes
GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"
BOLD = "\033[1m"

TARGETS = [
    ("8.8.8.8", 53, "Google DNS"),
    ("1.1.1.1", 53, "Cloudflare DNS"),
]


def check_connection(host: str, port: int, timeout: float = 3.0) -> tuple[bool, float]:
    """Check connection to a host and return (success, latency_ms)."""
    start = time.perf_counter()
    try:
        socket.create_connection((host, port), timeout=timeout)
        latency = (time.perf_counter() - start) * 1000
        return True, latency
    except OSError:
        return False, 0.0


def is_online() -> bool:
    """Return True if any target is reachable."""
    return any(check_connection(host, port)[0] for host, port, _ in TARGETS)


def tmux_output() -> int:
    """Output minimal tmux-formatted status."""
    if is_online():
        print("#[fg=green]●#[default]")
        return 0
    else:
        print("#[fg=red]●#[default]")
        return 1


def verbose_output() -> int:
    """Output detailed connection status."""
    print(f"{BOLD}Connection Status{RESET}")
    print("-" * 30)

    any_connected = False

    for host, port, name in TARGETS:
        connected, latency = check_connection(host, port)

        if connected:
            any_connected = True
            status = f"{GREEN}Connected{RESET}"
            latency_str = f"{latency:.1f}ms"
        else:
            status = f"{RED}Disconnected{RESET}"
            latency_str = "-"

        print(f"{name:15} {status:20} {latency_str}")

    print("-" * 30)

    if any_connected:
        print(f"{GREEN}{BOLD}Online{RESET}")
        return 0
    else:
        print(f"{RED}{BOLD}Offline{RESET}")
        return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Check internet connection status")
    parser.add_argument("--tmux", "-t", action="store_true", help="Output for tmux statusbar")
    args = parser.parse_args()

    if args.tmux:
        return tmux_output()
    return verbose_output()


if __name__ == "__main__":
    sys.exit(main())
