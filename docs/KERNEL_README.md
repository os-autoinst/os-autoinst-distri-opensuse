# Kernel test suite

This covers `lib/Kernel`, `lib/LTP`, `lib/Kselftests`, `lib/hpc`,
`lib/hpcbase.pm`, `lib/kernel.pm`, `tests/kernel`, `tests/hpc`,
`tests/ipsec`, `tests/xfstests` and other code parts where kernel-qe
is the code owner.

## Commit style

Follow the general rules from [`CONTRIBUTING.md`](../CONTRIBUTING.md)
(subject ≤72 chars, starts with a capital letter or a tag, no trailing dot,
blank line before the body). On top of that, prefix the subject with the
specific module or test file the commit touches, not a generic `kernel:`
tag — this keeps `git log --oneline` scannable and greppable per component.

Pick the prefix from what changed, examples:

* A `lib/Kernel/*.pm` module: use its package name, e.g. `Kernel::hba:`.
* `lib/LTP`: prefix with `LTP:`.
* `lib/Kselftests` (and `tests/kernel/kselftests_*.pm`): prefix with
  `Kselftests:`, optionally with a subarea, e.g. `Kselftests: BPF:`.
* A `tests/kernel/*.pm` test module: use the file's base name, e.g.
  `blktests:`.
* A feature that spans several files of the same test family: use the
  family name, e.g. `kernel/nvme:`.

Examples from history:

```
Kernel::hba: add check_fc_hosts()
blktests: gate HBA reporting on check_fc_hosts()
kernel/nvme: run_nvme.pm: build nvme-cli from source on request
LTP: upload full 'rpm -qa' package manifest
Kselftests: BPF: Install iptables
```

A change that truly cuts across the whole area with no single natural
component (e.g. a shared CI/tooling fix) can fall back to a plain
`kernel:` prefix.

**Conventional Commits (`type(scope): subject`, e.g. `fix(hpc):`,
`feat(kernel):`) are not OK.** Use the bare component prefix above
instead — a handful of `type(scope):` commits exist in history, but
they are exceptions, not the style to follow.

## Commit body

The body is where the commit earns its keep: it should read like a
short, well-argued case for the change, not a changelog entry. Cover
both sides of the story:

* **What** changed — the essence of the fix or feature, in your own
  words, at a level a reviewer unfamiliar with the code can follow.
* **Why** it changed — the failure mode, the product/version it
  affects, the constraint that forced this particular approach, and
  any alternatives you ruled out and why.

A bare link to an external tracker (Progress, Bugzilla, Jira, ...) is
never a substitute for that explanation — links rot, trackers require
extra permissions to view, and `git log` is meant to stand on its own
as a permanent record. If a ticket applies, weave its ID into the
explanation instead of dropping an isolated link:

```
Kernel::utils: add is_debugfs_mounted and enable_debugfs

Kernel test modules need to check for and enable debugfs at
/sys/kernel/debug (e.g. on SLE 16.1+, where it is disabled by default
per PED-8812). is_debugfs_mounted() mirrors blktests' _have_debugfs()
findmnt check; enable_debugfs() mounts it.
```
