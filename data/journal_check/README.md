# journal_check bug references

`bug_refs.json` is the list of known journal messages used by
[`tests/console/journal_check.pm`](../../tests/console/journal_check.pm).

The test module reads the system journal and compares every line against
the entries in this file.

## Format

Example:

```json
{
    "bsc#1188238": {
        "description": "Bluetooth: hci0: command 0x0c03 tx timeout|Bluetooth: hci0: BCM: Reset failed (-110)",
        "products": {
            "sle-micro": ["5.0", "5.1"],
            "opensuse": ["Tumbleweed", "15.2", "15.3"]
        },
        "type": "ignore"
    }
}
```

Each top-level key identifies one known issue. The value is an object with
exactly three required fields: `description`, `products` and `type`. No other
fields are allowed.

### Key

Preferably a bug reference, so the entry can be traced back and eventually
retired.

| Form | Example |
| --- | --- |
| `bsc#`, `boo#`, `poo#` + number | `bsc#1188238` |
| `gh#owner/repo#` + number | `gh#OSInside/kiwi#1867` |

Several references may be joined with `|` when one message is tracked by more
than one bug, e.g. `bsc#1022525|bsc#1177461`.

A free-form slug such as `chrony` or `tpm-auth-session` is also accepted.
It should however only be used for `type: ignore`.

### `description`

A **Perl regular expression**, matched unanchored against each journal line.
Alternatives can be combined with `|`.

Because it is a regex and not a literal string, metacharacters that are meant
literally have to be escaped:

```json
"description": "Activation request for 'org\\.freedesktop\\.nm_dispatcher' failed\\."
```

Keep patterns as specific as the message allows. A pattern like `.*failed.*`
would hide unrelated errors on every product it is enabled for.

### `products`

A map of openQA `DISTRI` to the list of affected `VERSION` values. An entry only
applies when the job's `DISTRI` is a key here *and* the job's `VERSION` appears
in the corresponding array.

```json
"products": {
   "opensuse": [
         "Tumbleweed"
   ],
   "microos": [
         "Tumbleweed"
   ],
   "sle-micro": [
         "6.2"
   ],
   "sle": [
         "16.0",
         "16.1"
   ]
}
```

Supported `DISTRI` include: `opensuse`, `sle`, `microos`, `sle-micro`,
`leap-micro`.

The value must always be an **array**, even for a single version.

#### Version matching

Version comparison is a plain string equality against the job's `VERSION`, after
two transformations:

1. `VERSION` is truncated at the first `:`, so a staging job running
   `VERSION=16.1:PR-5106` matches the entry `16.1`.
2. For openSUSE only, a `VERSION` starting with `Staging:` is treated as
   `Tumbleweed`, so staging projects reuse the Tumbleweed entries.

### `type`

| Value | Effect in openQA |
| --- | --- |
| `bug` | `record_soft_failure` — the job turns *softfailed* and shows up for review |
| `ignore` | `bmwqemu::diag` only — nothing is shown in the web UI |
| `feature` | `record_info` — an informational step, the job result is unaffected |

Use `bug` with a real bug reference for anything that is a genuine defect, so it
stays visible until the bug is fixed. Reserve `ignore` for messages that are
expected and harmless (deliberate test actions, hardware quirks of the worker,
noisy-but-benign kernel chatter).

### `arch`

Optional list of architectures the entry is applied on. If set, the entry is only applied
to those architectures and ignored otherwise. If not set, all architectures will be included.

Example:

```json
"ntp-cant-synchronise": {
   "description": "Can't synchronise: no selectable sources \\([0-9]+ unreachable sources\\)",
   "products": {
      "sle": [
            "16.0",
            "16.1"
      ]
   },
   "arch": [
      "s390x"
   ],
   "type": "ignore"
}
```

## Adding an entry

1. Get the exact message from the failing job's `Unknown issue` step or from the
   uploaded `full_journal.txt`.
2. Pick the key: a bug reference if at all possible; a slug only for `ignore`.
3. Turn the message into a regex — escape metacharacters, drop volatile parts
   such as PIDs, timestamps and device numbers, but keep enough context that the
   pattern cannot match unrelated errors.
4. List only the products and versions actually affected. Do not blanket-add
   versions "just in case": that is how real regressions get hidden.
5. Choose `type` per the table above.
6. Run `make unit-test` (or `prove -l t/52_journal_check_bug_refs.t`).

## Validation

`bug_refs.json` is checked by
[`t/52_journal_check_bug_refs.t`](../../t/52_journal_check_bug_refs.t), which
runs as part of `make unit-test` and therefore in CI. It verifies that the file
is valid JSON, that it conforms to `schema.yaml`.

```bash
prove -l t/52_journal_check_bug_refs.t   # this file only
make unit-test                           # whole suite
```
