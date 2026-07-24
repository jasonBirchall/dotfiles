# Detection

Some notes on the detection setup that sits on top of auditd.

The `auditd/` directory collects telemetry — a handful of tamper watches on the
files an attacker touches to persist on my machine (`~/.ssh`, shell rc files,
systemd user units, `/etc/audit` itself). This directory does the other half:
Sigma rules that turn those raw audit records into named alerts, plus a way to
fire each alert on purpose and check it still works.

Nothing here ships telemetry to a SIEM. It's a laptop, so the whole thing runs
locally: [Zircolite](https://github.com/wagga40/Zircolite) reads
`/var/log/audit/audit.log`, matches my rules against it, and writes findings to
`~/.local/state/sigma-scan/`.

## Layout

```
detection/
  rules/<source>/    Sigma rules, grouped by telemetry source (auditd, ...)
  sigma-scan.sh      run the rules for a source over its log
  run-tests.sh       fire each rule's trigger and assert it detects
  tests/             one trigger per rule, mapped to an Atomic Red Team atomic
```

Rules are written per audit *record*, against the field names Zircolite
flattens auditd into (`type`, `key`, `comm`, `name`, …). There's no pySigma
pipeline in the middle — what you see in the YAML is what matches the log.

## Running it

```sh
make sigma-scan            # scan every source with rules and a readable log
make sigma-test            # fire each no-sudo trigger, assert the rule detects
make sigma-test SUDO=1     # also run the two that touch /etc/audit and the live ruleset
```

`sigma check` runs the SigmaHQ linter on every rule as a pre-commit hook, so a
broken rule can't land. `make sigma-test` is the stronger check: it proves the
rule actually fires on the thing it's supposed to catch, rather than just
parsing.

## The rules

Seven rules, all over auditd telemetry. Each one has a test under `tests/` that
triggers it and asserts it detected; the tests are adapted from Atomic Red Team
Linux atomics where one exists.

| Rule | Level | ATT&CK | Fires when | Test |
|---|---|---|---|---|
| `ssh_authorized_keys_modified` | high | T1098.004 | any process writes or deletes an `authorized_keys` file | `ssh_authorized_keys` |
| `ssh_dir_modified_by_unexpected_process` | medium | T1098.004 | something outside the ssh toolchain writes to `~/.ssh` | `ssh_authorized_keys` |
| `shell_rc_modified_by_unexpected_process` | medium | T1546.004 | a non-editor process writes to a shell rc file | `rc_symlink_replace` |
| `systemd_user_unit_modified` | medium | T1543.002 | a unit lands in `~/.config/systemd/user` outside home-manager | `systemd_user_unit` |
| `audit_config_modified_by_unexpected_process` | high | T1685.004 | `/etc/audit` is written by anything but the provisioning tools | `audit_config_write` |
| `audit_tamper_rule_removed` | medium | T1685.004 | a `*-tamper` watch is removed from the kernel ruleset | `audit_rule_removed` |
| `tamper_watch_failed_access` | medium | T1083 | a write to a watched path fails (`success=no`) | `failed_access` |

Each rule file carries its own `falsepositives:` block — read those before you
act on an alert. The short version: home-manager and package installs are the
usual benign causes, and each rule's allowlist is tuned to let those through.

### Two of these don't fire the way you'd expect

Writing these tests turned up two things about my own machine that I'd have got
wrong from the rule text alone.

**Shell rc files can't be appended to.** The obvious `.bashrc` persistence move
— `echo 'evil' >> ~/.bashrc`, which is exactly what Atomic Red Team's T1546.004
atomic does — fails on this box with `EACCES` and produces *no audit event at
all*. My rc files are home-manager symlinks into the read-only nix store, so
there's no inode to append to. The real tamper vector here is replacing the
managed symlink (`rm ~/.bashrc && …`), and the `rm` is what trips the watch.
That's what `rc_symlink_replace` does, and it's a more honest test than the
stock atomic. If you ever move off home-manager for shell config, revisit this.

**The systemd atomic targets the wrong path.** Atomic Red Team's T1543.002
writes to `/etc/systemd/system` — system-wide, root-owned. My watch is on the
*user* unit dir, `~/.config/systemd/user`, because that's where an unprivileged
attacker gets persistence without root. So `systemd_user_unit` overrides the
atomic's path to hit the watch. Same technique, different (and for me, more
relevant) location.

## The tests

A test performs its action, runs `sigma-scan.sh`, checks the expected rule
matched an event produced *after* the trigger fired, then cleans up after
itself. Cleanup runs on an `EXIT` trap, so a trigger that dies half-way still
restores state — backed-up files come back, symlinks get recreated, permissions
reset.

Two tests need root — writing to `/etc/audit` and deleting a live watch — so
they're skipped unless you pass `SUDO=1`. The sudo tests restore the full
ruleset from disk with `augenrules --load`, so a failed run can't leave the
watches disabled.

List what's there and how it maps to ATT&CK:

```sh
bash detection/run-tests.sh --list
```

## Adding to it

**A new rule for auditd:** drop a YAML file in `rules/auditd/`, add a test in
`tests/` (copy the closest existing one — the contract is a comment block at the
top of each). `sigma check` and `make sigma-test` will tell you if either half
is wrong.

**A new telemetry source** (say, suricata's `eve.json`): make
`rules/<source>/`, then add one line to the `SOURCES` table in `sigma-scan.sh`
mapping the source to its Zircolite input flag and default log path. No new
scripts. The scan and the pre-commit hook pick it up on the directory name.

I've deliberately kept this to custom rules over the tamper watches for now,
rather than pulling in the ~180 Linux rules Zircolite bundles. I want to learn
the false-positive rhythm of my own machine on a small set I fully understand
first. Most of the bundled rules need `execve` auditing I'm not collecting yet
anyway — that's the next step when I'm ready, and it lights up roughly
three-quarters of the public ruleset at once.
